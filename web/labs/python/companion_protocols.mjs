/**
 * Minimal standards-based LSP and Debug Adapter Protocol clients over the
 * authenticated local companion's JSON WebSocket bridge.
 *
 * LSP: 3.17 textDocument sync, diagnostics, completion and hover.
 * DAP: initialize/launch, breakpoints, threads, frames, scopes, variables,
 * continue, next, step-in, step-out and terminate.
 */
function unixPath(value){return String(value).replaceAll('\\','/').replace(/\/+$/,'');}
function fileUrl(root,name){
  const path=unixPath(root)+'/'+name.replace(/^\/+/,'');
  return 'file://'+path.split('/').map((part,i)=>i===0?part:encodeURIComponent(part)).join('/');
}
function localPath(root,name){return unixPath(root)+'/'+name;}

export class RpcChannel {
  constructor(ws,kind){
    this.ws=ws;this.kind=kind;this.seq=1;this.pending=new Map();
    this.listeners=new Map();this.events=new Map();this.closed=false;
    ws.addEventListener('close',()=>this.close());
  }
  close(){
    this.closed=true;
    for(const pending of this.pending.values())pending.reject(Error(this.kind+' connection closed'));
    this.pending.clear();
    this.ws.close();
  }
  event(name,handler){this.listeners.set(name,handler);}
  waitEvent(name,timeout=20000){
    if(this.events.has(name))return Promise.resolve(this.events.get(name));
    return new Promise((resolve,reject)=>{
      const previous=this.listeners.get('wait:'+name);
      const timer=setTimeout(()=>{this.listeners.delete('wait:'+name);reject(Error('Timed out waiting for '+name));},timeout);
      this.listeners.set('wait:'+name,value=>{
        clearTimeout(timer);this.listeners.delete('wait:'+name);previous?.(value);resolve(value);
      });
    });
  }
  receive(message){
    if(this.kind==='lsp'){
      if(message.id!==undefined){
        const pending=this.pending.get(message.id);
        if(pending){this.pending.delete(message.id);
          if(message.error)pending.reject(Error(message.error.message||'LSP error'));
          else pending.resolve(message.result);}
      }
      if(message.method)this.publish(message.method,message.params);
    }else{
      if(message.type==='response'){
        const pending=this.pending.get(message.request_seq);
        if(pending){this.pending.delete(message.request_seq);
          if(!message.success)pending.reject(Error(message.message||'Debug adapter error'));
          else pending.resolve(message.body??{});}
      }
      if(message.type==='event')this.publish(message.event,message.body??{});
    }
  }
  publish(name,detail){
    this.events.set(name,detail);
    this.listeners.get(name)?.(detail);
    this.listeners.get('wait:'+name)?.(detail);
  }
  send(message){
    if(this.closed||this.ws.readyState!==WebSocket.OPEN)throw Error('Protocol session is closed');
    this.ws.send(JSON.stringify({type:'rpc',message}));
  }
  notify(name,params){
    if(this.kind==='lsp')this.send({jsonrpc:'2.0',method:name,params});
  }
  request(name,params={}){
    const id=this.seq++;
    const packet=this.kind==='lsp'
      ?{jsonrpc:'2.0',id,method:name,params}
      :{seq:id,type:'request',command:name,arguments:params};
    const promise=new Promise((resolve,reject)=>this.pending.set(id,{resolve,reject}));
    try{this.send(packet);}catch(error){this.pending.delete(id);return Promise.reject(error);}
    return promise;
  }
}

export class LanguageSession {
  constructor(connection,getSource,onDiagnostics){
    this.connection=connection;this.getSource=getSource;
    this.onDiagnostics=onDiagnostics;this.channel=null;this.version=new Map();
    this.opened=new Set();this.timer=null;
  }
  path(name){return fileUrl(this.connection.health.workspace,name);}
  async start(){
    let channel;
    const socket=await this.connection.socket('lsp',event=>{
      if(event.type==='rpc')channel?.receive(event.message);
      if(event.type==='closed')this.channel=null;
      if(event.type==='error')console.warn('Local language server:',event.message);
    });
    channel=new RpcChannel(socket,'lsp');this.channel=channel;
    channel.event('textDocument/publishDiagnostics',params=>{
      this.onDiagnostics?.(params.uri,params.diagnostics??[]);
    });
    const workspace=this.connection.health.workspace;
    await channel.request('initialize',{
      processId:null,clientInfo:{name:'Arcside',version:'0.1'},
      rootUri:fileUrl(workspace,'').replace(/\/$/,''),
      workspaceFolders:[{uri:fileUrl(workspace,'').replace(/\/$/,''),name:'Arcside Project'}],
      capabilities:{textDocument:{
        publishDiagnostics:{relatedInformation:true},
        completion:{completionItem:{snippetSupport:false}},
        hover:{contentFormat:['markdown','plaintext']}}},
      initializationOptions:{},trace:'off'
    });
    channel.notify('initialized',{});
    for(const [name,source] of Object.entries(this.getSource()))
      if(name.endsWith('.py'))this.open(name,source);
    return channel;
  }
  open(name,source){
    if(!this.channel||!name.endsWith('.py'))return;
    if(this.opened.has(name)){this.update(name,source);return;}
    this.opened.add(name);this.version.set(name,1);
    this.channel.notify('textDocument/didOpen',{textDocument:{
      uri:this.path(name),languageId:'python',version:1,text:source}});
  }
  update(name,source){
    if(!this.channel||!name.endsWith('.py'))return;
    if(!this.opened.has(name)){this.open(name,source);return;}
    const version=(this.version.get(name)||1)+1;
    this.version.set(name,version);
    this.channel.notify('textDocument/didChange',{
      textDocument:{uri:this.path(name),version},
      contentChanges:[{text:source}]
    });
  }
  debounce(name,source){
    if(!this.channel)return;
    clearTimeout(this.timer);
    this.timer=setTimeout(()=>this.update(name,source),250);
  }
  async completion(name,line,character){
    if(!this.channel)return [];
    const result=await this.channel.request('textDocument/completion',{
      textDocument:{uri:this.path(name)},position:{line,character}});
    return Array.isArray(result)?result:result?.items??[];
  }
  async hover(name,line,character){
    if(!this.channel)return null;
    return this.channel.request('textDocument/hover',{
      textDocument:{uri:this.path(name)},position:{line,character}});
  }
  stop(){
    clearTimeout(this.timer);
    if(this.channel){this.channel.notify('shutdown',{});this.channel.close();}
    this.channel=null;this.opened.clear();
  }
}

