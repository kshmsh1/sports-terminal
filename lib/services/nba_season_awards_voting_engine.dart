/// Source-backed awards and voting projection for one canonical NBA Season.
///
/// This engine never infers an award winner from rank or vote totals. `winner`
/// is true only when the source row explicitly marks the recipient as a winner.
/// Voting fields remain null unless the canonical Season command exposes them.
class NbaSeasonAwardsVotingEngine {
  const NbaSeasonAwardsVotingEngine();

  NbaSeasonAwardsVotingResult build(
    Map<String, dynamic> payload, {
    required String seasonId,
  }) {
    final normalizedSeason = seasonId.trim();
    if (normalizedSeason.isEmpty) {
      throw ArgumentError.value(seasonId, 'seasonId', 'Season is required.');
    }

    final rows = _awardMaps(payload['awards'])
        .map((row) => NbaSeasonAwardVotingRow(
              award: _awardFirst(
                row,
                const ['award', 'award_name', 'name'],
              ),
              playerId: _awardFirst(
                row,
                const ['player_key', 'player_id'],
              ),
              playerName: _awardFirst(
                row,
                const ['player_name', 'canonical_name', 'recipient'],
              ),
              winner: _awardBool(row['winner'] ?? row['is_winner']),
              rank: _awardInt(row['rank'] ?? row['place']),
              rankText: _awardFirst(
                row,
                const ['rank_text', 'rank_label', 'place_text'],
              ),
              votePoints: _awardDouble(
                row['vote_points'] ??
                    row['award_points'] ??
                    row['total_vote_points'],
              ),
              firstPlaceVotes: _awardInt(
                row['first_place_votes'] ?? row['first_votes'],
              ),
              totalVotes: _awardDouble(
                row['total_votes'] ?? row['ballots'] ?? row['votes_received'],
              ),
              voteShare: _awardDouble(
                row['vote_share'] ?? row['share'] ?? row['vote_pct'],
              ),
              source: _awardSource(row),
            ))
        .where((row) => row.award.isNotEmpty || row.playerName.isNotEmpty)
        .toList(growable: false);

    final grouped = <String, List<NbaSeasonAwardVotingRow>>{};
    for (final row in rows) {
      final key = row.award.trim().toUpperCase();
      grouped.putIfAbsent(key, () => <NbaSeasonAwardVotingRow>[]).add(row);
    }

    final awards = <NbaSeasonAwardVotingGroup>[];
    for (final entry in grouped.entries) {
      final awardRows = [...entry.value]
        ..sort((left, right) {
          if (left.winner != right.winner) return left.winner ? -1 : 1;
          final leftRank = left.rank ?? 1 << 30;
          final rightRank = right.rank ?? 1 << 30;
          if (leftRank != rightRank) return leftRank.compareTo(rightRank);
          final voteCompare = (right.votePoints ?? double.negativeInfinity)
              .compareTo(left.votePoints ?? double.negativeInfinity);
          if (voteCompare != 0) return voteCompare;
          return left.playerName.compareTo(right.playerName);
        });
      awards.add(
        NbaSeasonAwardVotingGroup(
          award: awardRows.first.award.isEmpty ? entry.key : awardRows.first.award,
          rows: List.unmodifiable(awardRows),
        ),
      );
    }
    awards.sort((left, right) => left.award.compareTo(right.award));

    return NbaSeasonAwardsVotingResult(
      seasonId: normalizedSeason,
      awards: List.unmodifiable(awards),
      sourceRows: rows.length,
    );
  }
}

class NbaSeasonAwardsVotingResult {
  const NbaSeasonAwardsVotingResult({
    required this.seasonId,
    required this.awards,
    required this.sourceRows,
  });

  final String seasonId;
  final List<NbaSeasonAwardVotingGroup> awards;
  final int sourceRows;

  bool get hasAwards => awards.isNotEmpty;
  int get awardCount => awards.length;
  int get explicitWinnerRows => awards.fold(
        0,
        (total, award) => total + award.rows.where((row) => row.winner).length,
      );
  int get rowsWithVoteDetail => awards.fold(
        0,
        (total, award) =>
            total + award.rows.where((row) => row.hasVoteDetail).length,
      );
}

class NbaSeasonAwardVotingGroup {
  const NbaSeasonAwardVotingGroup({
    required this.award,
    required this.rows,
  });

  final String award;
  final List<NbaSeasonAwardVotingRow> rows;

  NbaSeasonAwardVotingRow? get explicitWinner {
    for (final row in rows) {
      if (row.winner) return row;
    }
    return null;
  }

  bool get hasVoteDetail => rows.any((row) => row.hasVoteDetail);
}

class NbaSeasonAwardVotingRow {
  const NbaSeasonAwardVotingRow({
    required this.award,
    required this.playerId,
    required this.playerName,
    required this.winner,
    required this.rank,
    required this.rankText,
    required this.votePoints,
    required this.firstPlaceVotes,
    required this.totalVotes,
    required this.voteShare,
    required this.source,
  });

  final String award;
  final String playerId;
  final String playerName;
  final bool winner;
  final int? rank;
  final String rankText;
  final double? votePoints;
  final int? firstPlaceVotes;
  final double? totalVotes;
  final double? voteShare;
  final String source;

  bool get hasVoteDetail =>
      votePoints != null ||
      firstPlaceVotes != null ||
      totalVotes != null ||
      voteShare != null;

  String get rankLabel {
    if (rank != null) return '#$rank';
    return rankText.isEmpty ? '—' : rankText;
  }
}

List<Map<String, dynamic>> _awardMaps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

Map<String, dynamic> _awardMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : const {};

String _awardFirst(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

String _awardSource(Map<String, dynamic> row) {
  final direct = _awardFirst(
    row,
    const ['source_key', 'source', 'source_table'],
  );
  if (direct.isNotEmpty) return direct;
  return _awardFirst(
    _awardMap(row['provenance']),
    const ['source_key', 'source', 'source_table'],
  );
}

bool _awardBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'true', '1', 'yes', 'y', 'winner'}
      .contains(value?.toString().trim().toLowerCase());
}

int? _awardInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

double? _awardDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}
