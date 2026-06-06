import '../models/player_profile.dart';
import '../models/team.dart';
import '../models/transaction_record.dart';

class TransactionRecordValidationIssue {
  const TransactionRecordValidationIssue({required this.severity, required this.code, required this.message, required this.rowId});

  final String severity;
  final String code;
  final String message;
  final String? rowId;

  bool get isBlocking => severity == 'Blocker';
}

class TransactionRecordValidationSummary {
  const TransactionRecordValidationSummary({required this.issues});

  final List<TransactionRecordValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class TransactionRecordValidator {
  const TransactionRecordValidator();

  TransactionRecordValidationSummary validate({required List<TransactionRecord> transactions, required List<PlayerProfile> players, required List<Team> teams}) {
    final issues = <TransactionRecordValidationIssue>[];
    final playerIds = players.map((item) => item.id).toSet();
    final teamIds = teams.map((item) => item.id).toSet();
    final rowIds = <String>{};

    for (final row in transactions) {
      if (row.id.trim().isEmpty) issues.add(_blocker('missing-row-id', 'Transaction row is missing id.', row.id));
      if (!rowIds.add(row.id)) issues.add(_blocker('duplicate-row-id', 'Duplicate transaction row id: ${row.id}.', row.id));
      if (row.playerId != null && row.playerId!.trim().isNotEmpty && !playerIds.contains(row.playerId)) issues.add(_blocker('player-join-missing', 'Transaction references missing playerId: ${row.playerId}.', row.id));
      if (row.fromTeamId != null && row.fromTeamId!.trim().isNotEmpty && !teamIds.contains(row.fromTeamId)) issues.add(_blocker('from-team-join-missing', 'Transaction references missing fromTeamId: ${row.fromTeamId}.', row.id));
      if (row.toTeamId != null && row.toTeamId!.trim().isNotEmpty && !teamIds.contains(row.toTeamId)) issues.add(_blocker('to-team-join-missing', 'Transaction references missing toTeamId: ${row.toTeamId}.', row.id));
      if (row.fromTeamId != null && row.toTeamId != null && row.fromTeamId == row.toTeamId) issues.add(_warning('same-from-to-team', 'Transaction has the same fromTeamId and toTeamId.', row.id));
      if (row.sourceId == null || row.sourceId!.trim().isEmpty) issues.add(_blocker('missing-source-id', 'Transaction row is missing sourceId.', row.id));
      if (row.asOf == null || row.asOf!.trim().isEmpty) issues.add(_blocker('missing-as-of', 'Transaction row is missing asOf metadata.', row.id));
      if (row.date == null || row.date!.trim().isEmpty) issues.add(_warning('missing-date', 'Transaction date is blank.', row.id));
      if (row.transactionType == null || row.transactionType!.trim().isEmpty) issues.add(_warning('missing-transaction-type', 'Transaction type is blank.', row.id));
      if (row.playerId == null && (row.playerName == null || row.playerName!.trim().isEmpty) && row.description == null) issues.add(_warning('missing-subject', 'Transaction has no player, playerName, or description.', row.id));
    }

    return TransactionRecordValidationSummary(issues: issues);
  }

  TransactionRecordValidationIssue _blocker(String code, String message, String? rowId) => TransactionRecordValidationIssue(severity: 'Blocker', code: code, message: message, rowId: rowId);
  TransactionRecordValidationIssue _warning(String code, String message, String? rowId) => TransactionRecordValidationIssue(severity: 'Warning', code: code, message: message, rowId: rowId);
}
