class NbaPlayerCareerAward {
  const NbaPlayerCareerAward({
    required this.seasonId,
    required this.award,
    required this.result,
    required this.rank,
    required this.votes,
    required this.points,
    required this.source,
  });

  final String seasonId;
  final String award;
  final String result;
  final double? rank;
  final double? votes;
  final double? points;
  final String source;
}

class NbaPlayerCareerAllStarSelection {
  const NbaPlayerCareerAllStarSelection({
    required this.seasonId,
    required this.selection,
    required this.conference,
    required this.starter,
    required this.source,
  });

  final String seasonId;
  final String selection;
  final String conference;
  final bool? starter;
  final String source;
}

class NbaPlayerCareerDraftRecord {
  const NbaPlayerCareerDraftRecord({
    required this.draftYear,
    required this.round,
    required this.pick,
    required this.teamKey,
    required this.teamLabel,
    required this.source,
  });

  final int? draftYear;
  final int? round;
  final int? pick;
  final String teamKey;
  final String teamLabel;
  final String source;
}

class NbaPlayerCareerGameRecord {
  const NbaPlayerCareerGameRecord({
    required this.gameKey,
    required this.seasonId,
    required this.gameDate,
    required this.teamKey,
    required this.teamName,
    required this.opponentTeamKey,
    required this.opponentName,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.minutes,
    required this.homeTeamKey,
    required this.awayTeamKey,
    required this.homeScore,
    required this.awayScore,
    required this.source,
  });

  final String gameKey;
  final String seasonId;
  final String gameDate;
  final String teamKey;
  final String teamName;
  final String opponentTeamKey;
  final String opponentName;
  final double? points;
  final double? rebounds;
  final double? assists;
  final double? minutes;
  final String homeTeamKey;
  final String awayTeamKey;
  final double? homeScore;
  final double? awayScore;
  final String source;

  String get matchupLabel {
    final opponent = opponentName.isNotEmpty
        ? opponentName
        : (opponentTeamKey.isNotEmpty ? opponentTeamKey : 'OPPONENT NOT EXPOSED');
    final team = teamName.isNotEmpty
        ? teamName
        : (teamKey.isNotEmpty ? teamKey : 'TEAM NOT EXPOSED');
    return '$team vs $opponent';
  }
}

class NbaPlayerCareerContext {
  const NbaPlayerCareerContext({
    required this.awards,
    required this.allStarSelections,
    required this.draftRecords,
    required this.recentGames,
    required this.identityRows,
    required this.conflictRows,
    required this.fieldProvenanceRows,
  });

  final List<NbaPlayerCareerAward> awards;
  final List<NbaPlayerCareerAllStarSelection> allStarSelections;
  final List<NbaPlayerCareerDraftRecord> draftRecords;
  final List<NbaPlayerCareerGameRecord> recentGames;
  final int identityRows;
  final int conflictRows;
  final int fieldProvenanceRows;

  bool get hasAwards => awards.isNotEmpty;
  bool get hasAllStar => allStarSelections.isNotEmpty;
  bool get hasDraft => draftRecords.isNotEmpty;
  bool get hasGames => recentGames.isNotEmpty;

  String get sourceBoundaryLabel {
    final gaps = <String>[];
    if (!hasAwards) gaps.add('AWARDS NOT EXPOSED');
    if (!hasAllStar) gaps.add('ALL-STAR NOT EXPOSED');
    if (!hasDraft) gaps.add('DRAFT NOT EXPOSED');
    if (!hasGames) gaps.add('PLAYER GAME ROWS NOT EXPOSED');
    return gaps.isEmpty ? 'SOURCE-BACKED CAREER CONTEXT' : gaps.join(' · ');
  }
}

/// Projects only rows that are explicitly attached to the canonical Player
/// dossier. Award winners, All-Star starter status, draft position, and Game
/// identities are never inferred from surrounding season statistics.
class NbaPlayerCareerContextEngine {
  const NbaPlayerCareerContextEngine();

