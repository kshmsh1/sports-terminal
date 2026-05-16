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
