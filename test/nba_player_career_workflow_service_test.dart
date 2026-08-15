import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_player_career_context_engine.dart';
import 'package:sports_terminal/services/nba_player_career_engine.dart';
import 'package:sports_terminal/services/nba_player_career_workflow_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('packages canonical career seasons, tenure and source-backed context', () {
    final career = _career();
    final context = const NbaPlayerCareerContextEngine().build({
      'awards': [
        {'season_id': '2020-21', 'award': 'Example Award'},
      ],
      'all_star': [
        {'season_id': '2020-21', 'selection': 'All-Star'},
      ],
      'draft': [
        {'draft_year': 2010, 'round': 1, 'pick': 5, 'team_key': 'alpha'},
      ],
      'recent_games': [
        {
          'game_key': 'g1',
          'season_id': '2020-21',
          'game_date': '2021-01-01',
          'team_key': 'alpha',
          'opponent_team_key': 'beta',
          'pts': 25,
        },
      ],
    });

    final payload = const NbaPlayerCareerWorkflowService().package(
      career: career,
      context: context,
      targetRoute: 'Workspace',
    );

    expect(payload.sourceObjectType, 'NBA Player Career');
    expect(payload.sourceObjectId, 'p1');
    expect(payload.targetRoute, 'Workspace');
    expect(payload.readinessState, 'Ready');
    expect(payload.rows.where((row) => row['row_type'] == 'career_season').length, 2);
    expect(payload.rows.where((row) => row['row_type'] == 'team_tenure').length, 1);
    expect(payload.rows.where((row) => row['row_type'] == 'award').length, 1);
    expect(payload.rows.where((row) => row['row_type'] == 'all_star').length, 1);
    expect(payload.rows.where((row) => row['row_type'] == 'draft').length, 1);
    expect(payload.rows.where((row) => row['row_type'] == 'recent_game').length, 1);
    expect(payload.metadata['teamFranchiseCoverageComplete'], isTrue);
    expect(payload.metadata['careerGames'], 162);
  });

  test('empty career packages Partial without synthesizing rows', () {
    const career = NbaPlayerCareerSnapshot(
      playerKey: 'p1',
      playerName: 'Example Star',
      primaryPosition: '',
      activeFrom: '',
      activeTo: '',
      nbaId: '',
      brefId: '',
      identityConfidence: null,
      sourceCount: null,
      seasons: [],
      tenures: [],
      missingTeamDossierKeys: [],
      multiTeamAggregateSeasons: [],
      declaredFirstSeason: '',
      declaredLastSeason: '',
      declaredSeasonRows: null,
      materialConflictCount: 0,
    );
    const context = NbaPlayerCareerContext(
      awards: [],
      allStarSelections: [],
      draftRecords: [],
      recentGames: [],
      identityRows: 0,
      conflictRows: 0,
      fieldProvenanceRows: 0,
    );

    final payload = const NbaPlayerCareerWorkflowService().package(
      career: career,
      context: context,
      targetRoute: 'Source Audit',
    );

    expect(payload.readinessState, 'Partial');
    expect(payload.rows, isEmpty);
  });

  test('canonical Player career watch identity persists independently', () async {
    const workflows = NbaPlayerCareerWorkflowService();
    final career = _career();

    expect(await workflows.isWatched(career), isFalse);
    expect(await workflows.toggleWatch(career), isTrue);
    expect(await workflows.isWatched(career), isTrue);
    expect(await workflows.toggleWatch(career), isFalse);
  });

  test('research activation pins exact Player and last exposed season', () async {
    const workflows = NbaPlayerCareerWorkflowService();
    final context = await workflows.activateResearch(_career());

    expect(context.historical, isTrue);
    expect(context.season, '2020-21');
    expect(context.seasonType, 'regular');
    expect(context.playerKey, 'p1');
    expect(context.playerName, 'Example Star');
  });
}

NbaPlayerCareerSnapshot _career() => const NbaPlayerCareerEngine().build(
      {
        'profile': {
          'player_key': 'p1',
          'canonical_name': 'Example Star',
          'nba_id': '1001',
        },
        'seasons': [
          {
            'season_id': '2019-20',
            'season_type': 'regular',
            'team_key': 'alpha',
            'team_name': 'Alpha',
            'games': 80,
            'pts': 1600,
          },
          {
            'season_id': '2020-21',
            'season_type': 'regular',
            'team_key': 'alpha',
            'team_name': 'Alpha',
            'games': 82,
            'pts': 1722,
          },
        ],
        'summary': {
          'first_season': '2019-20',
          'last_season': '2020-21',
        },
      },
      playerKey: 'p1',
      teamDossiers: const {
        'alpha': {
          'profile': {
            'canonical_name': 'Alpha',
            'franchise_key': 'fr_alpha',
            'franchise_name': 'Alpha Franchise',
          },
        },
      },
    );
