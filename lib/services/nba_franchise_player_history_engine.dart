import 'nba_franchise_intelligence_engine.dart';

class NbaFranchisePlayerHistoryRow {
  const NbaFranchisePlayerHistoryRow({
    required this.playerKey,
    required this.playerName,
    required this.teamKeys,
    required this.firstSeason,
    required this.lastSeason,
    required this.seasons,
    required this.games,
    required this.points,
    required this.rebounds,
    required this.assists,
  });

  final String playerKey;
  final String playerName;
  final List<String> teamKeys;
  final String firstSeason;
  final String lastSeason;
  final int seasons;
  final num games;
  final num points;
  final num rebounds;
  final num assists;

  double? get pointsPerGame => games > 0 ? points / games : null;
  double? get reboundsPerGame => games > 0 ? rebounds / games : null;
  double? get assistsPerGame => games > 0 ? assists / games : null;
}

class NbaFranchisePlayerHistoryResult {
  const NbaFranchisePlayerHistoryResult({
    required this.franchiseKey,
    required this.players,
    required this.requestedTeamIdentities,
    required this.loadedTeamDossiers,
    required this.missingTeamDossiers,
    required this.sourceRows,
  });

  final String franchiseKey;
  final List<NbaFranchisePlayerHistoryRow> players;
  final int requestedTeamIdentities;
  final int loadedTeamDossiers;
  final int missingTeamDossiers;
  final int sourceRows;

  bool get available => loadedTeamDossiers > 0;
  bool get completeAcrossRequestedIdentities =>
      requestedTeamIdentities > 0 && missingTeamDossiers == 0;

  String get coverageLabel =>
      '$loadedTeamDossiers/$requestedTeamIdentities team dossiers loaded · $sourceRows bounded notable-player rows';

  String get methodologyLabel =>
      'Aggregated from each canonical Team dossier’s regular-season notable_players collection. Each Team dossier is intentionally bounded to its source-defined top player set; this is a franchise research leaderboard, not an exhaustive all-player ledger.';
}

class _Accumulator {
  _Accumulator({required this.playerKey, required this.playerName});

  final String playerKey;
  String playerName;
  final Set<String> teamKeys = {};
  String firstSeason = '';
  String lastSeason = '';
  int seasons = 0;
  num games = 0;
  num points = 0;
  num rebounds = 0;
  num assists = 0;
}

/// Aggregates bounded notable-player rows from canonical Team dossiers for all
/// team identities belonging to one Franchise.
class NbaFranchisePlayerHistoryEngine {
  const NbaFranchisePlayerHistoryEngine();

  NbaFranchisePlayerHistoryResult build({
    required NbaFranchiseIntelligenceSnapshot franchise,
    required Map<String, Map<String, dynamic>> teamDossiers,
  }) {
    final requested = franchise.teamIdentities.map((row) => row.teamKey).where((key) => key.isNotEmpty).toSet();
    final accumulators = <String, _Accumulator>{};
    var loaded = 0;
    var sourceRows = 0;

    for (final teamKey in requested) {
      final dossier = teamDossiers[teamKey];
      if (dossier == null) continue;
      loaded += 1;
      final notable = dossier['notable_players'];
      if (notable is! List) continue;
      for (final raw in notable) {
        if (raw is! Map) continue;
        final row = raw.map((key, value) => MapEntry(key.toString(), value));
        final playerKey = _text(row, const ['player_key', 'playerKey']);
        final playerName = _text(row, const ['player_name', 'canonical_name', 'name']);
        if (playerKey.isEmpty || playerName.isEmpty) continue;
        sourceRows += 1;
        final accumulator = accumulators.putIfAbsent(
          playerKey,
          () => _Accumulator(playerKey: playerKey, playerName: playerName),
        );
        if (accumulator.playerName.isEmpty) accumulator.playerName = playerName;
        accumulator.teamKeys.add(teamKey);
        accumulator.games += _number(row, const ['games', 'gp']) ?? 0;
        accumulator.points += _number(row, const ['pts', 'points']) ?? 0;
        accumulator.rebounds += _number(row, const ['reb', 'rebounds']) ?? 0;
        accumulator.assists += _number(row, const ['ast', 'assists']) ?? 0;
        accumulator.seasons += _integer(row, const ['seasons', 'season_count']) ?? 0;
        final first = _text(row, const ['first_season', 'firstSeason']);
        final last = _text(row, const ['last_season', 'lastSeason']);
        if (first.isNotEmpty && (accumulator.firstSeason.isEmpty || first.compareTo(accumulator.firstSeason) < 0)) {
          accumulator.firstSeason = first;
        }
        if (last.isNotEmpty && (accumulator.lastSeason.isEmpty || last.compareTo(accumulator.lastSeason) > 0)) {
          accumulator.lastSeason = last;
        }
      }
    }

    final players = [
      for (final accumulator in accumulators.values)
        NbaFranchisePlayerHistoryRow(
          playerKey: accumulator.playerKey,
          playerName: accumulator.playerName,
          teamKeys: (accumulator.teamKeys.toList()..sort()),
          firstSeason: accumulator.firstSeason,
          lastSeason: accumulator.lastSeason,
          seasons: accumulator.seasons,
          games: accumulator.games,
          points: accumulator.points,
          rebounds: accumulator.rebounds,
          assists: accumulator.assists,
        ),
    ]
      ..sort((left, right) {
        final byGames = right.games.compareTo(left.games);
        if (byGames != 0) return byGames;
        final byPoints = right.points.compareTo(left.points);
        if (byPoints != 0) return byPoints;
        return left.playerName.compareTo(right.playerName);
      });

    return NbaFranchisePlayerHistoryResult(
      franchiseKey: franchise.franchiseKey,
      players: List.unmodifiable(players),
      requestedTeamIdentities: requested.length,
      loadedTeamDossiers: loaded,
      missingTeamDossiers: requested.length - loaded,
      sourceRows: sourceRows,
    );
  }
}

String _text(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

num? _number(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value;
    final parsed = num.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

int? _integer(Map<String, dynamic> row, List<String> keys) => _number(row, keys)?.toInt();
