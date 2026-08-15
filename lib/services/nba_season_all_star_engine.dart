/// Canonical All-Star selection projection for one NBA Season command payload.
///
/// A row is labeled a starter only when the source explicitly says so. Every
/// other usable row is represented as selected, not inferred as a reserve,
/// replacement, injury substitute, or roster role unless those fields exist.
class NbaSeasonAllStarEngine {
  const NbaSeasonAllStarEngine();

  NbaSeasonAllStarResult build(
    Map<String, dynamic> payload, {
    required String seasonId,
  }) {
    final normalizedSeason = seasonId.trim();
    if (normalizedSeason.isEmpty) {
      throw ArgumentError.value(seasonId, 'seasonId', 'Season is required.');
    }

    final rows = _allStarMaps(payload['all_star'])
        .map((row) => NbaSeasonAllStarRow(
              playerId: _allStarFirst(
                row,
                const ['player_key', 'player_id'],
              ),
              playerName: _allStarFirst(
                row,
                const ['player_name', 'canonical_name', 'name'],
              ),
              teamId: _allStarFirst(
                row,
                const ['team_key', 'team_id'],
              ),
              teamLabel: _allStarFirst(
                row,
                const ['team_name', 'team_abbreviation', 'team'],
              ),
              starter: _allStarBool(
                row['starter'] ?? row['is_starter'],
              ),
              conference: _allStarFirst(
                row,
                const ['conference', 'conference_name'],
              ),
              rosterLabel: _allStarFirst(
                row,
                const ['roster_label', 'roster', 'all_star_team'],
              ),
              selectionType: _allStarFirst(
                row,
                const ['selection_type', 'selection', 'role'],
              ),
              source: _allStarSource(row),
            ))
        .where((row) => row.playerId.isNotEmpty || row.playerName.isNotEmpty)
        .toList(growable: false)
      ..sort((left, right) {
        if (left.starter != right.starter) return left.starter ? -1 : 1;
        final rosterCompare = left.rosterLabel.compareTo(right.rosterLabel);
        if (rosterCompare != 0) return rosterCompare;
        return left.playerName.compareTo(right.playerName);
      });

    return NbaSeasonAllStarResult(
      seasonId: normalizedSeason,
      rows: List.unmodifiable(rows),
    );
  }
}

class NbaSeasonAllStarResult {
  const NbaSeasonAllStarResult({
    required this.seasonId,
    required this.rows,
  });

  final String seasonId;
  final List<NbaSeasonAllStarRow> rows;

  bool get hasRows => rows.isNotEmpty;
  int get selections => rows.length;
  int get explicitStarters => rows.where((row) => row.starter).length;
  int get rowsWithRosterLabel =>
      rows.where((row) => row.rosterLabel.isNotEmpty).length;
  int get rowsWithSelectionType =>
      rows.where((row) => row.selectionType.isNotEmpty).length;

  List<String> get conferences {
    final values = rows
        .map((row) => row.conference)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    return List.unmodifiable(values);
  }
}

class NbaSeasonAllStarRow {
  const NbaSeasonAllStarRow({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamLabel,
    required this.starter,
    required this.conference,
    required this.rosterLabel,
    required this.selectionType,
    required this.source,
  });

  final String playerId;
  final String playerName;
  final String teamId;
  final String teamLabel;
  final bool starter;
  final String conference;
  final String rosterLabel;
  final String selectionType;
  final String source;

  String get statusLabel => starter ? 'STARTER' : 'SELECTED';
}

List<Map<String, dynamic>> _allStarMaps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

Map<String, dynamic> _allStarMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : const {};

String _allStarFirst(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

String _allStarSource(Map<String, dynamic> row) {
  final direct = _allStarFirst(
    row,
    const ['source_key', 'source', 'source_table'],
  );
  if (direct.isNotEmpty) return direct;
  return _allStarFirst(
    _allStarMap(row['provenance']),
    const ['source_key', 'source', 'source_table'],
  );
}

bool _allStarBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'true', '1', 'yes', 'y', 'starter'}
      .contains(value?.toString().trim().toLowerCase());
}
