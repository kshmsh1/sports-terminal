// Real-time shared Arcside workbooks, separate from the privileged Python runtime.
// Tokens live only in page memory. Structural edits use optimistic concurrency;
// independent cell edits merge, same-cell stale writes are rejected by server.
export function collaborationEndpoint(value){
  const url=new URL(String(value).trim());
  if(url.protocol!=='http:'||!['127.0.0.1','localhost'].includes(url.hostname)
    ||!url.port||url.username||url.password||url.pathname!=='/'
    ||url.search||url.hash)throw Error('Use http://127.0.0.1:8767 for local collaboration');
  return url.origin;
}
const clone=value=>JSON.parse(JSON.stringify(value));
const comparable=state=>{
  const value=clone(state);
  // Active sheet is an individual viewer preference, not a collaborative edit.
  delete value.workbook.active;
  return value;
};
function structural(state){
  const snap=comparable(state);
  const structure={
    name:snap.name,
    sheetNames:snap.workbook.sheets.map(x=>x.name),
    widths:snap.workbook.sheets.map(x=>x.widths),
    rules:snap.workbook.rules??[],
    charts:snap.workbook.charts??[],
    pivots:snap.workbook.pivots??[],
  };
  return JSON.stringify(structure);
}
export function diffWorkbook(before,after){
  if(structural(before)!==structural(after))return {type:'replace',snapshot:after};
  const changes=[];
  const source=new Map(before.workbook.sheets.map(s=>[s.name,s]));
  for(const current of after.workbook.sheets){
    const old=source.get(current.name);
    if(!old)return {type:'replace',snapshot:after};
    for(const [field,key] of [['raw','cells'],['style','styles']]){
      const left=old[key]??{},right=current[key]??{};
      for(const ref of new Set([...Object.keys(left),...Object.keys(right)])){
        if(JSON.stringify(left[ref])===JSON.stringify(right[ref]))continue;
        changes.push({sheet:current.name,ref,field,
          value:field==='raw'?(right[ref]??''):(right[ref]??null)});
      }
    }
  }
  return changes.length?{type:'patch',changes}:null;
}
function applyPatch(snapshot,changes){
  const sheets=new Map(snapshot.workbook.sheets.map(s=>[s.name,s]));
  for(const change of changes){
    const sheet=sheets.get(change.sheet);
    if(!sheet)continue;
    const target=change.field==='raw'?sheet.cells:sheet.styles;
    if(change.field==='raw'){
      if(change.value)target[change.ref]=change.value;
      else delete target[change.ref];
    }else if(change.value===null)delete target[change.ref];
    else target[change.ref]=clone(change.value);
  }
  return snapshot;
}
const jsonHeaders=token=>({'Content-Type':'application/json','Authorization':'Bearer '+token});
export class WorkbookCollaboration{
  constructor({getState,loadState,applyRemote,onStatus=()=>{},onPresence=()=>{},onCursor=()=>{},onConflict=()=>{}}){
    this.getState=getState;this.loadState=loadState;this.applyRemote=applyRemote;
    this.onStatus=onStatus;this.onPresence=onPresence;this.onCursor=onCursor;this.onConflict=onConflict;
    this.base='http://127.0.0.1:8767';
    this.room=null;this.role=null;this.key='';this.client=null;this.revision=0;
    this.socket=null;this.baseline=null;this.pending=null;this.timer=null;
    this.queued=[];this.blocked=false;
  }
  get connected(){return this.socket?.readyState===WebSocket.OPEN&&!!this.client;}
  get readonly(){return this.role==='viewer';}
  async request(path,key,body){
    const response=await fetch(this.base+path,{
      method:body===undefined?'GET':'POST',headers:jsonHeaders(key),
      body:body===undefined?undefined:JSON.stringify(body),
    });
    const data=await response.json();
    if(!response.ok)throw Error(data.detail||'Collaboration HTTP '+response.status);
    return data;
  }
  async create({address='http://127.0.0.1:8767',adminKey,snapshot}){
    this.base=collaborationEndpoint(address);
    if(!adminKey)throw Error('Room creation key required');
    return await this.request('/api/rooms',adminKey,{snapshot});
  }
  async join({address='http://127.0.0.1:8767',room,key,name='Editor'}){
    this.disconnect();
    this.base=collaborationEndpoint(address);
    if(!/^[a-f0-9]{24}$/.test(String(room))||!key||key.length<20)
      throw Error('Enter a valid room ID and room access key');
    this.room=room;this.key=key;
    const socket=new WebSocket(this.base.replace(/^http:/,'ws:')+'/ws/rooms/'+room);
    this.socket=socket;
    return await new Promise((resolve,reject)=>{
      let started=false;
      const timeout=setTimeout(()=>{
        if(!started){socket.close();reject(Error('Collaboration connection timed out'));}
      },10000);
      socket.onopen=()=>socket.send(JSON.stringify({
        type:'authenticate',key,name:String(name).slice(0,48),
      }));
      socket.onmessage=event=>{
        let message;
        try{message=JSON.parse(event.data);}catch{return;}
        if(message.type==='welcome'){
          clearTimeout(timeout);started=true;this.client=message.client;
          this.role=message.role;this.revision=message.revision;
          this.baseline=comparable(message.snapshot);
          this.blocked=false;
          this.loadState(message.snapshot);
          this.onStatus('Shared · '+this.role+' · revision '+this.revision);
          resolve({room,role:this.role,revision:this.revision});
          return;
        }
        this.receive(message);
      };
      socket.onerror=()=>{if(!started){clearTimeout(timeout);reject(Error('Cannot connect to collaboration server'));}};
      socket.onclose=event=>{
        clearTimeout(timeout);
        if(this.socket!==socket)return;
        const expected=!this.client;
        this.client=null;this.pending=null;
        if(!started)reject(Error('Collaboration rejected: '+(event.reason||event.code)));
        if(!expected)this.onStatus('Disconnected · local workbook still available');
        this.onPresence([]);
      };
    });
  }
  disconnect(){
    clearTimeout(this.timer);
    this.timer=null;
    const old=this.socket;
    this.socket=null;this.pending=null;this.client=null;
    this.room=null;this.key='';this.role=null;this.baseline=null;this.queued=[];
    this.revision=0;this.blocked=false;
    old?.close();
    this.onPresence([]);
  }
  changed(){
    if(!this.connected||this.readonly||this.blocked)return;
    clearTimeout(this.timer);
    this.timer=setTimeout(()=>this.flush(),100);
  }
  flush(){
    if(!this.connected||this.readonly||this.pending||this.blocked)return;
    const next=comparable(this.getState());
    const diff=diffWorkbook(this.baseline,next);
    if(!diff)return;
    if(diff.type==='patch'&&diff.changes.length>1200){
      this.onStatus('Too many simultaneous cell edits to sync; edit smaller ranges.');
      this.blocked=true;return;
    }
    const id=crypto.randomUUID();
    const frame={...diff,type:diff.type,id,base:this.revision};
    if(frame.type==='replace')frame.snapshot=this.getState();
    const text=JSON.stringify(frame);
    if(text.length>650000){
      this.onStatus('Changes exceed room sync limit; export a local backup.');
      this.blocked=true;return;
    }
    this.pending={id,submitted:next};
    this.socket.send(text);
    this.onStatus('Syncing shared workbook…');
  }
  cursor(sheet,ref){
    if(this.connected)this.socket.send(JSON.stringify({type:'cursor',sheet,ref}));
  }
  receive(message){
    if(message.type==='presence'){this.onPresence(message.participants??[]);return;}
    if(message.type==='cursor'){this.onCursor(message);return;}
    if(message.type==='ack'){
      if(!this.pending||message.id!==this.pending.id)return;
      this.baseline=this.pending.submitted;
      this.pending=null;this.revision=message.revision;
      this.onStatus('Synced · '+this.role+' · revision '+this.revision);
      const queue=this.queued.splice(0);
      for(const event of queue)this.applyEvent(event);
      this.changed();return;
    }
    if(message.type==='conflict'){
      this.pending=null;this.queued=[];
      this.blocked=true;
      this.onConflict(message,this.getState());
      this.baseline=comparable(message.snapshot);
      this.revision=message.revision;
      this.loadState(message.snapshot);
      this.blocked=false;
      this.onStatus('Conflict: remote version restored; local backup downloaded');
      return;
    }
    if(message.type==='error'){
      this.pending=null;this.onStatus('Collaboration error: '+message.message);
      return;
    }
    if(message.type==='event'){
      if(this.pending){
        this.queued.push(message);return;
      }
      // Preserve local unflushed edits: send first, then apply remote change.
      if(diffWorkbook(this.baseline,comparable(this.getState()))){
        this.queued.push(message);
        this.flush();return;
      }
      this.applyEvent(message);
    }
  }
  applyEvent(event){
    // Out-of-order queued events can precede our own ACK; each delivery is
    // unique and still needs to update the baseline even if ACK is newer.
    this.revision=Math.max(this.revision,event.revision);
    if(event.kind==='replace'){
      this.baseline=comparable(event.snapshot);
      this.loadState(event.snapshot);
    }else if(event.kind==='patch'){
      applyPatch(this.baseline,event.changes);
      this.applyRemote(event.changes);
    }
    this.onStatus('Live · '+this.role+' · revision '+this.revision);
  }
}
