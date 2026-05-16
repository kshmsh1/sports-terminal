class BacklogItem {
  const BacklogItem({
    required this.id,
    required this.title,
    required this.area,
    required this.priority,
    required this.status,
    required this.whyItMatters,
    required this.acceptanceCriteria,
  });

  final String id;
  final String title;
  final String area;
  final String priority;
  final String status;
  final String whyItMatters;
  final String acceptanceCriteria;
}
