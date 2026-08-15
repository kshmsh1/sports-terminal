class TerminalModelDefinition {
  const TerminalModelDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.version,
    required this.status,
    required this.inputObjects,
    required this.inputMetrics,
    required this.outputs,
    required this.method,
    required this.limitations,
    required this.sourcePolicy,
    required this.releasePolicy,
    this.dependencies = const [],
    this.tags = const [],
  });

  final String id;
  final String name;
  final String category;
  final String version;
  final String status;
  final List<String> inputObjects;
  final List<String> inputMetrics;
  final List<String> outputs;
  final String method;
  final String limitations;
  final String sourcePolicy;
  final String releasePolicy;
  final List<String> dependencies;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'version': version,
        'status': status,
        'inputObjects': inputObjects,
        'inputMetrics': inputMetrics,
        'outputs': outputs,
        'method': method,
        'limitations': limitations,
        'sourcePolicy': sourcePolicy,
        'releasePolicy': releasePolicy,
        'dependencies': dependencies,
        'tags': tags,
      };

  factory TerminalModelDefinition.fromJson(Map<String, dynamic> json) =>
      TerminalModelDefinition(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Uncategorized',
        version: json['version']?.toString() ?? '1',
        status: json['status']?.toString() ?? 'registered',
        inputObjects: _strings(json['inputObjects']),
        inputMetrics: _strings(json['inputMetrics']),
        outputs: _strings(json['outputs']),
        method: json['method']?.toString() ?? '',
        limitations: json['limitations']?.toString() ?? '',
        sourcePolicy: json['sourcePolicy']?.toString() ?? '',
        releasePolicy: json['releasePolicy']?.toString() ?? '',
        dependencies: _strings(json['dependencies']),
        tags: _strings(json['tags']),
      );
}

List<String> _strings(dynamic value) => value is List
    ? [for (final item in value) item.toString()]
    : const [];
