import {setupPowerPanel} from './power_panel.mjs';
const $=id=>document.getElementById(id);
const KEY='arcside.pythonlab.v1';
const defaults={
'main.py':'# Arcside Python Lab — browser Python with NumPy, pandas, and Matplotlib\nimport numpy as np\nimport pandas as pd\n\nvalues = np.array([18, 24, 29, 34, 40, 51], dtype=float)\nframe = pd.DataFrame({"observation": range(1, len(values) + 1), "value": values})\nprint(frame.to_string(index=False))\nprint("\\nMean:", round(values.mean(), 2))\n# import matplotlib.pyplot as plt\n# plt.plot(values, marker="o")\n# plt.title("Arcside analysis")\n',
'test_math.py':'import unittest\n\nclass BasicMathTests(unittest.TestCase):\n    def test_addition(self):\n        self.assertEqual(2 + 2, 4)\n\n    def test_average(self):\n        self.assertAlmostEqual(sum([2, 4, 6]) / 3, 4)\n',
'README.md':'# Arcside Python Lab\nProject files are kept in your browser. Execution uses Pyodide. Virtual environments, OS terminals and live debugpy sessions require a separate desktop runtime.\n'
};
let project={name:'Untitled Project',entry:'main.py',files:{...defaults}},active='main.py',opened=['main.py'];
let models={},editor=null,worker=null,busy=false,requests=new Map(),nextId=1,breakpoints={},decorations=[];
let diagnostics=[],trace=[],traceIndex=0,figures=[],variables=[],changedFiles=new Set(),saveTimer,lintTimer;
let power=null;
try {
const saved=JSON.parse(localStorage.getItem(KEY));
if(saved?.version===1&&saved.project?.files&&Object.keys(saved.project.files).length){
 project=saved.project;active=saved.active in project.files?saved.active:Object.keys(project.files)[0];
 opened=Array.isArray(saved.opened)?saved.opened.filter(n=>n in project.files):[active];
 breakpoints=saved.breakpoints??{};
}
}catch(e){console.warn('Project load:',e);}
if(!opened.includes(active))opened.unshift(active);
$('projectName').value=project.name;
function save(){
 try{
 localStorage.setItem(KEY,JSON.stringify({version:1,project,active,opened,breakpoints}));
 changedFiles.clear();$('dirtyStatus').textContent='Saved locally';
 }catch(e){$('dirtyStatus').textContent='Storage full: export project';}
}
function dirty(name=active){
 power?.onEdit(name,project.files[name]);
 changedFiles.add(name);$('dirtyStatus').textContent='Unsaved changes…';
 clearTimeout(saveTimer);saveTimer=setTimeout(save,450);
 renderFiles();renderTabs();renderOutline();
}
function status(s){$('status').textContent=s;$('runtimeStatus').textContent=s;}
function running(value){
 busy=value;
 for(const id of ['run','debug','runTests','runSelection','replRun','install'])$(id).disabled=value;
 $('stop').disabled=!value;
}
function kernel(){
 if(worker)return worker;
 worker=new Worker('./kernel.worker.js');
 worker.onmessage=({data})=>{
 if(data.type==='status'){$('kernelFlag').textContent=data.text;status(data.text);return;}
 const req=requests.get(data.id);
 if(req){requests.delete(data.id);req.resolve(data);}
 };
 worker.onerror=e=>{
 for(const req of requests.values())req.reject(Error(e.message||'Python kernel error'));
 requests.clear();running(false);status('Kernel error');
 };
 return worker;
}
async function send(mode,extra={}){
 if(busy)throw Error('Kernel busy. Stop it to restart.');
 running(true);const id=nextId++;
 const promise=new Promise((resolve,reject)=>requests.set(id,{resolve,reject}));
 kernel().postMessage({type:mode,mode,id,entry:active,files:project.files,code:code(),...extra});
 try{return await promise;}finally{running(false);}
}
function terminate(){
 if(power?.active){void power.stop();return;}
 if(worker)worker.terminate();worker=null;
 for(const req of requests.values())req.reject(Error('Kernel terminated'));
 requests.clear();running(false);status('Stopped — next Run restarts Python');
 $('kernelFlag').textContent='Kernel stopped';
}
$('stop').onclick=terminate;
function language(name){
 if(name.endsWith('.py'))return 'python';
 if(name.endsWith('.json'))return 'json';
 if(name.endsWith('.md'))return 'markdown';
 return 'plaintext';
}
function code(){return editor&&models[active]?models[active].getValue():$('fallback').hidden?project.files[active]:$('fallback').value;}
function sync(){project.files[active]=code();}
function model(name){
 if(models[name])return models[name];
 const uri=monaco.Uri.parse('file:///arcside/'+encodeURIComponent(name));
 const m=monaco.editor.createModel(project.files[name]??'',language(name),uri);
 m.onDidChangeContent(()=>{
 project.files[name]=m.getValue();dirty(name);
 if(name===active){clearTimeout(lintTimer);lintTimer=setTimeout(analyze,1300);}
 });
 models[name]=m;return m;
}
function initEditor(){
 if(!window.require){useFallback();return;}
 window.require.config({paths:{vs:'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs'}});
 window.MonacoEnvironment={getWorkerUrl:()=>{
 const script="self.MonacoEnvironment={baseUrl:'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/'};importScripts('https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs/base/worker/workerMain.js');";
 return 'data:text/javascript;charset=utf-8,'+encodeURIComponent(script);
 }};
 window.require(['vs/editor/editor.main'],()=>{
 monaco.editor.defineTheme('arcside',{base:'vs-dark',inherit:true,rules:[
 {token:'comment',foreground:'7891aa',fontStyle:'italic'},
 {token:'keyword',foreground:'a4a4ff'},{token:'string',foreground:'a7dcab'},
 {token:'number',foreground:'f2b882'}],colors:{'editor.background':'#0e1623','editor.lineHighlightBackground':'#1a2b40'}});
 editor=monaco.editor.create($('editor'),{
 model:model(active),theme:'arcside',automaticLayout:true,fontSize:13,
 fontFamily:'Menlo,Consolas,monospace',lineNumbers:'on',minimap:{enabled:true},
 glyphMargin:true,scrollBeyondLastLine:false,tabSize:4,insertSpaces:true,
 bracketPairColorization:{enabled:true},guides:{indentation:true},quickSuggestions:true
 });
 editor.onDidChangeCursorPosition(e=>$('cursorPosition').textContent='Ln '+e.position.lineNumber+', Col '+e.position.column);
 editor.onMouseDown(e=>{
 if(e.target.type===monaco.editor.MouseTargetType.GUTTER_GLYPH_MARGIN){
 const line=e.target.position?.lineNumber;if(line)toggleBreakpoint(line);
 }});
 editor.addAction({id:'arcside-run',label:'Run Python',keybindings:[monaco.KeyMod.CtrlCmd|monaco.KeyCode.Enter],run:()=>execute('run')});
 editor.addAction({id:'arcside-debug',label:'Trace execution',keybindings:[monaco.KeyCode.F5],run:()=>execute('debug')});
 editor.addAction({id:'arcside-rename',label:'Rename selected token (text only)',keybindings:[monaco.KeyMod.CtrlCmd|monaco.KeyMod.Shift|monaco.KeyCode.KeyR],run:renameToken});
 monaco.languages.registerCompletionItemProvider('python',{provideCompletionItems(m,pos){
 const word=m.getWordUntilPosition(pos);
 const words=['print','range','len','sum','min','max','enumerate','zip','list','dict','set','tuple','str','int','float','sorted','lambda','def','class','return','import','from','as','if','else','elif','for','while','try','except','with','assert','yield','True','False','None','self','np','pd','plt'];
 const local=[...m.getValue().matchAll(/^\s*(?:def|class)\s+([A-Za-z_]\w*)|^\s*([A-Za-z_]\w*)\s*=/gm)].map(v=>v[1]??v[2]);
 return {suggestions:[...new Set([...words,...local])].map(label=>({
 label,kind:monaco.languages.CompletionItemKind.Text,insertText:label,
 range:{startLineNumber:pos.lineNumber,endLineNumber:pos.lineNumber,startColumn:word.startColumn,endColumn:word.endColumn}
 }))};
 }});
 $('fallback').hidden=true;status('Editor ready; Python loads on Run');
 showBreakpoints();renderOutline();
 },()=>useFallback());
}
function useFallback(){
 $('fallback').hidden=false;$('fallback').value=project.files[active];
 status('Basic editor mode — Monaco CDN unavailable');
}
function renameToken(){
 if(!editor)return;
 const m=models[active],sel=editor.getSelection(),highlight=m.getValueInRange(sel).trim();
 const word=/^[A-Za-z_]\w*$/.test(highlight)?highlight:m.getWordAtPosition(editor.getPosition())?.word;
 if(!word)return;
 const next=prompt('Text-only rename (not semantic refactoring)',word);
 if(!next||!/^[A-Za-z_]\w*$/.test(next))return;
 m.setValue(m.getValue().replace(new RegExp('\\b'+word+'\\b','g'),next));
}
$('fallback').oninput=e=>{project.files[active]=e.target.value;dirty();};
function toggleBreakpoint(line){
 const set=new Set(breakpoints[active]??[]);
 if(set.has(line))set.delete(line);else set.add(line);
 breakpoints[active]=[...set].sort((a,b)=>a-b);
 showBreakpoints();dirty();
}
function showBreakpoints(){
 if(!editor)return;
 decorations=editor.deltaDecorations(decorations,(breakpoints[active]??[]).map(line=>({
 range:new monaco.Range(line,1,line,1),options:{glyphMarginClassName:'arcside-breakpoint',glyphMarginHoverMessage:{value:'Trace breakpoint'}}
 })));
}
function setActive(name){
 if(!(name in project.files))return;
 if(name!==active && active in project.files)sync();
 active=name;
 if(!opened.includes(name))opened.push(name);
 if(editor)editor.setModel(model(name));
 else $('fallback').value=project.files[name];
 $('activePath').textContent=name;
 renderFiles();renderTabs();renderOutline();showBreakpoints();updateProblems([]);save();
 power?.onActive(name,project.files[name]);
}
function renderFiles(){
 const root=$('files');root.replaceChildren();
 for(const name of Object.keys(project.files).sort()){
 const div=document.createElement('div');div.className='file'+(active===name?' selected':'');div.role='treeitem';
 const icon=document.createElement('span');icon.className='file-icon';icon.textContent=name.endsWith('.py')?'Py':'◇';
 const text=document.createElement('span');text.className='filename';text.textContent=name;
 div.append(icon,text);div.onclick=()=>setActive(name);root.appendChild(div);
 }
 $('projectLabel').textContent=project.name.toUpperCase();
}
function renderTabs(){
 const root=$('tabs');root.replaceChildren();
 for(const name of opened.filter(n=>n in project.files)){
 const tab=document.createElement('button');tab.className='tab'+(active===name?' active':'');tab.onclick=()=>setActive(name);
 const title=document.createElement('span');title.textContent=name;tab.append(title);
 if(changedFiles.has(name)){const dot=document.createElement('span');dot.className='unsaved';dot.textContent='●';tab.append(dot);}
 const close=document.createElement('span');close.className='close';close.textContent='×';
 close.onclick=e=>{e.stopPropagation();opened=opened.filter(n=>n!==name);if(active===name)setActive(opened[0]??Object.keys(project.files)[0]);else renderTabs();save();};
 tab.append(close);root.append(tab);
 }
}
function renderOutline(){
 const root=$('outline');root.replaceChildren();
 const src=code();
 const hits=[...src.matchAll(/^\s*(?:async\s+)?(def|class)\s+([A-Za-z_]\w*)/gm)];
 if(!hits.length){root.textContent='No classes or functions in this file.';return;}
 for(const hit of hits){
 const line=src.slice(0,hit.index).split('\n').length;
 const div=document.createElement('div');div.className='symbol';div.textContent=(hit[1]==='class'?'▣ ':'ƒ ')+hit[2];
 div.onclick=()=>{if(editor){editor.revealLineInCenter(line);editor.setPosition({lineNumber:line,column:1});editor.focus();}};
 root.append(div);
 }
}
$('newFile').onclick=()=>{
 const name=prompt('New filename','module.py');if(!name)return;
 if(!/^[a-zA-Z0-9_.\/ -]{1,160}$/.test(name)||name.includes('..')||name.startsWith('/')||name.endsWith('/')){alert('Invalid filename');return;}
 if(name in project.files){setActive(name);return;}
 project.files[name]=name.endsWith('.py')?'# '+name+'\n':'';
 setActive(name);dirty(name);
};
$('renameFile').onclick=()=>{
 const name=prompt('Rename file',active);
 if(!name||name===active)return;
 if(!/^[a-zA-Z0-9_.\/ -]{1,160}$/.test(name)||name.includes('..')||name.startsWith('/')||name in project.files){alert('Invalid filename');return;}
 const old=active;sync();project.files[name]=project.files[old];delete project.files[old];
 if(models[old]){models[old].dispose();delete models[old];}
 opened=opened.map(n=>n===old?name:n);breakpoints[name]=breakpoints[old]??[];delete breakpoints[old];
 power?.onDelete(old);
 if(project.entry===old)project.entry=name;active=name;setActive(name);dirty(name);
};
$('deleteFile').onclick=()=>{
 if(Object.keys(project.files).length<=1){alert('At least one file is required');return;}
 if(!confirm('Delete '+active+'?'))return;
 const old=active;power?.onDelete(old);delete project.files[old];
 if(models[old]){models[old].dispose();delete models[old];}
 opened=opened.filter(n=>n!==old);active=opened[0]??Object.keys(project.files)[0];
 if(project.entry===old)project.entry=active;setActive(active);dirty(active);
};
$('projectName').onchange=e=>{project.name=e.target.value.trim()||'Untitled Project';renderFiles();save();};
$('importFile').onclick=()=>$('picker').click();
$('picker').onchange=async e=>{
 let last=null;
 for(const file of e.target.files??[]){
 if(file.size>500000)continue;
 const source=await file.text();
 if(file.name.endsWith('.arcside-python.json')){
   try{
     const parsed=JSON.parse(source);
     if(parsed.version!==1||!parsed.project?.files||!Object.keys(parsed.project.files).length)throw Error('Invalid Arcside project');
     for(const m of Object.values(models))m.dispose();
     models={};project=parsed.project;opened=[Object.keys(project.files)[0]];
     active=opened[0];breakpoints={};
     if(editor)editor.setModel(model(active));else $('fallback').value=project.files[active];
     $('projectName').value=project.name;$('activePath').textContent=active;last=active;
   }catch(error){alert('Cannot import project: '+error.message);}
   continue;
 }
 const name=file.name.replace(/[^a-zA-Z0-9_. -]/g,'_');
 if(!name)continue;
 project.files[name]=source;last=name;
 }
 if(last){setActive(last);dirty(last);}
 e.target.value='';
};
function download(filename,text,mime){
 const blob=new Blob([text],{type:mime}),url=URL.createObjectURL(blob),a=document.createElement('a');
 a.href=url;a.download=filename;a.click();setTimeout(()=>URL.revokeObjectURL(url),2000);
}
$('exportFile').onclick=()=>{sync();download(active,project.files[active],'text/plain;charset=utf-8');};
$('exportProject').onclick=()=>{
 sync();download(project.name.replace(/[^a-z0-9_-]+/gi,'_')+'.arcside-python.json',
 JSON.stringify({version:1,project},null,2),'application/json');
};
function output(stdout='',stderr='',append=false){
 if(!append){$('stdout').textContent='';$('stderr').textContent='';}
 $('stdout').textContent+=stdout;$('stderr').textContent+=stderr;
}
function updateProblems(items){
 diagnostics=items;$('problemCount').textContent=items.length;
 const root=$('problemList');root.replaceChildren();
 if(!items.length)root.textContent='No syntax diagnostics.';
 for(const d of items){
 const div=document.createElement('div');div.className='problem';div.textContent='Line '+d.line+': '+d.message;
 div.onclick=()=>{if(editor){editor.revealLineInCenter(d.line);editor.setPosition({lineNumber:d.line,column:d.column});}};
 root.append(div);
 }
 if(window.monaco&&models[active])monaco.editor.setModelMarkers(models[active],'arcside-python',
 items.map(d=>({startLineNumber:d.line,endLineNumber:d.line,startColumn:d.column,endColumn:d.column+1,severity:monaco.MarkerSeverity.Error,message:d.message})));
}
async function analyze(){
 if(power?.active||busy||!active.endsWith('.py'))return;
 const file=active;try{
 const data=await send('analyze',{entry:active,code:code()});
 if(file===active)updateProblems(data.diagnostics??[]);
 }catch(e){console.warn('Syntax checks:',e);}
}
async function execute(mode,extra={}){
 if(busy)return;
 if(power?.active)return power.execute(mode,extra);
 sync();
 if(['run','debug','test'].includes(mode))setPanel('output');
 const start=performance.now();
 output(mode==='test'?'Discovering unit tests…\n':'Running '+active+'…\n');
 try{
 const data=await send(mode,{breakpoints:breakpoints[active]??[],...extra});
 if(data.type==='error'){output('',data.message);return;}
 output((data.stdout??'')+(data.summary?'\n'+data.summary:''),data.stderr??'');
 if(data.ok===false&&!(data.stderr??''))output('','Execution failed.');
 status((data.ok===false?'Failed':'Completed')+' in '+((performance.now()-start)/1000).toFixed(2)+'s');
 figures=data.figures??[];renderFigures();trace=data.events??[];traceIndex=0;renderTrace();
 variables=data.variables??variables;renderVariables();
 if(mode==='debug')setPanel('debugger');
 }catch(e){output('',String(e.message??e));}
}
$('run').onclick=()=>execute('run');
$('runSelection').onclick=()=>{
 const selected=editor?.getModel()?.getValueInRange(editor.getSelection())??'';
 if(!selected.trim()){execute('run');return;}
 execute('repl',{code:selected});
};$('debug').onclick=()=>execute('debug');$('runTests').onclick=()=>execute('test');
$('clearOutput').onclick=()=>output();
$('replRun').onclick=()=>{
 const cmd=$('replInput').value;if(!cmd.trim())return;
 $('replInput').value='';execute('repl',{code:cmd});
};
$('replInput').onkeydown=e=>{if(e.key==='Enter')$('replRun').click();};
$('install').onclick=()=>{const name=$('packageInput').value.trim();if(name)execute('install',{package:name});};

