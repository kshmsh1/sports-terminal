class EraBand {
  const EraBand({
    required this.id,
    required this.name,
    required this.startSeasonId,
    required this.endSeasonId,
    required this.status,
    required this.description,
    required this.primaryContext,
  });

  final String id;
  final String name;
  final String startSeasonId;
  final String endSeasonId;
  final String status;
  final String description;
  final String primaryContext;
}
