import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/controllers/route_payload_controller.dart';
import 'package:sports_terminal/models/route_payload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists and hydrates active payload plus history', () async {
    SharedPreferences.setMockInitialValues({});
    final first = RoutePayloadController();
    const payload = RoutePayload(
      sourceObjectType: 'TeamStatTable',
      sourceObjectId: 'teams',
      displayLabel: 'Team Board',
      selectedColumns: ['team_id'],
      selectedRows: ['BOS'],
      filterSummary: 'none',
      sourceSnapshot: 'fixture',
      readinessState: 'Ready',
      blockers: [],
      targetRoute: 'Workspace',
      availableActions: ['Workspace'],
      columns: [RoutePayloadColumn(key: 'team_id', label: 'Team')],
      rows: [
        {'team_id': 'BOS'},
      ],
    );

    first.setActivePayload(payload, origin: 'test');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final second = RoutePayloadController();
    await second.hydrate();

    expect(second.activePayload, isNotNull);
    expect(second.activePayload!.displayLabel, 'Team Board');
    expect(second.activePayload!.rows.first['team_id'], 'BOS');
    expect(second.history, hasLength(1));
    expect(second.hydrated, isTrue);

    first.dispose();
    second.dispose();
  });
}
