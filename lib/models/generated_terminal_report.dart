import 'dart:convert';

enum GeneratedTerminalReportCoverage {
  ready,
  partial,
  blocked,
}

extension GeneratedTerminalReportCoverageLabel on GeneratedTerminalReportCoverage {
  String get label {
    switch (this) {
      case GeneratedTerminalReportCoverage.ready:
        return 'READY';
      case GeneratedTerminalReportCoverage.partial:
        return 'PARTIAL';
      case GeneratedTerminalReportCoverage.blocked:
        return 'BLOCKED';
    }
  }
}

class GeneratedTerminalReportColumn {
  const GeneratedTerminalReportColumn({
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
}

class GeneratedTerminalReport {
  const GeneratedTerminalReport({
    required this.title,
    required this.subtitle,
    required this.sourceObjectType,
    required this.sourceObjectId,
    required this.sourceSnapshot,
    required this.readinessState,
    required this.coverage,
    required this.filterSummary,
    required this.blockers,
    required this.createdAtIso,
    required this.schemaVersion,
    required this.columns,
    required this.rows,
    required this.metadata,
    required this.methodNote,
  });

  final String title;
  final String subtitle;
  final String sourceObjectType;
  final String sourceObjectId;
  final String sourceSnapshot;
  final String readinessState;
  final GeneratedTerminalReportCoverage coverage;
  final String filterSummary;
  final List<String> blockers;
  final String createdAtIso;
  final int schemaVersion;
  final List<GeneratedTerminalReportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> metadata;
  final String methodNote;

  int get rowCount => rows.length;
  int get columnCount => columns.length;
  bool get hasStructuredData => rows.isNotEmpty && columns.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'sourceObjectType': sourceObjectType,
        'sourceObjectId': sourceObjectId,
        'sourceSnapshot': sourceSnapshot,
        'readinessState': readinessState,
        'coverage': coverage.label,
        'filterSummary': filterSummary,
        'blockers': blockers,
        'createdAtIso': createdAtIso,
        'schemaVersion': schemaVersion,
        'columns': [for (final column in columns) column.toJson()],
        'rows': rows,
        'metadata': metadata,
        'methodNote': methodNote,
      };

  String encodeJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# ${_markdown(title)}')
      ..writeln()
      ..writeln(_markdown(subtitle))
      ..writeln()
      ..writeln('## Scope')
      ..writeln('- Object: ${_markdown(sourceObjectType)} · ${_markdown(sourceObjectId)}')
      ..writeln('- Coverage: ${coverage.label}')
      ..writeln('- Upstream readiness: ${_markdown(readinessState)}')
      ..writeln('- Filter: ${_markdown(filterSummary.isEmpty ? 'None declared' : filterSummary)}')
      ..writeln('- Structured rows: $rowCount')
      ..writeln('- Structured columns: $columnCount')
      ..writeln()
      ..writeln('## Source & provenance')
      ..writeln('- Source snapshot: ${_markdown(sourceSnapshot.isEmpty ? 'Unavailable' : sourceSnapshot)}')
      ..writeln('- RoutePayload schema: v$schemaVersion')
      ..writeln('- Payload created at: ${_markdown(createdAtIso.isEmpty ? 'Unspecified' : createdAtIso)}')
      ..writeln()
      ..writeln('## Constraints');

    if (blockers.isEmpty) {
      buffer.writeln('- No upstream blockers were declared.');
    } else {
      for (final blocker in blockers) {
        buffer.writeln('- ${_markdown(blocker)}');
      }
    }
    buffer
      ..writeln()
      ..writeln(_markdown(methodNote))
      ..writeln()
      ..writeln('## Data');

    if (!hasStructuredData) {
      buffer.writeln('No structured rows were supplied. The report does not reconstruct data from labels or prose.');
      return buffer.toString().trimRight();
    }

    buffer
      ..writeln('| ${columns.map((column) => _markdown(column.label)).join(' | ')} |')
      ..writeln('| ${columns.map((_) => '---').join(' | ')} |');
    for (final row in rows) {
      buffer.writeln(
        '| ${columns.map((column) => _markdown(_displayValue(row[column.key]))).join(' | ')} |',
      );
    }
    return buffer.toString().trimRight();
  }

  String toTsv() {
    if (columns.isEmpty) return '';
    final buffer = StringBuffer()
      ..writeln(columns.map((column) => _tsv(column.label)).join('\t'));
    for (final row in rows) {
      buffer.writeln(
        columns.map((column) => _tsv(_tsvValue(row[column.key]))).join('\t'),
      );
    }
    return buffer.toString().trimRight();
  }
}

String _displayValue(dynamic value) {
  if (value == null) return '—';
  if (value is String && value.trim().isEmpty) return '—';
  return value.toString();
}

String _tsvValue(dynamic value) {
  if (value == null) return 'NA';
  if (value is String && value.trim().isEmpty) return 'NA';
  return value.toString();
}

String _markdown(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('|', '\\|')
    .replaceAll('\r', ' ')
    .replaceAll('\n', ' ');

String _tsv(String value) => value
    .replaceAll('\t', ' ')
    .replaceAll('\r', ' ')
    .replaceAll('\n', ' ');
