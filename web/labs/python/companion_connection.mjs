/**
 * Explicit, in-memory connection to a local Arcside Python companion.
 * No token is stored in localStorage, URL query strings or project exports.
 */
export class CompanionConnection {
  constructor() {
    this.base='';
    this.token='';
    this.health=null;
  }
  get connected(){return Boolean(this.health);}
  async connect(address,token){
    const url=new URL(address);
    if(url.protocol!=='http:' || !['127.0.0.1','localhost','[::1]'].includes(url.hostname)
      || (url.pathname!=='/'&&url.pathname!=='') || url.search||url.hash)
      throw Error('Companion must use http://127.0.0.1:8766 (loopback only).');
    if(!token?.trim())throw Error('Paste the temporary token printed by the local companion.');
    this.base=url.origin;
    this.token=token.trim();
    try{
      this.health=await this.request('/v1/health',undefined,'GET',8500);
      return this.health;
    }catch(e){
      this.disconnect();
      throw e;
    }
  }
  disconnect(){this.health=null;this.token='';this.base='';}
  async request(path,body,method='POST',timeout=150000){
    if(!this.base||!this.token)throw Error('Not connected to local companion.');
    const options={method,headers:{'X-Arcside-Token':this.token}};
    if(body!==undefined){
      options.headers['Content-Type']='application/json';
      options.body=JSON.stringify(body);
    }
    options.signal=AbortSignal.timeout(timeout);
    let response;
    try{response=await fetch(this.base+path,options);}
    catch(e){throw Error('Companion unavailable or browser blocked loopback access: '+e.message);}
    let data;
    try{data=await response.json();}catch{throw Error('Unexpected companion response ('+response.status+').');}
    if(!response.ok)throw Error(typeof data.detail==='string'?data.detail:'Companion error '+response.status);
    return data;
  }
  async sync(files){return this.request('/v1/files/sync',{files});}
  async socket(channel,onMessage){
    if(!this.connected)throw Error('Connect to companion first.');
    const address=this.base.replace(/^http:/,'ws:')+'/v1/ws/'+channel;
    return new Promise((resolve,reject)=>{
      const ws=new WebSocket(address);
      let done=false;
      const timer=setTimeout(()=>{if(!done){done=true;ws.close();reject(Error(channel+' connection timed out'));}},15000);
      ws.onopen=()=>ws.send(JSON.stringify({type:'auth',token:this.token}));
      ws.onmessage=e=>{
        let payload;
        try{payload=JSON.parse(e.data);}catch{return;}
        if(payload.type==='ready'&&!done){
          done=true;clearTimeout(timer);resolve(ws);return;
        }
        if(payload.type==='error'&&!done){
          done=true;clearTimeout(timer);ws.close();reject(Error(payload.message));return;
        }
        onMessage?.(payload,ws);
      };
      ws.onerror=()=>{
        if(!done){done=true;clearTimeout(timer);reject(Error('Cannot establish local '+channel+' WebSocket'));}
      };
      ws.onclose=()=>{
        if(!done){done=true;clearTimeout(timer);reject(Error('Local '+channel+' WebSocket closed'));}
        else onMessage?.({type:'closed'},ws);
      };
    });
  }
}
