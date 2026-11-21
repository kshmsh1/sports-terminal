import {test,expect} from '@playwright/test';
import {mockStatic,makeRows} from './mock';

test.beforeEach(async({page})=>{await mockStatic(page);});

test('genuine-zero versus missing fields, 50-game filter, and source-recorded team stints',async({page})=>{
 const base=makeRows(3);
 const traded={...base[0],player_id:'synthetic-traded',player_label:'Test Traded',
  team_ids:'BOS,CHI',games:50,plus_minus:0,team_stints:[
   {...base[0],player_id:'synthetic-traded',player_label:'Test Traded',team_ids:'BOS',games:25,plus_minus:0},
   {...base[0],player_id:'synthetic-traded',player_label:'Test Traded',team_ids:'CHI',games:25,plus_minus:0}
  ]};
 const disqualified={...base[1],player_id:'synthetic-49',player_label:'Test 49',games:49};
 const missing={...base[2],player_id:'synthetic-missing',player_label:'Test Missing',games:52,
  plus_minus:undefined};
 await page.route('**/data/nba_static/seasons/2025-26/regular.json',r=>
  r.fulfill({status:200,contentType:'application/json',
   body:JSON.stringify({season_id:'2025-26',season_type:'regular',
    players:[],player_season_totals:[traded,disqualified,missing]})}));
 await page.goto('/stats?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByText('2 of 3 player rows',{exact:false})).toBeVisible();
 await expect(page.getByRole('button',{name:'Expand stints for Test Traded'})).toBeVisible();
 await page.getByRole('button',{name:'Expand stints for Test Traded'}).click();
 await expect(page.locator('.stint-row')).toHaveCount(2);
 await page.getByLabel('Find player').fill('Test Missing');
 await expect(page.getByText('1 of 3 player rows',{exact:false})).toBeVisible();
 await expect(page.locator('tbody tr:not(.spacer-row)').first()).toContainText('—');
 await page.getByLabel('Find player').fill('');
 await page.getByRole('checkbox',{name:/Qualify/}).uncheck();
 await expect(page.getByText('3 of 3 player rows',{exact:false})).toBeVisible();
});

test('narrow viewport retains navigability, keyboard focus and rate controls',async({page})=>{
 await page.setViewportSize({width:390,height:844});
 await page.goto('/stats?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Player statistics'})).toBeVisible();
 await page.getByRole('link',{name:'Skip to content'}).focus();
 await expect(page.getByRole('link',{name:'Skip to content'})).toBeFocused();
 await page.getByLabel('Rate basis').selectOption('per100');
 await expect(page).toHaveURL(/basis=per100/);
 await page.getByRole('button',{name:'Playoffs'}).click();
 await expect(page).toHaveURL(/segment=playoffs/);
 await expect(page.getByText('1 of 1 player rows',{exact:false})).toBeVisible();
 await expect(page.getByRole('alert')).toHaveCount(0);
});
