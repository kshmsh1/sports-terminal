/**
 * Editable notebook cells backed by one real native Jupyter kernel.
 * Source text persists locally; bearer tokens and rich outputs do not.
 */
const $=id=>document.getElementById(id);
const NOTEBOOK_KEY='arcside.notebook.v1';

export class LocalNotebook {
  constructor(connection,notice){
    this.connection=connection;this.notice=notice;
    this.socket=null;this.ready=false;this.waiting=null;this.pending=new Map();
    this.cells=[];this.next=1;
    try{
      const stored=JSON.parse(localStorage.getItem(NOTEBOOK_KEY));
      if(Array.isArray(stored?.cells))this.cells=stored.cells.slice(0,100)
        .filter(x=>typeof x.code==='string'&&x.code.length<=250000)
        .map(x=>({id:Number(x.id)||this.next++,code:x.code,outputs:[]}));
    }catch{}
    if(!this.cells.length)this.cells=[{id:this.next++,code:'x = [2, 3, 5, 7]\nprint("Mean:",sum(x)/len(x))',outputs:[]}];
    this.next=Math.max(this.next,1,...this.cells.map(c=>c.id+1));
  }
  initialize(){
    $('startNotebook').onclick=()=>this.start().catch(e=>this.notice(e.message));
    $('addNotebookCell').onclick=()=>this.add();
    $('runNotebookAll').onclick=()=>this.runAll();
    $('interruptNotebook').onclick=()=>this.send({type:'interrupt'});
    $('restartNotebook').onclick=()=>this.send({type:'restart'});
    $('exportNotebook').onclick=()=>this.export();
    $('importNotebook').onclick=()=>$('notebookPicker').click();
    $('notebookPicker').onchange=e=>this.import(e);
    $('expandNotebook').onclick=()=>{
      const panel=document.querySelector('.bottom-panel');
      panel.classList.toggle('notebook-expanded');
      $('expandNotebook').textContent=panel.classList.contains('notebook-expanded')?'Collapse':'Expand';
    };
    this.render();
  }
  connectionChanged(){
    $('startNotebook').disabled=!this.connection.connected;
    if(!this.connection.connected)this.disconnect();
  }
  persist(){
    try{
      localStorage.setItem(NOTEBOOK_KEY,JSON.stringify({
        version:1,cells:this.cells.map(c=>({id:c.id,code:c.code}))
      }));
    }catch(e){this.notice('Notebook sources could not be saved: '+e.message);}
  }
  add(code='',index=this.cells.length){
    this.cells.splice(index,0,{id:this.next++,code,outputs:[]});
    this.persist();this.render();
  }
  remove(id){
    if(this.cells.length<2){this.notice('Notebook requires at least one cell');return;}
    this.cells=this.cells.filter(c=>c.id!==id);this.persist();this.render();
  }
  async start(){
    if(this.ready)return;
    if(this.waiting)return this.waiting;
    if(!this.connection.connected)throw Error('Connect the trusted local Python companion first.');
    $('notebookStatus').textContent='Launching Jupyter kernel…';
    let resolveReady,rejectReady;
    const readyPromise=new Promise((resolve,reject)=>{resolveReady=resolve;rejectReady=reject;});
    this.waiting=readyPromise;
    try{
      this.socket=await this.connection.socket('notebook',payload=>{
        if(payload.type==='kernel-ready'){
          this.ready=true;
          $('notebookStatus').textContent='Jupyter kernel ready · '+payload.python;
          resolveReady();
        }else if(payload.type==='error'){
          $('notebookStatus').textContent=payload.message;
          rejectReady(Error(payload.message));
        }else if(payload.type==='closed'){
          this.ready=false;this.socket=null;
          $('notebookStatus').textContent='Notebook disconnected';
          rejectReady(Error('Notebook socket closed'));
        }else this.receive(payload);
      });
      await Promise.race([readyPromise,new Promise((_,reject)=>
        setTimeout(()=>reject(Error('Kernel initialization timed out')),45000))]);
    }catch(e){this.socket?.close();this.socket=null;this.ready=false;throw e;}
    finally{this.waiting=null;}
  }
  send(message){
    if(!this.socket||this.socket.readyState!==WebSocket.OPEN){
      this.notice('Jupyter kernel not running');return;
    }
    this.socket.send(JSON.stringify(message));
  }
  async runCell(id){
    const cell=this.cells.find(c=>c.id===id);
    if(!cell)return;
    try{await this.start();}
    catch(e){this.notice(e.message);return;}
    if(this.pending.size){this.notice('One cell is already running');return;}
    cell.outputs=[];this.renderOutputs(cell);
    $('notebookStatus').textContent='Executing cell '+id+'…';
    const promise=new Promise((resolve,reject)=>this.pending.set(String(id),{resolve,reject}));
    this.send({type:'execute',id:String(id),code:cell.code});
    try{await promise;}catch(e){this.notice(e.message);}
  }
  async runAll(){
    for(const cell of [...this.cells])await this.runCell(cell.id);
  }
  receive(payload){
    if(payload.type==='interrupted'){
      $('notebookStatus').textContent='Interrupt requested';return;
    }
    const pending=this.pending.get(String(payload.id));
    if(payload.type==='busy'){this.notice('Kernel busy: finish current cell first');pending?.reject(Error('Busy'));return;}
    const cell=this.cells.find(c=>String(c.id)===String(payload.id));
    if(!cell)return;
    if(payload.type==='stream'){
      cell.outputs.push({kind:'text',text:String(payload.text??'')});
    }else if(payload.type==='display'){
      cell.outputs.push({kind:'text',text:String(payload.text??'')});
    }else if(payload.type==='image'){
      cell.outputs.push({kind:'image',data:String(payload.data??'')});
    }else if(payload.type==='error-output'){
      cell.outputs.push({kind:'error',text:String(payload.traceback??'')});
    }else if(payload.type==='finished'){
      $('notebookStatus').textContent='Cell '+cell.id+' finished';
      if(pending){pending.resolve();this.pending.delete(String(payload.id));}
    }
    this.renderOutputs(cell);
  }
  render(){
    const root=$('notebookCells');root.replaceChildren();
    for(const cell of this.cells){
      const article=document.createElement('article');article.className='notebook-cell';
      article.dataset.cellId=String(cell.id);
      const actions=document.createElement('div');actions.className='notebook-cell-actions';
      const title=document.createElement('span');title.textContent='In [ ] · Cell '+cell.id;
      const run=document.createElement('button');run.textContent='Run cell';run.onclick=()=>this.runCell(cell.id);
      const insert=document.createElement('button');insert.textContent='+ Below';insert.onclick=()=>{
        this.add('',this.cells.findIndex(c=>c.id===cell.id)+1);
      };
      const del=document.createElement('button');del.textContent='Delete';del.onclick=()=>this.remove(cell.id);
      actions.append(title,run,insert,del);
      const input=document.createElement('textarea');input.className='notebook-code';
      input.spellcheck=false;input.value=cell.code;input.setAttribute('aria-label','Python notebook cell '+cell.id);
      input.oninput=()=>{cell.code=input.value;this.persist();};
      input.onkeydown=e=>{
        if((e.ctrlKey||e.metaKey)&&e.key==='Enter'){
          e.preventDefault();this.runCell(cell.id);
        }
        if(e.key==='Tab'){e.preventDefault();input.setRangeText('    ',input.selectionStart,input.selectionEnd,'end');cell.code=input.value;this.persist();}
      };
      const output=document.createElement('div');output.className='notebook-cell-output';
      output.dataset.output=String(cell.id);
      article.append(actions,input,output);root.append(article);
      this.renderOutputs(cell);
    }
  }
  renderOutputs(cell){
    const root=document.querySelector('[data-output="'+cell.id+'"]');
    if(!root)return;
    root.replaceChildren();
    for(const item of cell.outputs){
      if(item.kind==='image'){
        const img=document.createElement('img');img.src='data:image/png;base64,'+item.data;
        img.alt='Python notebook plot';root.append(img);
      }else{
        const pre=document.createElement('pre');pre.textContent=item.text;
        if(item.kind==='error')pre.className='notebook-error';
        root.append(pre);
      }
    }
  }
  export(){
    const notebook={
      cells:this.cells.map(cell=>({
        cell_type:'code',execution_count:null,metadata:{},
        source:cell.code.split(/(?<=\n)/g),outputs:[]
      })),
      metadata:{kernelspec:{display_name:'Python 3',language:'python',name:'python3'},
                language_info:{name:'python'}},
      nbformat:4,nbformat_minor:5
    };
    const blob=new Blob([JSON.stringify(notebook,null,2)],{type:'application/json'});
    const url=URL.createObjectURL(blob),link=document.createElement('a');
    link.href=url;link.download='arcside-notebook.ipynb';link.click();
    setTimeout(()=>URL.revokeObjectURL(url),2000);
  }
  async import(event){
    const file=event.target.files?.[0];
    if(!file)return;
    try{
      if(file.size>4_000_000)throw Error('Notebook exceeds 4 MB');
      const parsed=JSON.parse(await file.text());
      if(parsed.nbformat!==4||!Array.isArray(parsed.cells))throw Error('Not a Jupyter v4 notebook');
      const cells=parsed.cells.filter(c=>c.cell_type==='code').slice(0,100);
      this.cells=cells.map(c=>({
        id:this.next++,
        code:(Array.isArray(c.source)?c.source.join(''):String(c.source??'')).slice(0,250000),
        outputs:[]
      }));
      if(!this.cells.length)this.add('');
      this.persist();this.render();
    }catch(e){this.notice('Notebook import failed: '+e.message);}
    event.target.value='';
  }
  disconnect(){
    for(const entry of this.pending.values())entry.reject(Error('Kernel disconnected'));
    this.pending.clear();this.socket?.close();
    this.socket=null;this.ready=false;this.waiting=null;
    $('notebookStatus').textContent='Connect the local companion to restart Jupyter';
  }
}
