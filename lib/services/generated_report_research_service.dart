import '../models/generated_terminal_report.dart';
import '../models/research_object.dart';
import 'terminal_metric_registry.dart';

class GeneratedReportResearchService {
  const GeneratedReportResearchService({
    this.metricRegistry = const TerminalMetricRegistry(),
  });

  final TerminalMetricRegistry metricRegistry;

  ResearchObject fromReport(
    GeneratedTerminalReport report, {
    required String authorId,
    String id = '',
    String? createdAtIso,
  }) {
    final release = _releaseFor(report);
    final rights = _rightsFor(report);
    final queryDefinitions = _queriesFor(report);
    final registeredMetrics = <Map<String, dynamic>>[];
    for (final column in report.columns) {
      final definition = metricRegistry.resolve(column.key) ?? metricRegistry.resolve(column.label);
      if (definition == null) continue;
      if (registeredMetrics.any((item) => item['key'] == definition.key)) continue;
      registeredMetrics.add({
        'key': definition.key,
        'name': definition.name,
        'unit': definition.unit,
        'method': definition.method,
      });
    }
    final fingerprint = report.contentFingerprint;
    final researchId = id.trim().isEmpty ? 'report-$fingerprint' : id.trim();
    final created = createdAtIso ?? DateTime.now().toUtc().toIso8601String();
    return ResearchObject(
      id: researchId,
      version: 1,
      title: report.title,
      authorId: authorId,
      createdAtIso: created,
      dataRelease: release,
      queryDefinitions: queryDefinitions,
      selectedEntities: [
        {
          'objectType': report.sourceObjectType,
          'objectId': report.sourceObjectId,
          'label': report.title,
        },
      ],
      filters: {
        'summary': report.filterSummary,
      },
      computedMetrics: registeredMetrics,
      chartSpecs: const [],
      methodNotes: report.methodNote,
      citations: report.sourceSnapshot.trim().isEmpty
          ? const []
          : [
              {
                'sourceSnapshot': report.sourceSnapshot,
                'release': release,
              },
            ],
      schemaVersion: 2,
      artifactType: 'generated-report',
      artifactPayload: {
        ...report.toJson(),
        'modelIds': const ['route-payload-report-v1'],
      },
      tags: [
        'report',
        report.sourceObjectType.toLowerCase(),
        report.coverage.label.toLowerCase(),
      ],
      status: report.coverage.label.toLowerCase(),
      contentFingerprint: fingerprint,
      rightsEnvelopes: rights,
      summary: report.subtitle,
    );
  }

  String _releaseFor(GeneratedTerminalReport report) {
    for (final key in const ['dataRelease', 'release', 'releaseId', 'ingestionRelease']) {
      final value = report.metadata[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return report.sourceSnapshot.trim();
  }

  List<Map<String, dynamic>> _rightsFor(GeneratedTerminalReport report) {
    final raw = report.metadata['rightsEnvelopes'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          item.map((key, value) => MapEntry(key.toString(), value)),
    ];
  }

  List<Map<String, dynamic>> _queriesFor(GeneratedTerminalReport report) {
    final raw = report.metadata['universalQuery'] ?? report.metadata['query'];
    if (raw is! Map) return const [];
    return [raw.map((key, value) => MapEntry(key.toString(), value))];
  }
}
