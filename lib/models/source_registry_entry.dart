class SourceRegistryEntry {
  const SourceRegistryEntry({
    required this.id,
    required this.name,
    required this.domain,
    required this.sourceType,
    required this.status,
    required this.rightsPosture,
    required this.refreshCadence,
    required this.notes,
  });

  final String id;
  final String name;
  final String domain;
  final String sourceType;
  final String status;
  final String rightsPosture;
  final String refreshCadence;
  final String notes;
}
