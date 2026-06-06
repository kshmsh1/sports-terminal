import '../models/award_record.dart';
import '../models/player_profile.dart';
import '../models/season.dart';
import '../models/team.dart';

class AwardRecordValidationIssue {
  const AwardRecordValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class AwardRecordValidationSummary {
  const AwardRecordValidationSummary({required this.issues});

  final List<AwardRecordValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class AwardRecordValidator {
  const AwardRecordValidator();

  AwardRecordValidationSummary validate({required List<AwardRecord> awards, required List<PlayerProfile> players, required List<Team> teams, required List<Season> seasons}) {
    final issues = <AwardRecordValidationIssue>[];
    final playerIds = players.map((item) => item.id).toSet();
    final teamIds = teams.map((item) => item.id).toSet();
    final seasonIds = seasons.map((item) => item.id).toSet();
    final rowIds = <String>{};
    final naturalKeys = <String>{};

    for (final row in awards) {
      if (row.id.trim().isEmpty) issues.add(_blocker('missing-row-id', 'Award row is missing id.', row.id));
      if (!rowIds.add(row.id)) issues.add(_blocker('duplicate-row-id', 'Duplicate award row id: ${row.id}.', row.id));
      if (row.awardName.trim().isEmpty) issues.add(_blocker('missing-award-name', 'Award row is missing awardName.', row.id));
      if (row.seasonId.trim().isEmpty) issues.add(_blocker('missing-season-id', 'Award row is missing seasonId.', row.id));
      if (!seasonIds.contains(row.seasonId)) issues.add(_blocker('season-join-missing', 'Award row references missing seasonId: ${row.seasonId}.', row.id));
      if (row.playerId != null && row.playerId!.trim().isNotEmpty && !playerIds.contains(row.playerId)) issues.add(_blocker('player-join-missing', 'Award row references missing playerId: ${row.playerId}.', row.id));
      if (row.teamId != null && row.teamId!.trim().isNotEmpty && !teamIds.contains(row.teamId)) issues.add(_blocker('team-join-missing', 'Award row references missing teamId: ${row.teamId}.', row.id));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Award row is missing sourceId.', row.id));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Award row is missing asOf metadata.', row.id));

      final naturalKey = '${row.awardName}|${row.seasonId}|${row.rank ?? 'rank'}|${row.playerId ?? row.teamId ?? 'recipient'}';
      if (!naturalKeys.add(naturalKey)) issues.add(_blocker('duplicate-natural-key', 'Duplicate award natural key: $naturalKey.', row.id));

      if (row.rank != null && row.rank! < 1) issues.add(_blocker('rank-range', 'Award rank must be positive.', row.id));
      _checkNonNegative(issues, row.id, 'votesFirstPlace', row.votesFirstPlace?.toDouble());
      _checkNonNegative(issues, row.id, 'points', row.points);
      if (row.share != null && (row.share! < 0 || row.share! > 1.5)) issues.add(_warning('share-range', 'Award vote share is outside expected decimal range.', row.id));
      if (row.playerId == null && row.teamId == null) issues.add(_warning('missing-recipient', 'Award row has neither playerId nor teamId.', row.id));
    }

    return AwardRecordValidationSummary(issues: issues);
  }

  void _checkNonNegative(List<AwardRecordValidationIssue> issues, String rowId, String field, double? value) {
    if (value != null && value < 0) issues.add(_blocker('negative-$field', '$field cannot be negative.', rowId));
  }

  AwardRecordValidationIssue _blocker(String code, String message, String? rowId) => AwardRecordValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  AwardRecordValidationIssue _warning(String code, String message, String? rowId) => AwardRecordValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
