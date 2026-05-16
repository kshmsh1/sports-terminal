class TeamSeasonStat {
  const TeamSeasonStat({
    required this.id,
    required this.teamId,
    required this.seasonId,
    this.seasonType,
    this.wins,
    this.losses,
    this.winPercentage,
    this.pointsPerGame,
    this.opponentPointsPerGame,
    this.pace,
    this.offensiveRating,
    this.defensiveRating,
    this.netRating,
    this.personalFoulsPerGame,
    this.fieldGoalPercentage,
    this.threePointPercentage,
    this.freeThrowPercentage,
    this.effectiveFieldGoalPercentage,
    this.trueShootingPercentage,
    this.turnoversPerGame,
    this.reboundsPerGame,
    this.assistsPerGame,
    this.stealsPerGame,
    this.blocksPerGame,
    this.sourceId,
    this.asOf,
  });

  factory TeamSeasonStat.fromJson(Map<String, dynamic> json) {
    return TeamSeasonStat(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      seasonId: json['seasonId'] as String,
      seasonType: json['seasonType'] as String?,
      wins: json['wins'] as int?,
      losses: json['losses'] as int?,
      winPercentage: (json['winPercentage'] as num?)?.toDouble(),
      pointsPerGame: (json['pointsPerGame'] as num?)?.toDouble(),
      opponentPointsPerGame: (json['opponentPointsPerGame'] as num?)?.toDouble(),
      pace: (json['pace'] as num?)?.toDouble(),
      offensiveRating: (json['offensiveRating'] as num?)?.toDouble(),
      defensiveRating: (json['defensiveRating'] as num?)?.toDouble(),
      netRating: (json['netRating'] as num?)?.toDouble(),
      personalFoulsPerGame: (json['personalFoulsPerGame'] as num?)?.toDouble(),
      fieldGoalPercentage: (json['fieldGoalPercentage'] as num?)?.toDouble(),
      threePointPercentage: (json['threePointPercentage'] as num?)?.toDouble(),
      freeThrowPercentage: (json['freeThrowPercentage'] as num?)?.toDouble(),
      effectiveFieldGoalPercentage: (json['effectiveFieldGoalPercentage'] as num?)?.toDouble(),
      trueShootingPercentage: (json['trueShootingPercentage'] as num?)?.toDouble(),
      turnoversPerGame: (json['turnoversPerGame'] as num?)?.toDouble(),
      reboundsPerGame: (json['reboundsPerGame'] as num?)?.toDouble(),
      assistsPerGame: (json['assistsPerGame'] as num?)?.toDouble(),
      stealsPerGame: (json['stealsPerGame'] as num?)?.toDouble(),
      blocksPerGame: (json['blocksPerGame'] as num?)?.toDouble(),
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

  final String id;
  final String teamId;
  final String seasonId;
  final String? seasonType;
  final int? wins;
  final int? losses;
  final double? winPercentage;
  final double? pointsPerGame;
  final double? opponentPointsPerGame;
  final double? pace;
  final double? offensiveRating;
  final double? defensiveRating;
  final double? netRating;
  final double? personalFoulsPerGame;
  final double? fieldGoalPercentage;
  final double? threePointPercentage;
  final double? freeThrowPercentage;
  final double? effectiveFieldGoalPercentage;
  final double? trueShootingPercentage;
  final double? turnoversPerGame;
  final double? reboundsPerGame;
  final double? assistsPerGame;
  final double? stealsPerGame;
  final double? blocksPerGame;
  final String? sourceId;
  final String? asOf;
}
