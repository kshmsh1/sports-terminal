import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/route_payload.dart';

void main() {
  test('schema-v2 route payload round-trips structured rows', () {
    const payload = RoutePayload(
      sourceObjectType: 'PlayerStatTable',
      sourceObjectId: 'leaders',
      displayLabel: 'Scoring Leaders',
      selectedColumns: ['player', 'ppg'],
      selectedRows: ['p1'],
      filterSummary: 'ppg > 20',
      sourceSnapshot: 'unit-test fixture',
      readinessState: 'Ready',
      blockers: [],
      targetRoute: 'Python Lab',
      availableActions: ['Workspace', 'Python Lab'],
      schemaVersion: 2,
      createdAtIso: '2026-07-21T00:00:00.000Z',
      columns: [
        RoutePayloadColumn(key: 'player', label: 'Player'),
        RoutePayloadColumn(
          key: 'ppg',
          label: 'PPG',
          dataType: 'number',
        ),
      ],
      rows: [
        {'player': 'Example Player', 'ppg': 27.5},
      ],
      metadata: {'datasetId': 'leaders'},
    );

    final decoded = RoutePayload.tryDecode(payload.encode());

    expect(decoded, isNotNull);
    expect(decoded!.schemaVersion, 2);
    expect(decoded.rowCount, 1);
    expect(decoded.columnCount, 2);
    expect(decoded.rows.first['ppg'], 27.5);
    expect(decoded.columns.last.dataType, 'number');
    expect(decoded.metadata['datasetId'], 'leaders');
    expect(decoded.hasStructuredRows, isTrue);
  });

  test('legacy payload JSON remains readable', () {
    final payload = RoutePayload.fromJson({
      'sourceObjectType': 'Team',
      'sourceObjectId': 'BOS',
      'displayLabel': 'Boston',
      'selectedColumns': ['team_id'],
      'selectedRows': ['BOS'],
      'filterSummary': 'none',
      'sourceSnapshot': 'legacy',
      'readinessState': 'Ready',
      'blockers': <String>[],
      'targetRoute': 'Workspace',
      'availableActions': ['Workspace'],
    });

    expect(payload.schemaVersion, 1);
    expect(payload.rows, isEmpty);
    expect(payload.columns, isEmpty);
    expect(payload.displayLabel, 'Boston');
  });
}
