import '../models/season.dart';
import '../models/standings_record.dart';
import '../models/team.dart';

class StandingsRecordValidationIssue {
  const StandingsRecordValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class StandingsRecordValidationSummary {
  const StandingsRecordValidationSummary({required this.issues});

  final List<StandingsRecordValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class StandingsRecordValidator {
  const StandingsRecordValidator();

  StandingsRecordValidationSummary validate({required List<StandingsRecord> standings, required List<Team> teams, required List<Season> seasons}) {
    final issues = <StandingsRecordValidationIssue>[];
    final teamIds = teams.map((item) => item.id).toSet();
    final seasonIds = seasons.map((item) => item.id).toSet();
    final rowIds = <String>{};
    final naturalKeys = <String>{};

    for (final row in standings) {
      if (row.id.trim().isEmpty) issues.add(_blocker('missing-row-id', 'Standings row is missing id.', row.id));
      if (!rowIds.add(row.id)) issues.add(_blocker('duplicate-row-id', 'Duplicate standings row id: ${row.id}.', row.id));
      if (row.teamId.trim().isEmpty) issues.add(_blocker('missing-team-id', 'Standings row is missing teamId.', row.id));
      if (!teamIds.contains(row.teamId)) issues.add(_blocker('team-join-missing', 'Standings row references missing teamId: ${row.teamId}.', row.id));
      if (row.seasonId.trim().isEmpty) issues.add(_blocker('missing-season-id', 'Standings row is missing seasonId.', row.id));
      if (!seasonIds.contains(row.seasonId)) issues.add(_blocker('season-join-missing', 'Standings row references missing seasonId: ${row.seasonId}.', row.id));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Standings row is missing sourceId.', row.id));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Standings row is missing asOf metadata.', row.id));

      final naturalKey = '${row.teamId}|${row.seasonId}|${row.conference ?? 'league'}|${row.division ?? 'all'}';
      if (!naturalKeys.add(naturalKey)) issues.add(_blocker('duplicate-natural-key', 'Duplicate standings natural key: $naturalKey.', row.id));

      _checkNonNegative(issues, row.id, 'wins', row.wins?.toDouble());
      _checkNonNegative(issues, row.id, 'losses', row.losses?.toDouble());
      _checkNonNegative(issues, row.id, 'gamesBack', row.gamesBack);
      if (row.seed != null && (row.seed! < 1 || row.seed! > 30)) issues.add(_warning('seed-range', 'Seed is outside expected league/team range.', row.id));
      if (row.winPercentage != null && (row.winPercentage! < 0 || row.winPercentage! > 1.5)) issues.add(_warning('win-percentage-range', 'Win percentage is outside expected decimal range.', row.id));
      if (row.wins != null && row.losses != null && row.wins! + row.losses! > 90) issues.add(_warning('record-total-high', 'Wins plus losses is unusually high for one NBA season standings row.', row.id));
    }

    return StandingsRecordValidationSummary(issues: issues);
  }

  void _checkNonNegative(List<StandingsRecordValidationIssue> issues, String rowId, String field, double? value) {
    if (value != null && value < 0) issues.add(_blocker('negative-$field', '$field cannot be negative.', rowId));
  }

  StandingsRecordValidationIssue _blocker(String code, String message, String? rowId) => StandingsRecordValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  StandingsRecordValidationIssue _warning(String code, String message, String? rowId) => StandingsRecordValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
