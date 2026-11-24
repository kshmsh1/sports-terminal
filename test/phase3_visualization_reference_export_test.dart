// Original Flutter Visualization Studio source-based top-N and regression goldens.
// Run locally against original published v5 shards; no fixtures.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

const corpus=String.fromEnvironment('ARCSIDE_VIS_CORPUS');
const seasonCsv=String.fromEnvironment('ARCSIDE_VIS_SEASONS',defaultValue:'2025-26,1986-87,1946-47');
const output=String.fromEnvironment('ARCSIDE_VIS_OUTPUT',
 defaultValue:'experimental/arcside-react/evidence/visualization/dart-reference.json');
Map<String,dynamic> readJson(String p)=>(jsonDecode(File(p).readAsStringSync()) as Map).cast<String,dynamic>();

bool available(NbaStatsRow row,String key,NbaStatsBasis basis) {
 final v=row.value(key);
 if(v==null||!v.isFinite)return false;
 if(key=='gp')return true;
 final raw=row.raw;
 final minute=raw['minutes']??raw['mp']??raw['minutes_per_game']??raw['mpg'];
 final minutes=minute is num?minute.toDouble():double.tryParse(minute?.toString()??'');
 if((basis==NbaStatsBasis.per36||basis==NbaStatsBasis.per48)&&
   (minutes==null||minutes<=0))return false;
 if((basis==NbaStatsBasis.per75||basis==NbaStatsBasis.per100)&&
   (minutes??0)<=0&&raw['field_goal_attempts']==null&&raw['fga']==null)return false;
 const aliases=<String,List<String>>{
  'pts':['points','pts','points_per_game','ppg'],
  'ast':['assists','ast','assists_per_game','apg'],
  'reb':['rebounds','trb','reb','rebounds_per_game','rpg']
 };
 if(aliases.containsKey(key)&&!aliases[key]!.any((k)=>raw[k]!=null))return false;
 return true;
}
Map<String,dynamic> regression(List<NbaStatsRow> rows,String x,String y){
 final pairs=<List<double>>[];
 for(final r in rows){
  final xv=r.value(x),yv=r.value(y);
  if(xv!=null&&yv!=null&&xv.isFinite&&yv.isFinite)pairs.add([xv,yv]);
 }
 if(pairs.isEmpty)return {'count':0,'slope':0,'intercept':0,'r':0,'rSquared':0};
 if(pairs.length==1)return {'count':1,'slope':0,'intercept':pairs.first[1],'r':0,'rSquared':0};
 final mx=pairs.fold<double>(0,(s,p)=>s+p[0])/pairs.length;
 final my=pairs.fold<double>(0,(s,p)=>s+p[1])/pairs.length;
 var xx=0.0,yy=0.0,xy=0.0;
 for(final p in pairs){final dx=p[0]-mx,dy=p[1]-my;xx+=dx*dx;yy+=dy*dy;xy+=dx*dy;}
 final slope=xx==0?0.0:xy/xx,intercept=my-slope*mx;
 final denominator=math.sqrt(xx*yy);
 final r=denominator==0?0.0:(xy/denominator).clamp(-1.0,1.0).toDouble();
 return {'count':pairs.length,'slope':slope,'intercept':intercept,'r':r,'rSquared':r*r};
}
void main(){
 test('export original Flutter Visualization Studio rows from real NBA v5 shards',(){
  if(corpus.isEmpty)throw StateError('Original NBA v5 corpus is REQUIRED');
  final manifest=readJson('$corpus/manifest.json');
  if(manifest['contract']!='sports-terminal-static-nba-website-v5'||
   manifest['static_schema_version']!=5||manifest['database_fingerprint']==null)
   throw StateError('Invalid NBA v5 source');
  final published=(jsonDecode(File('$corpus/seasons.json').readAsStringSync()) as List)
    .map((r)=>(r as Map)['season_id'].toString()).toSet();
  const engine=NbaStatsWorkstationEngine();
  final cases=<Map<String,dynamic>>[];
  for(final season in seasonCsv.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty)){
   if(!published.contains(season))throw StateError('Unpublished season $season');
   for(final segment in ['regular','playoffs']){
    final raw=readJson('$corpus/seasons/$season/$segment.json');
    if(raw['season_id']!=season||raw['season_type']!=segment||
      raw['player_season_totals'] is! List)throw StateError('Invalid source shard');
    final records=(raw['player_season_totals'] as List).map((entry){
     final r=(entry as Map).cast<String,dynamic>();
     return {...r,if(r['season_type']==null&&r['seasonType']==null&&r['segment']==null)
       'season_type':segment};
    }).toList();
    final snap=NbaTerminalSeedSnapshot.fromMap({...raw,'player_season_totals':records});
    final kind=segment=='playoffs'?NbaStatsSeasonType.playoffs:NbaStatsSeasonType.regular;
    for(final basis in NbaStatsBasis.values){
     final rows=engine.buildRows(snap,basis:basis,seasonType:kind);
     for(final variant in ['defaultTop40','rebVsAstTop40','allEligible','noGpThreshold']){
      final x=variant=='rebVsAstTop40'?'reb':'ast';
      final y=variant=='rebVsAstTop40'?'ast':'pts';
      final gp=variant=='noGpThreshold'?0:(segment=='playoffs'?4:50);
      final topN=variant=='allEligible'?0:40;
      final matching=rows.where((r)=>(r.value('gp')??0)>=gp).toList();
      final filtered=matching.where((r)=>available(r,x,basis)&&available(r,y,basis)).toList();
      final ranked=[...filtered]..sort((a,b){
       final cmp=b.value(y)!.compareTo(a.value(y)!);
       if(cmp!=0)return cmp;
       final name=a.player.compareTo(b.player);
       return name!=0?name:a.playerId.compareTo(b.playerId);
      });
      final plotted=topN==0?ranked:ranked.take(topN).toList();
      cases.add({'season':season,'segment':segment,'basis':basis.name,
       'variant':variant,'x':x,'y':y,'minGames':gp,'topN':topN,
       'sourceRowCount':rows.length,'matchingCount':matching.length,
       'eligibleCount':filtered.length,'plotted':[
        for(final r in plotted){'id':r.playerId,'player':r.player,'team':r.team,
         'x':r.value(x),'y':r.value(y)}
       ],'regression':regression(plotted,x,y)});
     }
    }
   }
  }
  final file=File(output);file.parent.createSync(recursive:true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
   'kind':'ARCSIDE_FLUTTER_VISUALIZATION_REFERENCE_V1',
   'source':'ACTUAL_LOCAL_V5_CORPUS',
   'manifestFingerprint':manifest['database_fingerprint'],'cases':cases}));
  expect(cases.any((c)=>(c['plotted'] as List).length>=20),isTrue,
   reason:'No populated source-backed sample');
  // ignore: avoid_print
  print('ARCSIDE_FLUTTER_VIS_REFERENCE: ${file.path}');
 }, skip: corpus.isEmpty
   ? 'Requires explicit ARCSIDE_VIS_CORPUS pointing to the original local NBA v5 data'
   : false);
}
