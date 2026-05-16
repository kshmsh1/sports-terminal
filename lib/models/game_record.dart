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
