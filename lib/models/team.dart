class Team {
  const Team({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.conference,
    required this.wins,
    required this.losses,
    required this.offensiveRating,
    required this.defensiveRating,
    required this.netRating,
  });

  final String id;
  final String name;
  final String abbreviation;
  final String conference;
  final int wins;
  final int losses;
  final double offensiveRating;
  final double defensiveRating;
  final double netRating;
}
