import '../models/generated_terminal_report.dart';
import '../models/route_payload.dart';

class RoutePayloadReportGenerator {
  const RoutePayloadReportGenerator();

  GeneratedTerminalReport generate(RoutePayload payload) {
    final columns = _columnsFor(payload);
    final rows = <Map<String, dynamic>>[
      for (final row in payload.rows) _projectRow(row, columns),
    ];
    final coverage = _coverageFor(
      payload,
      hasStructuredData: rows.isNotEmpty && columns.isNotEmpty,
    );
    final titleBase = payload.displayLabel.trim().isEmpty
        ? '${payload.sourceObjectType} ${payload.sourceObjectId}'.trim()
        : payload.displayLabel.trim();

    return GeneratedTerminalReport(
      title: '$titleBase — Source-Backed Report',
      subtitle:
          'Generated directly from the active ${payload.sourceObjectType} RoutePayload without inferred sports facts.',
      sourceObjectType: payload.sourceObjectType,
      sourceObjectId: payload.sourceObjectId,
      sourceSnapshot: payload.sourceSnapshot,
      readinessState: payload.readinessState,
      coverage: coverage,
      filterSummary: payload.filterSummary,
      blockers: List<String>.unmodifiable(payload.blockers),
      createdAtIso: payload.createdAtIso,
      schemaVersion: payload.schemaVersion,
      columns: List<GeneratedTerminalReportColumn>.unmodifiable(columns),
      rows: List<Map<String, dynamic>>.unmodifiable(rows),
      metadata: Map<String, dynamic>.unmodifiable(payload.metadata),
      methodNote:
          'Method: structured RoutePayload rows are reproduced exactly after column projection. Missing values remain missing. selectedRows labels and other prose are never parsed into synthetic data.',
    );
  }

  List<GeneratedTerminalReportColumn> _columnsFor(RoutePayload payload) {
    if (payload.columns.isEmpty) return const [];
    final requested = payload.selectedColumns
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final sourceColumns = [
      for (final column in payload.columns)
        GeneratedTerminalReportColumn(
          key: column.key,
          label: column.label,
          dataType: column.dataType,
          unit: column.unit,
        ),
    ];
    if (requested.isEmpty) return sourceColumns;

    final matched = <GeneratedTerminalReportColumn>[];
    final used = <String>{};
    for (final request in requested) {
      for (final column in sourceColumns) {
        if (used.contains(column.key)) continue;
        final key = column.key.trim().toLowerCase();
        final label = column.label.trim().toLowerCase();
        if (request == key || request == label) {
          matched.add(column);
          used.add(column.key);
          break;
        }
      }
    }
    return matched.isEmpty ? sourceColumns : matched;
  }

  Map<String, dynamic> _projectRow(
    Map<String, dynamic> source,
    List<GeneratedTerminalReportColumn> columns,
  ) {
    return <String, dynamic>{
      for (final column in columns)
        column.key: source.containsKey(column.key)
            ? source[column.key]
            : source.containsKey(column.label)
                ? source[column.label]
                : null,
    };
  }

  GeneratedTerminalReportCoverage _coverageFor(
    RoutePayload payload, {
    required bool hasStructuredData,
  }) {
    final readiness = payload.readinessState.trim().toLowerCase();
    final explicitlyBlocked = readiness.contains('block');
    final explicitlyPartial = readiness.contains('partial') ||
        readiness.contains('pending') ||
        readiness.contains('unavailable') ||
        readiness.contains('unknown');
    final sourceMissing = payload.sourceSnapshot.trim().isEmpty;

    if (explicitlyBlocked || (!hasStructuredData && payload.blockers.isNotEmpty)) {
      return GeneratedTerminalReportCoverage.blocked;
    }
    if (payload.blockers.isNotEmpty ||
        !hasStructuredData ||
        sourceMissing ||
        explicitlyPartial) {
      return GeneratedTerminalReportCoverage.partial;
    }
    return GeneratedTerminalReportCoverage.ready;
  }
}
