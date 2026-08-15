import 'nba_entity_intelligence_repository.dart';

typedef NbaPlayerComparisonSearchLoader = Future<Map<String, dynamic>> Function(
  String query,
  String league,
);

class NbaPlayerCareerComparisonCandidate {
  const NbaPlayerCareerComparisonCandidate({
    required this.playerKey,
    required this.playerName,
    required this.nbaId,
    required this.leagueId,
    required this.lastSeason,
    required this.position,
  });

  final String playerKey;
  final String playerName;
  final String nbaId;
  final String leagueId;
  final String lastSeason;
  final String position;

  bool get usable => playerKey.isNotEmpty && playerName.isNotEmpty;
}

class NbaPlayerCareerComparisonDiscoveryService {
  const NbaPlayerCareerComparisonDiscoveryService();

  Future<List<NbaPlayerCareerComparisonCandidate>> search(
    String query, {
    String league = 'NBA',
    int limit = 20,
    NbaPlayerComparisonSearchLoader? loader,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) return const [];
    final normalizedLeague = league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase();
    final payload = await (loader?.call(normalizedQuery, normalizedLeague) ??
        const NbaEntityIntelligenceRepository().search(
          normalizedQuery,
          league: normalizedLeague,
          kinds: const {'player'},
          limitPerKind: limit.clamp(1, 100),
        ));
    final groups = _comparisonMap(payload['groups']);
    final rawPlayers = groups['players'];
    if (rawPlayers is! List) return const [];
    final seen = <String>{};
    final result = <NbaPlayerCareerComparisonCandidate>[];
    for (final raw in rawPlayers) {
      final row = _comparisonMap(raw);
      final key = _comparisonText(row, const ['player_key', 'playerKey']);
      final name = _comparisonText(
        row,
        const ['canonical_name', 'player_name', 'name'],
      );
      if (key.isEmpty || name.isEmpty || !seen.add(key)) continue;
      result.add(
        NbaPlayerCareerComparisonCandidate(
          playerKey: key,
          playerName: name,
          nbaId: _comparisonText(row, const ['nba_id', 'nbaId']),
          leagueId: _comparisonText(row, const ['league_id', 'league'])
              .ifEmpty(normalizedLeague),
          lastSeason: _comparisonText(
            row,
            const ['last_stat_season', 'last_season', 'season_id'],
          ),
          position: _comparisonText(
            row,
            const ['primary_position', 'position'],
          ),
        ),
      );
      if (result.length >= limit.clamp(1, 100)) break;
    }
    return List.unmodifiable(result);
  }

  NbaPlayerCareerComparisonCandidate? exactMatch(
    Iterable<NbaPlayerCareerComparisonCandidate> candidates, {
    String playerKey = '',
    String nbaId = '',
    String playerName = '',
  }) {
    final key = playerKey.trim();
    final nba = nbaId.trim();
    final name = playerName.trim().toLowerCase();
    for (final candidate in candidates) {
      if (key.isNotEmpty && candidate.playerKey == key) return candidate;
      if (nba.isNotEmpty && candidate.nbaId == nba) return candidate;
    }
    if (name.isNotEmpty) {
      for (final candidate in candidates) {
        if (candidate.playerName.toLowerCase() == name) return candidate;
      }
    }
    return null;
  }
}

Map<String, dynamic> _comparisonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

String _comparisonText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
