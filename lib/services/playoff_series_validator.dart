import '../models/playoff_series_record.dart';
import '../models/season.dart';
import '../models/team.dart';

class PlayoffSeriesValidationIssue {
  const PlayoffSeriesValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class PlayoffSeriesValidationSummary {
  const PlayoffSeriesValidationSummary({required this.issues});

  final List<PlayoffSeriesValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class PlayoffSeriesValidator {
  const PlayoffSeriesValidator();

  PlayoffSeriesValidationSummary validate({required List<PlayoffSeriesRecord> series, required List<Team> teams, required List<Season> seasons}) {
    final issues = <PlayoffSeriesValidationIssue>[];
    final teamIds = teams.map((item) => item.id).toSet();
    final seasonIds = seasons.map((item) => item.id).toSet();
    final rowIds = <String>{};
    final naturalKeys = <String>{};

    for (final row in series) {
      if (row.id.trim().isEmpty) issues.add(_blocker('missing-row-id', 'Playoff series row is missing id.', row.id));
      if (!rowIds.add(row.id)) issues.add(_blocker('duplicate-row-id', 'Duplicate playoff series row id: ${row.id}.', row.id));
      if (row.seasonId.trim().isEmpty) issues.add(_blocker('missing-season-id', 'Playoff series row is missing seasonId.', row.id));
      if (!seasonIds.contains(row.seasonId)) issues.add(_blocker('season-join-missing', 'Playoff series row references missing seasonId: ${row.seasonId}.', row.id));
      if (row.winningTeamId != null && row.winningTeamId!.trim().isNotEmpty && !teamIds.contains(row.winningTeamId)) issues.add(_blocker('winning-team-join-missing', 'Series references missing winningTeamId: ${row.winningTeamId}.', row.id));
      if (row.losingTeamId != null && row.losingTeamId!.trim().isNotEmpty && !teamIds.contains(row.losingTeamId)) issues.add(_blocker('losing-team-join-missing', 'Series references missing losingTeamId: ${row.losingTeamId}.', row.id));
      if (row.winningTeamId != null && row.losingTeamId != null && row.winningTeamId == row.losingTeamId) issues.add(_blocker('same-team-series', 'Winning and losing teams cannot be the same.', row.id));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Playoff series row is missing sourceId.', row.id));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Playoff series row is missing asOf metadata.', row.id));

      final naturalKey = '${row.seasonId}|${row.round ?? 'unknown'}|${row.winningTeamId ?? 'winner'}|${row.losingTeamId ?? 'loser'}';
      if (!naturalKeys.add(naturalKey)) issues.add(_blocker('duplicate-natural-key', 'Duplicate playoff series natural key: $naturalKey.', row.id));

      _checkNonNegative(issues, row.id, 'gamesPlayed', row.gamesPlayed?.toDouble());
      _checkNonNegative(issues, row.id, 'winnerWins', row.winnerWins?.toDouble());
      _checkNonNegative(issues, row.id, 'loserWins', row.loserWins?.toDouble());
      if (row.gamesPlayed != null && (row.gamesPlayed! < 1 || row.gamesPlayed! > 7)) issues.add(_warning('games-played-range', 'Games played is outside expected best-of-seven range.', row.id));
      if (row.winnerWins != null && row.loserWins != null && row.winnerWins! <= row.loserWins!) issues.add(_warning('series-score-order', 'Winner wins should exceed loser wins.', row.id));
      if (row.winningSeed != null && (row.winningSeed! < 1 || row.winningSeed! > 16)) issues.add(_warning('winning-seed-range', 'Winning seed is outside expected playoff range.', row.id));
      if (row.losingSeed != null && (row.losingSeed! < 1 || row.losingSeed! > 16)) issues.add(_warning('losing-seed-range', 'Losing seed is outside expected playoff range.', row.id));
    }

    return PlayoffSeriesValidationSummary(issues: issues);
  }

  void _checkNonNegative(List<PlayoffSeriesValidationIssue> issues, String rowId, String field, double? value) {
    if (value != null && value < 0) issues.add(_blocker('negative-$field', '$field cannot be negative.', rowId));
  }

  PlayoffSeriesValidationIssue _blocker(String code, String message, String? rowId) => PlayoffSeriesValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  PlayoffSeriesValidationIssue _warning(String code, String message, String? rowId) => PlayoffSeriesValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
