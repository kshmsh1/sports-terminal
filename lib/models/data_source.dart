class DataSource {
  const DataSource({
    required this.id,
    required this.name,
    required this.status,
    required this.description,
    this.asOf,
    this.attribution,
  });

  final String id;
  final String name;
  final DataSourceStatus status;
  final String description;
  final String? asOf;
  final String? attribution;
}

enum DataSourceStatus {
  connected,
  planned,
  restricted,
}
