import 'nba_entity_intelligence_repository.dart';
import 'nba_player_career_context_engine.dart';
import 'nba_player_career_engine.dart';

typedef NbaPlayerCareerComparisonDossierLoader = Future<Map<String, dynamic>> Function(
  String playerKey,
  String seasonType,
);
typedef NbaPlayerCareerComparisonTeamLoader = Future<Map<String, dynamic>> Function(
  String teamKey,
);

class NbaPlayerCareerComparisonBundle {
  const NbaPlayerCareerComparisonBundle({
    required this.leftCareer,
    required this.rightCareer,
    required this.leftContext,
    required this.rightContext,
  });

  final NbaPlayerCareerSnapshot leftCareer;
  final NbaPlayerCareerSnapshot rightCareer;
  final NbaPlayerCareerContext leftContext;
  final NbaPlayerCareerContext rightContext;
}

/// Loads two historical Player dossiers through one explicit comparison boundary.
/// Team/Franchise enrichment is attempted only for team keys already exposed by
/// each Player season row; failed Team dossier loads remain visible coverage gaps.
class NbaPlayerCareerComparisonLoader {
  const NbaPlayerCareerComparisonLoader();

  Future<NbaPlayerCareerComparisonBundle> load({
    required String leftPlayerKey,
    required String rightPlayerKey,
    String league = 'NBA',
    String seasonType = 'regular',
    NbaPlayerCareerComparisonDossierLoader? loadPlayer,
    NbaPlayerCareerComparisonTeamLoader? loadTeam,
  }) async {
    final normalizedLeague = league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase();
    final normalizedSeasonType = seasonType.trim().toLowerCase() == 'playoffs'
        ? 'playoffs'
        : 'regular';
    final repository = const NbaEntityIntelligenceRepository();
    final playerLoader = loadPlayer ??
        (String key, String type) => repository.playerDossier(
              key,
              league: normalizedLeague,
              seasonType: type,
              recentGames: 50,
            );
    final teamLoader = loadTeam ??
        (String key) => repository.teamDossier(
              key,
              league: normalizedLeague,
              seasonType: 'regular',
              recentGames: 0,
            );

    final left = await _loadOne(
      leftPlayerKey,
      normalizedSeasonType,
      playerLoader,
      teamLoader,
    );
    final right = await _loadOne(
      rightPlayerKey,
      normalizedSeasonType,
      playerLoader,
      teamLoader,
    );
    return NbaPlayerCareerComparisonBundle(
      leftCareer: left.$1,
      rightCareer: right.$1,
      leftContext: left.$2,
      rightContext: right.$2,
    );
  }

  Future<(NbaPlayerCareerSnapshot, NbaPlayerCareerContext)> _loadOne(
    String playerKey,
    String seasonType,
    NbaPlayerCareerComparisonDossierLoader loadPlayer,
    NbaPlayerCareerComparisonTeamLoader loadTeam,
  ) async {
    final key = playerKey.trim();
    if (key.isEmpty) {
      throw ArgumentError('Both canonical historical Player keys are required.');
    }
    final payload = await loadPlayer(key, seasonType);
    final teamKeys = <String>{};
    final rawSeasons = payload['seasons'];
    if (rawSeasons is List) {
      for (final raw in rawSeasons) {
        if (raw is! Map) continue;
        final teamKey = raw['team_key']?.toString().trim() ?? '';
        if (teamKey.isNotEmpty) teamKeys.add(teamKey);
      }
    }
    final teamDossiers = <String, Map<String, dynamic>>{};
    for (final teamKey in teamKeys) {
      try {
        teamDossiers[teamKey] = await loadTeam(teamKey);
      } catch (_) {
        // Missing Team dossier remains an explicit career coverage gap.
      }
    }
    return (
      const NbaPlayerCareerEngine().build(
        payload,
        playerKey: key,
        teamDossiers: teamDossiers,
      ),
      const NbaPlayerCareerContextEngine().build(payload),
    );
  }
}
