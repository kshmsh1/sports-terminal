class Player {
  const Player({
    required this.id,
    required this.name,
    required this.team,
    required this.position,
    required this.age,
    required this.pointsPerGame,
    required this.reboundsPerGame,
    required this.assistsPerGame,
    required this.trueShootingPct,
    required this.usageRate,
  });

  final String id;
  final String name;
  final String team;
  final String position;
  final int age;
  final double pointsPerGame;
  final double reboundsPerGame;
  final double assistsPerGame;
  final double trueShootingPct;
  final double usageRate;
}
