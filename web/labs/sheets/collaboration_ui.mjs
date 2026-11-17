import {WorkbookCollaboration} from './collaboration.mjs';

const h=(tag,{text,cls,id,type,value,placeholder}={})=>{
  const e=document.createElement(tag);
  if(text!==undefined)e.textContent=text;
  if(cls)e.className=cls;if(id)e.id=id;
  if(type)e.type=type;if(value!==undefined)e.value=value;
  if(placeholder)e.placeholder=placeholder;
  return e;
};
function field(title,input){
  const label=h('label',{cls:'collab-field'});
  label.append(h('span',{text:title}),input);
  return label;
}
function copyButton(text){
  const button=h('button',{text:'Copy'});
  button.onclick=async()=>{
    try{await navigator.clipboard.writeText(text);button.textContent='Copied';}
    catch{button.textContent='Select and copy the key manually';}
  };
  return button;
}
function readonlyKey(label,key){
  const row=h('div',{cls:'collab-secret'});
  const input=h('input',{type:'text',value:key});
  input.readOnly=true;input.setAttribute('aria-label',label+' access key');
  input.onclick=()=>input.select();
  row.append(h('strong',{text:label}),input,copyButton(key));
  return row;
}
function backup(name,value){
  const data=new Blob([JSON.stringify(value,null,2)],{type:'application/json'});
  const url=URL.createObjectURL(data),anchor=h('a');
  anchor.href=url;
  anchor.download=(name||'Arcside-workbook').replace(/[^A-Za-z0-9_-]/g,'_')+'-conflict-backup.arcside.json';
  anchor.click();
  setTimeout(()=>URL.revokeObjectURL(url),3000);
}
export function setupCollaboration(ctx){
  const $=id=>document.getElementById(id);
  const cursors=new Map();
  let role='viewer';
  const collab=new WorkbookCollaboration({
    getState:ctx.getState,
    loadState:state=>{ctx.loadState(state);cursors.clear();},
    applyRemote:ctx.applyRemote,
    onStatus:value=>{
      $('collabStatus').textContent=value;
      $('collabStatus').title=value;
    },
    onPresence:people=>{
      $('collabPeople').textContent=people.length?people.map(p=>p.name).join(' · '):'';
      $('collabPeople').title=people.map(p=>p.name+' ('+p.role+')').join('\n');
      ctx.refresh();
    },
    onCursor:message=>{
      cursors.set(message.client,message);
      ctx.refresh();
    },
    onConflict:(message,local)=>{
      backup(local.name,local);
      $('collabStatus').textContent='Edit conflict · backup downloaded';
      window.alert('A different editor updated the same cell or workbook structure. '
        +'Your local version was downloaded as a backup; the latest shared version is restored.');
    },
  });
  const shareButton=$('shareWorkbook');
  function open(){
    const wrap=h('div',{cls:'collab-dialog'});
    const intro=h('p',{text:'Collaborate across browser tabs or trusted devices connected to the same configured service. '
      +'Access keys grant workbook permissions, never Python execution. Keep keys out of URLs and public messages.'});
    const status=h('div',{id:'collabDialogStatus',cls:'collab-dialog-status'});
    const address=h('input',{id:'collabAddress',value:'http://127.0.0.1:8767'});
    const name=h('input',{id:'collabName',value:'Arcside collaborator'});
    const common=h('div',{cls:'collab-common'});
    common.append(field('Local collaboration URL',address),field('Display name',name));
    const createSection=h('section',{cls:'collab-section'});
    createSection.append(h('h3',{text:'Create a shared workbook'}));
    createSection.append(h('p',{text:'Start the collaboration service from the Arcside launcher. '
      +'Paste its one-time room creation key; sharing keys are generated for individual roles.'}));
    const admin=h('input',{id:'collabAdmin',type:'password',placeholder:'Paste room creation key'});
    const create=h('button',{id:'collabCreate',text:'Create shared room',cls:'primary'});
    const results=h('div',{id:'collabCreated',cls:'collab-generated'});
    createSection.append(field('Room creation key',admin),create,results);
    const joinSection=h('section',{cls:'collab-section'});
    joinSection.append(h('h3',{text:'Join an existing workbook'}));
    const room=h('input',{id:'collabRoom',placeholder:'24-character room ID'});
    const key=h('input',{id:'collabKey',type:'password',placeholder:'Paste owner, editor, or viewer access key'});
    const join=h('button',{id:'collabJoin',text:'Join room'});
    const leave=h('button',{id:'collabLeave',text:'Leave shared room'});
    const history=h('button',{id:'collabHistory',text:'Version history'});
    const revisionList=h('div',{id:'collabHistoryItems',cls:'collab-history'});
    joinSection.append(field('Room ID',room),field('Room access key',key),join,leave,history,revisionList);
    const note=h('p',{cls:'collab-note',text:'Local version: you can keep editing offline after leaving, '
      +'but disconnected edits do not automatically merge. Join replaces the current browser workbook '
      +'with the shared workbook; export a copy first if needed.'});
    wrap.append(intro,common,createSection,joinSection,status,note);
    const showError=error=>{status.textContent='Error: '+(error?.message??error);status.classList.add('error');};
    const showInfo=value=>{status.textContent=value;status.classList.remove('error');};
    create.onclick=async()=>{
      create.disabled=true;
      try{
        const response=await collab.create({address:address.value,adminKey:admin.value,
          snapshot:ctx.getState()});
        admin.value='';room.value=response.room;key.value=response.owner_key;
        await collab.join({address:address.value,room:response.room,key:response.owner_key,
          name:name.value});
        key.value='';
        results.replaceChildren();
        results.append(h('p',{text:'Room created. Copy these keys now: they are not shown again.'}));
        results.append(readonlyKey('Room ID',response.room));
        results.append(readonlyKey('Owner',response.owner_key));
        results.append(readonlyKey('Editor',response.editor_key));
        results.append(readonlyKey('Viewer',response.viewer_key));
        showInfo('Connected to new workbook as owner.');
      }catch(e){showError(e);}
      finally{create.disabled=false;}
    };
    join.onclick=async()=>{
      if(!confirm('Join shared room and replace this browser workbook? Download a workbook backup first if needed.'))return;
      join.disabled=true;
      try{
        const response=await collab.join({address:address.value,room:room.value.trim(),
          key:key.value.trim(),name:name.value});
        key.value='';results.replaceChildren();
        showInfo('Connected as '+response.role+' · revision '+response.revision);
      }catch(e){showError(e);}
      finally{join.disabled=false;}
    };
    history.onclick=async()=>{
      try{
        const data=await collab.history();
        revisionList.replaceChildren();
        const items=[...data.events];
        if(!items.length||items.at(-1).revision<1)
          items.push({revision:0,kind:'created',time_ms:Date.now()});
        for(const item of items){
          const entry=h('div',{cls:'collab-history-row'});
          const date=new Date(item.time_ms).toLocaleString();
          entry.append(h('span',{text:'Revision '+item.revision+' · '+item.kind+' · '+date}));
          const inspect=h('button',{text:'Preview'});
          inspect.onclick=async()=>{
            try{
              const data=await collab.version(item.revision);
              const detail=h('pre',{text:JSON.stringify(data.snapshot,null,2).slice(0,14000)});
              detail.className='collab-version-preview';
              revisionList.querySelector('.collab-version-preview')?.remove();
              revisionList.append(detail);
            }catch(e){showError(e);}
          };
          entry.append(inspect);
          if(collab.role==='owner'){
            const restore=h('button',{text:'Restore'});
            restore.onclick=async()=>{
              if(!confirm('Restore workbook revision '+item.revision+' for all collaborators? '
                +'This creates a new revision, and current shared state remains in version history.'))return;
              try{
                await collab.restore(item.revision);
                showInfo('Restoring revision '+item.revision+'…');
              }catch(e){showError(e);}
            };
            entry.append(restore);
          }
          revisionList.append(entry);
        }
      }catch(e){showError(e);}
    };
    leave.onclick=()=>{
      collab.disconnect();
      showInfo('Disconnected. This workbook remains available locally.');
      $('collabStatus').textContent='Local only';
      $('collabPeople').textContent='';
    };
    ctx.modal('Share & collaborate',wrap);
  }
  shareButton.onclick=open;
  $('collabStatus').textContent='Local only';
  return {
    get connected(){return collab.connected;},
    get readonly(){return collab.readonly;},
    get room(){return collab.room;},
    edit(){
      if(collab.readonly&&collab.connected){
        if(collab.baseline && ctx.isChanged(collab.baseline)){
          collab.onStatus('Read-only room: changes are not permitted');
          ctx.loadState({...collab.baseline,
            workbook:{...collab.baseline.workbook,active:ctx.getActiveSheet()}});
        }
        return;
      }
      collab.changed();
    },
    select(sheet,ref){collab.cursor(sheet,ref);},
    cursor(sheet,ref){
      return [...cursors.values()].find(v=>v.sheet===sheet&&v.ref===ref)||null;
    },
    disconnect:()=>collab.disconnect(),
  };
}