export class DebugSession {
  constructor(connection,onEvent){
    this.connection=connection;this.onEvent=onEvent;this.channel=null;
    this.threadId=null;this.stack=[];this.active=false;
  }
  async launch(entry,breakpoints=[]){
    if(this.active)await this.stop();
    let channel;
    const socket=await this.connection.socket('debug',payload=>{
      if(payload.type==='rpc')channel?.receive(payload.message);
      if(payload.type==='adapter-ready')channel?.publish('adapter-ready',payload);
      if(payload.type==='error')this.onEvent?.('error',payload.message);
      if(payload.type==='closed'){this.active=false;this.onEvent?.('closed');}
    });
    channel=new RpcChannel(socket,'dap');this.channel=channel;this.active=true;
    channel.event('stopped',async event=>{
      this.threadId=event.threadId;
      this.onEvent?.('stopped',event);
      try{await this.inspect(event.threadId);}catch(e){this.onEvent?.('error',e.message);}
    });
    channel.event('output',event=>this.onEvent?.('output',event));
    channel.event('terminated',()=>{this.active=false;this.onEvent?.('terminated');});
    channel.event('exited',event=>this.onEvent?.('exited',event));
    try{
      const adapter=await channel.waitEvent('adapter-ready');
      const target=localPath(this.connection.health.workspace,entry);
      await channel.request('initialize',{
        adapterID:'python',clientID:'arcside',clientName:'Arcside Python Lab',
        linesStartAt1:true,columnsStartAt1:true,pathFormat:'path',
        supportsVariableType:true,supportsVariablePaging:true
      });
      const initialized=channel.waitEvent('initialized');
      const launched=channel.request('launch',{
        name:'Arcside Debug',type:'python',request:'launch',
        program:target,cwd:this.connection.health.workspace,
        python:adapter.python,console:'internalConsole',redirectOutput:true,
        justMyCode:false,subProcess:false
      });
      await initialized;
      await channel.request('setBreakpoints',{
        source:{name:entry.split('/').at(-1),path:target},
        breakpoints:breakpoints.map(line=>({line})),sourceModified:false
      });
      await channel.request('configurationDone',{});
      await launched;
      this.onEvent?.('started',{target});
    }catch(e){await this.stop();throw e;}
  }
  async inspect(threadId){
    if(!this.channel)return;
    const trace=await this.channel.request('stackTrace',{threadId,startFrame:0,levels:30});
    this.stack=trace.stackFrames??[];
    this.onEvent?.('stack',this.stack);
    if(this.stack.length)await this.frame(this.stack[0].id);
  }
  async frame(frameId){
    if(!this.channel)return;
    const scopes=await this.channel.request('scopes',{frameId});
    const values=[];
    for(const scope of (scopes.scopes??[]).slice(0,4)){
      if(!scope.variablesReference)continue;
      const data=await this.channel.request('variables',{
        variablesReference:scope.variablesReference,start:0,count:100});
      values.push({scope:scope.name,variables:data.variables??[]});
    }
    this.onEvent?.('variables',values);
  }
  async command(command){
    if(!this.channel||!this.threadId)throw Error('No paused debug thread');
    await this.channel.request(command,{threadId:this.threadId});
    this.onEvent?.('resumed',{command});
  }
  async stop(){
    const channel=this.channel;
    this.channel=null;this.active=false;this.threadId=null;
    if(channel){
      try{await Promise.race([
        channel.request('disconnect',{restart:false,terminateDebuggee:true}),
        new Promise((_,reject)=>setTimeout(()=>reject(Error('disconnect timeout')),2500))
      ]);}catch{}
      channel.close();
    }
  }
}
