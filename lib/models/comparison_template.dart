class ComparisonTemplate {
  const ComparisonTemplate({
    required this.id,
    required this.name,
    required this.comparisonType,
    required this.status,
    required this.primaryEntities,
    required this.requiredDatasets,
    required this.output,
    required this.notes,
  });

  final String id;
  final String name;
  final String comparisonType;
  final String status;
  final String primaryEntities;
  final String requiredDatasets;
  final String output;
  final String notes;
}
