class PlayerStatLine {
  const PlayerStatLine({
    required this.playerId,
    required this.seasonId,
    required this.seasonType,
    this.teamAbbreviation,
    this.gamesPlayed,
    this.minutesPerGame,
    this.pointsPerGame,
    this.reboundsPerGame,
    this.assistsPerGame,
    this.stealsPerGame,
    this.blocksPerGame,
    this.turnoversPerGame,
    this.fieldGoalPct,
    this.threePointPct,
    this.freeThrowPct,
    this.trueShootingPct,
    this.usageRate,
    this.sourceId,
    this.asOf,
  });

  final String playerId;
  final String seasonId;
  final String seasonType;
  final String? teamAbbreviation;
  final int? gamesPlayed;
  final double? minutesPerGame;
  final double? pointsPerGame;
  final double? reboundsPerGame;
  final double? assistsPerGame;
  final double? stealsPerGame;
  final double? blocksPerGame;
  final double? turnoversPerGame;
  final double? fieldGoalPct;
  final double? threePointPct;
  final double? freeThrowPct;
  final double? trueShootingPct;
  final double? usageRate;
  final String? sourceId;
  final String? asOf;
}
