class RosterEntry {
  const RosterEntry({
    required this.playerId,
    required this.teamId,
    required this.seasonId,
    this.jerseyNumber,
    this.position,
    this.rosterStatus,
    this.contractType,
    this.startDate,
    this.endDate,
    this.sourceId,
    this.asOf,
  });

  final String playerId;
  final String teamId;
  final String seasonId;
  final String? jerseyNumber;
  final String? position;
  final String? rosterStatus;
  final String? contractType;
  final String? startDate;
  final String? endDate;
  final String? sourceId;
  final String? asOf;
}
