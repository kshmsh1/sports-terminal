class PlayoffSeriesRecord {
  const PlayoffSeriesRecord({
    required this.id,
    required this.seasonId,
    this.round,
    this.seriesName,
    this.winningTeamId,
    this.losingTeamId,
    this.winningSeed,
    this.losingSeed,
    this.gamesPlayed,
    this.winnerWins,
    this.loserWins,
    this.sourceId,
    this.asOf,
  });

  factory PlayoffSeriesRecord.fromJson(Map<String, dynamic> json) {
    return PlayoffSeriesRecord(
      id: json['id'] as String,
      seasonId: json['seasonId'] as String,
      round: json['round'] as String?,
      seriesName: json['seriesName'] as String?,
      winningTeamId: json['winningTeamId'] as String?,
      losingTeamId: json['losingTeamId'] as String?,
      winningSeed: json['winningSeed'] as int?,
      losingSeed: json['losingSeed'] as int?,
      gamesPlayed: json['gamesPlayed'] as int?,
      winnerWins: json['winnerWins'] as int?,
      loserWins: json['loserWins'] as int?,
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

  final String id;
  final String seasonId;
  final String? round;
  final String? seriesName;
  final String? winningTeamId;
  final String? losingTeamId;
  final int? winningSeed;
  final int? losingSeed;
  final int? gamesPlayed;
  final int? winnerWins;
  final int? loserWins;
  final String? sourceId;
  final String? asOf;
}
