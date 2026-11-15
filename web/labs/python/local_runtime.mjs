// Explicitly opt-in, local-only Arcside desktop Python companion client.
// The bearer token is never put into URL paths, query strings or persisted
// project exports. The browser Pyodide execution mode remains independent.
export function validateLocalAddress(input) {
  const url = new URL(String(input).trim());
  if (url.protocol !== 'http:' ||
      !['127.0.0.1', 'localhost'].includes(url.hostname) ||
      !url.port || url.username || url.password || url.pathname !== '/' ||
      url.search || url.hash) {
    throw Error('Local runtime must use http://127.0.0.1:PORT only');
  }
  return url.origin;
}
export function localFileUri(workspace, name) {
  const path=String(workspace).replace(/\\/g,'/').replace(/\/+$/,'');
  return 'file://' + path.split('/').map((piece,i)=>i===0?'':encodeURIComponent(piece)).join('/')+
    '/' + String(name).split('/').map(encodeURIComponent).join('/');
}
export class LocalRuntime {
  constructor() {
    this.base='http://127.0.0.1:8766';
    this.token='';
    this.info=null;
    this.activeJob=null;
    this.sockets=new Set();
    this.knownHashes={};
  }
  get connected(){return Boolean(this.token && this.info);}
  async connect(address,token) {
    const base=validateLocalAddress(address);
    if(!token || token.trim().length<20)throw Error('Paste the token printed by the local companion');
    this.base=base;
    this.token=token.trim();
    try {
      this.info=await this.get('/api/status');
      return this.info;
    }catch(e){
      this.token='';this.info=null;
      throw e;
    }
  }
  disconnect() {
    for(const socket of this.sockets)socket.close();
    this.sockets.clear();
    this.info=null;this.token='';this.activeJob=null;
    this.knownHashes={};
  }
  async request(path,body) {
    if(!this.token)throw Error('Local runtime is not connected');
    const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),300000);
    try{
      const response=await fetch(this.base+path,{
        method:body===undefined?'GET':'POST',
        headers:{'Authorization':'Bearer '+this.token,'Content-Type':'application/json'},
        body:body===undefined?undefined:JSON.stringify(body),
        signal:controller.signal,
      });
      const raw=await response.text();
      const data=raw?JSON.parse(raw):{};
      if(!response.ok)throw Error(typeof data.detail==='string'?data.detail:
        'Local runtime HTTP '+response.status);
      return data;
    }catch(e){
      if(e.name==='TypeError')throw Error('Cannot reach local runtime. Check that the companion is running and this page Origin is allowed.');
      throw e;
    }finally{clearTimeout(timer);}
  }
  get(path){return this.request(path);}
  post(path,body){return this.request(path,body);}
  async sync(files) {
    const result=await this.post('/api/sync',{files,expected:this.knownHashes});
    Object.assign(this.knownHashes,result.hashes??{});
    return result;
  }
  listFiles(){return this.get('/api/files');}
  async readFile(path){
    const result=await this.post('/api/read',{path});
    this.knownHashes[path]=result.sha256;
    return result;
  }
  async run(files,entry,mode='run',source) {
    await this.sync(files);
    const job_id=crypto.randomUUID().replace(/-/g,'');
    this.activeJob=job_id;
    const request={job_id,entry,mode:['test','coverage','profile','selection'].includes(mode)?mode:'run'};
    if(mode==='selection')request.source=source;
    try{return await this.post('/api/run',request);}
    finally{if(this.activeJob===job_id)this.activeJob=null;}
  }
  interrupt(){return this.activeJob?this.post('/api/interrupt',{job_id:this.activeJob}):Promise.resolve({interrupted:false});}
  async envs(){return this.get('/api/env');}
  async createEnv(name,manager){return this.post('/api/env/create',{name,manager});}
  async selectEnv(name){const r=await this.post('/api/env/select',{name});this.info=await this.get('/api/status');return r;}
  install(packages){return this.post('/api/env/install',{packages});}
  format(path){return this.post('/api/tool',{path,action:'format'});}
  lint(path){return this.post('/api/tool',{path,action:'lint'});}
  git(action,extra={}){return this.post('/api/git',{action,...extra});}
  async socket(channel,onMessage,onClose=()=>{}) {
    if(!this.connected)throw Error('Connect local runtime first');
    const url=this.base.replace(/^http:/,'ws:')+'/ws/'+channel;
    const ws=new WebSocket(url);
    this.sockets.add(ws);
    return new Promise((resolve,reject)=>{
      let opened=false;
      ws.onopen=()=>ws.send(JSON.stringify({type:'authenticate',token:this.token}));
      ws.onmessage=event=>{
        let data;
        try{data=JSON.parse(event.data);}catch{return;}
        if(data.type==='authenticated'&&!opened){opened=true;resolve(ws);return;}
        onMessage(data,ws);
      };
      ws.onerror=()=>{if(!opened)reject(Error('Local WebSocket connection failed'));};
      ws.onclose=event=>{
        this.sockets.delete(ws);
        if(!opened)reject(Error('WebSocket rejected: '+(event.reason||event.code)));
        onClose(event);
      };
    });
  }
}
export class LiveDebugger {
  constructor(runtime,onUpdate=()=>{}) {
    this.runtime=runtime;
    this.onUpdate=onUpdate;
    this.seq=0;this.pending=new Map();
    this.ws=null;this.threadId=null;this.frameId=null;
    this.initialized=null;
    this.closed=false;
  }
  async connect() {
    this.ws=await this.runtime.socket('dap',(msg)=>this.receive(msg),()=>{
      this.closed=true;
      for(const [,pending] of this.pending)pending.reject(Error('Debugger disconnected'));
      this.pending.clear();this.onUpdate({type:'closed'});
    });
    return this;
  }
  send(command,args={}) {
    if(!this.ws||this.ws.readyState!==WebSocket.OPEN)
      return Promise.reject(Error('Debugger is not connected'));
    const seq=++this.seq;
    const request={seq,type:'request',command,arguments:args};
    return new Promise((resolve,reject)=>{
      this.pending.set(seq,{resolve,reject});
      this.ws.send(JSON.stringify({type:'protocol',payload:request}));
    });
  }
  receive(wrapper) {
    if(wrapper.type==='error'){this.onUpdate({type:'error',message:wrapper.message});return;}
    if(wrapper.type!=='protocol')return;
    const packet=wrapper.payload;
    if(packet.type==='response'){
      const p=this.pending.get(packet.request_seq);
      if(p){this.pending.delete(packet.request_seq);
        if(packet.success===false)p.reject(Error(packet.message||'Debug adapter rejected request'));
        else p.resolve(packet.body??{});
      }
    }else if(packet.type==='event'){
      if(packet.event==='initialized'&&this.initialized)this.initialized();
      if(packet.event==='stopped'){
        this.threadId=packet.body?.threadId;
        this.onUpdate({type:'stopped',reason:packet.body?.reason});
        void this.inspect(this.threadId);
      }
      if(packet.event==='output')this.onUpdate({type:'output',...packet.body});
      if(packet.event==='terminated'||packet.event==='exited')this.onUpdate({type:'terminated'});
      if(packet.event==='continued')this.onUpdate({type:'continued'});
    }
  }
  async launch({program,cwd,python,breakpoints=[]}) {
    await this.send('initialize',{
      clientID:'arcside',clientName:'Arcside Python Lab',
      adapterID:'python',pathFormat:'path',linesStartAt1:true,columnsStartAt1:true,
      supportsVariableType:true,supportsVariablePaging:true,
      supportsRunInTerminalRequest:false,supportsProgressReporting:false,
    });
    const initialized=new Promise((resolve,reject)=>{
      this.initialized=resolve;
      setTimeout(()=>reject(Error('debugpy did not initialize in time')),30000);
    });
    // Launch returns only after debugger config has been completed.
    const launching=this.send('launch',{
      name:'Arcside local launch',type:'python',request:'launch',
      program,cwd,python,console:'internalConsole',
      justMyCode:false,redirectOutput:true,subProcess:false,
      stopOnEntry:false,
    });
    await initialized;
    await this.send('setBreakpoints',{
      source:{path:program,name:program.split('/').pop()},
      breakpoints:breakpoints.map(line=>({line})),
      lines:breakpoints,
      sourceModified:true,
    });
    await this.send('configurationDone',{});
    await launching;
    this.onUpdate({type:'launched'});
  }
  async inspect(threadId){
    if(threadId==null)return;
    try{
      const frames=(await this.send('stackTrace',{threadId,startFrame:0,levels:50})).stackFrames??[];
      this.frameId=frames[0]?.id??null;
      const scopes=this.frameId===null?[]:(await this.send('scopes',{frameId:this.frameId})).scopes??[];
      const variables=[];
      for(const scope of scopes.slice(0,4)){
        const data=await this.send('variables',{variablesReference:scope.variablesReference,start:0,count:100});
        variables.push({scope:scope.name,values:data.variables??[]});
      }
      this.onUpdate({type:'snapshot',frames,scopes:variables,threadId});
    }catch(error){this.onUpdate({type:'error',message:String(error)});}
  }
  resume(){return this.send('continue',{threadId:this.threadId});}
  next(){return this.send('next',{threadId:this.threadId});}
  stepIn(){return this.send('stepIn',{threadId:this.threadId});}
  stepOut(){return this.send('stepOut',{threadId:this.threadId});}
  pause(){return this.send('pause',{threadId:this.threadId});}
  evaluate(expression){return this.send('evaluate',{expression,frameId:this.frameId,context:'watch'});}
  async stop(){
    if(!this.ws)return;
    try{await Promise.race([this.send('disconnect',{terminateDebuggee:true}),new Promise(r=>setTimeout(r,3000))]);}
    catch{}
    this.ws.close();this.ws=null;
  }
}
