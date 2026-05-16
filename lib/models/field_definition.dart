class FieldDefinition {
  const FieldDefinition({
    required this.field,
    required this.domain,
    required this.type,
    required this.required,
    required this.nullPolicy,
    required this.description,
  });

  final String field;
  final String domain;
  final String type;
  final String required;
  final String nullPolicy;
  final String description;
}
