import {test,expect} from '@playwright/test';

test.skip(!process.env.ARCSIDE_COLLAB_E2E_ADMIN,
  'Realtime collaboration browser suite runs with the isolated collaboration service');
test.setTimeout(100000);
const ADMIN=process.env.ARCSIDE_COLLAB_E2E_ADMIN;

async function createRoom(page){
  await page.goto('/labs/sheets/index.html');
  await expect(page.locator('.grid-cell[title="120000"]')).toBeVisible();
  await page.locator('#shareWorkbook').click();
  await expect(page.locator('#modal')).toBeVisible();
  await page.locator('#collabAdmin').fill(ADMIN);
  await page.locator('#collabCreate').click();
  await expect(page.locator('#collabDialogStatus')).toContainText('owner');
  const room=await page.locator('[aria-label="Room ID access key"]').inputValue();
  const editor=await page.locator('[aria-label="Editor access key"]').inputValue();
  const viewer=await page.locator('[aria-label="Viewer access key"]').inputValue();
  await page.locator('#closeModal').click();
  return {room,editor,viewer};
}
async function joinRoom(page,room,key){
  await page.goto('/labs/sheets/index.html');
  await page.locator('#shareWorkbook').click();
  await page.locator('#collabRoom').fill(room);
  await page.locator('#collabKey').fill(key);
  page.once('dialog',dialog=>dialog.accept());
  await page.locator('#collabJoin').click();
  await expect(page.locator('#collabDialogStatus')).toContainText('Connected as');
  await page.locator('#closeModal').click();
}

test('two Chromium clients edit different cells, sync in real time, and share presence',async({browser})=>{
  const first=await browser.newContext(),second=await browser.newContext();
  const a=await first.newPage(),b=await second.newPage();
  try{
    const keys=await createRoom(a);
    await joinRoom(b,keys.room,keys.editor);
    await expect(a.locator('#collabPeople')).toContainText('Arcside collaborator');
    await a.locator('.grid-cell[title="120000"]').dblclick();
    await a.locator('#cellEditor').fill('131000');
    await a.locator('#cellEditor').press('Enter');
    await expect(b.locator('.grid-cell[title="131000"]')).toBeVisible({timeout:15000});
    await b.locator('.grid-cell[title="82000"]').dblclick();
    await b.locator('#cellEditor').fill('90000');
    await b.locator('#cellEditor').press('Enter');
    await expect(a.locator('.grid-cell[title="90000"]')).toBeVisible({timeout:15000});
    await expect(a.locator('.grid-cell[title="=B2-C2"]')).toContainText('41000');
    await expect(b.locator('.grid-cell[title="=B2-C2"]')).toContainText('41000');
  }finally{await first.close();await second.close();}
});

test('viewer role receives live updates but cannot persist edits',async({browser})=>{
  const first=await browser.newContext(),viewer=await browser.newContext();
  const a=await first.newPage(),b=await viewer.newPage();
  try{
    const keys=await createRoom(a);
    await joinRoom(b,keys.room,keys.viewer);
    await expect(b.locator('#collabStatus')).toContainText('viewer');
    await b.locator('.grid-cell[title="120000"]').dblclick();
    await b.locator('#cellEditor').fill('999999');
    await b.locator('#cellEditor').press('Enter');
    await expect(b.locator('.grid-cell[title="120000"]')).toBeVisible({timeout:10000});
    await expect(a.locator('.grid-cell[title="120000"]')).toBeVisible();
    await a.locator('.grid-cell[title="120000"]').dblclick();
    await a.locator('#cellEditor').fill('123000');
    await a.locator('#cellEditor').press('Enter');
    await expect(b.locator('.grid-cell[title="123000"]')).toBeVisible({timeout:15000});
  }finally{await first.close();await viewer.close();}
});

test('sheet creation broadcasts an atomic workbook structure replacement',async({browser})=>{
  const first=await browser.newContext(),second=await browser.newContext();
  const a=await first.newPage(),b=await second.newPage();
  try{
    const keys=await createRoom(a);
    await joinRoom(b,keys.room,keys.editor);
    a.once('dialog',dialog=>dialog.accept('Collab Data'));
    await a.locator('[data-action="addSheet"]').click();
    await expect(b.locator('.sheet-tab').filter({hasText:'Collab Data'})).toBeVisible({timeout:15000});
  }finally{await first.close();await second.close();}
});
