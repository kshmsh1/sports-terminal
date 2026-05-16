class QaCheckItem {
  const QaCheckItem({
    required this.id,
    required this.area,
    required this.check,
    required this.status,
    required this.risk,
    required this.owner,
    required this.acceptanceCriteria,
  });

  final String id;
  final String area;
  final String check;
  final String status;
  final String risk;
  final String owner;
  final String acceptanceCriteria;
}
