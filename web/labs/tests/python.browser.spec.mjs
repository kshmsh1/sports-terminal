import { test, expect } from '@playwright/test';

test('Monaco code editor mounts and multi-file navigation works',async ({page}) => {
  await page.goto('/labs/python/index.html');
  await expect(page.locator('#files .file')).toHaveCount(3);
  await expect(page.locator('#editor .monaco-editor')).toBeVisible({timeout:60000});
  await page.locator('#files .file').filter({hasText:'test_math.py'}).click();
  await expect(page.locator('#activePath')).toHaveText('test_math.py');
  await expect(page.locator('#tabs .tab.active')).toContainText('test_math.py');
});

test('Python kernel genuinely executes code and shows standard output',async ({page}) => {
  await page.goto('/labs/python/index.html');
  await expect(page.locator('#editor .monaco-editor')).toBeVisible({timeout:60000});
  await page.evaluate(()=>{
    const model=window.monaco.editor.getModels().find(m=>m.uri.path.endsWith('main.py'));
    model.setValue('print("arcside-runtime-ok")\nprint(2+2)\n');
  });
  await page.locator('#run').click();
  await expect(page.locator('#stdout')).toContainText('arcside-runtime-ok',{timeout:180000});
  await expect(page.locator('#stdout')).toContainText('4',{timeout:180000});
  await expect(page.locator('#stderr')).toBeEmpty();
});

test('Python syntax errors surface in Problems with line number',async ({page})=>{
  await page.goto('/labs/python/index.html');
  await expect(page.locator('#editor .monaco-editor')).toBeVisible({timeout:60000});
  await page.evaluate(()=>{
    window.monaco.editor.getModels().find(m=>m.uri.path.endsWith('main.py')).setValue('def broken(:\n    pass\n');
  });
  await expect(page.locator('#problemCount')).toHaveText('1',{timeout:180000});
  await page.locator('[data-panel="problems"]').click();
  await expect(page.locator('#problemList')).toContainText('Line 1');
});

test('unittest runner discovers project tests',async ({page})=>{
  await page.goto('/labs/python/index.html');
  await expect(page.locator('#editor .monaco-editor')).toBeVisible({timeout:60000});
  await page.locator('#runTests').click();
  await expect(page.locator('#stdout')).toContainText('Ran 2 tests',{timeout:180000});
  await expect(page.locator('#stdout')).toContainText('failures: 0',{timeout:180000});
});

test('virtual terminal exposes explicit supported commands',async ({page})=>{
  await page.goto('/labs/python/index.html');
  await page.locator('[data-panel="terminal"]').click();
  await page.locator('#terminalInput').fill('ls');
  await page.locator('#terminalExecute').click();
  await expect(page.locator('#terminalLog')).toContainText('test_math.py');
  await page.locator('#terminalInput').fill('help');
  await page.locator('#terminalExecute').click();
  await expect(page.locator('#terminalLog')).toContainText('not an OS shell');
});
