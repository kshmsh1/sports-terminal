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

  String get selectedColumnsLabel => selectedColumns.join(', ');
  String get selectedRowsLabel => selectedRows.join(', ');
  String get blockersLabel => blockers.isEmpty ? 'None' : blockers.join(', ');
  String get actionsLabel => availableActions.join(', ');
  String get routeKey => '${sourceObjectType.toLowerCase()}:$sourceObjectId→$targetRoute';
  String get conciseDebugLabel => '$displayLabel → $targetRoute';
  bool get hasBlockers => blockers.isNotEmpty;

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
    );
  }

  Map<String, Object> toSummaryMap() => {
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
      };
}

const immediateRouteTargets = <String>[
  'Open',
  'Workspace',
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
