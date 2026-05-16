class FranchiseHistoryEvent {
  const FranchiseHistoryEvent({
    required this.id,
    required this.teamId,
    required this.eventType,
    this.startSeasonId,
    this.endSeasonId,
    this.previousName,
    this.newName,
    this.previousCity,
    this.newCity,
    this.description,
    this.sourceId,
    this.asOf,
  });

  final String id;
  final String teamId;
  final String eventType;
  final String? startSeasonId;
  final String? endSeasonId;
  final String? previousName;
  final String? newName;
  final String? previousCity;
  final String? newCity;
  final String? description;
  final String? sourceId;
  final String? asOf;
}
