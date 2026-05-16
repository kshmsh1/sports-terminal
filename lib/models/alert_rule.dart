class AlertRule {
  const AlertRule({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.trigger,
    required this.description,
    required this.requiredData,
  });

  final String id;
  final String name;
  final String category;
  final String status;
  final String trigger;
  final String description;
  final String requiredData;
}
