class CoverageItem {
  const CoverageItem({
    required this.dataset,
    required this.domain,
    required this.assetPath,
    required this.recordCount,
    required this.status,
    required this.priority,
    required this.nextStep,
  });

  final String dataset;
  final String domain;
  final String assetPath;
  final int recordCount;
  final String status;
  final String priority;
  final String nextStep;
}
