class PlayerSeasonStat {
  const PlayerSeasonStat({
    required this.id,
    required this.playerId,
    required this.seasonId,
    this.teamId,
    this.seasonType,
    this.gamesPlayed,
    this.minutesPerGame,
    this.pointsPerGame,
    this.reboundsPerGame,
    this.assistsPerGame,
    this.stealsPerGame,
    this.blocksPerGame,
    this.turnoversPerGame,
    this.sourceId,
    this.asOf,
  });

  factory PlayerSeasonStat.fromJson(Map<String, dynamic> json) {
    return PlayerSeasonStat(
      id: json['id'] as String,
      playerId: json['playerId'] as String,
      seasonId: json['seasonId'] as String,
      teamId: json['teamId'] as String?,
      seasonType: json['seasonType'] as String?,
      gamesPlayed: json['gamesPlayed'] as int?,
      minutesPerGame: (json['minutesPerGame'] as num?)?.toDouble(),
      pointsPerGame: (json['pointsPerGame'] as num?)?.toDouble(),
      reboundsPerGame: (json['reboundsPerGame'] as num?)?.toDouble(),
      assistsPerGame: (json['assistsPerGame'] as num?)?.toDouble(),
      stealsPerGame: (json['stealsPerGame'] as num?)?.toDouble(),
      blocksPerGame: (json['blocksPerGame'] as num?)?.toDouble(),
      turnoversPerGame: (json['turnoversPerGame'] as num?)?.toDouble(),
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

  final String id;
  final String playerId;
  final String seasonId;
  final String? teamId;
  final String? seasonType;
  final int? gamesPlayed;
  final double? minutesPerGame;
  final double? pointsPerGame;
  final double? reboundsPerGame;
  final double? assistsPerGame;
  final double? stealsPerGame;
  final double? blocksPerGame;
  final double? turnoversPerGame;
  final String? sourceId;
  final String? asOf;

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'seasonId': seasonId,
        'teamId': teamId,
        'seasonType': seasonType,
        'gamesPlayed': gamesPlayed,
        'minutesPerGame': minutesPerGame,
        'pointsPerGame': pointsPerGame,
        'reboundsPerGame': reboundsPerGame,
        'assistsPerGame': assistsPerGame,
        'stealsPerGame': stealsPerGame,
        'blocksPerGame': blocksPerGame,
        'turnoversPerGame': turnoversPerGame,
        'sourceId': sourceId,
        'asOf': asOf,
      };
}
