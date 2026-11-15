import { test, expect } from '@playwright/test';

test.beforeEach(async ({page}) => {
  await page.goto('/labs/sheets/index.html');
  await expect(page.locator('#gridScroll')).toBeVisible();
  await expect(page.locator('.grid-cell').first()).toBeVisible();
});

test('starter workbook renders evaluated cells and recalculates after edit', async ({page}) => {
  await expect(page.locator('.grid-cell').filter({hasText:'38000'}).first()).toBeVisible();
  await page.locator('.grid-cell[title="120000"]').dblclick();
  await expect(page.locator('#cellEditor')).toBeVisible();
  await page.locator('#cellEditor').fill('130000');
  await page.locator('#cellEditor').press('Enter');
  await expect(page.locator('.grid-cell').filter({hasText:'48000'}).first()).toBeVisible();
  await expect(page.locator('.grid-cell').filter({hasText:'163700'}).first()).toBeVisible();
  await expect(page.locator('#saveStatus')).toContainText('Saved');
});

test('formula bar edits selected cell and displays arithmetic results', async ({page}) => {
  await page.locator('.grid-cell[title="=B2-C2"]').click();
  await expect(page.locator('#nameBox')).toHaveText('D2');
  await page.locator('#formulaInput').fill('=ROUND(SUM(B2:B5)/4,2)');
  await page.locator('#formulaInput').press('Enter');
  await expect(page.locator('.grid-cell').filter({hasText:'113875'}).first()).toBeVisible();
});

test('new sheets, cross-sheet references and formula circular errors', async ({page}) => {
  page.once('dialog',dialog=>dialog.accept('Tests'));
  await page.locator('[data-action="addSheet"]').click();
  await expect(page.locator('.sheet-tab.active')).toHaveText('Tests');
  await page.locator('#formulaInput').fill('=Analysis!B2/2');
  await page.locator('#formulaInput').press('Enter');
  await expect(page.locator('.grid-cell').filter({hasText:'60000'}).first()).toBeVisible();
  await page.locator('#gridScroll').focus();
  await page.keyboard.press('ArrowDown');
  await page.locator('#formulaInput').fill('=B2+1');
  await page.locator('#formulaInput').press('Enter');
  await page.locator('#gridScroll').focus();
  await page.keyboard.press('ArrowDown');
  await page.locator('#formulaInput').fill('=A2+1');
  await page.locator('#formulaInput').press('Enter');
  await expect(page.locator('.grid-cell').filter({hasText:'#CYCLE!'}).first()).toBeVisible();
});

test('chart modal and pivot summary use live sheet values', async ({page}) => {
  await page.locator('[data-action="chart"]').click();
  await expect(page.locator('#modal')).toBeVisible();
  await expect(page.locator('#modal .chart')).toBeVisible();
  await page.locator('#closeModal').click();
  await page.locator('[data-action="pivot"]').click();
  await expect(page.locator('.sheet-tab.active')).toContainText('Pivot');
  await expect(page.locator('.grid-cell').filter({hasText:'120000'}).first()).toBeVisible();
});

test('workbook JSON export is offered as downloadable file', async ({page}) => {
  const downloadPromise=page.waitForEvent('download');
  await page.locator('[data-action="exportWorkbook"]').click();
  const file=await downloadPromise;
  expect(file.suggestedFilename()).toMatch(/\.arcside\.json$/);
});

test('grid mounts at a mobile viewport without creating millions of DOM nodes', async ({page}) => {
  await page.setViewportSize({width:390,height:780});
  await page.reload();
  await expect(page.locator('#gridScroll')).toBeVisible();
  const count=await page.locator('.grid-cell').count();
  expect(count).toBeGreaterThan(10);
  expect(count).toBeLessThan(3000);
});
