// Shared UX primitives for independently mounted Arcside Labs.
// No framework or data dependency. Commands call EXISTING UI handlers;
// keyboard/mouse interactions are deterministic and easy to audit.
export function matchCommands(commands,query){
  const words=String(query??'').toLowerCase().trim().split(/\s+/).filter(Boolean);
  return commands.filter(c=>words.every(w=>
    (c.label+' '+(c.section??'')+' '+(c.keywords??'')).toLowerCase().includes(w)))
    .sort((a,b)=>(a.order??100)-(b.order??100)||a.label.localeCompare(b.label));
}
const element=(tag,cls,text)=>{
  const el=document.createElement(tag);
  if(cls)el.className=cls;
  if(text!==undefined)el.textContent=text;
  return el;
};
export function createCommandPalette({commands,getCommands,trigger,placeholder='Search commands…'}){
  if(typeof document==='undefined')return {open(){},close(){}};
  const source=()=>getCommands?getCommands():commands??[];
  const layer=element('div','arcside-palette-layer');
  layer.hidden=true;
  const dialog=element('div','arcside-palette');
  dialog.setAttribute('role','dialog');dialog.setAttribute('aria-modal','true');
  dialog.setAttribute('aria-label','Arcside command palette');
  const input=element('input','arcside-palette-search');
  input.type='search';input.placeholder=placeholder;
  input.setAttribute('aria-label','Search workspace commands');
  input.autocomplete='off';input.spellcheck=false;
  const list=element('div','arcside-palette-results');
  list.setAttribute('role','listbox');
  const footer=element('div','arcside-palette-footer','↑ ↓ Navigate   ·   Enter Run   ·   Esc Close');
  dialog.append(input,list,footer);layer.append(dialog);document.body.append(layer);
  let focusReturn=null,results=[],active=0;
  function render(){
    results=matchCommands(source(),input.value).slice(0,65);
    active=Math.min(active,Math.max(0,results.length-1));
    list.replaceChildren();
    if(!results.length){
      list.append(element('p','arcside-palette-empty','No matching commands. Try another keyword.'));
      return;
    }
    let prev='';
    results.forEach((command,index)=>{
      if(command.section!==prev){
        prev=command.section;
        list.append(element('div','arcside-command-section',command.section||'Commands'));
      }
      const item=element('button','arcside-palette-item'+(index===active?' active':''));
      item.type='button';item.setAttribute('role','option');
      item.setAttribute('aria-selected',String(index===active));
      const name=element('span','arcside-command-name',command.label);
      item.append(name);
      if(command.shortcut)item.append(element('kbd','arcside-command-key',command.shortcut));
      if(command.disabled)item.disabled=true;
      item.onclick=()=>run(index);
      item.onmousemove=()=>{if(active!==index){active=index;highlight();}};
      list.append(item);
    });
  }
  function highlight(){
    const choices=[...list.querySelectorAll('.arcside-palette-item')];
    choices.forEach((b,i)=>{
      b.classList.toggle('active',i===active);
      b.setAttribute('aria-selected',String(i===active));
    });
    choices[active]?.scrollIntoView({block:'nearest'});
  }
  function run(index){
    const command=results[index];
    if(!command||command.disabled)return;
    close();
    try{command.run();}catch(error){
      console.error('Command palette failed:',command.label,error);
    }
  }
  function open(){
    if(!layer.hidden)return;
    focusReturn=document.activeElement;
    layer.hidden=false;input.value='';active=0;render();
    input.focus();
  }
  function close(){
    if(layer.hidden)return;
    layer.hidden=true;
    focusReturn?.focus?.();
  }
  input.oninput=()=>{active=0;render();};
  input.onkeydown=e=>{
    if(e.key==='ArrowDown'){e.preventDefault();active=(active+1)%Math.max(1,results.length);highlight();}
    if(e.key==='ArrowUp'){e.preventDefault();active=(active-1+Math.max(1,results.length))%Math.max(1,results.length);highlight();}
    if(e.key==='Enter'){e.preventDefault();run(active);}
    if(e.key==='Escape'){e.preventDefault();close();}
  };
  layer.onmousedown=e=>{if(e.target===layer)close();};
  dialog.onkeydown=e=>{
    if(e.key!=='Tab')return;
    // Keep keyboard focus inside the modal.
    const nodes=[input,...dialog.querySelectorAll('button:not(:disabled)')];
    const current=nodes.indexOf(document.activeElement);
    if(e.shiftKey&&current===0){e.preventDefault();nodes.at(-1).focus();}
    else if(!e.shiftKey&&current===nodes.length-1){e.preventDefault();input.focus();}
  };
  const button=typeof trigger==='string'?document.querySelector(trigger):trigger;
  if(button)button.addEventListener('click',open);
  document.addEventListener('keydown',e=>{
    if(e.key==='Escape'&&!layer.hidden){e.preventDefault();close();return;}
    const commandKey=e.metaKey||e.ctrlKey;
    if(commandKey&&(e.key.toLowerCase()==='k'||(e.shiftKey&&e.key.toLowerCase()==='p'))){
      e.preventDefault();e.stopPropagation();open();
    }
  },true);
  return {open,close,layer,input};
}
function prefGet(key,fallback){
  try{return localStorage.getItem(key)??fallback;}catch{return fallback;}
}
function prefSet(key,value){
  try{localStorage.setItem(key,String(value));}catch{}
}
export function setupPythonLayout(){
  const root=document.querySelector('.ide');
  if(!root)return;
  const left=document.getElementById('toggleExplorer');
  const right=document.getElementById('toggleInspector');
  const on=key=>prefGet('arcside.python.layout.'+key,'true')!=='false';
  function toggle(which,visible){
    root.classList.toggle(which+'-hidden',!visible);
    const btn=which==='explorer'?left:right;
    btn?.setAttribute('aria-pressed',String(visible));
    btn?.setAttribute('aria-label',(visible?'Hide ':'Show ')+(which==='explorer'?'file explorer':'right inspector'));
    prefSet('arcside.python.layout.'+which,visible);
  }
  toggle('explorer',on('explorer'));
  toggle('inspector',on('inspector'));
  left?.addEventListener('click',()=>toggle('explorer',root.classList.contains('explorer-hidden')));
  right?.addEventListener('click',()=>toggle('inspector',root.classList.contains('inspector-hidden')));
  for(const [id,kind,css,min,max] of [
    ['explorerHandle','horizontal','--explorer-width',145,460],
    ['inspectorHandle','reverse','--inspector-width',175,430],
    ['panelHandle','vertical','--bottom-height',160,650],
  ]){
    const grip=document.getElementById(id);
    if(!grip)continue;
    const stored=Number(prefGet('arcside.python.layout.'+id,'0'));
    if(stored>=min&&stored<=max)root.style.setProperty(css,stored+'px');
    const axis=kind==='vertical'?'y':'x';
    let start=null;
    function update(value){
      const limit=kind==='vertical'?
        Math.min(max,Math.floor(window.innerHeight*.70)):
        Math.min(max,Math.floor(window.innerWidth*.35));
      const next=Math.max(min,Math.min(limit,value));
      root.style.setProperty(css,next+'px');
      grip.setAttribute('aria-valuenow',String(next));
      prefSet('arcside.python.layout.'+id,next);
    }
    grip.addEventListener('pointerdown',e=>{
      if(e.button!==0)return;
      e.preventDefault();
      start={pos:axis==='x'?e.clientX:e.clientY,
        size:parseFloat(getComputedStyle(root).getPropertyValue(css))||
          (kind==='vertical'?255:kind==='reverse'?215:226)};
      grip.setPointerCapture(e.pointerId);
      grip.classList.add('dragging');
    });
    grip.addEventListener('pointermove',e=>{
      if(!start)return;
      const current=axis==='x'?e.clientX:e.clientY;
      const delta=current-start.pos;
      update(start.size+(kind==='horizontal'?delta:-delta));
    });
    function stop(){start=null;grip.classList.remove('dragging');}
    grip.addEventListener('pointerup',stop);
    grip.addEventListener('pointercancel',stop);
    grip.addEventListener('keydown',e=>{
      if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End'].includes(e.key))return;
      e.preventDefault();
      const now=Number.parseFloat(getComputedStyle(root).getPropertyValue(css))||
        (kind==='vertical'?255:kind==='reverse'?215:226);
      const direction=['ArrowRight','ArrowUp'].includes(e.key)?1:-1;
      update(e.key==='Home'?min:e.key==='End'?max:now+
        (kind==='reverse'?-direction:direction)*18);
    });
  }
  // Panel hidden state and resizing are layout-only. Interpreter/kernels are retained.
  return {
    toggleExplorer:()=>left?.click(),
    toggleInspector:()=>right?.click(),
  };
}
