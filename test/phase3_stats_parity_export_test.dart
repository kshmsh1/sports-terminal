// Executes the ORIGINAL Flutter/Dart statistics engine against the exact same
// source rows used in React. Never infer or manufacture missing numeric fields.
// Run from repository root:
// flutter test test/phase3_stats_parity_export_test.dart
// flutter test test/phase3_stats_parity_export_test.dart \
//   --dart-define=ARCSIDE_PARITY_CORPUS=web/data/nba_static \
//   --dart-define=ARCSIDE_PARITY_SEASONS=2025-26,1986-87,1946-47
// All output lives under ignored experimental/arcside-react/evidence/parity/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/services/nba_terminal_seed_repository.dart';

const corpusRoot = String.fromEnvironment('ARCSIDE_PARITY_CORPUS');
const seasonList = String.fromEnvironment(
  'ARCSIDE_PARITY_SEASONS',
  defaultValue: '2025-26,1986-87,1946-47',
);
const outputPath = String.fromEnvironment(
  'ARCSIDE_PARITY_OUTPUT',
  defaultValue: 'experimental/arcside-react/evidence/parity/dart-reference.json',
);

Map<String, dynamic> loadObject(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

List<Map<String, dynamic>> loadSnapshots() {
  if (corpusRoot.isEmpty) {
    return [
      loadObject('experimental/arcside-react/tests/parity_fixture.json'),
    ];
  }
  final manifest = loadObject('$corpusRoot/manifest.json');
  if (manifest['contract'] != 'sports-terminal-static-nba-website-v5' ||
      manifest['static_schema_version'] != 5 ||
      manifest['database_fingerprint'] == null) {
    throw StateError('Refusing to use a missing/non-v5 canonical corpus.');
  }
  final available = (jsonDecode(File('$corpusRoot/seasons.json').readAsStringSync()) as List)
      .map((s) => (s as Map)['season_id'].toString()).toSet();
  final snapshots = <Map<String, dynamic>>[];
  for (final season in seasonList.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    if (!available.contains(season)) throw StateError('Not in real catalog: $season');
    for (final segment in ['regular', 'playoffs']) {
      final file = File('$corpusRoot/seasons/$season/$segment.json');
      if (!file.existsSync()) throw StateError('Missing real shard: ${file.path}');
      final shard = loadObject(file.path);
      if (shard['season_id'] != season || shard['season_type'] != segment ||
          shard['player_season_totals'] is! List) {
        throw StateError('Invalid source shard: ${file.path}');
      }
      snapshots.add(shard);
    }
  }
  return snapshots;
}

Map<String, dynamic> projectSnapshot(Map<String, dynamic> payload) {
  final segment = payload['season_type'].toString();
  // Only supply a missing segment TAG for the engine's row-selection predicate;
  // no numeric basketball data is synthesized.
  final records = (payload['player_season_totals'] as List).map((raw) {
    final row = (raw as Map).cast<String, dynamic>();
    return {
      ...row,
      if (row['season_type'] == null && row['seasonType'] == null && row['segment'] == null)
        'season_type': segment,
    };
  }).toList();
  return {...payload, 'player_season_totals': records};
}

Map<String, dynamic> serializeRow(
  NbaStatsRow row,
  NbaStatsWorkstationEngine engine,
  NbaStatsBasis basis,
) {
  final rawStints = engine.teamStintRows(row, basis: basis);
  return {
    'id': row.playerId,
    'player': row.player,
    'team': row.team,
    'position': row.position,
    'estimated': row.possessionsEstimated,
    'values': row.values.map((key, value) => MapEntry(
      key,
      value == null || !value.isFinite ? null : value,
    )),
    'percentiles': row.percentiles,
    'formatted': {
      for (final metric in nbaStatMetrics)
        metric.key: engine.formatValue(metric.key, row.value(metric.key)),
    },
    'stints': [
      for (final stint in rawStints) {
        'id': stint.playerId,
        'team': stint.team,
        'values': stint.values.map((key, value) => MapEntry(
          key, value == null || !value.isFinite ? null : value,
        )),
      }
    ],
  };
}

void main() {
  test('export ORIGINAL Flutter statistics goldens, not a reimplementation', () {
    const engine = NbaStatsWorkstationEngine();
    final sources = loadSnapshots();
    expect(sources, isNotEmpty);
    final out = <Map<String, dynamic>>[];
    var observed = 0;
    for (final raw in sources) {
      final payload = projectSnapshot(raw);
      final snapshot = NbaTerminalSeedSnapshot.fromMap(payload);
      final segment = payload['season_type'].toString();
      final type = segment == 'playoffs'
          ? NbaStatsSeasonType.playoffs
          : NbaStatsSeasonType.regular;
      for (final basis in NbaStatsBasis.values) {
        final rows = engine.buildRows(snapshot, basis: basis, seasonType: type);
        observed += rows.length;
        out.add({
          'season': payload['season_id'],
          'segment': segment,
          'basis': basis.name,
          'rows': [for (final row in rows) serializeRow(row, engine, basis)],
        });
      }
    }
    expect(observed, greaterThan(0), reason: 'No source records reached Dart; do not claim parity');
    final path = File(outputPath);
    path.parent.createSync(recursive: true);
    path.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'kind': 'ARCSIDE_DART_REFERENCE_OUTPUT',
      'engine': 'lib/services/nba_stats_workstation_engine.dart',
      'dataSource': corpusRoot.isEmpty ? 'SYNTHETIC_CONTRACT_ONLY' : 'ACTUAL_LOCAL_V5_CORPUS',
      'corpusRoot': corpusRoot,
      'sampleSeasons': seasonList,
      'segmentProjection': 'Only missing season_type tags are supplied; no numeric fields',
      'referenceCases': out,
    }));
    // The Dart exporter cannot and does not certify React parity.
    // ignore: avoid_print
    print('ARCSIDE_DART_PARITY_EXPORTED: ${path.path} (${out.length} samples, $observed player-basis rows)');
  });
}
