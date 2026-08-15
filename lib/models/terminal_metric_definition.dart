class TerminalMetricDefinition {
  const TerminalMetricDefinition({
    required this.key,
    required this.name,
    required this.category,
    required this.objectTypes,
    required this.description,
    required this.method,
    required this.sourcePolicy,
    required this.releasePolicy,
    required this.coveragePolicy,
    this.unit = '',
    this.formula = '',
    this.dependencies = const [],
    this.aliases = const [],
    this.status = 'definition-registered',
  });

  final String key;
  final String name;
  final String category;
  final List<String> objectTypes;
  final String description;
  final String method;
  final String sourcePolicy;
  final String releasePolicy;
  final String coveragePolicy;
  final String unit;
  final String formula;
  final List<String> dependencies;
  final List<String> aliases;
  final String status;

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'category': category,
        'objectTypes': objectTypes,
        'description': description,
        'method': method,
        'sourcePolicy': sourcePolicy,
        'releasePolicy': releasePolicy,
        'coveragePolicy': coveragePolicy,
        'unit': unit,
        'formula': formula,
        'dependencies': dependencies,
        'aliases': aliases,
        'status': status,
      };

  factory TerminalMetricDefinition.fromJson(Map<String, dynamic> json) =>
      TerminalMetricDefinition(
        key: json['key']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Uncategorized',
        objectTypes: _strings(json['objectTypes']),
        description: json['description']?.toString() ?? '',
        method: json['method']?.toString() ?? '',
        sourcePolicy: json['sourcePolicy']?.toString() ?? '',
        releasePolicy: json['releasePolicy']?.toString() ?? '',
        coveragePolicy: json['coveragePolicy']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
        formula: json['formula']?.toString() ?? '',
        dependencies: _strings(json['dependencies']),
        aliases: _strings(json['aliases']),
        status: json['status']?.toString() ?? 'definition-registered',
      );
}

List<String> _strings(dynamic value) => value is List
    ? [for (final item in value) item.toString()]
    : const [];
