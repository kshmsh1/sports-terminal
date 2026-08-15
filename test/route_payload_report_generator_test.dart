import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/generated_terminal_report.dart';
import 'package:sports_terminal/models/route_payload.dart';
import 'package:sports_terminal/services/route_payload_report_generator.dart';

void main() {
  const generator = RoutePayloadReportGenerator();

  test('generates a ready report from exact structured RoutePayload rows', () {
    const payload = RoutePayload(
      sourceObjectType: 'PlayerStatTable',
      sourceObjectId: 'leaders',
      displayLabel: 'Scoring Leaders',
      selectedColumns: ['player', 'ppg', 'note'],
      selectedRows: ['p1', 'p2'],
      filterSummary: 'ppg >= 20',
      sourceSnapshot: 'fixture-release-2026-08-15',
      readinessState: 'Ready',
      blockers: [],
      targetRoute: 'Reports',
      availableActions: ['Reports', 'Export'],
      schemaVersion: 2,
      createdAtIso: '2026-08-15T17:00:00.000Z',
      columns: [
        RoutePayloadColumn(key: 'player', label: 'Player'),
        RoutePayloadColumn(key: 'ppg', label: 'PPG', dataType: 'number'),
        RoutePayloadColumn(key: 'note', label: 'Note'),
      ],
      rows: [
        {'player': 'Example A', 'ppg': 28.4, 'note': null},
        {'player': 'Example B', 'ppg': 24.1, 'note': 'Observed row'},
      ],
      metadata: {'datasetId': 'leaders'},
    );

    final report = generator.generate(payload);

    expect(report.coverage, GeneratedTerminalReportCoverage.ready);
    expect(report.rowCount, 2);
    expect(report.columnCount, 3);
    expect(report.rows.first['ppg'], 28.4);
    expect(report.rows.first['note'], isNull);
    expect(report.metadata['datasetId'], 'leaders');
    expect(report.toMarkdown(), contains('Example A'));
    expect(report.toMarkdown(), contains('—'));
    expect(report.toTsv(), contains('NA'));

    final json = jsonDecode(report.encodeJson()) as Map<String, dynamic>;
    expect(json['sourceSnapshot'], 'fixture-release-2026-08-15');
    expect(json['coverage'], 'READY');
    expect((json['rows'] as List).first['note'], isNull);
  });

  test('selected columns project exact source fields without widening', () {
    const payload = RoutePayload(
      sourceObjectType: 'Team',
      sourceObjectId: 'BOS',
      displayLabel: 'Boston',
      selectedColumns: ['Team', 'Wins'],
      selectedRows: ['BOS'],
      filterSummary: 'season=2025-26',
      sourceSnapshot: 'fixture',
      readinessState: 'Ready',
      blockers: [],
      targetRoute: 'Reports',
      availableActions: ['Reports'],
      columns: [
        RoutePayloadColumn(key: 'team', label: 'Team'),
        RoutePayloadColumn(key: 'wins', label: 'Wins'),
        RoutePayloadColumn(key: 'losses', label: 'Losses'),
      ],
      rows: [
        {'team': 'Boston', 'wins': 55, 'losses': 27},
      ],
    );

    final report = generator.generate(payload);

    expect(report.columns.map((column) => column.key), ['team', 'wins']);
    expect(report.rows.single.keys, ['team', 'wins']);
    expect(report.toMarkdown(), isNot(contains('Losses')));
  });

  test('declared blockers keep populated reports partial rather than ready', () {
    const payload = RoutePayload(
      sourceObjectType: 'Game',
      sourceObjectId: 'g1',
      displayLabel: 'Game g1',
      selectedColumns: ['game_id'],
      selectedRows: ['g1'],
      filterSummary: 'game=g1',
      sourceSnapshot: 'fixture',
      readinessState: 'Partial',
      blockers: ['tracking feed unavailable'],
      targetRoute: 'Reports',
      availableActions: ['Reports'],
      columns: [RoutePayloadColumn(key: 'game_id', label: 'Game ID')],
      rows: [
        {'game_id': 'g1'},
      ],
    );

    final report = generator.generate(payload);

    expect(report.coverage, GeneratedTerminalReportCoverage.partial);
    expect(report.blockers, ['tracking feed unavailable']);
    expect(report.toMarkdown(), contains('tracking feed unavailable'));
  });

  test('blocked payload with no structured rows stays blocked and explicit', () {
    const payload = RoutePayload(
      sourceObjectType: 'Player',
      sourceObjectId: 'p1',
      displayLabel: 'Example Player',
      selectedColumns: ['player_id'],
      selectedRows: ['p1'],
      filterSummary: 'player=p1',
      sourceSnapshot: 'fixture',
      readinessState: 'Blocked',
      blockers: ['player stat rows missing'],
      targetRoute: 'Reports',
      availableActions: ['Reports'],
    );

    final report = generator.generate(payload);

    expect(report.coverage, GeneratedTerminalReportCoverage.blocked);
    expect(report.rows, isEmpty);
    expect(
      report.toMarkdown(),
      contains('No structured rows were supplied.'),
    );
    expect(report.toMarkdown(), isNot(contains('| player_id |')));
  });

  test('legacy label-only payload never becomes fabricated structured data', () {
    const payload = RoutePayload(
      sourceObjectType: 'Season',
      sourceObjectId: '2025-26',
      displayLabel: '2025-26 NBA Season',
      selectedColumns: ['season_id'],
      selectedRows: ['2025-26'],
      filterSummary: 'season=2025-26',
      sourceSnapshot: 'legacy-fixture',
      readinessState: 'Ready',
      blockers: [],
      targetRoute: 'Reports',
      availableActions: ['Reports'],
    );

    final report = generator.generate(payload);

    expect(report.coverage, GeneratedTerminalReportCoverage.partial);
    expect(report.rows, isEmpty);
    expect(report.columns, isEmpty);
    expect(report.toTsv(), isEmpty);
  });
}
