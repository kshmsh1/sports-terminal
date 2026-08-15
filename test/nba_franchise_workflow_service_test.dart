import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_franchise_intelligence_engine.dart';
import 'package:sports_terminal/services/nba_franchise_player_history_engine.dart';
import 'package:sports_terminal/services/nba_franchise_workflow_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('packages canonical franchise lineage, seasons and bounded player history', () {
    final franchise = _franchise();
    final players = const NbaFranchisePlayerHistoryEngine().build(
      franchise: franchise,
      teamDossiers: {
        'alpha': {
          'notable_players': [
            {
              'player_key': 'p1',
              'player_name': 'Player One',
              'games': 400,
              'pts': 9000,
              'reb': 2000,
              'ast': 2500,
              'first_season': '2020-21',
              'last_season': '2025-26',
              'seasons': 6,
            },
          ],
        },
      },
    );

    final payload = const NbaFranchiseWorkflowService().package(
      franchise: franchise,
      playerHistory: players,
      targetRoute: 'Workspace',
    );

    expect(payload.sourceObjectType, 'NBA Franchise');
    expect(payload.sourceObjectId, 'fr_alpha');
    expect(payload.targetRoute, 'Workspace');
    expect(payload.readinessState, 'Ready');
    expect(payload.rows.where((row) => row['row_type'] == 'team_identity').length, 1);
    expect(payload.rows.where((row) => row['row_type'] == 'season').length, 2);
    expect(payload.rows.where((row) => row['row_type'] == 'player_history').length, 1);
    expect(payload.metadata['totalWins'], 90);
    expect(payload.metadata['awardsMapping'], 'not-exposed-at-franchise-scope');
    expect(payload.metadata['draftMapping'], 'not-exposed-at-franchise-scope');
  });

  test('missing usable franchise rows packages partial state instead of fabricating data', () {
    const franchise = NbaFranchiseIntelligenceSnapshot(
      franchiseKey: 'fr_missing',
      franchiseName: 'Missing Franchise',
      currentAbbreviation: '',
      sourceCount: null,
      teamIdentities: [],
      seasons: [],
      firstSeason: '',
      lastSeason: '',
      declaredSeasonCount: null,
      declaredIdentityCount: null,
    );
    const playerHistory = NbaFranchisePlayerHistoryResult(
      franchiseKey: 'fr_missing',
      players: [],
      requestedTeamIdentities: 0,
      loadedTeamDossiers: 0,
      missingTeamDossiers: 0,
      sourceRows: 0,
    );

    final payload = const NbaFranchiseWorkflowService().package(
      franchise: franchise,
      playerHistory: playerHistory,
      targetRoute: 'Source Audit',
    );

    expect(payload.readinessState, 'Partial');
    expect(payload.rows, isEmpty);
  });

  test('canonical Franchise watch identity persists independently', () async {
    const workflows = NbaFranchiseWorkflowService();
    final franchise = _franchise();

    expect(await workflows.isWatched(franchise), isFalse);
    expect(await workflows.toggleWatch(franchise), isTrue);
    expect(await workflows.isWatched(franchise), isTrue);
    expect(await workflows.toggleWatch(franchise), isFalse);
  });

  test('research activation is pinned to the last explicitly exposed franchise season', () async {
    const workflows = NbaFranchiseWorkflowService();
    final context = await workflows.activateResearch(_franchise());

    expect(context.historical, isTrue);
    expect(context.season, '2025-26');
    expect(context.league, 'NBA');
    expect(context.seasonType, 'regular');
  });
}

NbaFranchiseIntelligenceSnapshot _franchise() => const NbaFranchiseIntelligenceSnapshot(
      franchiseKey: 'fr_alpha',
      franchiseName: 'Alpha Franchise',
      currentAbbreviation: 'ALP',
      sourceCount: 2,
      teamIdentities: [
        NbaFranchiseTeamIdentity(
          teamKey: 'alpha',
          teamName: 'Alpha',
          abbreviation: 'ALP',
          leagueId: 'NBA',
          activeFrom: '2020-21',
          activeTo: '2025-26',
          nbaTeamId: '100',
          sourceCount: 2,
        ),
      ],
      seasons: [
        NbaFranchiseSeasonObservation(
          seasonId: '2024-25',
          seasonType: 'regular',
          teamKey: 'alpha',
          teamName: 'Alpha',
          abbreviation: 'ALP',
          leagueId: 'NBA',
          wins: 40,
          losses: 42,
          winPct: 40 / 82,
          source: 'fixture',
        ),
        NbaFranchiseSeasonObservation(
          seasonId: '2025-26',
          seasonType: 'regular',
          teamKey: 'alpha',
          teamName: 'Alpha',
          abbreviation: 'ALP',
          leagueId: 'NBA',
          wins: 50,
          losses: 32,
          winPct: 50 / 82,
          source: 'fixture',
        ),
      ],
      firstSeason: '2020-21',
      lastSeason: '2025-26',
      declaredSeasonCount: 6,
      declaredIdentityCount: 1,
    );