function renderVariables() {
  $('variableCount').textContent=variables.length;
  const list=$('variableList'),quick=$('quickVariables');
  list.replaceChildren();quick.replaceChildren();
  if(!variables.length){
    list.textContent='No Python variables yet';
    quick.textContent='No variables captured';
    $('variablePreview').textContent='Run Python to inspect live values.';
    return;
  }
  for(const variable of variables) {
    const button=document.createElement('button');
    button.textContent=variable.name+' · '+variable.type+(variable.shape?' '+variable.shape:'');
    button.onclick=()=>showVariable(variable,button);
    list.appendChild(button);
    if(quick.children.length<9){
      const small=document.createElement('button');
      small.textContent=variable.name+' : '+variable.type;
      small.onclick=()=>{setPanel('variables');showVariable(variable,button);};
      quick.appendChild(small);
    }
  }
  showVariable(variables[0],list.firstChild);
}
function showVariable(item,button){
  for(const el of $('variableList').children)el.classList.toggle('active',el===button);
  const root=$('variablePreview');root.replaceChildren();
  const title=document.createElement('div');title.className='variable-title';
  title.textContent=item.name+' · '+item.type+(item.shape?' '+item.shape:'');
  root.appendChild(title);
  if(item.table&&Array.isArray(item.table.data)){
    const table=document.createElement('table');table.className='variable-dataframe';
    const head=document.createElement('thead'),header=document.createElement('tr');
    for(const label of ['#',...(item.table.columns??[])]) {
      const th=document.createElement('th');th.textContent=label;header.appendChild(th);
    }
    head.appendChild(header);table.appendChild(head);
    const body=document.createElement('tbody');
    for(const [i,values] of item.table.data.entries()){
      const row=document.createElement('tr');
      for(const value of [item.table.index?.[i]??i,...values]){
        const td=document.createElement('td');
        td.textContent=value===null?'':String(value);row.appendChild(td);
      }
      body.appendChild(row);
    }
    table.appendChild(body);root.appendChild(table);
  }else{
    const pre=document.createElement('pre');pre.textContent=item.preview??'';
    root.appendChild(pre);
  }
}
function renderFigures(){
 $('plotCount').textContent=figures.length;const root=$('figureGallery');root.replaceChildren();
 if(!figures.length){root.textContent='No Matplotlib plots generated.';return;}
 for(const data of figures){const img=document.createElement('img');img.src='data:image/png;base64,'+data;img.alt='Matplotlib output';root.append(img);}
}
function renderTrace(){
 $('prevTrace').disabled=traceIndex<=0;$('nextTrace').disabled=traceIndex>=trace.length-1;
 if(!trace.length){$('traceInfo').textContent='No trace';$('traceVars').textContent='No events. Choose Debug.';return;}
 const item=trace[traceIndex];
 $('traceInfo').textContent='Step '+(traceIndex+1)+' / '+trace.length+' · line '+item.line+(item.breakpoint?' · breakpoint':'');
 $('traceVars').textContent=Object.entries(item.locals??{}).map(([k,v])=>k+' = '+v).join('\n')||'(no locals)';
 if(editor){editor.revealLineInCenter(item.line);editor.setPosition({lineNumber:item.line,column:1});}
}
$('prevTrace').onclick=()=>{traceIndex=Math.max(0,traceIndex-1);renderTrace();};
$('nextTrace').onclick=()=>{traceIndex=Math.min(trace.length-1,traceIndex+1);renderTrace();};
function setPanel(name){
 for(const id of ['output','problems','debugger','plots','variables','console','terminal','notebook','tools'])$(id).hidden=id!==name;
 for(const el of document.querySelectorAll('[data-panel]'))el.classList.toggle('active',el.dataset.panel===name);
}
for(const el of document.querySelectorAll('[data-panel]'))el.onclick=()=>setPanel(el.dataset.panel);

