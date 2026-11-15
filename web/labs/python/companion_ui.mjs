import {CompanionConnection} from './companion_connection.mjs';
import {LanguageSession,DebugSession} from './companion_protocols.mjs';

const $=id=>document.getElementById(id);

/**
 * Optional local runtime features; never probes localhost until the user
 * explicitly enters a session token and presses Connect.
 */
export class LocalIde {
  constructor(hooks){
    this.hooks=hooks;this.connection=new CompanionConnection();
    this.language=null;this.debug=null;this.terminal=null;this.termUi=null;
    this.activeJob=null;this.isBusy=false;this.mounted=false;this.syncConfirmed=false;
  }
  get usingLocal(){return this.connection.connected&&$('companionMode').value==='local';}
  get debugging(){return Boolean(this.debug?.active);}
  initialize(){
    $('showCompanion').onclick=()=>document.body.classList.toggle('show-companion');
    $('connectCompanion').onclick=()=>this.connect();
    $('disconnectCompanion').onclick=()=>this.disconnect();
    $('openLocalTerminal').onclick=()=>this.startTerminal();
    $('closeLocalTerminal').onclick=()=>this.stopTerminal();
    $('createEnvironment').onclick=()=>this.createEnvironment();
    $('installNativePackages').onclick=()=>this.installPackages();
    $('enableLsp').onclick=()=>this.startLsp();
    $('nativeFormat').onclick=()=>this.nativeAction('format');
    $('nativeLint').onclick=()=>this.nativeAction('lint');
    $('nativeGit').onclick=()=>this.nativeAction('git');
    $('debugContinue').onclick=()=>this.debugCommand('continue');
    $('debugOver').onclick=()=>this.debugCommand('next');
    $('debugIn').onclick=()=>this.debugCommand('stepIn');
    $('debugOut').onclick=()=>this.debugCommand('stepOut');
    $('debugTerminate').onclick=()=>this.stopDebug();
    $('evaluateWatch').onclick=()=>this.evaluateWatch();
    $('watchExpression').onkeydown=e=>{if(e.key==='Enter')this.evaluateWatch();};
    $('companionMode').onchange=()=>this.runtimeChanged();
  }
  async connect(){
    $('connectCompanion').disabled=true;
    $('companionStatus').textContent='Connecting to local interpreter…';
    try{
      const info=await this.connection.connect($('companionUrl').value,$('companionToken').value);
      $('companionToken').value=''; // bearer token stays in RAM, not DOM or persistent storage.
      $('companionStatus').textContent='Connected · '+info.workspace;
      $('disconnectCompanion').disabled=false;
      $('openLocalTerminal').disabled=false;
      $('localEnvironment').hidden=false;
      $('companionMode').querySelector('[value="local"]').disabled=false;
      $('companionMode').value='local';
      $('localEnvDescription').textContent='Python: '+info.tools.python;
      this.runtimeChanged();
      this.hooks.status('Local companion connected (trusted OS execution)');
    }catch(e){
      this.hooks.status('Local connection failed');
      $('companionStatus').textContent=e.message;
    }finally{$('connectCompanion').disabled=false;}
  }
  disconnect(){
    this.stopTerminal();this.language?.stop();this.language=null;
    if(this.debug)this.debug.stop();this.debug=null;
    this.connection.disconnect();this.syncConfirmed=false;
    $('companionToken').value='';
    $('disconnectCompanion').disabled=true;
    $('openLocalTerminal').disabled=true;
    $('localEnvironment').hidden=true;
    $('companionMode').value='browser';
    $('companionMode').querySelector('[value="local"]').disabled=true;
    $('companionStatus').textContent='Disconnected';
    this.runtimeChanged();
  }
  runtimeChanged(){
    if(this.usingLocal){
      $('kernelFlag').textContent='Local native Python';
      $('runtimeStatus').textContent='Local interpreter connected';
    }else{
      $('kernelFlag').textContent='Browser Python';
      $('runtimeStatus').textContent='Pyodide / WebAssembly';
    }
  }
  async syncProject(){
    this.hooks.sync();
    const files=this.hooks.project().files;
    if(!this.syncConfirmed){
      const approved=confirm('This will write '+Object.keys(files).length+' browser project files into '+this.connection.health.workspace+' and OVERWRITE any files with matching names. Continue?');
      if(!approved)throw Error('Local file synchronization was cancelled.');
      this.syncConfirmed=true;
    }
    return this.connection.sync(files);
  }
  report(result,title){
    const msg=(result.stdout??'')+(result.stderr??'');
    this.hooks.output(result.stdout??'',result.stderr??'');
    this.hooks.status(title+' · '+(result.timeout?'timed out':result.exit_code===0?'completed':'failed ('+result.exit_code+')'));
    this.hooks.setPanel('output');
    return result;
  }
  async execute(mode,extra={}){
    if(!this.usingLocal)return false;
    if(this.isBusy)return true;
    this.isBusy=true;this.hooks.running(true);
    try{
      if(mode==='debug'){
        await this.syncProject();
        await this.startDebug();
        return true;
      }
      if(!['run','test','repl'].includes(mode))return false;
      this.hooks.output('','');
      this.hooks.status('Running native Python…');
      if(mode!=='repl')await this.syncProject();
      const path=mode==='test'?'/v1/tests':mode==='repl'?'/v1/snippet':'/v1/run';
      const job_id='arcside_'+crypto.randomUUID().replaceAll('-','');
      this.activeJob=job_id;
      const payload=mode==='repl'?{code:String(extra.code??''),job_id}:{entry:this.hooks.active(),timeout:120,job_id};
      const result=await this.connection.request(path,payload);
      this.report(result,mode==='test'?'Native pytest':mode==='repl'?'Native Python':'Native Python run');
      return true;
    }catch(e){
      this.hooks.output('',e.message);
      this.hooks.status('Native runtime error');
      this.hooks.setPanel('output');
      return true;
    }finally{this.isBusy=false;this.activeJob=null;this.hooks.running(false);}
  }
  async createEnvironment(){
    if(!this.connection.connected)return;
    const manager=$('environmentManager').value;
    if(!confirm('Create a '+manager+' environment inside '+this.connection.health.workspace+'?'))return;
    await this.background(async()=>{
      this.hooks.status('Creating '+manager+' environment…');
      const result=await this.connection.request('/v1/environment/create',{manager},'POST',220000);
      this.report(result,manager+' environment');
      await this.refreshEnvironment();
    });
  }
  async installPackages(){
    const packages=$('nativePackages').value.trim().split(/\s+/).filter(Boolean);
    if(!packages.length)return;
    if(!confirm('Install '+packages.join(', ')+' into this local project environment?'))return;
    await this.background(async()=>{
      this.hooks.status('Installing project packages…');
      const result=await this.connection.request('/v1/environment/install',{packages},'POST',220000);
      this.report(result,'Native package installation');
      await this.refreshEnvironment();
    });
  }
  async refreshEnvironment(){
    const info=await this.connection.request('/v1/environment',undefined,'GET',20000);
    $('localEnvDescription').textContent='Python: '+info.interpreter+' · '+(info.details.version??'');
  }
  async nativeAction(action){
    if(!this.connection.connected)return;
    await this.background(async()=>{
      if(action!=='git')await this.syncProject();
      const url=action==='git'?'/v1/git/status':action==='lint'?'/v1/lint':'/v1/format';
      const result=await this.connection.request(url,action==='git'?undefined:{entry:this.hooks.active()},
        action==='git'?'GET':'POST');
      this.report(result,action==='git'?'Git status':action==='lint'?'Ruff lint':'Ruff format');
      if(action==='format'&&result.exit_code===0){
        const updated=await this.connection.request('/v1/files/read',{entry:this.hooks.active()});
        this.hooks.replaceSource(updated.source);
        this.hooks.status('Formatted local Python and refreshed browser editor');
      }
    });
  }
  async background(work){
    try{await work();}catch(e){this.hooks.status(e.message);this.hooks.output('',e.message);this.hooks.setPanel('output');}
  }
  async startTerminal(){
    if(!this.connection.connected)return;
    if(this.terminal)return;
    $('terminalType').textContent='Connecting to real local PTY…';
    try{
      let socket;
      socket=await this.connection.socket('terminal',event=>{
        if(event.type==='output')this.appendTerminal(event.data);
        if(event.type==='error')this.appendTerminal(event.message+'\n');
        if(event.type==='closed'){this.terminal=null;$('closeLocalTerminal').disabled=true;}
      });
      this.terminal=socket;
      $('nativeTerminal').hidden=false;$('virtualTerminal').hidden=true;
      $('openLocalTerminal').disabled=true;$('closeLocalTerminal').disabled=false;
      $('terminalType').textContent='Real local shell · '+this.connection.health.workspace;
      const root=$('nativeTerminal');root.replaceChildren();
      const accessible=document.createElement('pre');accessible.id='nativeTerminalOutput';
      accessible.className='visually-hidden-terminal';accessible.setAttribute('role','log');
      accessible.setAttribute('aria-label','Local shell output');root.append(accessible);
      if(window.Terminal){
        const term=new window.Terminal({convertEol:true,cursorBlink:true,scrollback:2500,
          fontSize:12,theme:{background:'#0b1420',foreground:'#dae9f8'}});
        const fit=window.FitAddon?.FitAddon?new window.FitAddon.FitAddon():null;
        if(fit)term.loadAddon(fit);
        term.open(root);fit?.fit();
        this.termUi=term;
        term.onData(data=>socket.send(JSON.stringify({type:'input',data})));
        const cols=term.cols,rows=term.rows;
        socket.send(JSON.stringify({type:'resize',cols,rows}));
      }else{
        const log=document.createElement('pre');log.id='nativeShellLog';
        const input=document.createElement('input');input.id='nativeShellInput';
        input.placeholder='Type a command and press Enter';
        input.onkeydown=e=>{
          if(e.key==='Enter'){
            socket.send(JSON.stringify({type:'input',data:input.value+'\r'}));
            input.value='';
          }
        };
        root.append(log,input);
      }
      this.hooks.setPanel('terminal');
    }catch(e){$('terminalType').textContent=e.message;this.hooks.status(e.message);}
  }
  appendTerminal(data){
    const accessible=$('nativeTerminalOutput');
    if(accessible)accessible.textContent=(accessible.textContent+data).slice(-20000);
    if(this.termUi)this.termUi.write(data);
    else{
      const el=$('nativeShellLog');
      if(el){el.textContent=(el.textContent+data).slice(-100000);el.scrollTop=el.scrollHeight;}
    }
  }
  stopTerminal(){
    this.terminal?.close();this.terminal=null;
    this.termUi?.dispose();this.termUi=null;
    $('nativeTerminal').hidden=true;$('virtualTerminal').hidden=false;
    $('closeLocalTerminal').disabled=true;
    $('openLocalTerminal').disabled=!this.connection.connected;
    $('terminalType').textContent='Browser-only virtual commands';
  }
  async startLsp(){
    if(!this.connection.connected)return;
    this.language?.stop();
    try{
      const session=new LanguageSession(this.connection,()=>this.hooks.project().files,
        (uri,diags)=>this.renderDiagnostics(uri,diags));
      await session.start();this.language=session;
      $('enableLsp').textContent='Restart language server';
      this.hooks.status('Language server active · semantic completions/diagnostics');
    }catch(e){this.hooks.status('Language server unavailable: '+e.message);}
  }
  renderDiagnostics(uri,diags){
    const models=this.hooks.models();
    const name=Object.keys(models).find(n=>uri.endsWith('/'+encodeURIComponent(n)));
    if(!name)return;
    const monaco=window.monaco;
    monaco.editor.setModelMarkers(models[name],'arcside-lsp',diags.map(item=>({
      startLineNumber:(item.range?.start?.line??0)+1,
      startColumn:(item.range?.start?.character??0)+1,
      endLineNumber:(item.range?.end?.line??0)+1,
      endColumn:(item.range?.end?.character??1)+1,
      severity:({1:monaco.MarkerSeverity.Error,2:monaco.MarkerSeverity.Warning,
        3:monaco.MarkerSeverity.Info,4:monaco.MarkerSeverity.Hint})[item.severity]??monaco.MarkerSeverity.Info,
      message:item.message??'Language server diagnostic'
    })));
    if(name===this.hooks.active())$('problemCount').textContent=diags.length;
  }
  registerEditor(){
    if(this.mounted||!window.monaco)return;
    this.mounted=true;
    monaco.languages.registerCompletionItemProvider('python',{
      triggerCharacters:['.'],
      provideCompletionItems:async(model,pos)=>{
        if(!this.language?.channel)return {suggestions:[]};
        const name=decodeURIComponent(model.uri.path.split('/').at(-1));
        try{
          const items=await this.language.completion(name,pos.lineNumber-1,pos.column-1);
          const word=model.getWordUntilPosition(pos);
          return {suggestions:items.slice(0,100).map(item=>({
            label:item.label,kind:monaco.languages.CompletionItemKind.Function,
            detail:item.detail??'Language server',insertText:item.insertText??item.label,
            range:{startLineNumber:pos.lineNumber,endLineNumber:pos.lineNumber,
              startColumn:word.startColumn,endColumn:word.endColumn}
          }))};
        }catch{return {suggestions:[]};}
      }
    });
    monaco.languages.registerHoverProvider('python',{provideHover:async(model,pos)=>{
      if(!this.language?.channel)return null;
      const name=decodeURIComponent(model.uri.path.split('/').at(-1));
      try{
        const result=await this.language.hover(name,pos.lineNumber-1,pos.column-1);
        const raw=result?.contents;
        const text=typeof raw==='string'?raw:raw?.value??(Array.isArray(raw)?raw.map(x=>x.value??x).join('\n'):'');
        return text?{contents:[{value:text}]}:null;
      }catch{return null;}
    }});
  }
  documentChanged(name,text){this.language?.debounce(name,text);}
  async startDebug(){
    const debug=new DebugSession(this.connection,(type,event)=>this.debugEvent(type,event));
    this.debug=debug;
    this.hooks.setPanel('debugger');
    $('nativeDebugControls').hidden=false;
    $('debugWatch').hidden=false;
    $('browserTraceControls').hidden=true;
    $('traceInfo').textContent='Starting real debugpy session…';
    await debug.launch(this.hooks.active(),this.hooks.breakpoints());
    this.hooks.status('Native debugpy interactive session started');
  }
  debugEvent(type,event){
    if(type==='output'){
      const msg=event.output??'';
      if(event.category==='stderr')this.hooks.output('',msg,true);
      else this.hooks.output(msg,'',true);
    }else if(type==='stopped'){
      $('traceInfo').textContent='Paused: '+(event.reason??'breakpoint');
      this.hooks.setPanel('debugger');
    }else if(type==='stack'){
      const stack=$('debugStack');stack.replaceChildren();
      for(const frame of event){
        const row=document.createElement('button');
        row.textContent=(frame.source?.name??'python')+':'+frame.line+' · '+frame.name;
        row.onclick=()=>this.debug.frame(frame.id);
        stack.append(row);
      }
      if(event[0]){
        const first=event[0];
        const editor=this.hooks.editor();
        const file=first.source?.path?.replaceAll('\\','/').split('/').at(-1);
        if(file===this.hooks.active()&&editor){
          editor.revealLineInCenter(first.line);
          editor.setPosition({lineNumber:first.line,column:1});
        }
      }
    }else if(type==='variables'){
      $('traceVars').textContent=event.map(group=>
        group.scope+':\n'+group.variables.map(v=>'  '+v.name+' = '+v.value).join('\n')).join('\n\n');
    }else if(type==='resumed')$('traceInfo').textContent='Running · '+event.command;
    else if(type==='error')$('traceInfo').textContent='Debugger: '+event;
    else if(type==='terminated'||type==='closed')this.hooks.status('Debug session ended');
  }
  async debugCommand(name){
    try{await this.debug?.command(name);}catch(e){this.hooks.status(e.message);}
  }
  async evaluateWatch(){
    if(!this.debug?.channel||!this.debug?.stack?.length)return;
    const expression=$('watchExpression').value.trim();
    if(!expression)return;
    try{
      const data=await this.debug.channel.request('evaluate',{
        expression,frameId:this.debug.stack[0].id,context:'watch'});
      $('watchResult').textContent=data.result??'';
    }catch(e){$('watchResult').textContent=e.message;}
  }
  async stopDebug(){
    await this.debug?.stop();this.debug=null;
    $('nativeDebugControls').hidden=true;
    $('debugWatch').hidden=true;
    $('browserTraceControls').hidden=false;
  }
  async stop(){
    if(this.debugging)await this.stopDebug();
    // The local shell is deliberately independent of editor Stop.
    else if(this.usingLocal&&this.activeJob){
      const job_id=this.activeJob;
      try{
        const result=await this.connection.request('/v1/stop',{job_id});
        this.hooks.status(result.stopped?'Stopped local Python process':'Process already finished');
      }catch(e){this.hooks.status('Stop failed: '+e.message);}
    }
    else this.hooks.browserStop();
  }
}
