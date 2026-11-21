// Execute from repository root with Dart installed:
// dart run experimental/arcside-react/tools/export_trade_golden.dart
// This emits actual JSON responses from the ORIGINAL Dart TradeMachineEngine.
// Human-review before checking in as an accepted golden baseline.
import 'dart:convert';
import '../../../lib/services/trade_machine_engine.dart';

Map<String, dynamic> reportJson(TradeValidationReport report) => {
 'isValid':report.isValid,'errorCount':report.errorCount,'warningCount':report.warningCount,
 'findings':[for(final f in report.findings){
  'code':f.code,'message':f.message,'severity':f.severity.name,
  'team':f.team,'assetId':f.assetId
 }],
 'teamSummaries':{for(final entry in report.teamSummaries.entries)entry.key:{
  'outgoingSalary':entry.value.outgoingSalary,'incomingSalary':entry.value.incomingSalary,
  'postTradeSalary':entry.value.postTradeSalary,'maximumIncomingSalary':entry.value.maximumIncomingSalary.isFinite?
   entry.value.maximumIncomingSalary:null,
  'outgoingAssets':entry.value.outgoingAssets,'incomingAssets':entry.value.incomingAssets,
  'projectedRosterPlayers':entry.value.projectedRosterPlayers,'apronStatus':entry.value.apronStatus
 }}
};
TradeScenario scenario(String id,TradeAsset asset,{String destination='BBB'})=>TradeScenario(
 id:id,name:id,operatingSeason:'2026-27',teams:const ['AAA','BBB'],
 asOfDateIso:'2026-11-01T00:00:00Z',
 assignments:[TradeAssignment(asset:asset,destinationTeam:destination)],
 capContexts:{
  'AAA':TeamCapContext.nba2026_27(team:'AAA',teamSalary:120000000,minimumStandardRosterPlayers:13),
  'BBB':TeamCapContext.nba2026_27(team:'BBB',teamSalary:120000000,minimumStandardRosterPlayers:13)
 }
);
void main(){
 const engine=TradeMachineEngine();
 final cases=<String,TradeScenario>{
  'valid_salary_exchange':TradeScenario(
   id:'valid',name:'valid',operatingSeason:'2026-27',teams:const ['AAA','BBB'],
   assignments:const [
    TradeAssignment(asset:TradeAsset(id:'a',type:TradeAssetType.player,label:'A',originTeam:'AAA',salary:5000000),destinationTeam:'BBB'),
    TradeAssignment(asset:TradeAsset(id:'b',type:TradeAssetType.player,label:'B',originTeam:'BBB',salary:5000000),destinationTeam:'AAA')
   ],
   capContexts:{
    'AAA':TeamCapContext.nba2026_27(team:'AAA',teamSalary:120000000),
    'BBB':TeamCapContext.nba2026_27(team:'BBB',teamSalary:120000000)
   }),
  'reject_same_team':scenario('invalid',const TradeAsset(
   id:'wrong',type:TradeAssetType.player,label:'Wrong routing',originTeam:'AAA',salary:1000000),destination:'AAA'),
  'reject_dated_restriction':scenario('dated',const TradeAsset(
   id:'signed',type:TradeAssetType.player,label:'Signed player',originTeam:'AAA',salary:8000000,
   metadata:{'recently_signed_until':'2026-12-15T00:00:00Z'})),
  'byc_poison_pill':scenario('byc',const TradeAsset(
   id:'complex',type:TradeAssetType.player,label:'Complex contract',originTeam:'AAA',salary:20000000,
   metadata:{'base_year_compensation':true,'outgoing_matching_salary':10000000,
    'poison_pill':true,'incoming_matching_salary':25000000})),
  'draft_frozen':scenario('pick',const TradeAsset(
   id:'pick',type:TradeAssetType.draftPick,label:'Frozen 2031 first',originTeam:'AAA',
   metadata:{'round':'1','draft_year':2031,'years_out':5,'frozen':true}))
 };
 print(const JsonEncoder.withIndent('  ').convert({
  'source':'lib/services/trade_machine_engine.dart',
  'operatingSeason':'2026-27',
  'generatedFrom':'original Dart engine, not a TypeScript imitation',
  'cases':{for(final entry in cases.entries)entry.key:reportJson(engine.validate(entry.value))}
 }));
}
