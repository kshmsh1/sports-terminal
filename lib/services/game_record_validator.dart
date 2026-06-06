import '../models/game_record.dart';
import '../models/season.dart';
import '../models/team.dart';

class GameRecordValidationIssue {
  const GameRecordValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class GameRecordValidationSummary {
  const GameRecordValidationSummary({required this.issues});

  final List<GameRecordValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class GameRecordValidator {
  const GameRecordValidator();

  GameRecordValidationSummary validate({required List<GameRecord> games, required List<Team> teams, required List<Season> seasons}) {
    final issues = <GameRecordValidationIssue>[];
    final teamIds = teams.map((item) => item.id).toSet();
    final seasonIds = seasons.map((item) => item.id).toSet();
    final rowIds = <String>{};
    final naturalKeys = <String>{};

    for (final row in games) {
      if (row.id.trim().isEmpty) issues.add(_blocker('missing-row-id', 'Game row is missing id.', row.id));
      if (!rowIds.add(row.id)) issues.add(_blocker('duplicate-row-id', 'Duplicate game row id: ${row.id}.', row.id));
      if (row.seasonId.trim().isEmpty) issues.add(_blocker('missing-season-id', 'Game row is missing seasonId.', row.id));
      if (!seasonIds.contains(row.seasonId)) issues.add(_blocker('season-join-missing', 'Game row references missing seasonId: ${row.seasonId}.', row.id));
      if (row.homeTeamId != null && row.homeTeamId!.trim().isNotEmpty && !teamIds.contains(row.homeTeamId)) issues.add(_blocker('home-team-join-missing', 'Game row references missing homeTeamId: ${row.homeTeamId}.', row.id));
      if (row.awayTeamId != null && row.awayTeamId!.trim().isNotEmpty && !teamIds.contains(row.awayTeamId)) issues.add(_blocker('away-team-join-missing', 'Game row references missing awayTeamId: ${row.awayTeamId}.', row.id));
      if (row.homeTeamId != null && row.awayTeamId != null && row.homeTeamId == row.awayTeamId) issues.add(_blocker('same-team-game', 'Home and away teams cannot be the same.', row.id));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Game row is missing sourceId.', row.id));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Game row is missing asOf metadata.', row.id));

      final naturalKey = '${row.seasonId}|${row.gameDate ?? 'date'}|${row.homeTeamId ?? 'home'}|${row.awayTeamId ?? 'away'}';
      if (!naturalKeys.add(naturalKey)) issues.add(_blocker('duplicate-natural-key', 'Duplicate game natural key: $naturalKey.', row.id));

      _checkNonNegative(issues, row.id, 'homeScore', row.homeScore?.toDouble());
      _checkNonNegative(issues, row.id, 'awayScore', row.awayScore?.toDouble());
      if (row.homeScore != null && row.homeScore! > 200) issues.add(_warning('home-score-high', 'Home score is unusually high.', row.id));
      if (row.awayScore != null && row.awayScore! > 200) issues.add(_warning('away-score-high', 'Away score is unusually high.', row.id));
      if (row.gameDate == null || row.gameDate!.trim().isEmpty) issues.add(_warning('missing-game-date', 'Game date is missing.', row.id));
    }

    return GameRecordValidationSummary(issues: issues);
  }

  void _checkNonNegative(List<GameRecordValidationIssue> issues, String rowId, String field, double? value) {
    if (value != null && value < 0) issues.add(_blocker('negative-$field', '$field cannot be negative.', rowId));
  }

  GameRecordValidationIssue _blocker(String code, String message, String? rowId) => GameRecordValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  GameRecordValidationIssue _warning(String code, String message, String? rowId) => GameRecordValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
