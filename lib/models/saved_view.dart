class SavedView {
  const SavedView({
    required this.id,
    required this.name,
    required this.workspace,
    required this.status,
    required this.description,
    required this.filters,
    required this.output,
  });

  final String id;
  final String name;
  final String workspace;
  final String status;
  final String description;
  final String filters;
  final String output;
}
