import '../models/route_payload.dart';
import '../models/universal_query.dart';

class QueryContinuityService {
  const QueryContinuityService();

  static const supportedTargets = <String>{
    'Dashboard',
    'Compare',
    'Python Lab',
    'Workspace',
    'Export',
    'Saved View',
    'Source Audit',
  };

  RoutePayload package(
    UniversalQuery query, {
    required String targetRoute,
    List<Map<String, dynamic>> rows = const [],
    List<RoutePayloadColumn> columns = const [],
  }) {
    if (!supportedTargets.contains(targetRoute)) {
      throw ArgumentError('Unsupported query continuity target: $targetRoute');
    }
    final blockers = <String>[
      if (query.league.trim().isEmpty) 'league-required',
      if (query.objectType.trim().isEmpty) 'object-type-required',
      if (query.metrics.isEmpty && columns.isEmpty) 'metric-or-column-required',
    ];
    return RoutePayload(
      sourceObjectType: 'UniversalQuery',
      sourceObjectId: query.signature,
      displayLabel: query.naturalLanguage.trim().isEmpty
          ? '${query.league} ${query.objectType} query'
          : query.naturalLanguage.trim(),
      selectedColumns: columns.map((column) => column.key).toList(growable: false),
      selectedRows: rows
          .take(50)
          .map((row) => row['id']?.toString() ?? row['key']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      filterSummary: _filterSummary(query),
      sourceSnapshot: query.release,
      readinessState: blockers.isEmpty ? 'Ready' : 'Blocked',
      blockers: blockers,
      targetRoute: targetRoute,
      availableActions: supportedTargets.toList(growable: false),
      columns: columns,
      rows: rows,
      metadata: {
        'query': query.toJson(),
        'continuityContract': 'query-chart-compare-lab-v1',
        'release': query.release,
      },
    );
  }

  String _filterSummary(UniversalQuery query) {
    final parts = <String>[
      if (query.seasons.isNotEmpty) 'seasons=${query.seasons.join(',')}',
      if (query.seasonType.isNotEmpty) 'seasonType=${query.seasonType}',
      for (final filter in query.filters)
        '${filter.field}${filter.operator}${filter.value}',
      if (query.groupBy.isNotEmpty) 'groupBy=${query.groupBy.join(',')}',
      if (query.sort.isNotEmpty) 'sort=${query.sort.join(',')}',
      'limit=${query.limit}',
    ];
    return parts.join(' | ');
  }
}
