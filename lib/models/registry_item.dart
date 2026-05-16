class RegistryItem {
  const RegistryItem({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.description,
    required this.inputs,
    required this.nextStep,
  });

  final String id;
  final String title;
  final String category;
  final String priority;
  final String status;
  final String description;
  final String inputs;
  final String nextStep;
}
