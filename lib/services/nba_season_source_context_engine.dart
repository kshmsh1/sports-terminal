/// Normalizes the canonical historical Season command payload into a compact
/// source-backed context ledger for the permanent Season page.
///
/// Awards, All-Star, draft, coverage, and transaction rows are exposed only
/// when the backend actually returns those rows. The current historical Season
/// contract does not provide transactions, so `transactionCoverageAvailable`
/// remains false unless a compatible transaction collection is present.
class NbaSeasonSourceContextEngine {
  const NbaSeasonSourceContextEngine();

  NbaSeasonSourceContext build(
    Map<String, dynamic> payload, {
    required String seasonId,
    String league = 'NBA',
  }) {
    final awards = _maps(payload['awards'])
        .map((row) => NbaSeasonAwardContext(
              award: _first(row, const ['award', 'award_name', 'name']),
              playerId: _first(row, const ['player_key', 'player_id']),
              playerName: _first(row, const ['player_name', 'canonical_name', 'recipient']),
              winner: _bool(row['winner']),
              rankText: _first(row, const ['rank_text', 'rank', 'place']),
              source: _source(row),
            ))
        .where((row) => row.award.isNotEmpty || row.playerName.isNotEmpty)
        .toList(growable: false);
    final allStar = _maps(payload['all_star'])
        .map((row) => NbaSeasonAllStarContext(
              playerId: _first(row, const ['player_key', 'player_id']),
              playerName: _first(row, const ['player_name', 'canonical_name', 'name']),
              teamId: _first(row, const ['team_key', 'team_id']),
              teamLabel: _first(row, const ['team_name', 'team_abbreviation', 'team']),
              starter: _bool(row['starter']),
              source: _source(row),
            ))
        .where((row) => row.playerName.isNotEmpty || row.playerId.isNotEmpty)
        .toList(growable: false);
    final draft = _maps(payload['draft'])
        .map((row) => NbaSeasonDraftContext(
              draftYear: _int(row['draft_year']),
              pickNumber: _int(row['pick_number']),
              roundText: _first(row, const ['round_text', 'round']),
              playerId: _first(row, const ['player_key', 'player_id']),
              playerName: _first(row, const ['player_name', 'canonical_name', 'name']),
              teamId: _first(row, const ['team_key', 'team_id']),
              teamLabel: _first(row, const ['team_name', 'team_abbreviation', 'team']),
              source: _source(row),
            ))
        .where((row) => row.playerName.isNotEmpty || row.playerId.isNotEmpty)
        .toList(growable: false);
    final coverage = _maps(payload['coverage'])
        .map((row) => NbaSeasonCoverageContext(
              domain: _first(row, const ['domain', 'dataset', 'name']),
              status: _first(row, const ['status', 'coverage_status', 'state']),
              rows: _int(row['rows'] ?? row['row_count'] ?? row['count']),
              source: _source(row),
            ))
        .where((row) => row.domain.isNotEmpty)
        .toList(growable: false);

    final rawTransactions = <Map<String, dynamic>>[
      ..._maps(payload['transactions']),
      ..._maps(payload['transaction_rows']),
    ];
    final transactions = rawTransactions
        .map((row) => NbaSeasonTransactionContext(
              date: _first(row, const ['transaction_date', 'date', 'effective_date']),
              type: _first(row, const ['transaction_type', 'type', 'category']),
              description: _first(row, const ['description', 'summary', 'transaction']),
              teamId: _first(row, const ['team_key', 'team_id']),
              playerId: _first(row, const ['player_key', 'player_id']),
              source: _source(row),
            ))
        .where((row) =>
            row.date.isNotEmpty || row.description.isNotEmpty || row.type.isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));

    final summary = _map(payload['summary']);
    return NbaSeasonSourceContext(
      seasonId: seasonId,
      league: (payload['league']?.toString().trim().isNotEmpty == true
              ? payload['league'].toString()
              : league)
          .toUpperCase(),
      seasonType: payload['season_type']?.toString().trim() ?? '',
      awards: List.unmodifiable(awards),
      allStar: List.unmodifiable(allStar),
      draft: List.unmodifiable(draft),
      coverage: List.unmodifiable(coverage),
      transactions: List.unmodifiable(transactions),
      transactionCoverageAvailable:
          payload.containsKey('transactions') || payload.containsKey('transaction_rows'),
      declaredTeamCount: _int(summary['teams']),
      declaredPlayerCount: _int(summary['players']),
      declaredGameCount: _int(summary['games']),
    );
  }
}

class NbaSeasonSourceContext {
  const NbaSeasonSourceContext({
    required this.seasonId,
    required this.league,
    required this.seasonType,
    required this.awards,
    required this.allStar,
    required this.draft,
    required this.coverage,
    required this.transactions,
    required this.transactionCoverageAvailable,
    required this.declaredTeamCount,
    required this.declaredPlayerCount,
    required this.declaredGameCount,
  });

  final String seasonId;
  final String league;
  final String seasonType;
  final List<NbaSeasonAwardContext> awards;
  final List<NbaSeasonAllStarContext> allStar;
  final List<NbaSeasonDraftContext> draft;
  final List<NbaSeasonCoverageContext> coverage;
  final List<NbaSeasonTransactionContext> transactions;
  final bool transactionCoverageAvailable;
  final int? declaredTeamCount;
  final int? declaredPlayerCount;
  final int? declaredGameCount;

  bool get hasAwards => awards.isNotEmpty;
  bool get hasAllStar => allStar.isNotEmpty;
  bool get hasDraft => draft.isNotEmpty;
  bool get hasCoverage => coverage.isNotEmpty;
  bool get hasTransactions => transactions.isNotEmpty;
}

class NbaSeasonAwardContext {
  const NbaSeasonAwardContext({
    required this.award,
    required this.playerId,
    required this.playerName,
    required this.winner,
    required this.rankText,
    required this.source,
  });
  final String award;
  final String playerId;
  final String playerName;
  final bool winner;
  final String rankText;
  final String source;
}

class NbaSeasonAllStarContext {
  const NbaSeasonAllStarContext({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamLabel,
    required this.starter,
    required this.source,
  });
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamLabel;
  final bool starter;
  final String source;
}

class NbaSeasonDraftContext {
  const NbaSeasonDraftContext({
    required this.draftYear,
    required this.pickNumber,
    required this.roundText,
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamLabel,
    required this.source,
  });
  final int? draftYear;
  final int? pickNumber;
  final String roundText;
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamLabel;
  final String source;
}

class NbaSeasonCoverageContext {
  const NbaSeasonCoverageContext({
    required this.domain,
    required this.status,
    required this.rows,
    required this.source,
  });
  final String domain;
  final String status;
  final int? rows;
  final String source;
}

class NbaSeasonTransactionContext {
  const NbaSeasonTransactionContext({
    required this.date,
    required this.type,
    required this.description,
    required this.teamId,
    required this.playerId,
    required this.source,
  });
  final String date;
  final String type;
  final String description;
  final String teamId;
  final String playerId;
  final String source;
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : const {};

String _first(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

String _source(Map<String, dynamic> row) {
  final provenance = _map(row['provenance']);
  return _first(row, const ['source_key', 'source', 'source_table']).isNotEmpty
      ? _first(row, const ['source_key', 'source', 'source_table'])
      : _first(provenance, const ['source_key', 'source', 'source_table']);
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'true', '1', 'yes', 'y', 'winner', 'starter'}
      .contains(value?.toString().trim().toLowerCase());
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}
