class DraftPick {
  const DraftPick({
    required this.id,
    required this.draftYear,
    this.round,
    this.pickNumber,
    this.teamId,
    this.playerId,
    this.playerName,
    this.schoolOrClub,
    this.country,
    this.sourceId,
    this.asOf,
  });

  factory DraftPick.fromJson(Map<String, dynamic> json) {
    return DraftPick(
      id: json['id'] as String,
      draftYear: json['draftYear'] as int,
      round: json['round'] as int?,
      pickNumber: json['pickNumber'] as int?,
      teamId: json['teamId'] as String?,
      playerId: json['playerId'] as String?,
      playerName: json['playerName'] as String?,
      schoolOrClub: json['schoolOrClub'] as String?,
      country: json['country'] as String?,
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

  final String id;
  final int draftYear;
  final int? round;
  final int? pickNumber;
  final String? teamId;
  final String? playerId;
  final String? playerName;
  final String? schoolOrClub;
  final String? country;
  final String? sourceId;
  final String? asOf;
}
