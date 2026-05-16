class EntityRelationship {
  const EntityRelationship({
    required this.id,
    required this.fromEntity,
    required this.toEntity,
    required this.relationship,
    required this.status,
    required this.description,
    required this.requiredDataset,
  });

  final String id;
  final String fromEntity;
  final String toEntity;
  final String relationship;
  final String status;
  final String description;
  final String requiredDataset;
}
