class DataHealthCheck {
  const DataHealthCheck({
    required this.id,
    required this.name,
    required this.domain,
    required this.severity,
    required this.status,
    required this.description,
    required this.remediation,
  });

  final String id;
  final String name;
  final String domain;
  final String severity;
  final String status;
  final String description;
  final String remediation;
}
