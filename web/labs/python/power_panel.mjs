import {LocalRuntime,LiveDebugger} from './local_runtime.mjs';
import {ArcsideLsp} from './lsp_client.mjs';

// Adds opt-in desktop powers to the existing browser editor.
// Nothing here starts the companion; the human must run and authorize it.
export function setupPowerPanel(ctx) {
  const $=id=>document.getElementById(id);
  const runtime=new LocalRuntime();
  let active=false,terminalSocket=null,terminalScreen=null,notebookSocket=null,liveDebug=null,lsp=null;
  const local=()=>active;
  const allowed=()=>active&&runtime.connected;
  const report=(text)=>{$('localToolLog').textContent=String(text);};
  const reportError=(error)=>{const message=error?.message??String(error);report('Error: '+message);ctx.setStatus('Local tool: '+message);};
  const logResult=(name,value)=>{
    const reportText=value?.stdout??'';
    report(name+'\n'+reportText+(value?.stderr?'\n'+value.stderr:'')+
      (value?.returncode!==undefined?'\nExit '+value.returncode:''));
    ctx.setPanel('tools');
  };
  function toggleMode(value) {
    active=value==='local';
    $('runtimeKind').textContent=active?'Local Python · CPython':'Browser Python';
    $('runtimeDetail').textContent=active
      ?'Trusted project execution with your OS permissions; token authentication required.'
      :'Runs inside a worker. No system interpreter or shell.';
    $('terminalTab').textContent=active?'Real PTY Terminal':'Virtual Terminal';
    $('terminalStatus').textContent=active?'Mac/Linux shell (opt in)':'Virtual commands';
    $('terminalConnect').hidden=!active;
    $('terminalInterrupt').hidden=!active;
    $('liveDebugger').hidden=!active;
    $('traceVars').hidden=active;
    $('prevTrace').parentElement.hidden=active;
    if(active){
      ctx.setPanel('tools');
      if(!runtime.connected)ctx.setStatus('Connect trusted local companion to execute native Python');
    }else{
      ctx.setStatus('Browser Python / Pyodide');
      ctx.setPanel('output');
    }
  }
  $('runtimeMode').onchange=e=>toggleMode(e.target.value);
  $('connectLocal').onclick=()=>{ctx.setPanel('tools');$('localToken').focus();};
  $('localConnect').onclick=async()=>{
    $('localConnect').disabled=true;
    try{
      const info=await runtime.connect($('localAddress').value,$('localToken').value);
      $('localToken').value=''; // do not retain credential in DOM
      $('localStatus').textContent='Connected · '+info.environment;
      $('runtimeStatus').textContent=info.interpreter;
      ctx.setStatus('Local companion ready · '+info.python);
      report('Connected to '+info.workspace+'\nInterpreter: '+info.interpreter+
        '\nFiles executed here have YOUR local user account permissions.');
      await refreshEnvironments();
      if(lsp){lsp.stop();lsp=null;}
      if(info.capabilities?.lsp&&ctx.getEditor()&&window.monaco){
        try{
          const models=ctx.getModels();
          for(const [name] of Object.entries(ctx.getProject().files))
            if(name.endsWith('.py'))ctx.ensureModel(name);
          lsp=new ArcsideLsp(runtime,window.monaco,models,ctx.getEditor(),ctx.setStatus);
          await lsp.start();
          for(const [name,source] of Object.entries(ctx.getProject().files))
            lsp.open(name,source);
        }catch(error){report('Connected; LSP unavailable: '+error.message);}
      }
    }catch(error){
      $('localStatus').textContent='Connection failed';
      reportError(error);
    }finally{$('localConnect').disabled=false;}
  };
  $('localOpenProject').onclick=async()=>{
    try{
      if(!runtime.connected)throw Error('Connect the companion first');
      const listing=await runtime.listFiles();
      const names=listing.files.filter(n=>/\.(?:py|pyi|md|json|ipynb|toml|txt|csv|ya?ml|ini|cfg)$/i.test(n)).slice(0,100);
      if(!names.length){report('No supported source files found in this local workspace');return;}
      if(!confirm('Replace your current browser project with '+names.length+' files from the local workspace? Export your browser project first if you need a backup.'))return;
      const files={};
      const failures=[];
      for(const name of names){
        try{
          const value=await runtime.readFile(name);
          files[name]=value.source;
        }catch(e){failures.push(name+': '+e.message);}
      }
      if(!Object.keys(files).length)throw Error('No readable local project files');
      ctx.replaceProjectFiles(files);
      report('Opened '+Object.keys(files).length+' workspace files. Future saves use revision-checked sync.'+
        (failures.length?'\nSkipped:\n'+failures.join('\n'):''));
    }catch(error){reportError(error);}
  };
  $('localDisconnect').onclick=()=>{
    lsp?.stop();lsp=null;
    void liveDebug?.stop();liveDebug=null;
    terminalSocket?.close();terminalSocket=null;
    notebookSocket?.close();notebookSocket=null;
    runtime.disconnect();
    $('localStatus').textContent='Disconnected';
    $('runtimeStatus').textContent='Local disconnected';
    report('Disconnected local runtime. Browser editor and saved project are preserved.');
  };
  async function refreshEnvironments(){
    if(!runtime.connected)return;
    const data=await runtime.envs(),select=$('localEnvSelect');
    select.replaceChildren();
    for(const name of data.names){
      const option=document.createElement('option');
      option.value=name;option.textContent=name;select.appendChild(option);
    }
    select.value=data.active;
    $('localStatus').textContent='Connected · '+data.active;
  }
  $('localEnvRefresh').onclick=()=>void refreshEnvironments().catch(reportError);
  $('localEnvCreate').onclick=async()=>{
    try{
      const data=await runtime.createEnv($('localEnvName').value.trim(),$('localEnvManager').value);
      logResult('Create environment',data);
      await refreshEnvironments();
    }catch(error){reportError(error);}
  };
  $('localEnvUse').onclick=async()=>{
    try{
      const data=await runtime.selectEnv($('localEnvSelect').value);
      report('Selected interpreter: '+data.interpreter);
      terminalSocket?.close();terminalSocket=null;
      notebookSocket?.close();notebookSocket=null;
      lsp?.stop();lsp=null;
      ctx.setStatus('Using '+data.active);
      await refreshEnvironments();
    }catch(error){reportError(error);}
  };
  async function installInput(source){
    if(!runtime.connected)throw Error('Connect the local companion first');
    const list=String(source).trim().split(/\s+/).filter(Boolean);
    if(!list.length)throw Error('Specify at least one package');
    const r=await runtime.install(list);
    logResult('Install '+list.join(' '),r);
    return r;
  }
  $('localInstall').onclick=()=>void installInput($('localPackage').value).catch(reportError);
  async function localTool(action){
    if(!allowed()){ctx.setPanel('tools');throw Error('Connect trusted local runtime first');}
    ctx.sync();
    if(['format','lint'].includes(action)){
      await runtime.sync(ctx.getProject().files);
      const result=action==='format'
        ?await runtime.format(ctx.getActive()):await runtime.lint(ctx.getActive());
      if(action==='format'&&result.returncode===0&&result.source!==undefined)
        ctx.replaceActiveSource(result.source);
      logResult(action,result);
      return;
    }
    if(action==='test'||action==='coverage'){
      const result=await runtime.run(ctx.getProject().files,ctx.getActive(),action);
      logResult(action,result);return;
    }
    if(action==='add'){
      await runtime.sync(ctx.getProject().files);
      logResult('Git add',await runtime.git('add',{paths:[ctx.getActive()]}));return;
    }
    if(action==='commit'){
      logResult('Git commit',await runtime.git('commit',{message:$('localCommitMessage').value}));return;
    }
    logResult('Git '+action,await runtime.git(action));
  }
  const controls={
    localFormat:'format',localLint:'lint',localTests:'test',localCoverage:'coverage',
    localGitStatus:'status',localGitDiff:'diff',localGitLog:'log',
    localGitInit:'init',localGitAdd:'add',localGitCommit:'commit',
  };
  for(const [id,action] of Object.entries(controls))
    $(id).onclick=()=>void localTool(action).catch(reportError);

  function debugOutput(update){
    if(update.type==='output'){
      const destination=update.category==='stderr'?'stderr':'stdout';
      $(destination).textContent+=(update.output??'');
    }else if(update.type==='stopped'){
      $('dapStatus').textContent='Paused · '+(update.reason??'breakpoint');
      ctx.setStatus('debugpy paused');
    }else if(update.type==='snapshot'){
      const frameRoot=$('dapFrames'),variableRoot=$('dapVariables');
      frameRoot.replaceChildren();variableRoot.replaceChildren();
      for(const frame of update.frames??[]){
        const row=document.createElement('button');row.className='debug-frame';
        row.textContent=(frame.name??'frame')+' · line '+frame.line;
        row.onclick=()=>{
          if(frame.source?.path?.endsWith('/'+ctx.getActive())){
            ctx.getEditor()?.revealLineInCenter(frame.line);
            ctx.getEditor()?.setPosition({lineNumber:frame.line,column:1});
          }
        };
        frameRoot.append(row);
      }
      for(const scope of update.scopes??[]){
        const label=document.createElement('b');label.textContent=scope.scope;
        variableRoot.append(label);
        for(const variable of scope.values??[]){
          const row=document.createElement('div');row.className='debug-variable';
          row.textContent=variable.name+' = '+variable.value;
          variableRoot.append(row);
        }
      }
    }else if(update.type==='error')$('dapStatus').textContent='Error: '+update.message;
    else if(update.type==='continued')$('dapStatus').textContent='Running';
    else if(update.type==='terminated'||update.type==='closed')
      $('dapStatus').textContent='Debug session ended';
    else if(update.type==='launched')$('dapStatus').textContent='debugpy attached';
  }
  async function beginDebug(){
    ctx.sync();
    ctx.setPanel('debugger');
    ctx.setRunning(true);
    try{
      await runtime.sync(ctx.getProject().files);
      await liveDebug?.stop();
      liveDebug=new LiveDebugger(runtime,debugOutput);
      await liveDebug.connect();
      const path=runtime.info.workspace.replace(/[\\/]+$/,'')+'/'+ctx.getActive();
      await liveDebug.launch({
        program:path,cwd:runtime.info.workspace,
        python:runtime.info.interpreter,
        breakpoints:ctx.getBreakpoints()[ctx.getActive()]??[],
      });
    }catch(error){
      debugOutput({type:'error',message:error.message});
      reportError(error);
    }finally{ctx.setRunning(false);}
  }
  const debugControls={
    dapContinue:'resume',dapNext:'next',dapStepIn:'stepIn',
    dapStepOut:'stepOut',dapPause:'pause',
  };
  for(const [id,method] of Object.entries(debugControls))
    $(id).onclick=()=>void liveDebug?.[method]().catch(reportError);
  $('dapStop').onclick=()=>void liveDebug?.stop().catch(reportError);
  $('dapEvaluate').onclick=async()=>{
    try{$('dapValue').textContent=(await liveDebug.evaluate($('dapWatch').value)).result??'';}
    catch(error){$('dapValue').textContent=error.message;}
  };

  async function ensureTerminal(){
    if(!runtime.connected)throw Error('Connect the companion first');
    if(terminalSocket?.readyState===WebSocket.OPEN)return terminalSocket;
    terminalSocket=await runtime.socket('terminal',message=>{
      if(message.type==='output'){
        const log=$('terminalLog');
        log.textContent=(log.textContent+message.data).slice(-120000);
        if(terminalScreen)terminalScreen.write(message.data);
      }else if(message.type==='error')$('terminalStatus').textContent=message.message;
    },()=>{
      terminalSocket=null;
      $('terminalStatus').textContent='PTY disconnected';
    });
    $('terminalStatus').textContent='Local shell connected';
    if(window.Terminal&&!terminalScreen){
      terminalScreen=new window.Terminal({
        convertEol:true,cols:88,rows:22,theme:{background:'#0b1421',foreground:'#d5e4fa'},
        fontSize:12,fontFamily:'Menlo,Consolas,monospace',
      });
      $('localTerminal').hidden=false;
      terminalScreen.open($('localTerminal'));
      terminalScreen.onData(data=>{
        if(terminalSocket?.readyState===WebSocket.OPEN)
          terminalSocket.send(JSON.stringify({type:'input',data}));
      });
      $('terminalLog').hidden=true;
      terminalSocket.send(JSON.stringify({type:'resize',cols:88,rows:22}));
    }
    return terminalSocket;
  }
  $('terminalConnect').onclick=()=>void ensureTerminal().catch(reportError);
  $('terminalInterrupt').onclick=()=>{
    if(terminalSocket?.readyState===WebSocket.OPEN)
      terminalSocket.send(JSON.stringify({type:'input',data:'\x03'}));
  };
  async function terminalInput(value){
    const socket=await ensureTerminal();
    socket.send(JSON.stringify({type:'input',data:value+'\n'}));
  }
  const notebookCells=()=>{
    const project=ctx.getProject();
    if(!Array.isArray(project.notebook))project.notebook=[];
    return project.notebook;
  };
  function notebookRender(){
    const root=$('notebookCells');root.replaceChildren();
    for(const cell of notebookCells()){
      const holder=document.createElement('section');holder.className='notebook-cell';
      const bar=document.createElement('div');bar.className='debug-controls';
      const run=document.createElement('button');run.textContent='▶ Run cell';
      const remove=document.createElement('button');remove.textContent='Delete cell';
      const label=document.createElement('span');label.textContent='Python code';
      const input=document.createElement('textarea');input.value=cell.source??'';
      input.spellcheck=false;input.rows=5;
      input.oninput=()=>{cell.source=input.value;ctx.save();};
      const output=document.createElement('div');output.className='notebook-output';output.dataset.cellId=cell.id;
      run.onclick=async()=>{
        try{
          await ensureNotebook();
          cell.source=input.value;ctx.save();
          output.replaceChildren();
          notebookSocket.send(JSON.stringify({type:'execute',id:cell.id,source:cell.source}));
        }catch(error){reportError(error);}
      };
      remove.onclick=()=>{
        ctx.getProject().notebook=notebookCells().filter(x=>x.id!==cell.id);
        ctx.save();notebookRender();
      };
      bar.append(run,remove,label);holder.append(bar,input,output);
      root.append(holder);
    }
  }
  async function ensureNotebook(){
    if(!runtime.connected)throw Error('Connect companion before using the Jupyter kernel');
    if(notebookSocket?.readyState===WebSocket.OPEN)return;
    notebookSocket=await runtime.socket('notebook',message=>{
      if(message.type==='ready'){$('notebookStatus').textContent='Jupyter ready · '+message.interpreter;return;}
      if(message.type==='error'){$('notebookStatus').textContent='Kernel error: '+message.message;return;}
      const node=[...document.querySelectorAll('.notebook-output')]
        .find(el=>el.dataset.cellId===String(message.id));
      if(!node)return;
      if(message.type==='started'){node.textContent='Running cell…';return;}
      if(message.type==='finished')return;
      if(message.type!=='cell_output')return;
      if(node.textContent==='Running cell…')node.textContent='';
      const body=message.content??{};
      if(message.kind==='clear_output'){node.replaceChildren();return;}
      if(message.kind==='stream')appendText(node,body.text??'');
      if(message.kind==='error')appendText(node,(body.traceback??[]).join('\n'));
      if(['display_data','execute_result'].includes(message.kind)){
        const image=body.data?.['image/png'];
        if(image){
          const img=document.createElement('img');
          img.alt='Jupyter cell chart';img.src='data:image/png;base64,'+
            (Array.isArray(image)?image.join(''):image);
          node.append(img);
        }
        const plain=body.data?.['text/plain'];
        if(plain)appendText(node,Array.isArray(plain)?plain.join(''):plain);
      }
    },()=>{notebookSocket=null;if(!$('notebookStatus').textContent.startsWith('Kernel error'))$('notebookStatus').textContent='Kernel stopped';});
    $('notebookStatus').textContent='Starting kernel…';
  }
  function appendText(node,value){
    const pre=document.createElement('pre');
    pre.textContent=String(value).slice(0,100000);
    node.append(pre);
  }
  $('notebookStart').onclick=()=>void ensureNotebook().catch(reportError);
  $('notebookAdd').onclick=()=>{
    notebookCells().push({id:crypto.randomUUID(),source:'print("Hello, Arcside")'});
    ctx.save();notebookRender();
  };
  $('notebookExport').onclick=()=>{
    const document={
      nbformat:4,nbformat_minor:5,metadata:{kernelspec:{name:'python3',display_name:'Python 3'}},
      cells:notebookCells().map(cell=>({
        cell_type:'code',metadata:{},execution_count:null,outputs:[],
        id:cell.id.replace(/-/g,'').slice(0,12),
        source:cell.source.split('\n').map((line,i,array)=>line+(i<array.length-1?'\n':'')),
      })),
    };
    const url=URL.createObjectURL(new Blob([JSON.stringify(document,null,2)],{type:'application/json'}));
    const anchor=document.createElement('a');anchor.href=url;anchor.download='arcside-notebook.ipynb';
    anchor.click();setTimeout(()=>URL.revokeObjectURL(url),3000);
  };
  notebookRender();

  return {
    get active(){return local();},
    get connected(){return allowed();},
    async execute(mode,extra={}){
      if(!allowed()){ctx.setPanel('tools');report('Connect the trusted local companion first.');return;}
      if(mode==='debug')return beginDebug();
      if(mode==='install')return installInput(extra.package??$('packageInput').value);
      ctx.sync();ctx.setRunning(true);
      ctx.setPanel(mode==='test'?'output':'output');
      ctx.writeOutput('Running local CPython…\n','');
      try{
        const kind=mode==='test'?'test':mode==='repl'?'selection':'run';
        const response=await runtime.run(ctx.getProject().files,ctx.getActive(),kind,extra.code);
        ctx.writeOutput(response.stdout??'',response.stderr??'');
        ctx.setStatus('Native Python exited '+response.returncode);
        return response;
      }catch(error){
        ctx.writeOutput('',error.message);
        ctx.setStatus('Local run failed');
      }finally{ctx.setRunning(false);}
    },
    async stop(){
      if(liveDebug){await liveDebug.stop();liveDebug=null;}
      await runtime.interrupt();
      ctx.setRunning(false);
    },
    terminal:terminalInput,
    refreshNotebook:notebookRender,
    onEdit(name,source){if(allowed())lsp?.change(name,source);},
    onActive(name,source){if(allowed())lsp?.open(name,source);},
    onDelete(name){lsp?.close(name);},
  };
}
