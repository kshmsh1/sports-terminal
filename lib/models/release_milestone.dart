class ReleaseMilestone {
  const ReleaseMilestone({
    required this.id,
    required this.name,
    required this.phase,
    required this.status,
    required this.goal,
    required this.scope,
    required this.exitCriteria,
  });

  final String id;
  final String name;
  final String phase;
  final String status;
  final String goal;
  final String scope;
  final String exitCriteria;
}
