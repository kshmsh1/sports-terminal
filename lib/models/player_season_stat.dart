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
    this.personalFoulsPerGame,
    this.fieldGoalPercentage,
    this.threePointPercentage,
    this.freeThrowPercentage,
    this.effectiveFieldGoalPercentage,
    this.trueShootingPercentage,
    this.usagePercentage,
    this.offensiveRating,
    this.defensiveRating,
    this.netRating,
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
      personalFoulsPerGame: (json['personalFoulsPerGame'] as num?)?.toDouble(),
      fieldGoalPercentage: (json['fieldGoalPercentage'] as num?)?.toDouble(),
      threePointPercentage: (json['threePointPercentage'] as num?)?.toDouble(),
      freeThrowPercentage: (json['freeThrowPercentage'] as num?)?.toDouble(),
      effectiveFieldGoalPercentage: (json['effectiveFieldGoalPercentage'] as num?)?.toDouble(),
      trueShootingPercentage: (json['trueShootingPercentage'] as num?)?.toDouble(),
      usagePercentage: (json['usagePercentage'] as num?)?.toDouble(),
      offensiveRating: (json['offensiveRating'] as num?)?.toDouble(),
      defensiveRating: (json['defensiveRating'] as num?)?.toDouble(),
      netRating: (json['netRating'] as num?)?.toDouble(),
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
  final double? personalFoulsPerGame;
  final double? fieldGoalPercentage;
  final double? threePointPercentage;
  final double? freeThrowPercentage;
  final double? effectiveFieldGoalPercentage;
  final double? trueShootingPercentage;
  final double? usagePercentage;
  final double? offensiveRating;
  final double? defensiveRating;
  final double? netRating;
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
        'personalFoulsPerGame': personalFoulsPerGame,
        'fieldGoalPercentage': fieldGoalPercentage,
        'threePointPercentage': threePointPercentage,
        'freeThrowPercentage': freeThrowPercentage,
        'effectiveFieldGoalPercentage': effectiveFieldGoalPercentage,
        'trueShootingPercentage': trueShootingPercentage,
        'usagePercentage': usagePercentage,
        'offensiveRating': offensiveRating,
        'defensiveRating': defensiveRating,
        'netRating': netRating,
        'sourceId': sourceId,
        'asOf': asOf,
      };
}
