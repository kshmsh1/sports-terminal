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
 await expect(page.getByText('40 plotted from 150 eligible', {exact:false})).toBeVisible();
 // Real-corpus acceptance must target the plotted-count paragraph, not the
 // neighboring `.subtle` color-group label in the same chart header.
 const plottedSummary=page.locator('.studio-chart-title p.subtle');
 await expect(plottedSummary).toHaveCount(1);
 await expect(plottedSummary).toContainText(/^40 plotted from 150 eligible/);
 await expect(page.getByRole('button',{name:'Drag pan'})).toHaveCount(0);
 await expect(page.getByRole('button',{name:'Wheel zoom'})).toHaveCount(0);
 // ECharts exposes inside dataZoom for wheel zoom and mouse-drag panning together.
 const chart=page.locator('.studio-chart');
 await expect(chart).toBeVisible();
 await expect(page.getByRole('button',{name:'Reset view'})).toBeVisible();
 await page.getByLabel('X metric').selectOption('reb');
 await page.getByRole('checkbox',{name:'Best-fit line'}).check();
 await page.getByRole('button',{name:'Reset view'}).click();
 await page.getByRole('button',{name:'Switch to light theme'}).click();
 await expect(page.locator('html')).toHaveAttribute('data-theme','light');
 await page.reload();
 await expect(page.getByLabel('X metric')).toHaveValue('reb');
 await expect(page.locator('html')).toHaveAttribute('data-theme','light');
});
test('wheel zoom, direct drag pan, and reset move the actual chart viewport without mode switches',async({page})=>{
 await page.goto('/visualizations?season=2025-26&segment=regular&basis=perGame');
 const plot=page.locator('.studio-chart');
 await expect(plot).toHaveAttribute('data-viewport-range','0.000:100.000|0.000:100.000');
 await plot.scrollIntoViewIfNeeded();
 const bounds=await plot.boundingBox();
 expect(bounds).not.toBeNull();
 const box=bounds!;
 await page.mouse.move(box.x+box.width*.55,box.y+box.height*.52);
 await page.mouse.wheel(0,-600);
 await expect.poll(()=>plot.getAttribute('data-viewport-range')).not.toBe('0.000:100.000|0.000:100.000');
 const zoomed=await plot.getAttribute('data-viewport-range');
 await page.mouse.move(box.x+box.width*.50,box.y+box.height*.52);
 await page.mouse.down();
 await page.mouse.move(box.x+box.width*.68,box.y+box.height*.65,{steps:12});
 await page.mouse.up();
 await expect.poll(()=>plot.getAttribute('data-viewport-range')).not.toBe(zoomed);
 await page.getByRole('button',{name:'Reset view'}).click();
 await expect(plot).toHaveAttribute('data-viewport-range','0.000:100.000|0.000:100.000');
 await expect(page.getByRole('button',{name:'Drag pan'})).toHaveCount(0);
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
 await page.getByRole('button',{name:'Next page'}).first().click();
 await expect(page.getByText('Page 2 / 8').first()).toBeVisible();
 await page.getByRole('button',{name:'Overview',exact:true}).click();
 await expect(page.getByRole('button',{name:'Expand RPG'})).toBeVisible();
 await page.getByRole('button',{name:'Expand RPG'}).click();
 await expect(page.getByRole('button',{name:'Sort by ORB'})).toBeVisible();
});

