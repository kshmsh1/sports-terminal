class AwardRecord {
  const AwardRecord({
    required this.id,
    required this.awardName,
    required this.seasonId,
    this.playerId,
    this.teamId,
    this.rank,
    this.votesFirstPlace,
    this.points,
    this.share,
    this.sourceId,
    this.asOf,
  });

  final String id;
  final String awardName;
  final String seasonId;
  final String? playerId;
  final String? teamId;
  final int? rank;
  final int? votesFirstPlace;
  final double? points;
  final double? share;
  final String? sourceId;
  final String? asOf;
}
