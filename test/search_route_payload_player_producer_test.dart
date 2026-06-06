import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/route_payload.dart';

void main() {
  test('player identity payload preserves source and downstream blockers', () {
    const player = PlayerProfile(
      id: 'nba-2544',
      displayName: 'LeBron James',
      firstName: 'LeBron',
      lastName: 'James',
      primaryTeamAbbreviation: 'LAL',
      sourceId: 'nba-api-common-all-players',
      asOf: '2026-06-05',
    );

    final payload = RoutePayload(
      sourceObjectType: 'Player',
      sourceObjectId: player.id,
      displayLabel: player.displayName,
      selectedColumns: const ['playerId', 'displayName', 'firstName', 'lastName', 'sourceId', 'asOf'],
      selectedRows: const [player.id],
      filterSummary: 'Search result: player=${player.displayName}; targetRoute=Workspace',
      sourceSnapshot: 'Connected local source-backed asset: player_profiles.json',
      readinessState: 'Player identity connected; player stats pending',
      blockers: const ['Player traditional stats pending', 'Roster windows pending'],
      targetRoute: 'Workspace',
      availableActions: const ['Workspace', 'Compare', 'Reports'],
    );

    expect(payload.sourceObjectType, 'Player');
    expect(payload.sourceObjectId, 'nba-2544');
    expect(payload.displayLabel, 'LeBron James');
    expect(payload.sourceSnapshot, contains('player_profiles.json'));
    expect(payload.blockers, contains('Player traditional stats pending'));
  });
}
