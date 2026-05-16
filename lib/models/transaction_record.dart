class TransactionRecord {
  const TransactionRecord({
    required this.id,
    this.date,
    this.transactionType,
    this.playerId,
    this.playerName,
    this.fromTeamId,
    this.toTeamId,
    this.description,
    this.sourceId,
    this.asOf,
  });

  final String id;
  final String? date;
  final String? transactionType;
  final String? playerId;
  final String? playerName;
  final String? fromTeamId;
  final String? toTeamId;
  final String? description;
  final String? sourceId;
  final String? asOf;
}