test('Flutter-style scatter defaults to top 40 by PTS and supports filtered exact populations',async({page})=>{
 await page.goto('/visualizations?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByLabel('Population size')).toHaveValue('40');
 await expect(page.getByText('40 plotted from 150 eligible',{exact:false})).toBeVisible();
 await expect(page.getByLabel('Linear regression statistics')).toContainText('40');
 await expect(page.getByText('Showing 40')).toBeVisible();
 const table=page.locator('.studio-underlying-title').locator('..').locator('table');
 await expect(table.getByRole('row')).toHaveCount(41);
 await expect(table.getByRole('row').nth(1)).toContainText('Synthetic Player 149');
 await page.getByLabel('Population size').selectOption('10');
 await expect(page.getByText('10 plotted from 150 eligible',{exact:false})).toBeVisible();
 await expect(table.getByRole('row')).toHaveCount(11);
 await page.getByLabel('Minimum games').fill('82');
 await expect(page.getByText('0 plotted from 0 eligible',{exact:false})).toBeVisible();
 await page.getByLabel('Minimum games').fill('50');
 await page.getByLabel('Population size').selectOption('0');
 await expect(page.getByText('150 plotted from 150 eligible',{exact:false})).toBeVisible();
 await expect(page.locator('.studio .chart-accessible tbody tr')).toHaveCount(100);
 await page.getByRole('button',{name:'Next rows'}).click();
 await expect(page.locator('.studio .chart-accessible tbody tr')).toHaveCount(50);
 await expect(page.getByText('Page 2 of 2')).toBeVisible();
 await page.getByRole('button',{name:'Previous rows'}).click();
 await expect(page.locator('.studio .chart-accessible tbody tr')).toHaveCount(100);
 await page.getByLabel('Filter by team or player').fill('BOS');
 await page.getByRole('button',{name:'Team: BOS'}).click();
 await expect(page.getByText('75 plotted from 75 eligible',{exact:false})).toBeVisible();
 await page.getByRole('button',{name:/Clear filter: Team BOS/}).click();
 await expect(page.getByText('150 plotted from 150 eligible',{exact:false})).toBeVisible();
});
test('studio uses source-backed chart settings, multiple visualizations and local presets',async({page})=>{
 await page.goto('/visualizations?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByLabel('Best-fit line')).toBeChecked();
 await page.getByLabel('X metric').selectOption('reb');
 await page.getByLabel('Y metric').selectOption('ast');
 await page.getByLabel('Player labels').uncheck();
 await page.getByLabel('Mean reference lines').check();
 await page.getByLabel('Color by').selectOption('Position');
 await page.getByLabel('Preset name').fill('Custom test view');
 await page.getByRole('button',{name:'Save as'}).click();
 await page.getByLabel('Chart type').selectOption('bar');
 await expect(page.getByText('20 plotted from 150 eligible',{exact:false})).toBeVisible();
 await page.getByLabel('Chart type').selectOption('histogram');
 await page.getByLabel('Histogram bins').selectOption('16');
 await page.getByLabel('Chart type').selectOption('cumulative');
 await page.getByLabel('Chart type').selectOption('box');
 await page.getByLabel('Chart type').selectOption('radar');
 await page.getByLabel('Chart type').selectOption('bubble');
 await page.getByLabel('Saved presets').selectOption('Custom test view');
 await expect(page.getByLabel('Chart type')).toHaveValue('scatter');
 await expect(page.getByLabel('X metric')).toHaveValue('reb');
 await expect(page.getByLabel('Y metric')).toHaveValue('ast');
 await expect(page.getByLabel('Player labels')).not.toBeChecked();
 await page.reload();
 await expect(page.getByLabel('Population size')).toHaveValue('40');
 await expect(page.getByLabel('X metric')).toHaveValue('reb');
 await expect(page.getByLabel('Saved presets')).toContainText('Custom test view');
});

test('Trade Machine pilot validates an editable modeled scenario without implying NBA execution',async({page})=>{
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await page.getByRole('button',{name:'Advanced scenario editor'}).click();
 await page.getByRole('button',{name:'Reset example'}).click();
 await expect(page.getByRole('heading',{name:/Trade Machine/})).toBeVisible();
 await expect(page.getByRole('status').filter({hasText:'No modeled blocking errors'})).toBeVisible();
 await page.getByRole('button',{name:'Show modeled validation details'}).click();
 await page.getByLabel('Asset 1 salary').fill('100000000');
 await expect(page.getByRole('status').filter({hasText:'blocking errors'})).toBeVisible();
 await page.getByRole('button',{name:'Add asset'}).click();
 await expect(page.getByLabel('Asset 3 ID')).toBeVisible();
 await page.getByRole('button',{name:'Reset example'}).click();
 await expect(page.getByRole('status').filter({hasText:'No modeled blocking errors'})).toBeVisible();
});

test('multi-team hypothetical trade editor never treats blank payroll as zero',async({page})=>{
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await page.getByRole('button',{name:'Advanced scenario editor'}).click();
 await page.getByRole('button',{name:'Reset example'}).click();
 await page.getByRole('button',{name:'Add participating team (2–5)'}).click();
 await expect(page.getByLabel('Trade team 3',{exact:true})).toHaveValue('CCC');
 await expect(page.getByRole('row').filter({hasText:'CCC'})).toBeVisible();
 await page.getByLabel('Trade team 3 salary').fill('');
 await expect(page.getByRole('alert')).toContainText('Enter nonnegative numeric payrolls');
 await page.getByLabel('Trade team 3 salary').fill('140000000');
 await page.getByRole('button',{name:'Remove team 3'}).click();
 await expect(page.getByLabel('Trade team 3',{exact:true})).toHaveCount(0);
});

test('player dossier exposes published historical career and advanced family tables',async({page})=>{
 await page.goto('/player/synthetic-0?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Synthetic Player 0'})).toBeVisible();
 const career=page.getByRole('region',{name:'Player career statistics table'});
 await expect(career.getByRole('row')).toHaveCount(3);
 await expect(career.getByRole('row').nth(1)).toContainText('2025-26');
 await expect(career.getByRole('row').nth(1)).toContainText('20.0');
 await career.getByRole('button',{name:'Expand RPG'}).click();
 await expect(career.getByRole('columnheader',{name:'ORB'})).toBeVisible();
 const advanced=page.getByRole('region',{name:'Player advanced statistics table'});
 await expect(advanced.getByRole('columnheader',{name:'BPM'})).toBeVisible();
 await page.getByRole('button',{name:'Playoffs'}).first().click();
 await expect(career.getByRole('row')).toHaveCount(2);
 await expect(career.getByRole('row').nth(1)).toContainText('2025-26');
 await page.getByLabel('Player advanced stat family').selectOption('Hustle Breakdown');
 await expect(page.getByText('Hustle Breakdown statistics have no published source-backed values')).toBeVisible();
 await page.reload();
 await expect(page).toHaveURL(/segment=playoffs/);
 await expect(career.getByRole('row')).toHaveCount(2);
});