  NbaPlayerCareerContext build(Map<String, dynamic> payload) {
    final awards = <NbaPlayerCareerAward>[];
    for (final raw in _contextList(payload['awards'])) {
      final row = _contextMap(raw);
      final award = _contextText(
        row,
        const ['award', 'award_name', 'name', 'category'],
      );
      if (award.isEmpty) continue;
      final provenance = _contextMap(row['provenance']);
      awards.add(
        NbaPlayerCareerAward(
          seasonId: _contextText(row, const ['season_id', 'seasonId']),
          award: award,
          result: _contextText(
            row,
            const ['result', 'selection', 'winner_label', 'status'],
          ),
          rank: _contextNumber(row, const ['rank', 'place', 'finish']),
          votes: _contextNumber(
            row,
            const ['votes', 'first_place_votes', 'vote_total'],
          ),
          points: _contextNumber(
            row,
            const ['points', 'voting_points', 'share'],
          ),
          source: _contextText(
            row,
            const ['primary_source', 'source_key', 'source'],
          ).ifEmpty(
            _contextText(provenance, const ['source_key', 'source', 'dataset']),
          ),
        ),
      );
    }
    awards.sort((left, right) {
      final bySeason = left.seasonId.compareTo(right.seasonId);
      if (bySeason != 0) return bySeason;
      return left.award.compareTo(right.award);
    });

    final allStar = <NbaPlayerCareerAllStarSelection>[];
    for (final raw in _contextList(payload['all_star'])) {
      final row = _contextMap(raw);
      final seasonId = _contextText(row, const ['season_id', 'seasonId']);
      if (seasonId.isEmpty) continue;
      final provenance = _contextMap(row['provenance']);
      allStar.add(
        NbaPlayerCareerAllStarSelection(
          seasonId: seasonId,
          selection: _contextText(
            row,
            const ['selection', 'selection_type', 'roster_status', 'label'],
          ),
          conference: _contextText(row, const ['conference', 'team']),
          starter: _contextNullableBool(
            row,
            const ['starter', 'is_starter', 'started'],
          ),
          source: _contextText(
            row,
            const ['primary_source', 'source_key', 'source'],
          ).ifEmpty(
            _contextText(provenance, const ['source_key', 'source', 'dataset']),
          ),
        ),
      );
    }
    allStar.sort((left, right) => left.seasonId.compareTo(right.seasonId));

    final draft = <NbaPlayerCareerDraftRecord>[];
    for (final raw in _contextList(payload['draft'])) {
      final row = _contextMap(raw);
      final year = _contextInteger(row, const ['draft_year', 'year']);
      final pick = _contextInteger(
        row,
        const ['pick', 'pick_number', 'overall_pick', 'overall'],
      );
      final round = _contextInteger(row, const ['round', 'draft_round']);
      final teamKey = _contextText(row, const ['team_key', 'draft_team_key']);
      if (year == null && pick == null && round == null && teamKey.isEmpty) continue;
      final provenance = _contextMap(row['provenance']);
      draft.add(
        NbaPlayerCareerDraftRecord(
          draftYear: year,
          round: round,
          pick: pick,
          teamKey: teamKey,
          teamLabel: _contextText(
            row,
            const ['team_name', 'team_abbreviation', 'draft_team', 'team'],
          ),
          source: _contextText(
            row,
            const ['primary_source', 'source_key', 'source'],
          ).ifEmpty(
            _contextText(provenance, const ['source_key', 'source', 'dataset']),
          ),
        ),
      );
    }
    draft.sort((left, right) =>
        (left.draftYear ?? 9999).compareTo(right.draftYear ?? 9999));

    final games = <NbaPlayerCareerGameRecord>[];
    for (final raw in _contextList(payload['recent_games'])) {
      final row = _contextMap(raw);
      final gameKey = _contextText(row, const ['game_key', 'gameKey']);
      if (gameKey.isEmpty) continue;
      final provenance = _contextMap(row['provenance']);
      games.add(
        NbaPlayerCareerGameRecord(
          gameKey: gameKey,
          seasonId: _contextText(row, const ['season_id', 'seasonId']),
          gameDate: _contextText(row, const ['game_date', 'date']),
          teamKey: _contextText(row, const ['team_key', 'teamKey']),
          teamName: _contextText(row, const ['team_name', 'team']),
          opponentTeamKey: _contextText(
            row,
            const ['opponent_team_key', 'opponentTeamKey'],
          ),
          opponentName: _contextText(
            row,
            const ['opponent_name', 'opponent_team_name', 'opponent'],
          ),
          points: _contextNumber(row, const ['pts', 'points']),
          rebounds: _contextNumber(row, const ['reb', 'rebounds']),
          assists: _contextNumber(row, const ['ast', 'assists']),
          minutes: _contextNumber(row, const ['minutes', 'min']),
          homeTeamKey: _contextText(
            row,
            const ['home_team_key', 'homeTeamKey'],
          ),
          awayTeamKey: _contextText(
            row,
            const ['away_team_key', 'awayTeamKey'],
          ),
          homeScore: _contextNumber(row, const ['home_score', 'homeScore']),
          awayScore: _contextNumber(row, const ['away_score', 'awayScore']),
          source: _contextText(
            row,
            const ['primary_source', 'source_key', 'source'],
          ).ifEmpty(
            _contextText(provenance, const ['source_key', 'source', 'dataset']),
          ),
        ),
      );
    }
    games.sort((left, right) {
      final byDate = right.gameDate.compareTo(left.gameDate);
      if (byDate != 0) return byDate;
      return right.gameKey.compareTo(left.gameKey);
    });

    return NbaPlayerCareerContext(
      awards: List.unmodifiable(awards),
      allStarSelections: List.unmodifiable(allStar),
      draftRecords: List.unmodifiable(draft),
      recentGames: List.unmodifiable(games),
      identityRows: _contextList(payload['identities']).length,
      conflictRows: _contextList(payload['conflicts']).length,
      fieldProvenanceRows: _contextList(payload['field_provenance']).length,
    );
  }
}

Map<String, dynamic> _contextMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Object?> _contextList(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

String _contextText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

double? _contextNumber(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

int? _contextInteger(Map<String, dynamic> row, List<String> keys) =>
    _contextNumber(row, keys)?.toInt();

bool? _contextNullableBool(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
  }
  return null;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
