import '../models/roster_directory_row.dart';
import 'roster_measurement_formatter.dart';

class RosterCompletenessIssue {
  const RosterCompletenessIssue({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.field,
    required this.message,
  });

  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final String field;
  final String message;
}

class TeamRosterCompleteness {
  const TeamRosterCompleteness({
    required this.teamId,
    required this.teamName,
    required this.rows,
    required this.identityCompleteRows,
    required this.fullyPopulatedRows,
    required this.issueCount,
    required this.knownPayrollUsd,
  });

  final String teamId;
  final String teamName;
  final int rows;
  final int identityCompleteRows;
  final int fullyPopulatedRows;
  final int issueCount;
  final int knownPayrollUsd;

  double get identityCompletionRate => rows == 0 ? 0 : identityCompleteRows / rows;
  double get fullCompletionRate => rows == 0 ? 0 : fullyPopulatedRows / rows;
}

class RosterCompletenessSummary {
  const RosterCompletenessSummary({
    required this.totalRows,
    required this.teamsCovered,
    required this.identityCompleteRows,
    required this.fullyPopulatedRows,
    required this.missingFrom,
    required this.missingJersey,
    required this.missingSalary,
    required this.missingPosition,
    required this.invalidHeight,
    required this.invalidWeight,
    required this.missingPlayerJoins,
    required this.missingTeamJoins,
    required this.knownPayrollUsd,
    required this.issues,
    required this.teams,
  });

  final int totalRows;
  final int teamsCovered;
  final int identityCompleteRows;
  final int fullyPopulatedRows;
  final int missingFrom;
  final int missingJersey;
  final int missingSalary;
  final int missingPosition;
  final int invalidHeight;
  final int invalidWeight;
  final int missingPlayerJoins;
  final int missingTeamJoins;
  final int knownPayrollUsd;
  final List<RosterCompletenessIssue> issues;
  final List<TeamRosterCompleteness> teams;

  int get identityIssueCount =>
      missingFrom +
      missingJersey +
      missingPosition +
      invalidHeight +
      invalidWeight +
      missingPlayerJoins +
      missingTeamJoins;

  double get identityCompletionRate =>
      totalRows == 0 ? 0 : identityCompleteRows / totalRows;

  double get fullCompletionRate =>
      totalRows == 0 ? 0 : fullyPopulatedRows / totalRows;
}

class RosterCompletenessService {
  const RosterCompletenessService({
    this.measurements = const RosterMeasurementFormatter(),
  });

  final RosterMeasurementFormatter measurements;

  RosterCompletenessSummary analyze(List<RosterDirectoryRow> rows) {
    var identityCompleteRows = 0;
    var fullyPopulatedRows = 0;
    var missingFrom = 0;
    var missingJersey = 0;
    var missingSalary = 0;
    var missingPosition = 0;
    var invalidHeight = 0;
    var invalidWeight = 0;
    var missingPlayerJoins = 0;
    var missingTeamJoins = 0;
    var knownPayrollUsd = 0;
    final issues = <RosterCompletenessIssue>[];
    final teamBuckets = <String, List<RosterDirectoryRow>>{};

    for (final row in rows) {
      teamBuckets.putIfAbsent(row.teamId, () => []).add(row);
      final entry = row.entry;
      var identityComplete = true;
      var fullyPopulated = true;

      void addIssue(String field, String message) {
        issues.add(
          RosterCompletenessIssue(
            playerId: row.playerId,
            playerName: row.playerName,
            teamId: row.teamId,
            teamName: row.teamName,
            field: field,
            message: message,
          ),
        );
      }

      if (row.player == null) {
        missingPlayerJoins += 1;
        identityComplete = false;
        fullyPopulated = false;
        addIssue('Player join', 'No player profile matches ${row.playerId}.');
      }
      if (row.team == null) {
        missingTeamJoins += 1;
        identityComplete = false;
        fullyPopulated = false;
        addIssue('Team join', 'No team reference matches ${row.teamId}.');
      }
      if (entry.jerseyNumber == null || entry.jerseyNumber!.trim().isEmpty) {
        missingJersey += 1;
        identityComplete = false;
        fullyPopulated = false;
        addIssue('Jersey', 'Current jersey number is missing.');
      }
      if (row.position == '—' || row.position.trim().isEmpty) {
        missingPosition += 1;
        identityComplete = false;
        fullyPopulated = false;
        addIssue('Position', 'Position is missing.');
      }
      if (row.from == '—' || row.from.trim().isEmpty) {
        missingFrom += 1;
        identityComplete = false;
        fullyPopulated = false;
        addIssue('From', 'College, prior club, or country is missing.');
      }
      if (measurements.heightInches(entry.height ?? row.player?.height) < 0) {
        invalidHeight += 1;
        identityComplete = false;
        fullyPopulated = false;
        addIssue('Height', 'Height is missing or cannot be parsed.');
      }
      final weight = entry.weightPounds ?? row.player?.weightPounds;
      if (weight == null || weight < 130 || weight > 350) {
        invalidWeight += 1;
        identityComplete = false;
        fullyPopulated = false;
        addIssue('Weight', 'Weight is missing or outside the expected NBA range.');
      }
      if (entry.salaryUsd == null) {
        missingSalary += 1;
        fullyPopulated = false;
        addIssue('Salary', 'Salary is unavailable in the source snapshot.');
      } else {
        knownPayrollUsd += entry.salaryUsd!;
      }

      if (identityComplete) identityCompleteRows += 1;
      if (fullyPopulated) fullyPopulatedRows += 1;
    }

    final teamSummaries = <TeamRosterCompleteness>[];
    for (final bucket in teamBuckets.entries) {
      final teamRows = bucket.value;
      var completeIdentity = 0;
      var completeFull = 0;
      var issueCount = 0;
      var payroll = 0;
      for (final row in teamRows) {
        final rowIssues = issues.where((issue) => issue.playerId == row.playerId && issue.teamId == row.teamId).toList();
        final identityIssues = rowIssues.where((issue) => issue.field != 'Salary').length;
        if (identityIssues == 0) completeIdentity += 1;
        if (rowIssues.isEmpty) completeFull += 1;
        issueCount += rowIssues.length;
        payroll += row.entry.salaryUsd ?? 0;
      }
      teamSummaries.add(
        TeamRosterCompleteness(
          teamId: bucket.key,
          teamName: teamRows.first.teamName,
          rows: teamRows.length,
          identityCompleteRows: completeIdentity,
          fullyPopulatedRows: completeFull,
          issueCount: issueCount,
          knownPayrollUsd: payroll,
        ),
      );
    }
    teamSummaries.sort((a, b) => a.teamName.compareTo(b.teamName));

    return RosterCompletenessSummary(
      totalRows: rows.length,
      teamsCovered: teamBuckets.length,
      identityCompleteRows: identityCompleteRows,
      fullyPopulatedRows: fullyPopulatedRows,
      missingFrom: missingFrom,
      missingJersey: missingJersey,
      missingSalary: missingSalary,
      missingPosition: missingPosition,
      invalidHeight: invalidHeight,
      invalidWeight: invalidWeight,
      missingPlayerJoins: missingPlayerJoins,
      missingTeamJoins: missingTeamJoins,
      knownPayrollUsd: knownPayrollUsd,
      issues: issues,
      teams: teamSummaries,
    );
  }
}