test('original Flutter 2026–27 seed is served with source and dated provenance',async({page})=>{
 const response=await page.request.get('/data/phase3/2026-27-contracts.json');
 expect(response.ok()).toBeTruthy();
 const payload=await response.json();
 expect(payload.kind).toBe('ARCSIDE_ORIGINAL_FLUTTER_2026_27_CONTRACT_SEED_V1');
 expect(payload.asOf).toBe('2026-09-11');
 expect(payload.records.find((x:{player:string})=>x.player==='Stephen Curry')?.salaries['2026-27']).toBe(62587158);
 expect(payload.records.length).toBeGreaterThan(100);
});

test('player contract panel prioritizes dated original salary snapshot over front-office registry',async({page})=>{
 await page.route('**/data/phase3/2026-27-contracts.json',route=>
  route.fulfill({status:200,contentType:'application/json',
   body:JSON.stringify({kind:'ARCSIDE_ORIGINAL_FLUTTER_2026_27_CONTRACT_SEED_V1',
    asOf:'2026-09-11',dartSeedSha256:'synthetic-test-only',sourceNote:'Fixture',
    records:[{id:'CHI:synthetic-player-0',player:'Synthetic Player 0',team:'CHI',
     salaries:{'2026-27':12000000},guaranteed:8000000,sourceStatus:'uploaded',
     sourceLabel:'Synthetic test source'}]})}));
 await page.route('**/data/nba_static/front_office/contracts.json',route=>
  route.fulfill({status:200,contentType:'application/json',body:JSON.stringify([{
   record:{player_id:'synthetic-0',team_id:'BOS',season:'2025-26',years:[{season:'2025-26',salary:6000000}]}
  }])}));
 await page.goto('/player/synthetic-0?season=2025-26&segment=regular&basis=perGame');
 const section=page.getByRole('region',{name:'Player contract'});
 await expect(section.getByText('2026–27 · Current salary record')).toBeVisible();
 await expect(section).toContainText('$12,000,000');
 await expect(section).toContainText('Synthetic test source');
 await expect(section).not.toContainText('BOS · 2025-26');
});

