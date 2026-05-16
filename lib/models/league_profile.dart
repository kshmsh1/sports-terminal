class LeagueProfile {
  const LeagueProfile({
    required this.id,
    required this.name,
    required this.shortName,
    required this.level,
    required this.priority,
    required this.status,
    required this.description,
    required this.relationshipToNba,
    required this.dataPosture,
  });

  final String id;
  final String name;
  final String shortName;
  final String level;
  final int priority;
  final String status;
  final String description;
  final String relationshipToNba;
  final String dataPosture;
}
