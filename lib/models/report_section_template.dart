class ReportSectionTemplate {
  const ReportSectionTemplate({
    required this.id,
    required this.reportType,
    required this.section,
    required this.priority,
    required this.status,
    required this.description,
    required this.dataInputs,
  });

  final String id;
  final String reportType;
  final String section;
  final String priority;
  final String status;
  final String description;
  final String dataInputs;
}
