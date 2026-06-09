import '../models/player_profile.dart';
import '../models/roster_entry.dart';
import '../models/season.dart';
import '../models/team.dart';
import 'roster_measurement_formatter.dart';

class RosterEntryValidationIssue {
  const RosterEntryValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class RosterEntryValidationSummary {
  const RosterEntryValidationSummary({required this.issues});

  final List<RosterEntryValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class RosterEntryValidator {
  const RosterEntryValidator({this.measurements = const RosterMeasurementFormatter()});

  final RosterMeasurementFormatter measurements;

  RosterEntryValidationSummary validate({
    required List<RosterEntry> rosters,
    required List<PlayerProfile> players,
    required List<Team> teams,
    required List<Season> seasons,
    bool requireFinalRosterSnapshot = false,
  }) {
    final issues = <RosterEntryValidationIssue>[];
    final playerIds = players.map((item) => item.id).toSet();
    final teamIds = teams.map((item) => item.id).toSet();
    final seasonIds = seasons.map((item) => item.id).toSet();
    final naturalKeys = <String>{};
    final coveredTeams = <String>{};

    for (final row in rosters) {
      final rowId = '${row.playerId}|${row.teamId}|${row.seasonId}|${row.startDate ?? 'start'}|${row.endDate ?? 'end'}';
      coveredTeams.add(row.teamId);
      if (row.playerId.trim().isEmpty) issues.add(_blocker('missing-player-id', 'Roster row is missing playerId.', rowId));
      if (!playerIds.contains(row.playerId)) issues.add(_blocker('player-join-missing', 'Roster row references missing playerId: ${row.playerId}.', rowId));
      if (row.teamId.trim().isEmpty) issues.add(_blocker('missing-team-id', 'Roster row is missing teamId.', rowId));
      if (!teamIds.contains(row.teamId)) issues.add(_blocker('team-join-missing', 'Roster row references missing teamId: ${row.teamId}.', rowId));
      if (row.seasonId.trim().isEmpty) issues.add(_blocker('missing-season-id', 'Roster row is missing seasonId.', rowId));
      if (!seasonIds.contains(row.seasonId)) issues.add(_blocker('season-join-missing', 'Roster row references missing seasonId: ${row.seasonId}.', rowId));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Roster row is missing sourceId.', rowId));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Roster row is missing asOf metadata.', rowId));
      if (!naturalKeys.add(rowId)) issues.add(_blocker('duplicate-natural-key', 'Duplicate roster natural key: $rowId.', rowId));
      if (row.startDate != null && row.endDate != null && row.startDate!.compareTo(row.endDate!) > 0) issues.add(_warning('date-window-order', 'Roster startDate is after endDate.', rowId));
      if (row.rosterStatus == null || row.rosterStatus!.trim().isEmpty) issues.add(_warning('missing-roster-status', 'Roster status is blank.', rowId));

      if (requireFinalRosterSnapshot) {
        if (row.seasonId != '2025-26') issues.add(_blocker('not-final-2025-26-season', 'Final roster rows must use seasonId 2025-26.', rowId));
        if (row.rosterStatus != 'Final roster') issues.add(_blocker('not-final-roster-status', 'Final roster rows must use rosterStatus "Final roster".', rowId));
        if (row.snapshotLabel != '2025-26 final roster snapshot') issues.add(_blocker('missing-final-snapshot-label', 'Final roster row must include the 2025-26 final roster snapshot label.', rowId));
        if (row.age == null || row.age! < 15 || row.age! > 50) issues.add(_blocker('invalid-final-roster-age', 'Final roster row must include a plausible age.', rowId));
        if (measurements.heightInches(row.height) < 60) issues.add(_blocker('invalid-final-roster-height', 'Final roster row must include parseable feet/inches height.', rowId));
        if (row.weightPounds == null || row.weightPounds! < 130 || row.weightPounds! > 350) issues.add(_blocker('invalid-final-roster-weight', 'Final roster row must include plausible weight in pounds.', rowId));
        if (row.fromDisplay == null || row.fromDisplay!.trim().isEmpty) issues.add(_warning('missing-final-roster-from', 'Final roster row is missing From context.', rowId));
        if (row.jerseyNumber == null || row.jerseyNumber!.trim().isEmpty) issues.add(_warning('missing-final-roster-jersey', 'Final roster row is missing jersey number.', rowId));
      }
    }

    if (requireFinalRosterSnapshot && rosters.isNotEmpty) {
      final missingTeams = teamIds.difference(coveredTeams).toList()..sort();
      if (missingTeams.isNotEmpty) issues.add(_blocker('final-roster-team-coverage-incomplete', 'Final roster snapshot is missing teams: ${missingTeams.join(', ')}.', 'global'));
    }

    return RosterEntryValidationSummary(issues: issues);
  }

  RosterEntryValidationIssue _blocker(String code, String message, String? rowId) => RosterEntryValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  RosterEntryValidationIssue _warning(String code, String message, String? rowId) => RosterEntryValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
