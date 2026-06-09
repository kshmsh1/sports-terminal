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
    this.snapshotLabel,
    this.age,
    this.height,
    this.weightPounds,
    this.college,
    this.from,
    this.salaryUsd,
    this.salaryDisplay,
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
      snapshotLabel: json['snapshotLabel'] as String?,
      age: json['age'] as int?,
      height: json['height'] as String?,
      weightPounds: json['weightPounds'] as int?,
      college: json['college'] as String?,
      from: json['from'] as String?,
      salaryUsd: json['salaryUsd'] as int?,
      salaryDisplay: json['salaryDisplay'] as String?,
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
  final String? snapshotLabel;
  final int? age;
  final String? height;
  final int? weightPounds;
  final String? college;
  final String? from;
  final int? salaryUsd;
  final String? salaryDisplay;

  String? get fromDisplay => from ?? college;
}
