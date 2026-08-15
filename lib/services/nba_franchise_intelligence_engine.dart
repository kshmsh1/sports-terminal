class NbaFranchiseTeamIdentity {
  const NbaFranchiseTeamIdentity({
    required this.teamKey,
    required this.teamName,
    required this.abbreviation,
    required this.leagueId,
    required this.activeFrom,
    required this.activeTo,
    required this.nbaTeamId,
    required this.sourceCount,
  });

  final String teamKey;
  final String teamName;
  final String abbreviation;
  final String leagueId;
  final String activeFrom;
  final String activeTo;
  final String nbaTeamId;
  final int? sourceCount;

  String get eraLabel {
    if (activeFrom.isEmpty && activeTo.isEmpty) return 'ERA NOT EXPOSED';
    if (activeFrom.isEmpty) return 'through $activeTo';
    if (activeTo.isEmpty) return '$activeFrom onward';
    if (activeFrom == activeTo) return activeFrom;
    return '$activeFrom → $activeTo';
  }
}

class NbaFranchiseSeasonObservation {
  const NbaFranchiseSeasonObservation({
    required this.seasonId,
    required this.seasonType,
    required this.teamKey,
    required this.teamName,
    required this.abbreviation,
    required this.leagueId,
    required this.wins,
    required this.losses,
    required this.winPct,
    required this.source,
  });

  final String seasonId;
  final String seasonType;
  final String teamKey;
  final String teamName;
  final String abbreviation;
  final String leagueId;
  final num? wins;
  final num? losses;
  final double? winPct;
  final String source;

  int get decisions => (wins?.toInt() ?? 0) + (losses?.toInt() ?? 0);
}

class NbaFranchiseIntelligenceSnapshot {
  const NbaFranchiseIntelligenceSnapshot({
    required this.franchiseKey,
    required this.franchiseName,
    required this.currentAbbreviation,
    required this.sourceCount,
    required this.teamIdentities,
    required this.seasons,
    required this.firstSeason,
    required this.lastSeason,
    required this.declaredSeasonCount,
    required this.declaredIdentityCount,
  });

  final String franchiseKey;
  final String franchiseName;
  final String currentAbbreviation;
  final int? sourceCount;
  final List<NbaFranchiseTeamIdentity> teamIdentities;
  final List<NbaFranchiseSeasonObservation> seasons;
  final String firstSeason;
  final String lastSeason;
  final int? declaredSeasonCount;
  final int? declaredIdentityCount;

  bool get available => franchiseKey.isNotEmpty && franchiseName.isNotEmpty;
  bool get hasSeasonHistory => seasons.isNotEmpty;
  bool get hasLineage => teamIdentities.isNotEmpty;

  String get seasonRangeLabel {
    if (firstSeason.isEmpty && lastSeason.isEmpty) return 'SEASON RANGE NOT EXPOSED';
    if (firstSeason.isEmpty) return lastSeason;
    if (lastSeason.isEmpty || firstSeason == lastSeason) return firstSeason;
    return '$firstSeason → $lastSeason';
  }
}

/// Pure projection over the canonical historical Franchise dossier.
///
/// This engine intentionally does not infer relocations, ownership changes,
/// championships, retired numbers, awards, or draft outcomes. It exposes only
/// the Franchise profile, canonical team identities, and source-backed season
/// observations already present in the dossier payload.
class NbaFranchiseIntelligenceEngine {
  const NbaFranchiseIntelligenceEngine();

