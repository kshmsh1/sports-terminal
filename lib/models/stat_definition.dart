class StatDefinition {
  const StatDefinition({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.category,
    required this.level,
    required this.status,
    required this.definition,
    required this.formula,
    required this.dataNeeds,
    required this.displayUse,
  });

  final String id;
  final String name;
  final String abbreviation;
  final String category;
  final String level;
  final String status;
  final String definition;
  final String formula;
  final String dataNeeds;
  final String displayUse;
}
