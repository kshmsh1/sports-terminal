class InjuryRecord {
  const InjuryRecord({
    required this.id,
    this.playerId,
    this.teamId,
    this.date,
    this.status,
    this.bodyPart,
    this.returnDate,
    this.description,
    this.sourceId,
    this.asOf,
  });

  factory InjuryRecord.fromJson(Map<String, dynamic> json) {
    return InjuryRecord(
      id: json['id'] as String,
      playerId: json['playerId'] as String?,
      teamId: json['teamId'] as String?,
      date: json['date'] as String?,
      status: json['status'] as String?,
      bodyPart: json['bodyPart'] as String?,
      returnDate: json['returnDate'] as String?,
      description: json['description'] as String?,
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

  final String id;
  final String? playerId;
  final String? teamId;
  final String? date;
  final String? status;
  final String? bodyPart;
  final String? returnDate;
  final String? description;
  final String? sourceId;
  final String? asOf;
}