  NbaFranchiseIntelligenceSnapshot build(
    Map<String, dynamic> payload, {
    required String franchiseKey,
  }) {
    final profile = _map(payload['profile']);
    final summary = _map(payload['summary']);
    final normalizedKey = _text(profile, const ['franchise_key', 'franchiseKey'])
        .ifEmpty(franchiseKey.trim());
    final name = _text(profile, const ['canonical_name', 'name', 'franchise_name']);
    final identities = <NbaFranchiseTeamIdentity>[];
    for (final raw in _list(payload['team_identities'])) {
      final row = _map(raw);
      final teamKey = _text(row, const ['team_key', 'teamKey']);
      final teamName = _text(row, const ['canonical_name', 'team_name', 'name']);
      if (teamKey.isEmpty && teamName.isEmpty) continue;
      identities.add(
        NbaFranchiseTeamIdentity(
          teamKey: teamKey,
          teamName: teamName,
          abbreviation: _text(row, const ['abbreviation', 'team_abbreviation']),
          leagueId: _text(row, const ['league_id', 'league']).toUpperCase(),
          activeFrom: _text(row, const ['active_from', 'activeFrom']),
          activeTo: _text(row, const ['active_to', 'activeTo']),
          nbaTeamId: _text(row, const ['nba_team_id', 'nbaTeamId']),
          sourceCount: _integer(row, const ['source_count', 'sourceCount']),
        ),
      );
    }
    identities.sort((left, right) {
      final byStart = left.activeFrom.compareTo(right.activeFrom);
      if (byStart != 0) return byStart;
      return left.teamName.compareTo(right.teamName);
    });

    final seasons = <NbaFranchiseSeasonObservation>[];
    for (final raw in _list(payload['seasons'])) {
      final row = _map(raw);
      final seasonId = _text(row, const ['season_id', 'seasonId']);
      final teamKey = _text(row, const ['team_key', 'teamKey']);
      if (seasonId.isEmpty || teamKey.isEmpty) continue;
      final wins = _number(row, const ['wins', 'w']);
      final losses = _number(row, const ['losses', 'l']);
      final explicitWinPct = _number(row, const ['win_pct', 'winPct']);
      final decisions = (wins?.toDouble() ?? 0) + (losses?.toDouble() ?? 0);
      final computed = decisions > 0 ? (wins?.toDouble() ?? 0) / decisions : null;
      final provenance = _map(row['provenance']);
      seasons.add(
        NbaFranchiseSeasonObservation(
          seasonId: seasonId,
          seasonType: _text(row, const ['season_type', 'seasonType']),
          teamKey: teamKey,
          teamName: _text(row, const ['canonical_team_name', 'team_name', 'canonical_name']),
          abbreviation: _text(row, const ['abbreviation', 'team_abbreviation']),
          leagueId: _text(row, const ['league_id', 'league']).toUpperCase(),
          wins: wins,
          losses: losses,
          winPct: explicitWinPct?.toDouble() ?? computed,
          source: _text(provenance, const ['source_key', 'source', 'dataset']),
        ),
      );
    }
    seasons.sort((left, right) {
      final bySeason = left.seasonId.compareTo(right.seasonId);
      if (bySeason != 0) return bySeason;
      final byType = left.seasonType.compareTo(right.seasonType);
      if (byType != 0) return byType;
      return left.teamKey.compareTo(right.teamKey);
    });

    return NbaFranchiseIntelligenceSnapshot(
      franchiseKey: normalizedKey,
      franchiseName: name,
      currentAbbreviation: _text(
        profile,
        const ['current_abbreviation', 'abbreviation', 'currentAbbreviation'],
      ),
      sourceCount: _integer(profile, const ['source_count', 'sourceCount']),
      teamIdentities: List.unmodifiable(identities),
      seasons: List.unmodifiable(seasons),
      firstSeason: _text(summary, const ['first_season', 'firstSeason']),
      lastSeason: _text(summary, const ['last_season', 'lastSeason']),
      declaredSeasonCount: _integer(summary, const ['seasons', 'season_count']),
      declaredIdentityCount: _integer(
        summary,
        const ['team_identities', 'teamIdentityCount'],
      ),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value.cast<Object?>() : const [];

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

int? _integer(Map<String, dynamic> row, List<String> keys) =>
    _number(row, keys)?.toInt();

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
