/* Arcside Python Lab. All user files stay in this browser. */
(() => {
'use strict';
const el = id => document.getElementById(id);
const KEY = 'arcside.python.lab.project.v1';
const SAMPLE = '# Arcside Python Lab\nimport math\nimport statistics\n\nvalues = [12, 19, 21, 28, 30, 34]\nprint("Mean:", round(statistics.mean(values), 2))\nprint("Standard deviation:", round(statistics.stdev(values), 2))\n\n# Click Load scientific toolkit to use pandas, NumPy and Matplotlib.\n';
let files={'main.py':SAMPLE}, active='main.py', tabs=['main.py'];
let models={}, editor=null, worker=null, ready=false, busy=false, plain=false;
let pending=0, breakpoints=new Set(), timer=null;
const validName=name=>/^[\w][\w .-]{0,110}\.(py|csv|json|txt|tsv|md)$/i.test(name);
function output(str,kind) {
  const span=document.createElement('span');span.textContent=str;
  if(kind)span.className=kind;
  el('output').appendChild(span);
  el('output').parentElement.scrollTop=el('output').parentElement.scrollHeight;
}
function status(v){el('status').textContent=v;}
function persist() {
  clearTimeout(timer);
  timer=setTimeout(()=>{
    try {
      const data=JSON.stringify({files,active,tabs,breakpoints:[...breakpoints]});
      if(data.length>3500000){status('Browser storage limit reached; export project');return;}
      localStorage.setItem(KEY,data);
    }catch(_){status('Storage full; export project');}
  },350);
}
function restore() {
  try{
    const data=JSON.parse(localStorage.getItem(KEY)||'null');
    if(!data||!data.files)return;
    const rows=Object.entries(data.files).filter(([n,v])=>validName(n)&&typeof v==='string').slice(0,150);
    if(!rows.length)return;
    files=Object.fromEntries(rows);
    active=Object.hasOwn(files,data.active)?data.active:rows[0][0];
    tabs=Array.isArray(data.tabs)?data.tabs.filter(n=>Object.hasOwn(files,n)):[active];
    if(!tabs.includes(active))tabs.push(active);
    breakpoints=new Set((data.breakpoints||[]).filter(n=>Number.isInteger(n)&&n>0));
  }catch(_){}
}
function code(){return plain?el('plain').value:(editor?editor.getValue():files[active]);}
function store(){if(active)files[active]=code();}
function model(name){
  if(!models[name]){
    const language=name.endsWith('.py')?'python':name.endsWith('.json')?'json':'plaintext';
    const m=monaco.editor.createModel(files[name]||'',language);
    m.onDidChangeContent(()=>{files[name]=m.getValue();persist();});
    models[name]=m;
  }
  return models[name];
}
function select(name){
  if(!Object.hasOwn(files,name))return;
  store();active=name;if(!tabs.includes(name))tabs.push(name);
  if(plain)el('plain').value=files[name];
  else if(editor)editor.setModel(model(name));
  render();persist();position();
}
function render(){
  const root=el('fileList');root.replaceChildren();
  for(const name of Object.keys(files).sort()){
    const d=document.createElement('div');d.className='file'+(name===active?' active':'');
    d.textContent=(name.endsWith('.py')?'◇ ':'▤ ')+name;
    d.onclick=()=>select(name);root.append(d);
  }
  const tabRoot=el('tabs');tabRoot.replaceChildren();
  for(const name of tabs){
    if(!Object.hasOwn(files,name))continue;
    const d=document.createElement('div');d.className='tab'+(name===active?' active':'');
    const label=document.createElement('span');label.textContent=name;
    const close=document.createElement('b');close.textContent='×';
    close.onclick=e=>{
      e.stopPropagation();tabs=tabs.filter(n=>n!==name);
      if(name===active)select(tabs.at(-1)||Object.keys(files)[0]);
      render();persist();
    };
    d.append(label,close);d.onclick=()=>select(name);tabRoot.append(d);
  }
}
function createFile(){
  const name=prompt('File name (analysis.py, data.csv, …)');
  if(!name)return;
  if(!validName(name)){alert('Invalid filename or file extension');return;}
  if(!Object.hasOwn(files,name)){store();files[name]=name.endsWith('.py')?'# '+name+'\n':'';}
  select(name);
}
function renameFile(){
  const next=prompt('Rename file',active);
  if(!next||next===active)return;
  if(!validName(next)||Object.hasOwn(files,next)){alert('Invalid or duplicate filename');return;}
  store();files[next]=files[active];delete files[active];
  if(models[active]){models[active].dispose();delete models[active];}
  tabs=tabs.map(n=>n===active?next:n);active=next;select(next);
}
function deleteFile(){
  if(Object.keys(files).length===1)return;
  if(!confirm('Delete '+active+'?'))return;
  delete files[active];if(models[active]){models[active].dispose();delete models[active];}
  tabs=tabs.filter(n=>n!==active);active=Object.keys(files)[0];
  if(!tabs.includes(active))tabs.push(active);
  if(plain)el('plain').value=files[active];else if(editor)editor.setModel(model(active));
  render();persist();
}
function download(name,value,type='text/plain'){
  const url=URL.createObjectURL(new Blob([value],{type}));
  const a=document.createElement('a');a.download=name;a.href=url;a.click();
  setTimeout(()=>URL.revokeObjectURL(url),1800);
}
async function importFiles(input){
  store();
  for(const f of [...input]){
    if(f.size>3000000){output('Skipped oversized file: '+f.name+'\n','stderr');continue;}
    const text=await f.text();
    if(f.name.endsWith('.json')&&f.name.includes('project')){
      try{
        const obj=JSON.parse(text);
        if(obj&&typeof obj.files==='object'){
          for(const [n,v] of Object.entries(obj.files))
            if(validName(n)&&typeof v==='string')files[n]=v;
          continue;
        }
      }catch(_){}
    }
    if(validName(f.name))files[f.name]=text;
  }
  select(Object.keys(files).at(-1));
}
function fallback(){
  plain=true;el('editor').style.display='none';el('plain').style.display='block';
  el('plain').value=files[active];
  el('plain').oninput=()=>{files[active]=el('plain').value;persist();position();};
  status('Plain text editor fallback · Monaco unavailable');
}
function initEditor(){
  const base='https://cdn.jsdelivr.net/npm/monaco-editor@0.55.1/min/';
  if(typeof require!=='function'||!require.config){fallback();return;}
  try{
    self.MonacoEnvironment={getWorkerUrl:()=>
      URL.createObjectURL(new Blob(['self.MonacoEnvironment={baseUrl:"'+base+'"};importScripts("'+base+'vs/base/worker/workerMain.js");'],
        {type:'text/javascript'}))};
    require.config({paths:{vs:base+'vs'}});
    require(['vs/editor/editor.main'],()=>{
      monaco.editor.defineTheme('arcside-dark',{base:'vs-dark',inherit:true,rules:[],
        colors:{'editor.background':'#111820','editor.selectionBackground':'#384e70'}});
      editor=monaco.editor.create(el('editor'),{
        model:model(active),theme:'arcside-dark',fontSize:13,
        fontFamily:'ui-monospace,SFMono-Regular,Consolas,monospace',
        minimap:{enabled:true},automaticLayout:true,scrollBeyondLastLine:false,
        stickyScroll:{enabled:true},glyphMargin:true,
        bracketPairColorization:{enabled:true}
      });
      editor.onDidChangeCursorPosition(position);
      editor.addCommand(monaco.KeyMod.CtrlCmd|monaco.KeyCode.Enter,()=>execute('execute',false));
      editor.addCommand(monaco.KeyMod.CtrlCmd|monaco.KeyCode.KeyS,()=>persist());
      editor.onMouseDown(e=>{
        if(e.target.type===monaco.editor.MouseTargetType.GUTTER_GLYPH_MARGIN&&e.target.position){
          const line=e.target.position.lineNumber;
          if(!breakpoints.add(line))breakpoints.delete(line);
          drawBreakpoints();
        }
      });
      drawBreakpoints();position();
    },fallback);
  }catch(_){fallback();}
}
function position(){
  if(editor&&!plain){
    const p=editor.getPosition();
    el('position').textContent=p?'Ln '+p.lineNumber+', Col '+p.column:'';
  }else{
    const n=el('plain').value.slice(0,el('plain').selectionStart).split('\n').length;
    el('position').textContent='Ln '+n;
  }
}
function drawBreakpoints(){
  const root=el('breakpoints');root.replaceChildren();
  for(const n of [...breakpoints].sort((a,b)=>a-b)){
    const b=document.createElement('button');b.textContent='Line '+n+' ×';
    b.onclick=()=>{breakpoints.delete(n);drawBreakpoints();persist();};root.append(b);
  }
  if(editor&&!plain){
    window._bpDecorations=editor.deltaDecorations(window._bpDecorations||[],
      [...breakpoints].map(n=>({
        range:new monaco.Range(n,1,n,1),
        options:{isWholeLine:true,glyphMarginClassName:'arcside-bp'}
      })));
  }
  persist();
}
function setBusy(b){
  busy=b;
  for(const id of ['run','debug','check','science'])
    el(id).disabled=b||!ready;
  el('stop').disabled=!worker;
}
function startKernel(){
  if(worker)worker.terminate();
  ready=false;worker=new Worker('./worker.js');setBusy(true);
  status('Booting Python WebAssembly…');
  el('runtime').textContent='Loading browser Python kernel…';
  worker.onmessage=e=>{
    const d=e.data;
    if(d.type==='ready'){
      ready=true;setBusy(false);status('Python ready');
      el('runtime').textContent='Python '+d.version+' · browser kernel ready';
      output('\nPython '+d.version+' ready.\n','result');
    }else if(d.type==='fatal'){
      output('\nKernel unavailable: '+d.error+'\n','stderr');
      el('runtime').textContent='Unable to load Pyodide';
      status('Kernel failed');ready=false;setBusy(false);
    }else if(['stdout','stderr','result'].includes(d.type)){
      output(d.message,d.type==='stderr'?'stderr':d.type==='result'?'result':'');
    }else if(d.type==='status')status(d.message);
    else if(d.type==='done'){
      setBusy(false);status('Completed');
      el('elapsed').textContent=d.elapsed.toFixed(0)+' ms';
      variables(d.variables);plots(d.figures);traces(d.traces);
    }else if(d.type==='error'){
      setBusy(false);status('Execution failed');output('\n'+d.error+'\n','stderr');
    }else if(d.type==='syntax'){
      setBusy(false);output('Syntax valid\n','result');status('Syntax valid');
    }else if(d.type==='packagesReady'){
      setBusy(false);output('Scientific packages loaded.\n','result');status('Scientific toolkit ready');
    }
  };
  worker.onerror=e=>{ready=false;setBusy(false);output('Worker: '+e.message+'\n','stderr');};
}
function variables(values={}){
  const root=el('vars');root.replaceChildren();
  for(const [name,v] of Object.entries(values)){
    const row=document.createElement('div');row.style.padding='6px 0';
    row.textContent=name+' ['+v.type+']\n'+v.value;root.append(row);
  }
  if(!root.children.length)root.textContent='—';
}
function plots(images=[]){
  const root=el('plots');root.replaceChildren();
  for(const image of images){
    const img=document.createElement('img');
    img.src='data:image/png;base64,'+image;img.alt='Python Matplotlib chart';
    root.append(img);
  }
}
function traces(items=[]){
  const root=el('traceResults');root.replaceChildren();
  root.textContent=items.length+' line snapshots';
  for(const item of items.slice(0,150)){
    const b=document.createElement('button');b.className='traceitem';
    b.textContent='Line '+item.line;
    b.onclick=()=>{
      el('vars').textContent=JSON.stringify(item.locals,null,2);
      if(editor&&!plain){
        editor.revealLineInCenter(item.line);
        editor.setPosition({lineNumber:item.line,column:1});
      }
    };root.append(b);
  }
}
function execute(type,trace=false){
  if(busy||!ready)return;
  store();persist();
  if(!active.endsWith('.py')){output('Select a Python file.\n','stderr');return;}
  el('output').replaceChildren();el('plots').replaceChildren();
  setBusy(true);status('Running…');
  worker.postMessage({id:++pending,type,code:files[active],files,
    trace,breakpoints:[...breakpoints]});
}
function bind(){
  el('newfile').onclick=createFile;el('rename').onclick=renameFile;
  el('delete').onclick=deleteFile;
  el('savefile').onclick=()=>{store();download(active,files[active]);};
  el('download').onclick=()=>{store();download('arcside-python-project.json',
    JSON.stringify({format:'arcside-python-1',files,active,tabs,
      breakpoints:[...breakpoints]},null,2),'application/json');};
  el('import').onclick=()=>el('importInput').click();
  el('importInput').onchange=e=>{void importFiles(e.target.files);e.target.value='';};
  el('check').onclick=()=>execute('syntax');
  el('run').onclick=()=>execute('execute');
  el('debug').onclick=()=>execute('execute',true);
  el('stop').onclick=()=>{output('\nKernel stopped and reset.\n','stderr');startKernel();};
  el('science').onclick=()=>{
    if(!busy&&ready){setBusy(true);worker.postMessage({id:++pending,type:'packages'});}
  };
  el('clear').onclick=()=>{el('output').replaceChildren();el('plots').replaceChildren();};
  el('addBreakpoint').onclick=()=>{
    const n=Number(el('breakpoint').value);
    if(Number.isInteger(n)&&n>0){breakpoints.add(n);drawBreakpoints();}
  };
  el('plain').addEventListener('keydown',e=>{
    if((e.ctrlKey||e.metaKey)&&e.key==='Enter'){e.preventDefault();execute('execute');}
    if(e.key==='Tab'){
      e.preventDefault();const box=el('plain');
      box.setRangeText('    ',box.selectionStart,box.selectionEnd,'end');
      box.dispatchEvent(new Event('input'));
    }
  });
  window.addEventListener('beforeunload',store);
}
restore();bind();render();startKernel();initEditor();
})();