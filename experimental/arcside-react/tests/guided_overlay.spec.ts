import {test,expect} from '@playwright/test';
import {installGuidedOverlay} from '../scripts/guided_overlay.mjs';

test('stopwatch controls survive document reloads and SPA DOM removal',async({page})=>{
 const marks:{event:string;frame?:unknown}[]=[];
 await page.exposeFunction('arcsideOverlayTestMark',(mark:{event:string;frame?:unknown})=>{
  marks.push(mark);
 });
 await page.addInitScript(installGuidedOverlay,{
  binding:'arcsideOverlayTestMark',
  title:'Controlled evaluation',
  instructions:'Check actual values before recording success'
 });
 await page.route('**/phase3-overlay-test',route=>route.fulfill({
  contentType:'text/html',body:'<!doctype html><html><body><main>Original workflow</main></body></html>'
 }));
 await page.goto('/phase3-overlay-test');
 const panel=page.getByRole('group',{name:'Arcside matched-task benchmark'});
 await expect(panel).toBeVisible();
 await page.reload();
 await expect(panel).toBeVisible();
 await page.locator('[data-arcside-action="start"]').click();
 await page.locator('[data-arcside-action="finish"]').click();
 await expect.poll(()=>marks.length).toBe(2);
 expect(marks.map(x=>x.event)).toEqual(['start','finish']);
 await panel.evaluate(n=>n.remove());
 await expect(panel).toBeVisible();
 await page.locator('[data-arcside-action="start"]').click();
 await page.locator('[data-arcside-action="fail"]').click();
 await expect.poll(()=>marks.length).toBe(4);
 expect(marks.map(x=>x.event)).toEqual(['start','finish','start','fail']);
});
