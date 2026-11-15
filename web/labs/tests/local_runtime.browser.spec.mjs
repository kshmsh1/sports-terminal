import {test,expect} from '@playwright/test';

const token=process.env.ARCSIDE_LOCAL_E2E_TOKEN;
test.skip(!token,'Real local companion is only launched in the dedicated integration job');
test.describe.configure({timeout:120000});

async function connect(page){
  await page.goto('/labs/python/index.html');
  await expect(page.locator('#editor .monaco-editor')).toBeVisible({timeout:60000});
  await page.locator('#runtimeMode').selectOption('local');
  await page.locator('#localAddress').fill('http://127.0.0.1:8766');
  await page.locator('#localToken').fill(token);
  await page.locator('#localConnect').click();
  await expect(page.locator('#localStatus')).toContainText('Connected',{timeout:30000});
}

test('opt-in companion runs native CPython from Monaco and exposes Git',async({page})=>{
  await connect(page);
  await page.evaluate(()=>window.monaco.editor.getModels()
    .find(m=>m.uri.path.endsWith('main.py'))
    .setValue('import sys\nprint("native-cpython-ok")\nprint(sys.version_info.major)\n'));
  await page.locator('#run').click();
  await expect(page.locator('#stdout')).toContainText('native-cpython-ok',{timeout:30000});
  await expect(page.locator('#stdout')).toContainText('3');
  await page.locator('[data-panel="tools"]').click();
  await page.locator('#localGitInit').click();
  await expect(page.locator('#localToolLog')).toContainText('Git init',{timeout:30000});
  await page.locator('#localGitStatus').click();
  await expect(page.locator('#localToolLog')).toContainText('Git status',{timeout:30000});
  await page.locator('#localProfile').click();
  await expect(page.locator('#localToolLog')).toContainText('function calls',{timeout:30000});
});

test('native real shell connects and accepts commands from editor',async({page})=>{
  await connect(page);
  await page.locator('[data-panel="terminal"]').click();
  await page.locator('#terminalConnect').click();
  await expect(page.locator('#terminalStatus')).toContainText('Local shell connected',{timeout:30000});
  await page.locator('#terminalInput').fill('printf "arcside-pty-ok\\n"');
  await page.locator('#terminalExecute').click();
  await expect(page.locator('#terminalLog')).toContainText('arcside-pty-ok',{timeout:30000});
});

test('real Jupyter session evaluates a cell with persistent kernel',async({page})=>{
  await connect(page);
  await page.locator('[data-panel="notebook"]').click();
  await page.locator('#notebookStart').click();
  await expect(page.locator('#notebookStatus')).toContainText('Jupyter ready',{timeout:60000});
  await page.locator('#notebookAdd').click();
  await page.locator('.notebook-cell textarea').last().fill('print("native-jupyter-cell-ok")');
  await page.locator('.notebook-cell').last().getByText('Run cell').click();
  await expect(page.locator('.notebook-cell').last().locator('.notebook-output'))
    .toContainText('native-jupyter-cell-ok',{timeout:30000});
});

test('debugpy DAP controller launches an actual program and pauses at a breakpoint',async({page})=>{
  await page.goto('/labs/python/index.html');
  const outcome=await page.evaluate(async(token)=>{
    const {LocalRuntime,LiveDebugger}=await import('/labs/python/local_runtime.mjs');
    const runtime=new LocalRuntime();
    await runtime.connect('http://127.0.0.1:8766',token);
    await runtime.sync({'dap_test.py':'x = 1\ny = x + 2\nprint(y)\n'});
    const report=[],root=runtime.info.workspace.replace(/[\\/]+$/,'');
    const debuggerSession=new LiveDebugger(runtime,event=>report.push(event));
    try{
      await debuggerSession.connect();
      await debuggerSession.launch({
        program:root+'/dap_test.py',cwd:root,python:runtime.info.interpreter,
        breakpoints:[2],
      });
      const stop=await new Promise((resolve,reject)=>{
        const started=Date.now();
        const tick=()=>{
          if(report.some(x=>x.type==='stopped'))resolve(true);
          else if(Date.now()-started>30000)reject(Error('No breakpoint stop: '+JSON.stringify(report)));
          else setTimeout(tick,70);
        };
        tick();
      });
      await debuggerSession.next();
      return {stop,reportTypes:report.map(x=>x.type)};
    }finally{await debuggerSession.stop();runtime.disconnect();}
  },token);
  expect(outcome.stop).toBe(true);
  expect(outcome.reportTypes).toContain('stopped');
});


test('Monaco receives diagnostics from actual python-lsp-server',async({page})=>{
  await connect(page);
  await expect(page.locator('#status')).toContainText('Python LSP connected',{timeout:30000});
  await page.evaluate(()=>window.monaco.editor.getModels()
    .find(m=>m.uri.path.endsWith('main.py'))
    .setValue('def invalid_syntax(:\n    pass\n'));
  await expect.poll(async()=>page.evaluate(()=>window.monaco.editor.getModelMarkers({owner:'arcside-pylsp'}).length),
    {timeout:30000}).toBeGreaterThan(0);
});


test('real Python LSP performs semantic rename in workspace source',async({page})=>{
  await page.goto('/labs/python/index.html');
  await expect(page.locator('#editor .monaco-editor')).toBeVisible({timeout:60000});
  const result=await page.evaluate(async(token)=>{
    const {LocalRuntime}=await import('/labs/python/local_runtime.mjs');
    const {ArcsideLsp}=await import('/labs/python/lsp_client.mjs');
    const runtime=new LocalRuntime();
    await runtime.connect('http://127.0.0.1:8766',token);
    const file='semantic_test.py';
    const source='total_for_rename = 17\nprint(total_for_rename)\n';
    await runtime.sync({[file]:source});
    const uri=window.monaco.Uri.parse('file:///arcside/semantic_test.py');
    const model=window.monaco.editor.createModel(source,'python',uri);
    const lsp=new ArcsideLsp(runtime,window.monaco,{[file]:model},null,()=>{});
    try{
      await lsp.start();
      lsp.open(file,source);
      const edits=await lsp.semanticRename(model,{lineNumber:1,column:6},'sum_total');
      const programEdits=edits.edits.map(e=>({range:e.textEdit.range,text:e.textEdit.text}));
      model.applyEdits(programEdits);
      return {count:programEdits.length,source:model.getValue()};
    }finally{lsp.stop();model.dispose();runtime.disconnect();}
  },token);
  expect(result.count).toBeGreaterThanOrEqual(1);
  expect(result.source).toContain('sum_total = 17');
  expect(result.source).toContain('print(sum_total)');
  expect(result.source).not.toContain('total_for_rename');
});
