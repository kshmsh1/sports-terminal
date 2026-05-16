class GlossaryItem {
  const GlossaryItem({
    required this.id,
    required this.term,
    required this.domain,
    required this.status,
    required this.definition,
    required this.terminalUse,
  });

  final String id;
  final String term;
  final String domain;
  final String status;
  final String definition;
  final String terminalUse;
}
