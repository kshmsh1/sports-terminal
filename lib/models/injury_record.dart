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
