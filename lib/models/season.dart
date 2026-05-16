class Season {
  const Season({
    required this.id,
    required this.label,
    required this.startYear,
    required this.endYear,
    required this.league,
  });

  final String id;
  final String label;
  final int startYear;
  final int endYear;
  final String league;
}
