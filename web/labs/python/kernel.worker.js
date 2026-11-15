/* Python runs in a dedicated Web Worker via Pyodide (WebAssembly).
 * This is an interactive local browser kernel, NOT a secure sandbox for
 * third-party code and NOT a substitute for a desktop Python interpreter.
 */
const PYODIDE_URL='https://cdn.jsdelivr.net/pyodide/v0.29.1/full/';
const ROOT='/home/pyodide/arcside';
let runtimePromise=null,working=false;
function status(text){postMessage({type:'status',text});}
async function kernel(){
  if(runtimePromise)return runtimePromise;
  runtimePromise=(async()=>{
    status('Downloading Python/WebAssembly runtime…');
    importScripts(PYODIDE_URL+'pyodide.js');
    const py=await loadPyodide({indexURL:PYODIDE_URL});
    py.FS.mkdirTree(ROOT);
    py.runPython(String.raw`
import io, sys, traceback, json, contextlib, base64, ast, unittest, os
_ARCSIDE_ROOT="/home/pyodide/arcside"
if _ARCSIDE_ROOT not in sys.path:
    sys.path.insert(0,_ARCSIDE_ROOT)
_arcside_namespace={"__name__":"__main__"}
def _arcside_analyze(code,filename):
    try:
        ast.parse(code,filename=filename)
        return json.dumps({"diagnostics":[]})
    except SyntaxError as exc:
        return json.dumps({"diagnostics":[{"line":exc.lineno or 1,"column":exc.offset or 1,"message":exc.msg or "Syntax error","severity":"error"}]})
def _arcside_execute(code,filename,mode,breakpoints):
    output,errors=io.StringIO(),io.StringIO()
    figures,events=[],[]
    current_file=os.path.abspath(filename)
    prev_trace=sys.gettrace()
    def trace(frame,event,arg):
        if event=="line" and os.path.abspath(frame.f_code.co_filename)==current_file and len(events)<2400:
            values={}
            for key,value in list(frame.f_locals.items())[:25]:
                if key.startswith("__"): continue
                try:
                    description=repr(value)
                    values[key]=description[:180]
                except Exception:
                    values[key]="<unrepresentable>"
            events.append({"line":frame.f_lineno,"locals":values,"breakpoint":frame.f_lineno in breakpoints})
        return trace
    result={"ok":True,"stdout":"","stderr":"","figures":[],"events":[],"summary":""}
    _arcside_namespace["__file__"]=filename
    _arcside_namespace["__name__"]="__main__"
    try:
        with contextlib.redirect_stdout(output),contextlib.redirect_stderr(errors):
            try:
                if mode=="test":
                    suite=unittest.defaultTestLoader.discover(_ARCSIDE_ROOT,pattern="test_*.py",top_level_dir=_ARCSIDE_ROOT)
                    outcome=unittest.TextTestRunner(stream=output,verbosity=2).run(suite)
                    result["summary"]="Tests: "+str(outcome.testsRun)+" / failures: "+str(len(outcome.failures))+" / errors: "+str(len(outcome.errors))
                    result["ok"]=outcome.wasSuccessful()
                else:
                    if mode=="debug": sys.settrace(trace)
                    try:
                        exec(compile(code,filename,"exec"),_arcside_namespace)
                    finally:
                        sys.settrace(prev_trace)
            except BaseException:
                result["ok"]=False
                traceback.print_exc(file=errors)
            try:
                import sys as _sys
                if "matplotlib.pyplot" in _sys.modules:
                    import matplotlib.pyplot as plt
                    for n in plt.get_fignums()[:12]:
                        buffer=io.BytesIO()
                        plt.figure(n).savefig(buffer,format="png",dpi=105,bbox_inches="tight")
                        figures.append(base64.b64encode(buffer.getvalue()).decode("ascii"))
                        plt.close(n)
            except BaseException as exc:
                errors.write("Plot rendering: "+str(exc)+"\n")
    finally:
        sys.settrace(prev_trace)
    result["stdout"]=output.getvalue()[-300000:]
    result["stderr"]=errors.getvalue()[-120000:]
    result["figures"]=figures
    result["events"]=events
    return json.dumps(result)
`);
    status('Python kernel ready');
    return py;
  })().catch(err=>{runtimePromise=null;throw err;});
  return runtimePromise;
}
function safePath(path) {
  const name=String(path||'');
  if(!/^[a-zA-Z0-9_.\/ -]{1,160}$/.test(name)||
     name.startsWith('/')||name.split('/').some(part=>part==='..'||part===''))throw Error('Invalid project path');
  return ROOT+'/'+name;
}
function writeFiles(py,files) {
  if(!files||typeof files!=='object')return;
  for(const [name,content] of Object.entries(files)) {
    if(typeof content!=='string'||content.length>500000)continue;
    const path=safePath(name);
    const parent=path.slice(0,path.lastIndexOf('/'));
    py.FS.mkdirTree(parent);
    py.FS.writeFile(path,content,{encoding:'utf8'});
  }
}
async function run(message) {
  const py=await kernel(),mode=message.mode??'run';
  const entry=message.entry??'main.py';
  writeFiles(py,message.files);
  const code=message.code??(message.files?.[entry]??'');
  const filename=safePath(entry);
  if(mode==='install'){
    const name=String(message.package??'');
    if(!/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,79}$/.test(name))throw Error('Invalid package name');
    status('Installing '+name+'…');
    await py.loadPackage('micropip');
    const micropip=py.pyimport('micropip');
    try {await micropip.install(name);} finally {micropip.destroy?.();}
    postMessage({type:'result',id:message.id,ok:true,stdout:'Installed '+name+' in this browser kernel.',stderr:'',figures:[],events:[]});return;
  }
  if(mode==='analyze'){
    py.globals.set('arcside_code',code);
    py.globals.set('arcside_filename',filename);
    const result=JSON.parse(py.runPython('_arcside_analyze(arcside_code,arcside_filename)'));
    postMessage({type:'diagnostics',id:message.id,...result});return;
  }
  status(mode==='debug'?'Collecting Python trace…':mode==='test'?'Running unittest suite…':'Running Python…');
  await py.loadPackagesFromImports(code);
  if(mode==='test') {
    for(const [path,text] of Object.entries(message.files??{}))
      if(path.startsWith('test_')||path.includes('/test_'))await py.loadPackagesFromImports(text);
  }
  py.globals.set('arcside_code',code);
  py.globals.set('arcside_filename',filename);
  py.globals.set('arcside_mode',mode);
  py.globals.set('arcside_breakpoints',message.breakpoints??[]);
  const raw=py.runPython('_arcside_execute(arcside_code,arcside_filename,arcside_mode,set(arcside_breakpoints.to_py()))');
  postMessage({type:'result',id:message.id,...JSON.parse(raw)});
}
self.onmessage=async({data})=>{
  if(data.type==='ping'){status('Worker online');return;}
  if(working){postMessage({type:'error',id:data.id,message:'Kernel busy'});return;}
  working=true;
  try {await run(data);}catch(error){
    postMessage({type:'error',id:data.id,message:String(error?.stack??error)});
  }finally{working=false;status('Ready');}
};