test('player comparison reuses canonical player metrics, multiple slots and tied-value rules',async({page})=>{
 await page.goto('/player-compare?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Player Comparison'})).toBeVisible();
 await page.getByLabel('Compare player 1',{exact:true}).selectOption('synthetic-0');
 await page.getByLabel('Compare player 2',{exact:true}).selectOption('synthetic-2');
 const table=page.getByRole('region',{name:'Player comparison metrics'});
 await expect(table).toBeVisible();
 await expect(table.getByRole('row',{name:/PTS/})).toBeVisible();
 await page.getByRole('button',{name:'Add player'}).click();
 await expect(page.getByLabel('Compare player 3',{exact:true})).toBeVisible();
 await page.getByLabel('Compare metric group').selectOption('Defense');
 await expect(table.getByRole('row',{name:/STOCKS/})).toBeVisible();
 await page.getByRole('button',{name:'Reset comparison'}).click();
 await expect(page.getByText(/Select at least two source-backed players/)).toBeVisible();
});
test('team comparison uses published team records, not fabricated team values',async({page})=>{
 await page.goto('/team-compare?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Team Comparison'})).toBeVisible();
 await page.getByLabel('Compare team 1',{exact:true}).selectOption('CHI');
 await page.getByLabel('Compare team 2',{exact:true}).selectOption('BOS');
 const table=page.getByRole('region',{name:'Team comparison metrics'});
 await expect(table).toContainText('Chicago');
 await expect(table.getByRole('row').filter({has:page.getByRole('rowheader',{name:'PPG',exact:true})})).toContainText('105.0');
 await page.getByLabel('Compare metric group').selectOption('Efficiency');
 await expect(table.getByRole('row',{name:/SRS/})).toContainText('—');
});
test('box scores use published original index and detail, including player inspection',async({page})=>{
 await page.goto('/box-scores?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Box Scores'})).toBeVisible();
 await page.getByRole('button',{name:/BOS 100 @ CHI 110/}).click();
 const detail=page.getByLabel('Game box-score inspector');
 await expect(detail.getByText('BOS @ CHI')).toBeVisible();
 await page.getByRole('group',{name:'Box score team'}).getByRole('button',{name:'CHI'}).click();
 await expect(page.getByRole('region',{name:'Individual game box score'})).toContainText('Synthetic Player 0');
 await page.getByRole('region',{name:'Individual game box score'}).getByRole('button',{name:'Synthetic Player 0'}).click();
 await expect(detail).toContainText('PTS: 25');
});
test('Financials renders original Flutter team reference, never a synthesized mock',async({page})=>{
 await page.route('**/data/phase3/2026-27-team-financials.json',route=>
  route.fulfill({status:200,contentType:'application/json',
   body:JSON.stringify({kind:'ARCSIDE_ORIGINAL_FLUTTER_TEAM_FINANCIALS_2026_27_V1',
    sourceAsOf:'2026-10-05',source:'Synthetic browser fixture',
    dartSourceSha256:'synthetic-browser-only',teams:Array.from({length:30},(_,i)=>({
     team:i===0?'CHI':'T'+String(i).padStart(2,'0'),standardRoster:14,twoWayRoster:3,
     capSpace:i===0?1000000:0,taxSpace:0,firstApronSpace:0,secondApronSpace:0,
     hardCap:null,availableExceptions:{},largestTpe:null,largestTpeExpires:null}))})}));
 await page.goto('/financials?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Financials'})).toBeVisible();
 await page.getByRole('button',{name:'CHI'}).click();
 await expect(page.getByLabel('Financial team inspector')).toContainText('$1,000,000');
});
test('with/without displays only genuinely published player-pair splits',async({page})=>{
 await page.goto('/with-without?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'With / Without'})).toBeVisible();
 await expect(page.getByText('SYNTHETIC_PLAYWRIGHT_ONLY')).toBeVisible();
 await page.getByLabel('With/without team').selectOption('CHI');
 await page.getByLabel('With/without player B').selectOption('synthetic-2');
 const table=page.getByRole('region',{name:'Synthetic Player 0 published splits'});
 await expect(table).toContainText('24.0');
 await expect(table).toContainText('20.0');
 await page.getByRole('button',{name:'Playoffs'}).first().click();
 await expect(page.getByText(/Lineup stint \/ play-by-play splits have not been materialized/)).toBeVisible();
});

test('player comparison saves and restores independent historical slots locally',async({page})=>{
 await page.goto('/player-compare?season=2025-26&segment=regular&basis=perGame');
 await page.getByLabel('Compare player 1',{exact:true}).selectOption('synthetic-0');
 await page.getByLabel('Compare player 2',{exact:true}).selectOption('synthetic-2');
 await page.getByLabel('Comparison preset name').fill('Test player matchup');
 await page.getByRole('button',{name:'Save local preset'}).click();
 await page.getByRole('button',{name:'Reset comparison'}).click();
 await expect(page.getByText(/Select at least two source-backed players/)).toBeVisible();
 await page.getByLabel('Saved comparison').selectOption('Test player matchup');
 await expect(page.getByLabel('Compare player 1',{exact:true})).toHaveValue('synthetic-0');
 await expect(page.getByLabel('Compare player 2',{exact:true})).toHaveValue('synthetic-2');
});
test('team directory resolves source index and opens true historical dossier',async({page})=>{
 await page.goto('/teams?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Teams',exact:true})).toBeVisible();
 await page.getByLabel('Find team').fill('Chicago');
 await page.getByRole('region',{name:'NBA teams directory'}).getByRole('button',{name:/Chicago.*CHI/}).click();
 await expect(page.getByRole('heading',{name:'Chicago',exact:true})).toBeVisible();
 await expect(page.getByRole('region',{name:'Team season history'})).toContainText('2025-26');
 await page.getByRole('group',{name:'Team history segment'}).getByRole('button',{name:'Playoffs'}).click();
 await expect(page.getByRole('region',{name:'Team season history'})).toContainText('2025-26');
 await expect(page.getByRole('region',{name:'Team season history'})).toContainText('6');
});
test('historical game finder shows published box score and optional true play-by-play',async({page})=>{
 await page.goto('/games?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Games',exact:true})).toBeVisible();
 await expect(page.getByRole('region',{name:'Published games'})).toContainText('synthetic-game-001');
 await page.getByRole('region',{name:'Published games'}).getByRole('button',{name:'Inspect'}).click();
 await expect(page.getByRole('region',{name:'Game player statistics'})).toContainText('Synthetic Player 0');
 await expect(page.getByRole('region',{name:'Published play-by-play'})).toContainText('Synthetic opening shot');
 await page.getByRole('button',{name:'Close game'}).click();
 await expect(page.getByRole('region',{name:'Game details'})).toHaveCount(0);
});
test('franchise history preserves Flutter planned-only scope and published identities',async({page})=>{
 await page.goto('/franchise-history?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'Franchise History'})).toBeVisible();
 await expect(page.getByRole('region',{name:'Franchise history build plan'})).toContainText('Historical names and relocations');
 await expect(page.getByRole('region',{name:'Franchise history build plan'})).toContainText('Planned');
 await page.getByLabel('Find franchise').fill('Chicago');
 await page.getByRole('region',{name:'Published franchise identity records'}).getByRole('button',{name:/Chicago/}).click();
 await expect(page.getByLabel('Franchise identity details')).toContainText('franchise-chi');
 await page.getByRole('button',{name:'Open team detail'}).click();
 await expect(page.getByRole('heading',{name:'Chicago',exact:true})).toBeVisible();
});

test('Trade Machine imports only exact original Flutter cap ledger for selected teams',async({page})=>{
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await page.getByRole('button',{name:'Advanced scenario editor'}).click();
 const res=await page.request.get('/data/phase3/2026-27-team-cap-ledger.json');
 expect(res.status()).toBe(200);
 const ledger=await res.json();
 expect(ledger.kind).toBe('ARCSIDE_ORIGINAL_DART_TEAM_CAP_LEDGER_2026_27_V1');
 expect(ledger.teams).toHaveLength(30);
 const bos=ledger.teams.find((x:{team:string})=>x.team==='BOS');
 const phi=ledger.teams.find((x:{team:string})=>x.team==='PHI');
 expect(bos?.totalCap).toBeGreaterThan(0);
 expect(phi?.totalCap).toBeGreaterThan(0);
 await page.getByLabel('Trade first team').fill('BOS');
 await page.getByLabel('Trade second team').fill('PHI');
 await page.getByRole('button',{name:'Apply original team cap ledgers to participating teams'}).click();
 await expect(page.getByLabel('First team salary')).toHaveValue(String(bos.salaryPosition));
 await expect(page.getByLabel('Second team salary')).toHaveValue(String(phi.salaryPosition));
 await expect(page.getByRole('status').filter({hasText:'Using original Flutter dated cap ledgers'})).toBeVisible();
 await page.getByLabel('First team salary').fill('140000000');
 await expect(page.getByRole('status').filter({hasText:'Using original Flutter dated cap ledgers'})).toHaveCount(0);
});

test('Trade Machine imports canonical dated first/second-round interests and TPE with restrictions',async({page})=>{
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await page.getByRole('button',{name:'Advanced scenario editor'}).click();
 const response=await page.request.get('/data/phase3/2026-27-draft-exceptions.json');
 expect(response.status()).toBe(200);
 const payload=await response.json();
 expect(payload.kind).toBe('ARCSIDE_ORIGINAL_FLUTTER_DRAFT_TPE_2026_27_V1');
 expect(payload.draftAssets.length).toBeGreaterThan(500);
 expect(payload.exceptions.length).toBeGreaterThan(50);
 expect(payload.firstSourceSha256).toMatch(/^[a-f0-9]{64}$/);
 expect(payload.secondSourceSha256).toMatch(/^[a-f0-9]{64}$/);
 const unavailable=payload.draftAssets.find((x:{id:string})=>x.id==='BOS-2029-1-OUT');
 expect(unavailable?.tradable).toBe(false);
 await page.getByLabel('Trade first team').fill('BOS');
 await page.getByLabel('Trade second team').fill('PHI');
 await expect(page.getByLabel('Source draft interest').locator('option[value="BOS-2029-1-OUT"]')).toHaveAttribute('disabled','');
 await page.getByLabel('Source draft interest').selectOption('BOS-2027-1');
 await page.getByLabel('Source asset receiving team').selectOption('PHI');
 await page.getByRole('button',{name:'Apply original team cap ledgers to participating teams'}).click();
 await page.getByRole('button',{name:'Add source draft interest'}).click();
 await expect(page.getByLabel('Asset 1 ID')).toHaveValue('BOS-2027-1');
 const tpe=payload.exceptions.find((x:{id:string})=>x.id==='BOS-simons-2027');
 expect(tpe?.available).toBeGreaterThan(0);
 await page.getByLabel('TPE receiving team').selectOption('BOS');
 await page.getByLabel('Source trade exception').selectOption('BOS-simons-2027');
 await page.getByRole('button',{name:'Use TPE for receiving team'}).click();
 await expect(page.getByText(/BOS models acquisition with/)).toBeVisible();
 await expect(page.getByLabel('Asset 2 ID')).toHaveCount(0);
 await page.getByRole('button',{name:'Show modeled validation details'}).click();
 await expect(page.getByLabel('CBA findings')).toContainText('TPE_UNUSED');
});

test('manual asset routing refuses to transfer TPE or signing exceptions',async({page})=>{
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await page.getByRole('button',{name:'Advanced scenario editor'}).click();
 await page.getByRole('button',{name:'Reset example'}).click();
 await page.getByLabel('Asset 1 type').selectOption('tradeException');
 await expect(page.getByRole('alert').filter({hasText:'TPEs and signing exceptions are not transferable'})).toBeVisible();
 await page.getByLabel('Asset 1 type').selectOption('signingException');
 await expect(page.getByRole('alert').filter({hasText:'TPEs and signing exceptions are not transferable'})).toBeVisible();
});

test('React-first trade workspace starts empty and examples remain opt-in',async({page})=>{
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await page.getByRole('button',{name:'Advanced scenario editor'}).click();
 await expect(page.getByLabel('Trade first team')).toHaveValue('');
 await expect(page.getByLabel('Asset 1 ID')).toHaveCount(0);
 await expect(page.getByText('No assets assigned.',{exact:false})).toBeVisible();
 await page.getByRole('button',{name:'Reset example'}).click();
 await expect(page.getByLabel('Asset 1 ID')).toHaveValue('a');
 await expect(page.getByText('Hypothetical example · illustrative teams and salaries, not NBA records.')).toBeVisible();
 await page.getByRole('button',{name:'New trade',exact:true}).click();
 await expect(page.getByLabel('Asset 1 ID')).toHaveCount(0);
});
test('financial table does not inherit truncated player-grid columns',async({page})=>{
 await page.goto('/financials?season=2025-26&segment=regular&basis=perGame');
 const table=page.getByRole('region',{name:'NBA team financial table'});
 await expect(table.getByRole('button',{name:'ATL',exact:true})).toBeVisible();
 const clipped=await table.locator('th,td').evaluateAll(cells=>cells.filter(e=>e.scrollWidth>e.clientWidth+1).map(e=>e.textContent));
 expect(clipped).toEqual([]);
});
test('with/without table uses readable column widths and content-driven height',async({page})=>{
 await page.goto('/with-without?season=2025-26&segment=regular&basis=perGame');
 await page.getByLabel('With/without team').selectOption('CHI');
 await page.getByLabel('With/without player A').selectOption('synthetic-0');
 const table=page.getByRole('region',{name:'Synthetic Player 0 published splits'});
 await expect(table.locator('thead th[scope=col]').filter({hasText:/^With teammate$/})).toBeVisible();
 const clipped=await table.locator('th,td').evaluateAll(cells=>cells.filter(e=>e.scrollWidth>e.clientWidth+1).map(e=>e.textContent));
 expect(clipped).toEqual([]);
});

test('comparison search and stored rate basis work after resetting a preset',async({page})=>{
 await page.goto('/player-compare?season=2025-26&segment=regular&basis=perGame');
 await page.getByLabel('Search comparison player 1').fill('Synthetic Player 0');
 await expect(page.getByLabel('Compare player 1',{exact:true}).locator('option')).toHaveCount(2);
 await page.getByLabel('Compare player 1',{exact:true}).selectOption('synthetic-0');
 await page.getByLabel('Compare player 2',{exact:true}).selectOption('synthetic-2');
 await page.getByLabel('Rate basis').selectOption('per36');
 await page.getByLabel('Comparison preset name').fill('Per 36 comparison');
 await page.getByRole('button',{name:'Save local preset'}).click();
 await page.getByRole('button',{name:'Reset comparison'}).click();
 await page.getByLabel('Rate basis').selectOption('perGame');
 await page.getByLabel('Saved comparison').selectOption('Per 36 comparison');
 await expect(page.getByLabel('Rate basis')).toHaveValue('per36');
 await expect(page.getByLabel('Compare player 1',{exact:true})).toHaveValue('synthetic-0');
});
test('box-score archive can reach records beyond the first page',async({page})=>{
 await page.route('**/data/nba_static/games/index.json',route=>route.fulfill({
  status:200,contentType:'application/json',body:JSON.stringify(Array.from({length:51},(_,i)=>({
   game_key:'fixture-game-'+i,season_id:'2025-26',season_type:'regular',
   game_date:'2025-12-01',away_team_abbreviation:'BOS',home_team_abbreviation:'CHI',
   away_score:i+1,home_score:100,box_score_available:false
  })))
 }));
 await page.goto('/box-scores?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByText('Page 1 of 2',{exact:false})).toBeVisible();
 await page.getByRole('button',{name:'Next page'}).click();
 await expect(page.getByRole('region',{name:'Historical games'}).getByRole('button',{name:/BOS 51 @ CHI 100/})).toBeVisible();
 await expect(page.getByRole('button',{name:'Next page'})).toBeDisabled();
});

test('financial source thresholds, roster and cap allocation match the dated original record',async({page})=>{
 const res=await page.request.get('/data/phase3/2026-27-team-financials.json',{maxRetries:1});
 expect(res.ok()).toBeTruthy();
 const data=await res.json();
 expect(data.league.salaryCap).toBe(164961000);
 expect(data.league.taxLine).toBe(200428000);
 expect(data.league.firstApron).toBe(209015000);
 expect(data.league.secondApron).toBe(221686000);
 expect(data.leagueSourceSha256).toMatch(/^[a-f0-9]{64}$/);
 const atl=data.teams.find((r:{team:string})=>r.team==='ATL');
 await page.goto('/financials?season=2025-26&segment=regular&basis=perGame');
 await expect(page.locator('.financials-workspace thead th[scope=col]').filter({hasText:/^Hard cap$/})).toBeVisible();
 await page.getByLabel('Find financial team').fill('ATL');
 const table=page.getByRole('region',{name:'NBA team financial table'});
 await expect(table.getByRole('row')).toHaveCount(2);
 await expect(table).toContainText(String(atl.standardRoster)+' + '+String(atl.twoWayRoster)+' two-way');
 await table.getByRole('button',{name:'ATL',exact:true}).click();
 const inspector=page.getByLabel('Financial team inspector');
 await expect(inspector).toContainText('$'+(data.league.salaryCap-atl.capSpace).toLocaleString('en-US'));
 await inspector.getByRole('button',{name:'Close details'}).click();
 await expect(inspector).toContainText('Select a team');
});

test('product Trade Machine selects real teams, routes players and picks, and explains dated restrictions',async({page})=>{
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await expect(page.locator('.trade-team-card')).toHaveCount(30);
 await page.getByRole('button',{name:'East',exact:true}).click();
 await expect(page.locator('.trade-team-card')).toHaveCount(15);
 await page.getByRole('button',{name:'New York Knicks',exact:true}).click();
 await page.getByRole('button',{name:'West',exact:true}).click();
 await page.getByRole('button',{name:'Houston Rockets',exact:true}).click();
 await page.getByRole('button',{name:'→ Build a Trade',exact:true}).click();
 await page.getByRole('group',{name:'Participating teams'}).getByRole('button',{name:'HOU',exact:true}).click();
 await expect(page.getByText('Viewing Houston Rockets')).toBeVisible();
 await page.getByLabel('Search trade assets').fill('Tari Eason');
 await expect(page.getByRole('button',{name:'Route Tari Eason',exact:true})).toBeDisabled();
 await page.getByLabel('Search trade assets').fill('Kevin Durant');
 await page.getByRole('button',{name:'Route Kevin Durant',exact:true}).click();
 await expect(page.getByLabel('Trade destination')).toHaveValue('NYK');
 await page.getByRole('button',{name:'Confirm route'}).click();
 await expect(page.getByLabel('Trade flow')).toContainText('Kevin Durant');
 await expect(page.getByLabel('Modeled validation results')).toContainText('TRADE_BONUS');
 await page.getByRole('button',{name:/^Draft picks/}).click();
 const available=page.locator('.trade-draft-list button:not([disabled])').first();
 await available.click();
 await page.getByRole('button',{name:'Confirm route'}).click();
 await expect(page.getByLabel('Trade flow')).toContainText('2 assets');
 await page.getByRole('button',{name:'Reset routes'}).click();
 await expect(page.getByText('Start building the trade')).toBeVisible();
});
test('product Trade Machine uses source context and normalizes Brooklyn, Charlotte and Phoenix',async({page})=>{
 const res=await page.request.get('/data/phase3/2026-27-trade-context.json');
 const context=await res.json();
 expect(context.kind).toBe('ARCSIDE_DATED_TRADE_CONTEXT_V1');
 expect(context.cash).toHaveLength(30);
 expect(context.restrictions.find((r:{player:string})=>r.player==='Tari Eason').eligibleDate).toBe('2027-01-15');
 expect(context.hashes.every((h:string)=>/^[0-9a-f]{64}$/.test(h))).toBe(true);
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await page.getByRole('button',{name:'Brooklyn Nets',exact:true}).click();
 await page.getByRole('button',{name:'Charlotte Hornets',exact:true}).click();
 await page.getByRole('button',{name:'Phoenix Suns',exact:true}).click();
 await page.getByRole('button',{name:'→ Build a Trade',exact:true}).click();
 await expect(page.locator('.trade-roster tbody tr').first()).toBeVisible();
 await page.getByRole('group',{name:'Participating teams'}).getByRole('button',{name:'CHA',exact:true}).click();
 await expect(page.locator('.trade-roster tbody tr').first()).toBeVisible();
 await page.getByRole('group',{name:'Participating teams'}).getByRole('button',{name:'PHX',exact:true}).click();
 await expect(page.locator('.trade-roster tbody tr').first()).toBeVisible();
});

test('NBA Home reads published dashboard and global search opens a canonical historical player',async({page})=>{
 await page.goto('/home?season=2025-26&segment=regular&basis=perGame');
 await expect(page.getByRole('heading',{name:'NBA Dashboard'})).toBeVisible();
 await expect(page.getByLabel('NBA Home')).toContainText('Synthetic Player 0');
 await page.getByLabel('Search players and teams').fill('Synthetic Player 0');
 await page.getByRole('region',{name:'Global search results'}).getByRole('button',{name:/Synthetic Player 0/}).click();
 await expect(page).toHaveURL(/\/player\/synthetic-0/);
 await expect(page.getByRole('heading',{name:'Synthetic Player 0',exact:true})).toBeVisible();
});

test('source-gated trade rights, sign-and-trade ranges and snapshots are available',async({page})=>{
 await page.goto('/trade?season=2025-26&segment=regular&basis=perGame');
 await page.getByRole('button',{name:'Boston Celtics',exact:true}).click();
 await page.getByRole('button',{name:'Philadelphia 76ers',exact:true}).click();
 await page.getByRole('button',{name:'→ Build a Trade',exact:true}).click();
 await page.getByRole('button',{name:'Draft rights',exact:true}).click();
 await page.getByRole('button',{name:'Route Justinian Jessup (draft rights)',exact:true}).click();
 await page.getByRole('button',{name:'Confirm route'}).click();
 await page.getByRole('group',{name:'Participating teams'}).getByRole('button',{name:'PHI',exact:true}).click();
 await page.getByRole('button',{name:'Free agents',exact:true}).click();
 await page.getByLabel('Kyle Lowry sign-and-trade salary').fill('100');
 await expect(page.getByRole('button',{name:'Route Kyle Lowry (sign-and-trade)',exact:true})).toHaveCount(0);
 await page.getByLabel('Kyle Lowry sign-and-trade salary').fill('3876529');
 await page.getByRole('button',{name:'Route Kyle Lowry (sign-and-trade)',exact:true}).click();
 await page.getByRole('button',{name:'Confirm route'}).click();
 await page.getByRole('button',{name:'Save snapshot'}).click();
 await expect(page.getByText('Trade snapshot saved to Recent Trades.')).toBeVisible();
 await page.reload();
 await page.getByRole('button',{name:/^Recent Trades/}).click();
 await page.getByRole('button',{name:'Open snapshot'}).click();
 await expect(page.getByLabel('Trade flow')).toContainText('Justinian Jessup');
 await expect(page.getByLabel('Trade flow')).toContainText('Kyle Lowry');
});

test('profile league-table view uses exact source ID and shared rate resolver',async({page})=>{
 await page.goto('/player/synthetic-0?season=2025-26&segment=regular&basis=perGame');
 const table=page.getByRole('region',{name:'Canonical player season statistics'});
 await expect(table.getByRole('row')).toHaveCount(2);
 await expect(table).toContainText('13.8');
 await page.getByLabel('Rate basis').selectOption('totals');
 await expect(table).toContainText('900.0');
 await page.getByLabel('Profile league-table coverage').selectOption('career');
 await expect(page.getByLabel('Canonical league-table statistics')).toContainText('1 of 2 exact season matches');
 await expect(page.getByLabel('Canonical league-table statistics')).toContainText('1 unavailable or ambiguous');
});
