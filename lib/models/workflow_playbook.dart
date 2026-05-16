class WorkflowPlaybook {
  const WorkflowPlaybook({
    required this.id,
    required this.name,
    required this.workspace,
    required this.status,
    required this.trigger,
    required this.steps,
    required this.requiredData,
    required this.output,
  });

  final String id;
  final String name;
  final String workspace;
  final String status;
  final String trigger;
  final List<String> steps;
  final String requiredData;
  final String output;
}
