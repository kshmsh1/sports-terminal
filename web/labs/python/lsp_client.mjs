// JSON-RPC 2.0 client for the companion's stdio python-lsp-server bridge.
import {localFileUri} from './local_runtime.mjs';

export class ArcsideLsp {
  constructor(runtime,monaco,models,editor,status=()=>{}) {
    this.runtime=runtime;this.monaco=monaco;this.models=models;this.editor=editor;
    this.status=status;this.ws=null;this.seq=0;this.pending=new Map();
    this.opened=new Set();this.registrations=[];
  }
  get connected(){return this.ws?.readyState===WebSocket.OPEN;}
  get workspace(){return this.runtime.info?.workspace??'';}
  toUri(name){return localFileUri(this.workspace,name);}
  fromUri(uri){
    const prefix='file://'+String(this.workspace).replace(/\\/g,'/')+'/';
    return uri.startsWith(prefix)?decodeURIComponent(uri.slice(prefix.length)):null;
  }
  async start() {
    this.ws=await this.runtime.socket('lsp',message=>this.receive(message),()=>{
      for(const [,pending] of this.pending)pending.reject(Error('LSP disconnected'));
      this.pending.clear();this.status('Language server disconnected');
    });
    const initialized=await this.request('initialize',{
      processId:null,clientInfo:{name:'Arcside Python Lab',version:'0.2'},
      rootUri:'file://'+this.workspace,
      capabilities:{
        textDocument:{
          synchronization:{dynamicRegistration:false,willSave:false,didSave:false},
          completion:{completionItem:{snippetSupport:false,documentationFormat:['plaintext','markdown']}},
          hover:{contentFormat:['plaintext','markdown']},
          definition:{dynamicRegistration:false},
          publishDiagnostics:{relatedInformation:true},
        },
        workspace:{workspaceFolders:false},
      },
      workspaceFolders:null,
      initializationOptions:{},
    });
    this.notify('initialized',{});
    this.registerProviders();
    this.status('Python LSP connected');
    return initialized;
  }
  receive(message){
    if(message.type==='error'){this.status('LSP: '+message.message);return;}
    if(message.type!=='protocol')return;
    const packet=message.payload;
    if(packet.id!==undefined && (packet.result!==undefined||packet.error!==undefined)){
      const pending=this.pending.get(packet.id);
      if(pending){
        this.pending.delete(packet.id);
        if(packet.error)pending.reject(Error(packet.error.message??'LSP error'));
        else pending.resolve(packet.result);
      }
      return;
    }
    if(packet.method==='textDocument/publishDiagnostics'){
      const name=this.fromUri(packet.params?.uri??'');
      const model=name&&this.models[name];
      if(!model)return;
      const markers=(packet.params.diagnostics??[]).map(diag=>({
        severity:(diag.severity===1?this.monaco.MarkerSeverity.Error:
          diag.severity===2?this.monaco.MarkerSeverity.Warning:
          this.monaco.MarkerSeverity.Info),
        message:diag.message??'Language diagnostic',
        startLineNumber:(diag.range?.start?.line??0)+1,
        startColumn:(diag.range?.start?.character??0)+1,
        endLineNumber:(diag.range?.end?.line??0)+1,
        endColumn:(diag.range?.end?.character??1)+1,
        source:diag.source??'pylsp',
      }));
      this.monaco.editor.setModelMarkers(model,'arcside-pylsp',markers);
    }
  }
  request(method,params){
    if(!this.connected)return Promise.reject(Error('Language server not connected'));
    const id=++this.seq;
    return new Promise((resolve,reject)=>{
      this.pending.set(id,{resolve,reject});
      this.ws.send(JSON.stringify({type:'protocol',payload:{jsonrpc:'2.0',id,method,params}}));
    });
  }
  notify(method,params){
    if(this.connected)this.ws.send(JSON.stringify({
      type:'protocol',payload:{jsonrpc:'2.0',method,params},
    }));
  }
  open(name,source){
    if(!name.endsWith('.py')||!this.connected)return;
    const uri=this.toUri(name);
    if(this.opened.has(name)){
      this.notify('textDocument/didChange',{
        textDocument:{uri,version:Date.now()},
        contentChanges:[{text:source}],
      });
    }else{
      this.opened.add(name);
      this.notify('textDocument/didOpen',{
        textDocument:{uri,languageId:'python',version:1,text:source},
      });
    }
  }
  change(name,source){this.open(name,source);}
  close(name){
    if(!this.opened.delete(name))return;
    this.notify('textDocument/didClose',{textDocument:{uri:this.toUri(name)}});
  }
  async complete(model,position){
    const name=Object.keys(this.models).find(k=>this.models[k]===model);
    if(!name)return {suggestions:[]};
    const result=await this.request('textDocument/completion',{
      textDocument:{uri:this.toUri(name)},
      position:{line:position.lineNumber-1,character:position.column-1},
    });
    const items=Array.isArray(result)?result:result?.items??[];
    const word=model.getWordUntilPosition(position);
    const range={startLineNumber:position.lineNumber,endLineNumber:position.lineNumber,
      startColumn:word.startColumn,endColumn:word.endColumn};
    return {suggestions:items.slice(0,250).map(item=>({
      label:item.label,insertText:item.insertText??item.label,
      detail:item.detail,documentation:typeof item.documentation==='string'
        ?item.documentation:item.documentation?.value,
      sortText:item.sortText,
      kind:item.kind===3?this.monaco.languages.CompletionItemKind.Function:
        item.kind===7?this.monaco.languages.CompletionItemKind.Class:
        this.monaco.languages.CompletionItemKind.Text,
      range,
    }))};
  }
  async hover(model,position){
    const name=Object.keys(this.models).find(k=>this.models[k]===model);
    if(!name)return {contents:[]};
    const result=await this.request('textDocument/hover',{
      textDocument:{uri:this.toUri(name)},
      position:{line:position.lineNumber-1,character:position.column-1},
    });
    if(!result?.contents)return {contents:[]};
    const source=result.contents;
    const content=Array.isArray(source)?source:[source];
    return {contents:content.map(x=>({value:typeof x==='string'?x:x.value??''}))};
  }
  async definition(model,position){
    const name=Object.keys(this.models).find(k=>this.models[k]===model);
    if(!name)return [];
    const result=await this.request('textDocument/definition',{
      textDocument:{uri:this.toUri(name)},
      position:{line:position.lineNumber-1,character:position.column-1},
    });
    const locations=Array.isArray(result)?result:result?[result]:[];
    return locations.map(item=>{
      const other=this.fromUri(item.uri),target=other&&this.models[other];
      if(!target)return null;
      const r=item.range;
      return {uri:target.uri,range:{
        startLineNumber:r.start.line+1,startColumn:r.start.character+1,
        endLineNumber:r.end.line+1,endColumn:r.end.character+1,
      }};
    }).filter(Boolean);
  }
  registerProviders(){
    const lang=this.monaco.languages;
    this.registrations.push(lang.registerCompletionItemProvider('python',{
      triggerCharacters:['.'],
      provideCompletionItems:(model,pos)=>this.complete(model,pos).catch(()=>({suggestions:[]})),
    }));
    this.registrations.push(lang.registerHoverProvider('python',{
      provideHover:(model,pos)=>this.hover(model,pos).catch(()=>({contents:[]})),
    }));
    this.registrations.push(lang.registerDefinitionProvider('python',{
      provideDefinition:(model,pos)=>this.definition(model,pos).catch(()=>[]),
    }));
  }
  stop(){
    for(const entry of this.registrations)entry.dispose();
    this.registrations.length=0;
    if(this.connected)this.notify('shutdown',null);
    this.ws?.close();
    this.ws=null;this.opened.clear();
  }
}
