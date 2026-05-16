class TerminalReport {
  const TerminalReport({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.description,
    required this.primaryEntities,
    required this.requiredDatasets,
  });

  final String id;
  final String title;
  final String category;
  final String priority;
  final String status;
  final String description;
  final String primaryEntities;
  final String requiredDatasets;
}
