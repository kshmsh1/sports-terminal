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
  String get blockersLabel => blockers.join(', ');
  String get actionsLabel => availableActions.join(', ');
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
