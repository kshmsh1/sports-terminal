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

  factory AwardRecord.fromJson(Map<String, dynamic> json) {
    return AwardRecord(
      id: json['id'] as String,
      awardName: json['awardName'] as String,
      seasonId: json['seasonId'] as String,
      playerId: json['playerId'] as String?,
      teamId: json['teamId'] as String?,
      rank: json['rank'] as int?,
      votesFirstPlace: json['votesFirstPlace'] as int?,
      points: (json['points'] as num?)?.toDouble(),
      share: (json['share'] as num?)?.toDouble(),
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

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
