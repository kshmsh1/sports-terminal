import {test,expect} from '@playwright/test';

// The real native companion is opt-in; regular browser tests never probe localhost.
test.skip(!process.env.ARCSIDE_NATIVE_TEST,'Only CI with throwaway native companion.');

test.beforeEach(async({page})=>{
  page.on('dialog',dialog=>dialog.accept());
  await page.goto('/labs/python/index.html');
  await expect(page.locator('#editor .monaco-editor')).toBeVisible({timeout:60000});
  await page.locator('#companionToken').fill('arcside-ci-throwaway-token');
  await page.locator('#connectCompanion').click();
  await expect(page.locator('#companionStatus')).toContainText('Connected',{timeout:20000});
  await expect(page.locator('#companionMode')).toHaveValue('local');
});

test('local companion executes native Python and selection snippets',async({page})=>{
  await page.evaluate(()=>window.monaco.editor.getModels().find(m=>m.uri.path.endsWith('main.py'))
    .setValue('print("local-native-python-ok")\n'));
  await page.locator('#run').click();
  await expect(page.locator('#stdout')).toContainText('local-native-python-ok',{timeout:60000});
  await expect(page.locator('#status')).toContainText('Native Python run');
  await page.locator('#runSelection').click();
  await expect(page.locator('#stdout')).toContainText('local-native-python-ok',{timeout:60000});
});

test('native pytest discovers and reports Python unit tests',async({page})=>{
  await page.locator('#runTests').click();
  await expect(page.locator('#stdout')).toContainText('2 passed',{timeout:60000});
  await expect(page.locator('#status')).toContainText('Native pytest');
});

test('native PTY terminal and real pylsp language server can connect',async({page})=>{
  await page.locator('[data-panel="terminal"]').click();
  await page.locator('#openLocalTerminal').click();
  await expect(page.locator('#terminalType')).toContainText('Real local shell',{timeout:20000});
  await expect(page.locator('#nativeTerminal')).toBeVisible();
  await page.locator('#closeLocalTerminal').click();
  await expect(page.locator('#nativeTerminal')).toBeHidden();
  await page.locator('#enableLsp').click();
  await expect(page.locator('#status')).toContainText('Language server active',{timeout:45000});
});

test('debugpy DAP launches a real script and exposes step controls',async({page})=>{
  test.setTimeout(120000);
  await page.evaluate(()=>window.monaco.editor.getModels().find(m=>m.uri.path.endsWith('main.py'))
    .setValue('n=5\nn+=2\nprint("dap-result",n)\n'));
  await page.locator('#debug').click();
  await expect(page.locator('#nativeDebugControls')).toBeVisible({timeout:60000});
  await expect(page.locator('#traceInfo')).toContainText('Paused',{timeout:60000});
  await page.locator('#debugOver').click();
  await expect(page.locator('#traceInfo')).toContainText(/Paused|Running/,{timeout:15000});
  await page.locator('#debugTerminate').click();
  await expect(page.locator('#nativeDebugControls')).toBeHidden();
});
