import {test,expect} from '@playwright/test';
import {mockStatic} from './mock';
test.beforeEach(async({page})=>{await mockStatic(page);});
test('deep link, history, qualification, rate switch and virtual scrolling',async({page})=>{
 await page.goto('/stats?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Player statistics'})).toBeVisible();
 await expect(page.getByText('150 of 150 player rows')).toBeVisible();
 await expect(page.getByRole('link',{name:'Synthetic Player 0'})).toHaveCount(0); // virtualized
 const scroller=page.getByRole('region',{name:'Scrollable player stats'});
 await scroller.evaluate(el=>{el.scrollTop=4000;el.dispatchEvent(new Event('scroll'));});
 await expect(page.getByRole('link',{name:/Synthetic Player/}).first()).toBeVisible();
 await page.getByRole('button',{name:'Sort by PTS'}).click();
 await page.getByLabel('Rate basis').selectOption('per36');
 await expect(page).toHaveURL(/basis=per36/);
 await page.getByRole('button',{name:'Playoffs'}).click();
 await expect(page).toHaveURL(/segment=playoffs/);
 await expect(page.getByText('1 of 1 player rows')).toBeVisible();
 await page.reload();
 await expect(page.getByRole('button',{name:'Playoffs'})).toHaveAttribute('aria-pressed','true');
 await page.getByRole('button',{name:'Open Advanced Stats'}).click();
 await expect(page).toHaveURL(/advanced/);
 await page.goBack();
 await expect(page).toHaveURL(/stats/);
});
test('scatter interactions and theme persist across refresh',async({page})=>{
 await page.goto('/visualizations?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByText('150 plotted')).toBeVisible();
 await page.getByRole('button',{name:'Drag pan'}).click();
 await expect(page.getByRole('button',{name:'Drag pan'})).toHaveAttribute('aria-pressed','true');
 await page.getByLabel('X metric').selectOption('reb');
 await page.getByRole('checkbox',{name:'Linear reference'}).check();
 await page.getByRole('button',{name:'Reset view'}).click();
 await page.getByRole('button',{name:'Switch to light theme'}).click();
 await expect(page.locator('html')).toHaveAttribute('data-theme','light');
 await page.reload();
 await expect(page.getByLabel('X metric')).toHaveValue('reb');
 await expect(page.locator('html')).toHaveAttribute('data-theme','light');
});
test('original embedded Python and Sheets receive strictly typed, same-origin context',async({page})=>{
 await page.goto('/workspaces/python?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByText('Context handshake: acknowledged')).toBeVisible({timeout:30000});
 let frame=page.frameLocator('iframe[title="Python Lab"]');
 await expect(frame.locator('#arcside-shell-context')).toContainText('2025-26 / regular');
 await expect(frame.locator('#projectName')).toBeVisible();
 await page.getByRole('link',{name:'Excel Workspace'}).click();
 await expect(page.getByText('Context handshake: acknowledged')).toBeVisible({timeout:30000});
 frame=page.frameLocator('iframe[title="Excel Workspace"]');
 await expect(frame.locator('#arcside-shell-context')).toContainText('2025-26 / regular');
 await expect(frame.locator('#workbookName')).toBeVisible();
});

test('semantic sort announcement and keyboard reachability',async({page})=>{
 await page.goto('/stats?season=2025-26&segment=regular&basis=perGame');
 const header=page.getByRole('columnheader',{name:/PTS/});
 await expect(header).toHaveAttribute('aria-sort','descending');
 await page.getByRole('button',{name:'Sort by PTS'}).click();
 await expect(header).toHaveAttribute('aria-sort','ascending');
 await page.getByRole('link',{name:'Skip to content'}).focus();
 await expect(page.getByRole('link',{name:'Skip to content'})).toBeFocused();
 await page.getByRole('button',{name:'Open Advanced Stats'}).click();
 await expect(page).toHaveURL(/advanced/);
});


test('advanced stats matches Flutter Overview production, rate-specific labels and sorting',async({page})=>{
 await page.goto('/advanced?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Advanced player statistics'})).toBeVisible();
 await expect(page.getByRole('button',{name:'Overview',exact:true})).toHaveAttribute('aria-pressed','true');
 await expect(page.getByRole('button',{name:'Sort by PPG'})).toBeVisible();
 await page.getByLabel('Rate basis').selectOption('per36');
 await expect(page.getByRole('button',{name:'Sort by PTS/36'})).toBeVisible();
 await page.getByLabel('Rate basis').selectOption('per100');
 const points=page.getByRole('button',{name:'Sort by PTS/100'});
 await expect(points).toBeVisible();
 await points.click();
 await expect(page.getByRole('columnheader',{name:/PTS/})).toHaveAttribute('aria-sort','ascending');
});
test('advanced stats exposes all Flutter metric families, filters, pagination and source-null values',async({page})=>{
 await page.goto('/advanced?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('group',{name:'Advanced stat groups'}).getByRole('button')).toHaveCount(18);
 await page.getByRole('button',{name:'Hustle Breakdown'}).click();
 await expect(page.getByRole('button',{name:'Sort by HUSTLE GP'})).toBeVisible();
 await expect(page.getByRole('cell',{name:'—'}).first()).toBeVisible();
 await page.getByLabel('Minimum GP').selectOption('0');
 await page.getByLabel('Minimum MPG').selectOption('0');
 await expect(page.getByText('150 of 150 player rows')).toBeVisible();
 await page.getByRole('button',{name:'Next page'}).click();
 await expect(page.getByText('Page 2 / 8')).toBeVisible();
 await page.getByRole('button',{name:'Overview',exact:true}).click();
 await expect(page.getByRole('button',{name:'Expand RPG'})).toBeVisible();
 await page.getByRole('button',{name:'Expand RPG'}).click();
 await expect(page.getByRole('button',{name:'Sort by ORB'})).toBeVisible();
});
