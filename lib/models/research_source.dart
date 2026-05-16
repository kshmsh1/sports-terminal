class ResearchSource {
  const ResearchSource({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.domain,
    required this.status,
    required this.reliability,
    required this.linkPolicy,
    required this.useCase,
  });

  final String id;
  final String title;
  final String sourceType;
  final String domain;
  final String status;
  final String reliability;
  final String linkPolicy;
  final String useCase;
}
