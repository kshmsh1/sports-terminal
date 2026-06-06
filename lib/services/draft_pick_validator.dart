import '../models/draft_pick.dart';
import '../models/player_profile.dart';
import '../models/team.dart';

class DraftPickValidationIssue {
  const DraftPickValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class DraftPickValidationSummary {
  const DraftPickValidationSummary({required this.issues});

  final List<DraftPickValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class DraftPickValidator {
  const DraftPickValidator();

  DraftPickValidationSummary validate({required List<DraftPick> picks, required List<PlayerProfile> players, required List<Team> teams}) {
    final issues = <DraftPickValidationIssue>[];
    final playerIds = players.map((item) => item.id).toSet();
    final teamIds = teams.map((item) => item.id).toSet();
    final rowIds = <String>{};
    final naturalKeys = <String>{};

    for (final row in picks) {
      if (row.id.trim().isEmpty) issues.add(_blocker('missing-row-id', 'Draft pick row is missing id.', row.id));
      if (!rowIds.add(row.id)) issues.add(_blocker('duplicate-row-id', 'Duplicate draft pick row id: ${row.id}.', row.id));
      if (row.draftYear < 1946 || row.draftYear > 2100) issues.add(_warning('draft-year-range', 'Draft year is outside expected NBA range.', row.id));
      if (row.teamId != null && row.teamId!.trim().isNotEmpty && !teamIds.contains(row.teamId)) issues.add(_blocker('team-join-missing', 'Draft pick references missing teamId: ${row.teamId}.', row.id));
      if (row.playerId != null && row.playerId!.trim().isNotEmpty && !playerIds.contains(row.playerId)) issues.add(_blocker('player-join-missing', 'Draft pick references missing playerId: ${row.playerId}.', row.id));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Draft pick is missing sourceId.', row.id));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Draft pick is missing asOf metadata.', row.id));
      final naturalKey = '${row.draftYear}|${row.round ?? 'round'}|${row.pickNumber ?? 'pick'}|${row.teamId ?? 'team'}';
      if (!naturalKeys.add(naturalKey)) issues.add(_blocker('duplicate-natural-key', 'Duplicate draft pick natural key: $naturalKey.', row.id));
      if (row.round != null && row.round! < 1) issues.add(_blocker('round-range', 'Draft round must be positive.', row.id));
      if (row.pickNumber != null && row.pickNumber! < 1) issues.add(_blocker('pick-range', 'Draft pick number must be positive.', row.id));
      if (row.playerId == null && (row.playerName == null || row.playerName!.trim().isEmpty)) issues.add(_warning('missing-player-label', 'Draft pick has neither playerId nor playerName.', row.id));
    }

    return DraftPickValidationSummary(issues: issues);
  }

  DraftPickValidationIssue _blocker(String code, String message, String? rowId) => DraftPickValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  DraftPickValidationIssue _warning(String code, String message, String? rowId) => DraftPickValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
