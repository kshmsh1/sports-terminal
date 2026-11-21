// Physical native screen-reader operator log. Never simulated by Playwright.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {createInterface} from 'node:readline/promises';
import {stdin,stdout} from 'node:process';
import {platform,release,arch} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const os=platform(),config=os==='darwin'?
 {browser:'native Safari',assistive:'VoiceOver'}:os==='win32'?
 {browser:'native Chrome',assistive:'NVDA'}:null;
if(!config)throw Error('Native assistive-technology session requires physical macOS or Windows; Linux/Playwright cannot sign off.');
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..');
const data=await readFile(path.join(root,'web/data/nba_static/manifest.json'));
const sha=createHash('sha256').update(data).digest('hex');
const urls={Flutter:process.env.ARCSIDE_FLUTTER_URL??'http://127.0.0.1:8768',
 React:process.env.ARCSIDE_REACT_URL??'http://127.0.0.1:4173'};
for(const [app,url] of Object.entries(urls)){
 const res=await fetch(url+'/data/nba_static/manifest.json');
 if(!res.ok()||createHash('sha256').update(Buffer.from(await res.arrayBuffer())).digest('hex')!==sha)
  throw Error(app+' is not serving the exact published NBA v5 corpus');
}
const routes=['Stats','Advanced Stats','Visualization Studio','Trade Machine','Player Compare',
 'Team Compare','Box Scores','Games','Financials','With/Without','Teams','Team Detail',
 'Franchise History','Player Profiles','Python Lab','Excel Workspace'];
const descriptions={
 'Stats':'filter, expand multi-team player, sort, switch segment/rate basis, profile navigation',
 'Advanced Stats':'advanced group, nested metrics, keyboard sorting and qualification',
 'Visualization Studio':'zoom/pan/reset/re-axis, accessible chart data table',
 'Trade Machine':'edit teams/assets, date and payroll, review CBA findings',
 'Player Compare':'select player slots, saved local comparison preset, segment switch',
 'Team Compare':'select actual teams and inspect comparison outputs',
 'Box Scores':'find historical game and inspect numeric data table',
 'Games':'filter historical games, open source detail or explicit unavailable state',
 'Financials':'read salary tables, team selection and sortable records',
 'With/Without':'select player pair, hear source-coverage limitations or splits',
 'Teams':'search directory and navigate to actual canonical team dossier',
 'Team Detail':'read roster, season history region and empty-history notice',
 'Franchise History':'read original implementation roadmap without invented relocations',
 'Player Profiles':'navigate career, advanced stat families, contracts and honors',
 'Python Lab':'iframe editor, execute/stop, output and token privacy',
 'Excel Workspace':'grid cell focus, workbook navigation, formula and import/export'
};
const rl=createInterface({input:stdin,output:stdout}),checks=[];let browserVersion='',atVersion='';
try{
 console.log('Native: '+config.browser+' + '+config.assistive);
 console.log('Test BOTH Flutter and React per route: keyboard traversal, visible focus, announced name/role/value, reading order, errors and no focus trap.');
 console.log('Do not enter PASS based on a screenshot, headless browser or simulated input.');
 browserVersion=(await rl.question('Actual browser version: ')).trim();
 atVersion=(await rl.question('Actual '+config.assistive+' version: ')).trim();
 if(!browserVersion||!atVersion)throw Error('Native browser and assistive versions required');
 for(const route of routes){
  console.log('\n'+route+': '+descriptions[route]+'\nFlutter: '+urls.Flutter+' | React: '+urls.React);
  const result=(await rl.question('Physical screen-reader/keyboard result [PASS / FAIL / BLOCKED]: ')).trim().toUpperCase();
  if(!['PASS','FAIL','BLOCKED'].includes(result))throw Error('No valid result for '+route);
  const notes=(await rl.question('Specific observed notes or defect references: ')).trim();
  if(!notes)throw Error('Missing observed details for '+route);
  checks.push({route,status:result,notes});
 }
}finally{rl.close()}
const status=checks.length===routes.length&&checks.every(x=>x.status==='PASS')?
 'NATIVE_OPERATOR_REPORTED_PASS':'INCOMPLETE_OR_BLOCKED';
const dir=path.resolve(here,'../evidence/native');await mkdir(dir,{recursive:true});
const file=path.join(dir,'native-'+os+'.json');
await writeFile(file,JSON.stringify({
 kind:'ARCSIDE_NATIVE_A11Y_OPERATOR_ATTESTATION_V1',manifestSha256:sha,
 source:'ACTUAL_LOCAL_V5_CORPUS',createdAt:new Date().toISOString(),
 os,release:release(),arch:arch(),browser:config.browser,browserVersion,
 assistiveTechnology:config.assistive,assistiveVersion:atVersion,
 directHumanObservation:true,checkedAgainstFlutter:true,checks,status,
 automatedWCAG22AACertified:false,
 caveat:'Operator observation is not an independent comprehensive WCAG 2.2 AA certification. Remediate all failing routes before migration.'
},null,2)+'\n');
console.log('Saved '+file+' '+checks.length+'/'+routes.length+' routes: '+status);
if(status!=='NATIVE_OPERATOR_REPORTED_PASS')process.exitCode=1;
