class NbaPlayerCareerSeason {
  const NbaPlayerCareerSeason({
    required this.seasonId,
    required this.seasonType,
    required this.leagueId,
    required this.teamKey,
    required this.teamName,
    required this.teamAbbreviation,
    required this.franchiseKey,
    required this.franchiseName,
    required this.games,
    required this.gamesStarted,
    required this.minutes,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.turnovers,
    required this.trueShootingPct,
    required this.playerEfficiencyRating,
    required this.winShares,
    required this.boxPlusMinus,
    required this.valueOverReplacement,
    required this.syntheticAggregate,
    required this.source,
  });

  final String seasonId;
  final String seasonType;
  final String leagueId;
  final String teamKey;
  final String teamName;
  final String teamAbbreviation;
  final String franchiseKey;
  final String franchiseName;
  final double? games;
  final double? gamesStarted;
  final double? minutes;
  final double? points;
  final double? rebounds;
  final double? assists;
  final double? steals;
  final double? blocks;
  final double? turnovers;
  final double? trueShootingPct;
  final double? playerEfficiencyRating;
  final double? winShares;
  final double? boxPlusMinus;
  final double? valueOverReplacement;
  final bool syntheticAggregate;
  final String source;

  double? perGame(double? total) {
    if (total == null || games == null || games! <= 0) return null;
    return total / games!;
  }

  double? get pointsPerGame => perGame(points);
  double? get reboundsPerGame => perGame(rebounds);
  double? get assistsPerGame => perGame(assists);
  double? get stealsPerGame => perGame(steals);
  double? get blocksPerGame => perGame(blocks);
  double? get turnoversPerGame => perGame(turnovers);

  String get teamLabel {
    if (teamName.isNotEmpty) return teamName;
    if (teamAbbreviation.isNotEmpty) return teamAbbreviation;
    if (teamKey.isNotEmpty) return teamKey;
    return syntheticAggregate ? 'MULTI-TEAM AGGREGATE' : 'TEAM NOT EXPOSED';
  }
}

class NbaPlayerCareerTenure {
  const NbaPlayerCareerTenure({
    required this.teamKey,
    required this.teamName,
    required this.franchiseKey,
    required this.franchiseName,
    required this.firstSeason,
    required this.lastSeason,
    required this.seasons,
    required this.games,
    required this.points,
  });

  final String teamKey;
  final String teamName;
  final String franchiseKey;
  final String franchiseName;
  final String firstSeason;
  final String lastSeason;
  final int seasons;
  final double? games;
  final double? points;

  String get seasonRangeLabel => firstSeason == lastSeason
      ? firstSeason
      : '$firstSeason → $lastSeason';
}

class NbaPlayerCareerSnapshot {
  const NbaPlayerCareerSnapshot({
    required this.playerKey,
    required this.playerName,
    required this.primaryPosition,
    required this.activeFrom,
    required this.activeTo,
    required this.nbaId,
    required this.brefId,
    required this.identityConfidence,
    required this.sourceCount,
    required this.seasons,
    required this.tenures,
    required this.missingTeamDossierKeys,
    required this.multiTeamAggregateSeasons,
    required this.declaredFirstSeason,
    required this.declaredLastSeason,
    required this.declaredSeasonRows,
    required this.materialConflictCount,
  });

  final String playerKey;
  final String playerName;
  final String primaryPosition;
  final String activeFrom;
  final String activeTo;
  final String nbaId;
  final String brefId;
  final double? identityConfidence;
  final int? sourceCount;
  final List<NbaPlayerCareerSeason> seasons;
  final List<NbaPlayerCareerTenure> tenures;
  final List<String> missingTeamDossierKeys;
  final List<String> multiTeamAggregateSeasons;
  final String declaredFirstSeason;
  final String declaredLastSeason;
  final int? declaredSeasonRows;
  final int materialConflictCount;

  bool get available => playerKey.isNotEmpty && playerName.isNotEmpty;
  bool get hasCareerRows => seasons.isNotEmpty;
  bool get completeTeamFranchiseCoverage =>
      missingTeamDossierKeys.isEmpty && multiTeamAggregateSeasons.isEmpty;

  String get careerRangeLabel {
    final first = declaredFirstSeason.isNotEmpty
        ? declaredFirstSeason
        : (seasons.isEmpty ? '' : seasons.first.seasonId);
    final last = declaredLastSeason.isNotEmpty
        ? declaredLastSeason
        : (seasons.isEmpty ? '' : seasons.last.seasonId);
    if (first.isEmpty && last.isEmpty) return 'CAREER RANGE NOT EXPOSED';
    if (first.isEmpty) return last;
    if (last.isEmpty || first == last) return first;
    return '$first → $last';
  }

