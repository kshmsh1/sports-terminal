import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/sports_object_router.dart';

void main() {
  const router = SportsObjectRouter();

  test('packages rows with preferred columns and inferred types', () {
    final payload = router.packageRows(
      datasetId: 'player_board',
      displayLabel: 'Player Board',
      sourceObjectType: 'PlayerStatTable',
      targetRoute: 'Workspace',
      rowKey: 'player_id',
      preferredColumns: const ['player_id', 'player_name', 'ppg'],
      rows: const [
        {'player_id': 'p1', 'player_name': 'Alpha', 'ppg': 25.5, 'active': true},
        {'player_id': 'p2', 'player_name': 'Beta', 'ppg': 20.0, 'active': false},
      ],
    );

    expect(payload.selectedColumns.take(3), ['player_id', 'player_name', 'ppg']);
    expect(payload.selectedRows, ['p1', 'p2']);
    expect(payload.rows.length, 2);
    expect(
      payload.columns.firstWhere((column) => column.key == 'ppg').dataType,
      'number',
    );
    expect(
      payload.columns.firstWhere((column) => column.key == 'active').dataType,
      'boolean',
    );
  });

  test('creates TSV and package-specific Python starter code', () {
    final payload = router.packageRows(
      datasetId: 'team records',
      displayLabel: 'Team Records',
      sourceObjectType: 'TeamStatTable',
      targetRoute: 'Python Lab',
      rows: const [
        {'team_id': 'BOS', 'wins': 60},
      ],
      preferredColumns: const ['team_id', 'wins'],
    );

    final tsv = router.toTsv(payload);
    final python = router.generatedPython(payload);

    expect(tsv, contains('team_id\twins'));
    expect(tsv, contains('BOS\t60'));
    expect(python, contains('team_records = st.active_payload_dataframe()'));
    expect(python, contains('Team Records'));
  });
}