function terminalCommand(){
 const value=$('terminalInput').value.trim();if(!value)return;
 $('terminalInput').value='';
 const log=$('terminalLog');
 function write(text){log.textContent+='\n'+text;log.scrollTop=log.scrollHeight;}
 if(power?.active){void power.terminal(value).catch(e=>write('Local shell error: '+e.message));return;}
 write('$ '+value);
 const [command,...rest]=value.split(/\s+/);
 const arg=rest.join(' ');
 if(command==='help')write('Commands: help, pwd, ls, cat <file>, open <file>, python <file>, unittest, pip install <package>, clear. This is not an OS shell.');
 else if(command==='pwd')write('/arcside/'+project.name.replace(/\s+/g,'_'));
 else if(command==='ls')write(Object.keys(project.files).sort().join('\n')||'(empty)');
 else if(command==='clear')log.textContent='';
 else if(command==='cat')write(project.files[arg]??'File not found: '+arg);
 else if(command==='open'){if(arg in project.files){setActive(arg);write('Opened '+arg);}else write('File not found: '+arg);}
 else if(command==='python'){
   if(arg in project.files){setActive(arg);execute('run');write('Python execution started. See Output panel.');}
   else write('File not found: '+arg);
 }
 else if(command==='unittest'){execute('test');write('Test execution started. See Output panel.');}
 else if(command==='pip'&&rest[0]==='install'&&rest[1]){execute('install',{package:rest[1]});write('Installation started. See Output panel.');}
 else write('Unsupported virtual command: '+command+'. Type help.');
}
$('terminalExecute').onclick=terminalCommand;
$('terminalInput').onkeydown=e=>{if(e.key==='Enter')terminalCommand();};

document.addEventListener('keydown',e=>{
 const cmd=e.ctrlKey||e.metaKey;
 if(cmd&&e.key.toLowerCase()==='s'){e.preventDefault();sync();save();}
 if(cmd&&e.key==='Enter'){e.preventDefault();execute('run');}
 if(e.key==='F5'){e.preventDefault();if(e.shiftKey)terminate();else execute('debug');}
});
window.addEventListener('beforeunload',save);
renderFiles();renderTabs();renderOutline();$('activePath').textContent=active;
running(false);
power=setupPowerPanel({
 getProject:()=>project,getActive:()=>active,getEditor:()=>editor,
 getModels:()=>models,ensureModel:name=>model(name),
 getBreakpoints:()=>breakpoints,
 setStatus:status,setPanel,running,setRunning:running,
 writeOutput:(stdout='',stderr='')=>output(stdout,stderr),
 sync,save,
 replaceActiveSource:source=>{
   if(editor&&models[active])models[active].setValue(source);
   else {project.files[active]=source;$('fallback').value=source;dirty(active);}
 },
});
setTimeout(initEditor,120);
