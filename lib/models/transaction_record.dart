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

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'] as String,
      date: json['date'] as String?,
      transactionType: json['transactionType'] as String?,
      playerId: json['playerId'] as String?,
      playerName: json['playerName'] as String?,
      fromTeamId: json['fromTeamId'] as String?,
      toTeamId: json['toTeamId'] as String?,
      description: json['description'] as String?,
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

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
