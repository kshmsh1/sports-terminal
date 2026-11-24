// Original Flutter scope: direct user journeys must be observed, not inferred.
export const finalModules=[
 {id:'stats',title:'Stats',route:'/stats',
  task:'Compare seasons, rate basis, qualification, sorting, traded player expansion and profile navigation.'},
 {id:'advanced',title:'Advanced Stats',route:'/advanced',
  task:'Compare all 18 stat groups, minimum games/minutes, per-100 rates, nested metric expansions and ordering.'},
 {id:'visualizations',title:'Visualization Studio',route:'/visualizations',
  task:'Verify identical plotted top-40 players, regression, zoom/pan/reset, axes, tooltip and underlying data.'},
 {id:'player-compare',title:'Player Compare',route:'/player-compare',
  task:'Select the same players, seasons and segments; compare metrics, filters, labels and missing-data handling.'},
 {id:'team-compare',title:'Team Compare',route:'/team-compare',
  task:'Choose the same teams and seasons, inspect all comparison tables and interaction/qualification controls.'},
 {id:'trade',title:'Trade Machine',route:'/trade',
  task:'Compare original 2023 CBA rules, 2–5 team assets, exceptions, salaries, roster, draft conveyance and legal findings. An independent pilot is not full parity.'},
 {id:'box-scores',title:'Box Scores',route:'/box-scores',
  task:'Open matching historical games in both shells, inspect all box-score metrics, tables, navigation and missing sources.'},
 {id:'financials',title:'Financials and Contracts',route:'/financials',
  task:'Compare original contract columns, cap ledgers, source dates, team/player filters and calculations.'},
 {id:'team-detail',title:'Team Detail',route:'/teams',
  task:'Find and open a real team dossier in both shells, compare roster, historical seasons, profile navigation and empty state.'},
 {id:'games',title:'Games',route:'/games',
  task:'Find the same historical games, sort/filter/open details, verify rows and provenance.'},
 {id:'franchise',title:'Franchise History',route:'/franchise-history',
  task:'Compare existing Flutter capabilities and confirm React is not inventing relocation, season or continuity data.'},
 {id:'with-without',title:'With/Without',route:'/with-without',
  task:'Select matching player/team splits and compare all supported ON/OFF measures; treat source gaps as blockers.'},
 {id:'player-profile',title:'Player Profiles',route:null,
  task:'Manually open the SAME real player on each shell. Compare original season/all-team stats, advanced stats, contracts, awards, headers and deep links.'},
 {id:'python-lab',title:'Python Lab',route:'/workspaces/python',
  task:'Exercise editor, execution, outputs, debugger/console, local environment, export/import, errors and original integrated workspace controls.'},
 {id:'sheets',title:'Excel Workspace',route:'/workspaces/sheets',
  task:'Compare formula engine, multi-sheet navigation, chart/table controls, cell selection, import/export, sharing and workbook integrity.'}
];
export function assessFinalVisual({checks,manifestSha256,realManifestSha256}){
 const errors=[];
 if(!manifestSha256||manifestSha256!==realManifestSha256)errors.push('Exact NBA v5 source fingerprint mismatch');
 const ids=new Set();
 for(const x of checks){
  if(ids.has(x.id))errors.push('Duplicate module '+x.id);
  ids.add(x.id);
  if(!['PASS','FAIL','BLOCKED'].includes(x.status))errors.push('Invalid status for '+x.id);
  if(!x.details||x.details.trim().length<15)errors.push('Specific functional observations missing for '+x.id);
  if(!x.flutterUrl?.startsWith('http://127.0.0.1:')||
    !x.reactUrl?.startsWith('http://127.0.0.1:'))
   errors.push('Local physical evidence URLs missing for '+x.id);
  if(x.status==='PASS'&&(!x.flutterScreenshotSha256||!x.reactScreenshotSha256))
   errors.push('Screenshot fingerprints missing for passed '+x.id);
 }
 if(checks.length!==finalModules.length||
  finalModules.some(x=>!ids.has(x.id)))errors.push('Not all 15 modules were independently checked');
 const failures=checks.filter(x=>x.status!=='PASS');
 return {status:errors.length?'INVALID_EVIDENCE':
  failures.length?'GAPS_OBSERVED':'OPERATOR_VISUAL_SAMPLE_PASS_ONLY',
  errors,failures:failures.map(x=>({id:x.id,status:x.status,details:x.details})),
  modulesReviewed:checks.length,modulesRequired:finalModules.length,
  ownerMigrationSignoff:false,fullFunctionalParityCertified:false,
  caveat:'This operator-attested spot check documents observed live UI, screenshots and defects. It is not a proof of comprehensive CBA, historical player data, native accessibility, GPU/frame/memory or security parity, and never signs a migration.'};
}
