import 'nba_stats_workstation_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// True if the league-wide season row represents multiple teams. The summary
/// stays in the standings; source-backed team stints are loaded on demand.
bool isMultiTeamStatsRow(NbaStatsRow row) {
  final teams = row.raw['teams_played_for'];
  if (teams is List) {
    final abbreviations = teams.map((team) => team.toString().trim())
        .where((team) => team.isNotEmpty).toSet();
    if (abbreviations.length > 1) return true;
  }
  return RegExp(r'^[2-9]TM$', caseSensitive: false)
      .hasMatch(row.team.trim()) ||
      const {'TOT', 'MULTI'}.contains(row.team.trim().toUpperCase());
}

/// Account for a player's *actual* franchises when applying a team filter.
/// A traded player's main row retains league-wide season totals.
bool statsRowMatchesTeam(NbaStatsRow row, String team) {
  if (team == 'All') return true;
  if (row.team.split(RegExp(r'[,/ ]+')).contains(team)) return true;
  final stints = row.raw['teams_played_for'];
  if (stints is List && stints.any(
      (value) => value.toString().toUpperCase() == team.toUpperCase())) {
    return true;
  }
  return false;
}

bool _isAggregateTeam(String team) {
  final normalized = team.toUpperCase();
  return normalized.isEmpty ||
      const {'TOT', 'MULTI', 'ALL'}.contains(normalized) ||
      RegExp(r'^[2-9]TM$').hasMatch(normalized);
}

/// Only actual canonical per-team rows from the historical player dossier are
/// accepted. Never apportion aggregated totals across franchises.
List<NbaStatsRow> sourceBackedTeamStints({
  required Map<String, dynamic> dossier,
  required String playerId,
  required String playerName,
  required String seasonId,
  required NbaStatsSeasonType seasonType,
}) {
  final source = dossier['seasons'];
  if (source is! List) return const [];
  final segment = seasonType == NbaStatsSeasonType.playoffs
      ? 'playoffs' : 'regular';
  final byTeam = <String, Map<String, dynamic>>{};

  for (final item in source) {
    if (item is! Map) continue;
    final season = (item['season_id'] ?? '').toString();
    final type = (item['season_type'] ?? '').toString().toLowerCase();
    final playoff = type.contains('play');
    if (season != seasonId || (segment == 'playoffs') != playoff) continue;
    final abbreviation =
        (item['team_abbreviation'] ?? '').toString().trim().toUpperCase();
    if (_isAggregateTeam(abbreviation)) continue;
    // Keep only rows with actual game participation; aggregates are excluded.
    final games = _toNum(item['games']);
    if (games == null || games <= 0) continue;
    final mapped = item.map((key, value) =>
        MapEntry(key.toString(), value));
    mapped['player_id'] = playerId;
    mapped['player_label'] = playerName;
    mapped['team_ids'] = abbreviation;
    mapped['season_type'] = segment;
    mapped['position'] = item['positions'] ??
        item['position'] ?? dossier['profile']?['primary_position'];
    final previous = byTeam[abbreviation];
    if (previous == null ||
        (_toNum(previous['games']) ?? 0) < games) {
      byTeam[abbreviation] = mapped;
    }
  }

  if (byTeam.isEmpty) return const [];
  final snapshot = NbaTerminalSeedSnapshot.fromMap({
    'players': [
      {'player_id': playerId, 'primary_position':
          dossier['profile'] is Map
              ? (dossier['profile'] as Map)['primary_position'] : null},
    ],
    'player_season_totals': byTeam.values.toList(),
  });
  final normalized = const NbaStatsWorkstationEngine().buildRows(
    snapshot,
    basis: NbaStatsBasis.perGame,
    seasonType: seasonType,
  )..sort((a, b) => a.team.compareTo(b.team));
  return normalized;
}

double? _toNum(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
