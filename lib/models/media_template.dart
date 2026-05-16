class MediaTemplate {
  const MediaTemplate({
    required this.id,
    required this.contentType,
    required this.status,
    required this.entityLinks,
    required this.requiredMetadata,
    required this.description,
    required this.displayUse,
  });

  final String id;
  final String contentType;
  final String status;
  final String entityLinks;
  final String requiredMetadata;
  final String description;
  final String displayUse;
}
