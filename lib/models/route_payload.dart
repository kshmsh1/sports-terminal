import 'dart:convert';

class RoutePayloadColumn {
  const RoutePayloadColumn({
    required this.key,
    required this.label,
    this.dataType = 'text',
    this.unit = '',
  });

  final String key;
  final String label;
  final String dataType;
  final String unit;

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'dataType': dataType,
        'unit': unit,
      };

  factory RoutePayloadColumn.fromJson(Map<String, dynamic> json) {
    return RoutePayloadColumn(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? json['key']?.toString() ?? '',
      dataType: json['dataType']?.toString() ?? 'text',
      unit: json['unit']?.toString() ?? '',
    );
  }
}

class RoutePayload {
  const RoutePayload({
    required this.sourceObjectType,
    required this.sourceObjectId,
    required this.displayLabel,
    required this.selectedColumns,
    required this.selectedRows,
    required this.filterSummary,
    required this.sourceSnapshot,
    required this.readinessState,
    required this.blockers,
    required this.targetRoute,
    required this.availableActions,
    this.schemaVersion = 2,
    this.createdAtIso = '',
    this.columns = const [],
    this.rows = const [],
    this.metadata = const {},
  });

  final String sourceObjectType;
  final String sourceObjectId;
  final String displayLabel;
  final List<String> selectedColumns;
  final List<String> selectedRows;
  final String filterSummary;
  final String sourceSnapshot;
  final String readinessState;
  final List<String> blockers;
  final String targetRoute;
  final List<String> availableActions;
  final int schemaVersion;
  final String createdAtIso;
  final List<RoutePayloadColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> metadata;

  String get selectedColumnsLabel => selectedColumns.join(', ');
  String get selectedRowsLabel => selectedRows.join(', ');
  String get blockersLabel => blockers.isEmpty ? 'None' : blockers.join(', ');
  String get actionsLabel => availableActions.join(', ');
  String get routeKey => '${sourceObjectType.toLowerCase()}:$sourceObjectId→$targetRoute';
  String get conciseDebugLabel => '$displayLabel → $targetRoute';
  bool get hasBlockers => blockers.isNotEmpty;
  bool get hasStructuredRows => rows.isNotEmpty && columns.isNotEmpty;
  int get rowCount => rows.length;
  int get columnCount => columns.length;
  String get createdAtLabel => createdAtIso.isEmpty ? 'Unspecified' : createdAtIso;

  RoutePayload copyWith({
    String? sourceObjectType,
    String? sourceObjectId,
    String? displayLabel,
    List<String>? selectedColumns,
    List<String>? selectedRows,
    String? filterSummary,
    String? sourceSnapshot,
    String? readinessState,
    List<String>? blockers,
    String? targetRoute,
    List<String>? availableActions,
    int? schemaVersion,
    String? createdAtIso,
    List<RoutePayloadColumn>? columns,
    List<Map<String, dynamic>>? rows,
    Map<String, dynamic>? metadata,
  }) {
    return RoutePayload(
      sourceObjectType: sourceObjectType ?? this.sourceObjectType,
      sourceObjectId: sourceObjectId ?? this.sourceObjectId,
      displayLabel: displayLabel ?? this.displayLabel,
      selectedColumns: selectedColumns ?? this.selectedColumns,
      selectedRows: selectedRows ?? this.selectedRows,
      filterSummary: filterSummary ?? this.filterSummary,
      sourceSnapshot: sourceSnapshot ?? this.sourceSnapshot,
      readinessState: readinessState ?? this.readinessState,
      blockers: blockers ?? this.blockers,
      targetRoute: targetRoute ?? this.targetRoute,
      availableActions: availableActions ?? this.availableActions,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'createdAtIso': createdAtIso,
        'sourceObjectType': sourceObjectType,
        'sourceObjectId': sourceObjectId,
        'displayLabel': displayLabel,
        'targetRoute': targetRoute,
        'selectedColumns': selectedColumns,
        'selectedRows': selectedRows,
        'filterSummary': filterSummary,
        'sourceSnapshot': sourceSnapshot,
        'readinessState': readinessState,
        'blockers': blockers,
        'availableActions': availableActions,
        'columns': [for (final column in columns) column.toJson()],
        'rows': rows,
        'metadata': metadata,
      };

  factory RoutePayload.fromJson(Map<String, dynamic> json) {
    final rawColumns = json['columns'];
    final rawRows = json['rows'];
    return RoutePayload(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      createdAtIso: json['createdAtIso']?.toString() ?? '',
      sourceObjectType: json['sourceObjectType']?.toString() ?? 'Unknown',
      sourceObjectId: json['sourceObjectId']?.toString() ?? 'unknown',
      displayLabel: json['displayLabel']?.toString() ?? 'Untitled payload',
      targetRoute: json['targetRoute']?.toString() ?? 'Open',
      selectedColumns: _stringList(json['selectedColumns']),
      selectedRows: _stringList(json['selectedRows']),
      filterSummary: json['filterSummary']?.toString() ?? '',
      sourceSnapshot: json['sourceSnapshot']?.toString() ?? '',
      readinessState: json['readinessState']?.toString() ?? 'Unknown',
      blockers: _stringList(json['blockers']),
      availableActions: _stringList(json['availableActions']),
      columns: rawColumns is List
          ? [
              for (final item in rawColumns)
                if (item is Map)
                  RoutePayloadColumn.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
            ]
          : const [],
      rows: rawRows is List
          ? [
              for (final item in rawRows)
                if (item is Map)
                  item.map((key, value) => MapEntry(key.toString(), value)),
            ]
          : const [],
      metadata: json['metadata'] is Map
          ? (json['metadata'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const {},
    );
  }

  String encode() => jsonEncode(toJson());

  static RoutePayload? tryDecode(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return RoutePayload.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, Object?> toSummaryMap() => {
        'schemaVersion': schemaVersion,
        'createdAtIso': createdAtIso,
        'sourceObjectType': sourceObjectType,
        'sourceObjectId': sourceObjectId,
        'displayLabel': displayLabel,
        'targetRoute': targetRoute,
        'selectedColumns': selectedColumns,
        'selectedRows': selectedRows,
        'filterSummary': filterSummary,
        'sourceSnapshot': sourceSnapshot,
        'readinessState': readinessState,
        'blockers': blockers,
        'availableActions': availableActions,
        'rowCount': rowCount,
        'columnCount': columnCount,
        'metadata': metadata,
      };
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}

const immediateRouteTargets = <String>[
  'Open',
  'Workspace',
  'Python Lab',
  'Compare',
  'Reports',
  'Saved View',
  'Export',
  'Alerts',
  'Dashboard',
  'Search',
  'Action Center',
  'Source Audit',
];
