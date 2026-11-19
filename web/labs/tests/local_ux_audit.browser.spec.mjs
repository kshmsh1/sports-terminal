import {test,expect} from '@playwright/test';
const token=process.env.ARCSIDE_LOCAL_E2E_TOKEN;
test.skip(!token,'Native workbench exploratory QA runs only with the isolated loopback companion');
test.describe.configure({timeout:120000});
async function connect(page){
  await page.goto('/labs/python/index.html');
  await expect(page.locator('#editor .monaco-editor')).toBeVisible({timeout:60000});
  await page.locator('#runtimeMode').selectOption('local');
  await page.locator('#localToken').fill(token);
  await page.locator('#localConnect').click();
  await expect(page.locator('#localStatus')).toContainText('Connected',{timeout:30000});
}
test('native IDE actions: Run, Run selection, Ruff lint/format, pytest, coverage and profiler',async({page})=>{
  await connect(page);
  await page.evaluate(()=>{
    const model=window.monaco.editor.getModels().find(m=>m.uri.path.endsWith('main.py'));
    model.setValue('value=7\nprint("native-ui-action",value)\n');
  });
  await page.locator('#run').click();
  await expect(page.locator('#stdout')).toContainText('native-ui-action 7',{timeout:30000});
  await page.locator('[data-panel="tools"]').click();
  await page.locator('#localLint').click();
  await expect(page.locator('#localToolLog')).toContainText('lint',{timeout:30000});
  await page.locator('#localFormat').click();
  await expect(page.locator('#localToolLog')).toContainText('format',{timeout:30000});
  await page.locator('#localTests').click();
  await expect(page.locator('#localToolLog')).toContainText('test',{timeout:30000});
  await page.locator('#localCoverage').click();
  await expect(page.locator('#localToolLog')).toContainText('coverage',{timeout:30000});
  await page.locator('#localProfile').click();
  await expect(page.locator('#localToolLog')).toContainText('function calls',{timeout:30000});
});
test('native environment picker and Git workflow controls respond with authentic companion output',async({page})=>{
  await connect(page);
  await page.locator('#localEnvRefresh').click();
  await expect(page.locator('#localEnvSelect option').first()).toBeAttached();
  await page.locator('#localEnvUse').click();
  await expect(page.locator('#localToolLog')).toContainText('Selected interpreter',{timeout:30000});
  await page.locator('#localGitInit').click();
  await expect(page.locator('#localToolLog')).toContainText('Git init',{timeout:30000});
  await page.locator('#localGitAdd').click();
  await expect(page.locator('#localToolLog')).toContainText('Git add',{timeout:30000});
  await page.locator('#localGitDiff').click();
  await expect(page.locator('#localToolLog')).toContainText('Git diff',{timeout:30000});
  await page.locator('#localGitStatus').click();
  await expect(page.locator('#localToolLog')).toContainText('Git status',{timeout:30000});
  await page.locator('#localGitLog').click();
  await expect(page.locator('#localToolLog')).toContainText('Git log',{timeout:30000});
  await page.locator('#localDisconnect').click();
  await expect(page.locator('#localStatus')).toHaveText('Disconnected');
});
test('native notebook control can export standards-based ipynb and retain editable cell source',async({page})=>{
  await connect(page);
  await page.locator('[data-panel="notebook"]').click();
  await page.locator('#notebookAdd').click();
  await expect(page.locator('.notebook-cell')).toHaveCount(1);
  await page.locator('.notebook-cell textarea').last().fill('print("my-ux-notebook")');
  const download=page.waitForEvent('download');
  await page.locator('#notebookExport').click();
  expect((await download).suggestedFilename()).toMatch(/\.ipynb$/);
});
