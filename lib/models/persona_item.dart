class PersonaItem {
  const PersonaItem({
    required this.id,
    required this.persona,
    required this.primaryJobs,
    required this.keyScreens,
    required this.mustHaveData,
    required this.workflowNeeds,
  });

  final String id;
  final String persona;
  final String primaryJobs;
  final String keyScreens;
  final String mustHaveData;
  final String workflowNeeds;
}
