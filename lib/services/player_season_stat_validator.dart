import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/season.dart';
import '../models/team.dart';

class PlayerSeasonStatValidationIssue {
  const PlayerSeasonStatValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class PlayerSeasonStatValidationSummary {
  const PlayerSeasonStatValidationSummary({required this.issues});

  final List<PlayerSeasonStatValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class PlayerSeasonStatValidator {
  const PlayerSeasonStatValidator();

  PlayerSeasonStatValidationSummary validate({
    required List<PlayerSeasonStat> stats,
    required List<PlayerProfile> players,
    required List<Season> seasons,
    required List<Team> teams,
  }) {
    final issues = <PlayerSeasonStatValidationIssue>[];
    final playerIds = players.map((item) => item.id).toSet();
    final seasonIds = seasons.map((item) => item.id).toSet();
    final teamIds = teams.map((item) => item.id).toSet();
    final rowIds = <String>{};
    final naturalKeys = <String>{};

    for (final row in stats) {
      if (row.id.trim().isEmpty) issues.add(_blocker('missing-row-id', 'Player stat row is missing id.', row.id));
      if (!rowIds.add(row.id)) issues.add(_blocker('duplicate-row-id', 'Duplicate player stat row id: ${row.id}.', row.id));
      if (row.playerId.trim().isEmpty) issues.add(_blocker('missing-player-id', 'Player stat row is missing playerId.', row.id));
      if (!playerIds.contains(row.playerId)) issues.add(_blocker('player-join-missing', 'Player stat row references missing playerId: ${row.playerId}.', row.id));
      if (row.seasonId.trim().isEmpty) issues.add(_blocker('missing-season-id', 'Player stat row is missing seasonId.', row.id));
      if (!seasonIds.contains(row.seasonId)) issues.add(_blocker('season-join-missing', 'Player stat row references missing seasonId: ${row.seasonId}.', row.id));
      if (row.teamId != null && row.teamId!.trim().isNotEmpty && !teamIds.contains(row.teamId)) issues.add(_blocker('team-join-missing', 'Player stat row references missing teamId: ${row.teamId}.', row.id));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Player stat row is missing sourceId.', row.id));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Player stat row is missing asOf metadata.', row.id));

      final naturalKey = '${row.playerId}|${row.seasonId}|${row.teamId ?? 'all'}|${row.seasonType ?? 'unknown'}';
      if (!naturalKeys.add(naturalKey)) issues.add(_blocker('duplicate-natural-key', 'Duplicate player-season stat natural key: $naturalKey.', row.id));

      _checkNonNegative(issues, row.id, 'gamesPlayed', row.gamesPlayed?.toDouble());
      _checkNonNegative(issues, row.id, 'minutesPerGame', row.minutesPerGame);
      _checkNonNegative(issues, row.id, 'pointsPerGame', row.pointsPerGame);
      _checkNonNegative(issues, row.id, 'reboundsPerGame', row.reboundsPerGame);
      _checkNonNegative(issues, row.id, 'assistsPerGame', row.assistsPerGame);
      _checkPercent(issues, row.id, 'fieldGoalPercentage', row.fieldGoalPercentage);
      _checkPercent(issues, row.id, 'threePointPercentage', row.threePointPercentage);
      _checkPercent(issues, row.id, 'freeThrowPercentage', row.freeThrowPercentage);
      _checkPercent(issues, row.id, 'effectiveFieldGoalPercentage', row.effectiveFieldGoalPercentage);
      _checkPercent(issues, row.id, 'trueShootingPercentage', row.trueShootingPercentage);
    }

    return PlayerSeasonStatValidationSummary(issues: issues);
  }

  void _checkNonNegative(List<PlayerSeasonStatValidationIssue> issues, String rowId, String field, double? value) {
    if (value != null && value < 0) issues.add(_blocker('negative-$field', '$field cannot be negative.', rowId));
  }

  void _checkPercent(List<PlayerSeasonStatValidationIssue> issues, String rowId, String field, double? value) {
    if (value == null) return;
    if (value < 0 || value > 1.5) issues.add(_warning('percent-range-$field', '$field is outside expected decimal percentage range.', rowId));
  }

  PlayerSeasonStatValidationIssue _blocker(String code, String message, String? rowId) => PlayerSeasonStatValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  PlayerSeasonStatValidationIssue _warning(String code, String message, String? rowId) => PlayerSeasonStatValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
