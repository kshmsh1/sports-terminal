class ImportJobPlan {
  const ImportJobPlan({
    required this.id,
    required this.name,
    required this.domain,
    required this.status,
    required this.input,
    required this.output,
    required this.validation,
  });

  final String id;
  final String name;
  final String domain;
  final String status;
  final String input;
  final String output;
  final String validation;
}