  double? get careerGames => _sumObserved(seasons.map((row) => row.games));
  double? get careerPoints => _sumObserved(seasons.map((row) => row.points));
  double? get careerRebounds => _sumObserved(seasons.map((row) => row.rebounds));
  double? get careerAssists => _sumObserved(seasons.map((row) => row.assists));

  String get tenureCoverageLabel {
    if (completeTeamFranchiseCoverage) return 'EXPLICIT TEAM / FRANCHISE COVERAGE';
    final gaps = <String>[];
    if (missingTeamDossierKeys.isNotEmpty) {
      gaps.add('${missingTeamDossierKeys.length} TEAM DOSSIER GAP(S)');
    }
    if (multiTeamAggregateSeasons.isNotEmpty) {
      gaps.add('${multiTeamAggregateSeasons.length} MULTI-TEAM AGGREGATE SEASON(S)');
    }
    return gaps.join(' · ');
  }
}

/// Source-bounded projection over one canonical historical Player dossier.
///
/// The engine never reconstructs traded-team stints from totals, guesses a
/// franchise from an abbreviation, or treats a multi-team aggregate as a
/// specific Team. Franchise identity is attached only when the caller supplies
/// a canonical Team dossier exposing `profile.franchise_key`.
class NbaPlayerCareerEngine {
  const NbaPlayerCareerEngine();

