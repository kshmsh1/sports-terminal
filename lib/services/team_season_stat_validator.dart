import '../models/season.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';

class TeamSeasonStatValidationIssue {
  const TeamSeasonStatValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class TeamSeasonStatValidationSummary {
  const TeamSeasonStatValidationSummary({required this.issues});

  final List<TeamSeasonStatValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class TeamSeasonStatValidator {
  const TeamSeasonStatValidator();

  TeamSeasonStatValidationSummary validate({
    required List<TeamSeasonStat> stats,
    required List<Team> teams,
    required List<Season> seasons,
  }) {
    final issues = <TeamSeasonStatValidationIssue>[];
    final teamIds = teams.map((item) => item.id).toSet();
    final seasonIds = seasons.map((item) => item.id).toSet();
    final rowIds = <String>{};
    final naturalKeys = <String>{};

    for (final row in stats) {
      if (row.id.trim().isEmpty) issues.add(_blocker('missing-row-id', 'Team stat row is missing id.', row.id));
      if (!rowIds.add(row.id)) issues.add(_blocker('duplicate-row-id', 'Duplicate team stat row id: ${row.id}.', row.id));
      if (row.teamId.trim().isEmpty) issues.add(_blocker('missing-team-id', 'Team stat row is missing teamId.', row.id));
      if (!teamIds.contains(row.teamId)) issues.add(_blocker('team-join-missing', 'Team stat row references missing teamId: ${row.teamId}.', row.id));
      if (row.seasonId.trim().isEmpty) issues.add(_blocker('missing-season-id', 'Team stat row is missing seasonId.', row.id));
      if (!seasonIds.contains(row.seasonId)) issues.add(_blocker('season-join-missing', 'Team stat row references missing seasonId: ${row.seasonId}.', row.id));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Team stat row is missing sourceId.', row.id));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Team stat row is missing asOf metadata.', row.id));

      final naturalKey = '${row.teamId}|${row.seasonId}|${row.seasonType ?? 'unknown'}';
      if (!naturalKeys.add(naturalKey)) issues.add(_blocker('duplicate-natural-key', 'Duplicate team-season stat natural key: $naturalKey.', row.id));

      _checkNonNegative(issues, row.id, 'wins', row.wins?.toDouble());
      _checkNonNegative(issues, row.id, 'losses', row.losses?.toDouble());
      _checkNonNegative(issues, row.id, 'pointsPerGame', row.pointsPerGame);
      _checkNonNegative(issues, row.id, 'opponentPointsPerGame', row.opponentPointsPerGame);
      _checkNonNegative(issues, row.id, 'pace', row.pace);
      _checkNonNegative(issues, row.id, 'reboundsPerGame', row.reboundsPerGame);
      _checkNonNegative(issues, row.id, 'assistsPerGame', row.assistsPerGame);
      _checkPercent(issues, row.id, 'winPercentage', row.winPercentage);
      _checkPercent(issues, row.id, 'fieldGoalPercentage', row.fieldGoalPercentage);
      _checkPercent(issues, row.id, 'threePointPercentage', row.threePointPercentage);
      _checkPercent(issues, row.id, 'freeThrowPercentage', row.freeThrowPercentage);
      _checkPercent(issues, row.id, 'effectiveFieldGoalPercentage', row.effectiveFieldGoalPercentage);
      _checkPercent(issues, row.id, 'trueShootingPercentage', row.trueShootingPercentage);

      if (row.wins != null && row.losses != null && row.wins! + row.losses! > 90) {
        issues.add(_warning('record-total-high', 'Wins plus losses is unusually high for one NBA season row.', row.id));
      }
    }

    return TeamSeasonStatValidationSummary(issues: issues);
  }

  void _checkNonNegative(List<TeamSeasonStatValidationIssue> issues, String rowId, String field, double? value) {
    if (value != null && value < 0) issues.add(_blocker('negative-$field', '$field cannot be negative.', rowId));
  }

  void _checkPercent(List<TeamSeasonStatValidationIssue> issues, String rowId, String field, double? value) {
    if (value == null) return;
    if (value < 0 || value > 1.5) issues.add(_warning('percent-range-$field', '$field is outside expected decimal percentage range.', rowId));
  }

  TeamSeasonStatValidationIssue _blocker(String code, String message, String? rowId) => TeamSeasonStatValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  TeamSeasonStatValidationIssue _warning(String code, String message, String? rowId) => TeamSeasonStatValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
