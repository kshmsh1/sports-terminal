class EraDefinition {
  const EraDefinition({
    required this.id,
    required this.name,
    required this.startSeasonId,
    this.endSeasonId,
    required this.category,
    required this.description,
    this.sourceId,
    this.asOf,
  });

  final String id;
  final String name;
  final String startSeasonId;
  final String? endSeasonId;
  final String category;
  final String description;
  final String? sourceId;
  final String? asOf;
}
