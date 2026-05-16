class MediaAsset {
  const MediaAsset({
    required this.id,
    this.title,
    this.assetType,
    this.entityType,
    this.entityId,
    this.url,
    this.publishedDate,
    this.summary,
    this.sourceId,
    this.asOf,
  });

  final String id;
  final String? title;
  final String? assetType;
  final String? entityType;
  final String? entityId;
  final String? url;
  final String? publishedDate;
  final String? summary;
  final String? sourceId;
  final String? asOf;
}
