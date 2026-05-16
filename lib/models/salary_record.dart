class SalaryRecord {
  const SalaryRecord({
    required this.id,
    this.playerId,
    this.teamId,
    this.seasonId,
    this.salaryAmount,
    this.capAmount,
    this.notes,
    this.sourceId,
    this.asOf,
  });

  final String id;
  final String? playerId;
  final String? teamId;
  final String? seasonId;
  final double? salaryAmount;
  final double? capAmount;
  final String? notes;
  final String? sourceId;
  final String? asOf;
}
