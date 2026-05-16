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

  factory RosterEntry.fromJson(Map<String, dynamic> json) {
    return RosterEntry(
      playerId: json['playerId'] as String,
      teamId: json['teamId'] as String,
      seasonId: json['seasonId'] as String,
      jerseyNumber: json['jerseyNumber'] as String?,
      position: json['position'] as String?,
      rosterStatus: json['rosterStatus'] as String?,
      contractType: json['contractType'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

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
