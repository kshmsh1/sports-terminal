/// Canonical draft-context projection for one NBA Season command payload.
///
/// Draft year, round, pick number, player, and selecting team remain exactly as
/// exposed by the source. The engine never derives a round from pick number or
/// assumes that a Season ID implies a specific draft year.
class NbaSeasonDraftClassEngine {
  const NbaSeasonDraftClassEngine();

  NbaSeasonDraftClassResult build(
    Map<String, dynamic> payload, {
    required String seasonId,
  }) {
    final normalizedSeason = seasonId.trim();
    if (normalizedSeason.isEmpty) {
      throw ArgumentError.value(seasonId, 'seasonId', 'Season is required.');
    }

    final rows = _draftMaps(payload['draft'])
        .map((row) => NbaSeasonDraftClassRow(
              draftYear: _draftInt(row['draft_year'] ?? row['year']),
              round: _draftInt(row['round'] ?? row['round_number']),
              roundText: _draftFirst(
                row,
                const ['round_text', 'round_label'],
              ),
              pickNumber: _draftInt(
                row['pick_number'] ?? row['overall_pick'] ?? row['pick'],
              ),
              playerId: _draftFirst(
                row,
                const ['player_key', 'player_id'],
              ),
              playerName: _draftFirst(
                row,
                const ['player_name', 'canonical_name', 'name'],
              ),
              teamId: _draftFirst(
                row,
                const ['team_key', 'team_id'],
              ),
              teamLabel: _draftFirst(
                row,
                const ['team_name', 'team_abbreviation', 'team'],
              ),
              source: _draftSource(row),
            ))
        .where((row) => row.playerId.isNotEmpty || row.playerName.isNotEmpty)
        .toList(growable: false)
      ..sort((left, right) {
        final yearCompare = (left.draftYear ?? 1 << 30)
            .compareTo(right.draftYear ?? 1 << 30);
        if (yearCompare != 0) return yearCompare;
        final pickCompare = (left.pickNumber ?? 1 << 30)
            .compareTo(right.pickNumber ?? 1 << 30);
        if (pickCompare != 0) return pickCompare;
        return left.playerName.compareTo(right.playerName);
      });

    final years = rows
        .map((row) => row.draftYear)
        .whereType<int>()
        .toSet()
        .toList(growable: false)
      ..sort();

    return NbaSeasonDraftClassResult(
      seasonId: normalizedSeason,
      rows: List.unmodifiable(rows),
      draftYears: List.unmodifiable(years),
    );
  }
}

class NbaSeasonDraftClassResult {
  const NbaSeasonDraftClassResult({
    required this.seasonId,
    required this.rows,
    required this.draftYears,
  });

  final String seasonId;
  final List<NbaSeasonDraftClassRow> rows;
  final List<int> draftYears;

  bool get hasRows => rows.isNotEmpty;
  int get sourceRows => rows.length;
  int get numberedPicks => rows.where((row) => row.pickNumber != null).length;
  int get firstRoundRows => rows.where((row) => row.round == 1).length;
  int get explicitTeamRows => rows.where((row) => row.teamId.isNotEmpty).length;
  int get rowsWithoutPickNumber => rows.where((row) => row.pickNumber == null).length;
}

class NbaSeasonDraftClassRow {
  const NbaSeasonDraftClassRow({
    required this.draftYear,
    required this.round,
    required this.roundText,
    required this.pickNumber,
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamLabel,
    required this.source,
  });

  final int? draftYear;
  final int? round;
  final String roundText;
  final int? pickNumber;
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamLabel;
  final String source;

  String get pickLabel => pickNumber == null ? '—' : '#$pickNumber';
  String get roundLabel {
    if (round != null) return 'R$round';
    return roundText.isEmpty ? '—' : roundText;
  }
}

List<Map<String, dynamic>> _draftMaps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

Map<String, dynamic> _draftMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : const {};

String _draftFirst(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

String _draftSource(Map<String, dynamic> row) {
  final direct = _draftFirst(
    row,
    const ['source_key', 'source', 'source_table'],
  );
  if (direct.isNotEmpty) return direct;
  return _draftFirst(
    _draftMap(row['provenance']),
    const ['source_key', 'source', 'source_table'],
  );
}

int? _draftInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
