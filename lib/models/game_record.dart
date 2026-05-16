class GameRecord {
  const GameRecord({
    required this.id,
    required this.seasonId,
    this.gameDate,
    this.seasonType,
    this.homeTeamId,
    this.awayTeamId,
    this.homeScore,
    this.awayScore,
    this.arena,
    this.city,
    this.sourceId,
    this.asOf,
  });

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    return GameRecord(
      id: json['id'] as String,
      seasonId: json['seasonId'] as String,
      gameDate: json['gameDate'] as String?,
      seasonType: json['seasonType'] as String?,
      homeTeamId: json['homeTeamId'] as String?,
      awayTeamId: json['awayTeamId'] as String?,
      homeScore: json['homeScore'] as int?,
      awayScore: json['awayScore'] as int?,
      arena: json['arena'] as String?,
      city: json['city'] as String?,
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

  final String id;
  final String seasonId;
  final String? gameDate;
  final String? seasonType;
  final String? homeTeamId;
  final String? awayTeamId;
  final int? homeScore;
  final int? awayScore;
  final String? arena;
  final String? city;
  final String? sourceId;
  final String? asOf;
}