  NbaPlayerCareerSnapshot build(
    Map<String, dynamic> payload, {
    required String playerKey,
    Map<String, Map<String, dynamic>> teamDossiers = const {},
  }) {
    final profile = _careerMap(payload['profile']);
    final summary = _careerMap(payload['summary']);
    final normalizedKey = _careerText(
      profile,
      const ['player_key', 'playerKey'],
    ).ifEmpty(playerKey.trim());

    final missingTeamDossiers = <String>{};
    final aggregateSeasons = <String>{};
    final seasons = <NbaPlayerCareerSeason>[];
    for (final raw in _careerList(payload['seasons'])) {
      final row = _careerMap(raw);
      final seasonId = _careerText(row, const ['season_id', 'seasonId']);
      if (seasonId.isEmpty) continue;
      final teamKey = _careerText(row, const ['team_key', 'teamKey']);
      final abbreviation = _careerText(
        row,
        const ['team_abbreviation', 'abbreviation'],
      );
      final syntheticAggregate = _careerBool(
            row,
            const ['synthetic_aggregate', 'syntheticAggregate'],
          ) ||
          teamKey.isEmpty ||
          abbreviation.toUpperCase() == 'MULTI' ||
          abbreviation.toUpperCase() == 'TOT';
      if (syntheticAggregate) aggregateSeasons.add(seasonId);

      var teamName = _careerText(
        row,
        const ['team_name', 'canonical_team_name'],
      );
      var franchiseKey = '';
      var franchiseName = '';
      if (teamKey.isNotEmpty) {
        final teamPayload = teamDossiers[teamKey];
        if (teamPayload == null) {
          missingTeamDossiers.add(teamKey);
        } else {
          final teamProfile = _careerMap(teamPayload['profile']);
          teamName = teamName.ifEmpty(
            _careerText(teamProfile, const ['canonical_name', 'team_name']),
          );
          franchiseKey = _careerText(
            teamProfile,
            const ['franchise_key', 'franchiseKey'],
          );
          franchiseName = _careerText(
            teamProfile,
            const ['franchise_name', 'franchiseName'],
          );
        }
      }
      final provenance = _careerMap(row['provenance']);
      seasons.add(
        NbaPlayerCareerSeason(
          seasonId: seasonId,
          seasonType: _careerText(row, const ['season_type', 'seasonType']),
          leagueId: _careerText(row, const ['league_id', 'league']).toUpperCase(),
          teamKey: teamKey,
          teamName: teamName,
          teamAbbreviation: abbreviation,
          franchiseKey: franchiseKey,
          franchiseName: franchiseName,
          games: _careerNumber(row, const ['games', 'gp']),
          gamesStarted: _careerNumber(row, const ['games_started', 'gs']),
          minutes: _careerNumber(row, const ['minutes', 'min']),
          points: _careerNumber(row, const ['pts', 'points']),
          rebounds: _careerNumber(row, const ['reb', 'rebounds']),
          assists: _careerNumber(row, const ['ast', 'assists']),
          steals: _careerNumber(row, const ['stl', 'steals']),
          blocks: _careerNumber(row, const ['blk', 'blocks']),
          turnovers: _careerNumber(row, const ['tov', 'turnovers']),
          trueShootingPct: _careerNumber(row, const ['ts_pct', 'tsPct']),
          playerEfficiencyRating: _careerNumber(row, const ['per']),
          winShares: _careerNumber(row, const ['ws', 'win_shares']),
          boxPlusMinus: _careerNumber(row, const ['bpm']),
          valueOverReplacement: _careerNumber(row, const ['vorp']),
          syntheticAggregate: syntheticAggregate,
          source: _careerText(
            row,
            const ['primary_source', 'source'],
          ).ifEmpty(
            _careerText(provenance, const ['source_key', 'source', 'dataset']),
          ),
        ),
      );
    }
    seasons.sort((left, right) {
      final bySeason = left.seasonId.compareTo(right.seasonId);
      if (bySeason != 0) return bySeason;
      return left.seasonType.compareTo(right.seasonType);
    });

    final tenureGroups = <String, List<NbaPlayerCareerSeason>>{};
    for (final season in seasons) {
      if (season.teamKey.isEmpty || season.syntheticAggregate) continue;
      tenureGroups.putIfAbsent(season.teamKey, () => []).add(season);
    }
    final tenures = <NbaPlayerCareerTenure>[];
    for (final entry in tenureGroups.entries) {
      final rows = entry.value..sort((a, b) => a.seasonId.compareTo(b.seasonId));
      final uniqueSeasons = rows.map((row) => row.seasonId).toSet();
      tenures.add(
        NbaPlayerCareerTenure(
          teamKey: entry.key,
          teamName: rows.map((row) => row.teamName).firstWhere(
                (value) => value.isNotEmpty,
                orElse: () => entry.key,
              ),
          franchiseKey: rows.map((row) => row.franchiseKey).firstWhere(
                (value) => value.isNotEmpty,
                orElse: () => '',
              ),
          franchiseName: rows.map((row) => row.franchiseName).firstWhere(
                (value) => value.isNotEmpty,
                orElse: () => '',
              ),
          firstSeason: rows.first.seasonId,
          lastSeason: rows.last.seasonId,
          seasons: uniqueSeasons.length,
          games: _sumObserved(rows.map((row) => row.games)),
          points: _sumObserved(rows.map((row) => row.points)),
        ),
      );
    }
    tenures.sort((left, right) {
      final byStart = left.firstSeason.compareTo(right.firstSeason);
      if (byStart != 0) return byStart;
      return left.teamName.compareTo(right.teamName);
    });

    return NbaPlayerCareerSnapshot(
      playerKey: normalizedKey,
      playerName: _careerText(
        profile,
        const ['canonical_name', 'player_name', 'name'],
      ),
      primaryPosition: _careerText(
        profile,
        const ['primary_position', 'position'],
      ),
      activeFrom: _careerText(profile, const ['active_from', 'activeFrom']),
      activeTo: _careerText(profile, const ['active_to', 'activeTo']),
      nbaId: _careerText(profile, const ['nba_id', 'nbaId']),
      brefId: _careerText(profile, const ['bref_id', 'brefId']),
      identityConfidence: _careerNumber(
        profile,
        const ['identity_confidence', 'identityConfidence'],
      ),
      sourceCount: _careerInteger(profile, const ['source_count', 'sourceCount']),
      seasons: List.unmodifiable(seasons),
      tenures: List.unmodifiable(tenures),
      missingTeamDossierKeys: List.unmodifiable(
        missingTeamDossiers.toList()..sort(),
      ),
      multiTeamAggregateSeasons: List.unmodifiable(
        aggregateSeasons.toList()..sort(),
      ),
      declaredFirstSeason: _careerText(
        summary,
        const ['first_season', 'firstSeason'],
      ),
      declaredLastSeason: _careerText(
        summary,
        const ['last_season', 'lastSeason'],
      ),
      declaredSeasonRows: _careerInteger(
        summary,
        const ['season_rows', 'seasonRows'],
      ),
      materialConflictCount: _careerInteger(
            summary,
            const ['material_conflicts', 'materialConflicts'],
          ) ??
          _careerList(payload['conflicts']).length,
    );
  }
}

Map<String, dynamic> _careerMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Object?> _careerList(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

String _careerText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

double? _careerNumber(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

int? _careerInteger(Map<String, dynamic> row, List<String> keys) =>
    _careerNumber(row, keys)?.toInt();

bool _careerBool(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
  }
  return false;
}

double? _sumObserved(Iterable<double?> values) {
  var observed = false;
  var total = 0.0;
  for (final value in values) {
    if (value == null) continue;
    observed = true;
    total += value;
  }
  return observed ? total : null;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
