// Phase 3: ACTUAL Flutter/Dart Advanced Stats catalog resolver reference.
// Captures source-native metrics in addition to the previously parity-tested
// derived engine values. Never manufactures missing statistics.
// Usage: flutter test test/phase3_advanced_acceptance_export_test.dart
//  --dart-define=ARCSIDE_ADVANCED_CORPUS=web/data/nba_static
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

const corpus = String.fromEnvironment('ARCSIDE_ADVANCED_CORPUS');
const seasonCsv = String.fromEnvironment('ARCSIDE_ADVANCED_SEASONS',
    defaultValue: '2025-26,1986-87,1946-47');
const output = String.fromEnvironment('ARCSIDE_ADVANCED_OUTPUT',
    defaultValue: 'experimental/arcside-react/evidence/advanced/dart-reference.json');
const maxRows = int.fromEnvironment('ARCSIDE_ADVANCED_MAX_ROWS', defaultValue: 80);

Map<String,dynamic> readJson(String p) =>
    (jsonDecode(File(p).readAsStringSync()) as Map).cast<String,dynamic>();

void main() {
  test('export real Flutter Advanced Stats resolver reference', () {
    if (corpus.isEmpty) throw StateError('Real canonical corpus is REQUIRED');
    final manifest = readJson('$corpus/manifest.json');
    if (manifest['contract'] != 'sports-terminal-static-nba-website-v5' ||
        manifest['static_schema_version'] != 5 ||
        manifest['database_fingerprint'] == null) {
      throw StateError('Refusing noncanonical source');
    }
    final allSeasons = (jsonDecode(File('$corpus/seasons.json').readAsStringSync()) as List)
        .map((x) => (x as Map)['season_id'].toString()).toSet();
    final reference = <Map<String,dynamic>>[];
    const engine = NbaStatsWorkstationEngine();
    const resolver = NbaTerminalMetricResolver();
    for (final season in seasonCsv.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty)) {
      if (!allSeasons.contains(season)) throw StateError('Unpublished season $season');
      for (final segment in ['regular','playoffs']) {
        final raw = readJson('$corpus/seasons/$season/$segment.json');
        if (raw['season_id'] != season || raw['season_type'] != segment ||
            raw['player_season_totals'] is! List) {
          throw StateError('Invalid shard $season/$segment');
        }
        // Exactly mirrors the previously verified parity export's only tag
        // projection; preserves every numeric source value untouched.
        final records = (raw['player_season_totals'] as List).map((item) {
          final r = (item as Map).cast<String,dynamic>();
          return {...r,
            if (r['season_type']==null && r['seasonType']==null && r['segment']==null)
              'season_type':segment};
        }).toList();
        final snap = NbaTerminalSeedSnapshot.fromMap(
          {...raw, 'player_season_totals':records});
        final kind = segment == 'playoffs'
          ? NbaStatsSeasonType.playoffs : NbaStatsSeasonType.regular;
        final bases = <Map<String,dynamic>>[];
        for (final basis in NbaStatsBasis.values) {
          final rows = engine.buildRows(snap, basis:basis, seasonType:kind);
          // Stable player ID sample, spread across the entire population.
          // Selection is independent of computed metric values.
          final byId = [...rows]..sort((a,b)=>a.playerId.compareTo(b.playerId));
          final step = byId.length <= maxRows ? 1 : byId.length/maxRows;
          final sampled = <NbaStatsRow>[];
          for (var i=0;i<maxRows && i*step<byId.length;i++) {
            sampled.add(byId[(i*step).floor()]);
          }
          bases.add({
            'basis':basis.name,
            'sourceRowCount':rows.length,
            'samples':[
              for (final row in sampled) {
                'id':row.playerId, 'player':row.player,
                'team':row.team,'position':row.position,
                'gp':row.value('gp'), 'minutes':row.value('min'),
                'metrics':{
                  for (final m in nbaTerminalMetrics)
                    m.key:resolver.value(row,m.key) ?? row.value(m.key)
                },
                'college': row.raw['bio_college']?.toString(),
                'country': row.raw['bio_country']?.toString(),
              }
            ]
          });
        }
        reference.add({'season':season,'segment':segment,'bases':bases});
      }
    }
    final file=File(output);
    file.parent.createSync(recursive:true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'kind':'ARCSIDE_FLUTTER_ADVANCED_STATS_REFERENCE',
      'source':'ACTUAL_LOCAL_V5_CORPUS',
      'sampleSeasons':seasonCsv,
      'manifestSha256':null, // computed from actual bytes in independent Node verifier
      'metrics':[for(final m in nbaTerminalMetrics){
        'key':m.key,'shortLabel':m.shortLabel,'engine':m.engineKey,
        'rawAliases':m.rawAliases,'format':m.format.name,
        'decimals':m.decimals,'children':m.children
      }],
      'families':[for(final f in nbaTerminalStatFamilies){
        'id':f.id,'name':f.label,'description':f.description,
        'metrics':f.metrics,'expansionOverrides':f.expansionOverrides
      }],
      'cases':reference
    }));
    expect(reference.length,greaterThanOrEqualTo(6));
    expect(reference.any((x)=>(x['bases'] as List).any(
        (b)=>(b['samples'] as List).isNotEmpty)),isTrue,
      reason:'Cannot certify an all-empty data sample');
    // ignore: avoid_print
    print('ARCSIDE_ADVANCED_DART_REFERENCE: ${file.path}');
  });
}
