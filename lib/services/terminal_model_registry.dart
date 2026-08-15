import '../models/terminal_model_definition.dart';
import 'terminal_metric_registry.dart';

class TerminalModelRegistry {
  const TerminalModelRegistry({this.metricRegistry = const TerminalMetricRegistry()});

  final TerminalMetricRegistry metricRegistry;

  static const definitions = <TerminalModelDefinition>[
    TerminalModelDefinition(
      id: 'observed-score-flow-v1',
      name: 'Observed Score Flow',
      category: 'Game Intelligence',
      version: '1.0',
      status: 'implemented',
      inputObjects: ['GameEvent'],
      inputMetrics: ['observed_score_margin'],
      outputs: ['score progression', 'lead changes', 'ties', 'largest observed leads', 'scoring runs'],
      method: 'Use explicit event score states in sequence order. No win-probability or possession model is inferred.',
      limitations: 'Completeness is bounded by exposed score-state events.',
      sourcePolicy: 'Requires source-backed event rows and explicit scores.',
      releasePolicy: 'Retain parent-game release provenance.',
      tags: ['game', 'events', 'observed'],
    ),
    TerminalModelDefinition(
      id: 'rolling-trend-v1',
      name: 'Rolling Trend',
      category: 'Time Series',
      version: '1.0',
      status: 'implemented',
      inputObjects: ['PlayerGame', 'TeamGame'],
      inputMetrics: ['rolling_average'],
      outputs: ['raw series', 'rolling series', 'recent-window comparison'],
      method: 'Order observed games chronologically and calculate explicit rolling windows over available values.',
      limitations: 'Missing observations remain gaps; no interpolation.',
      sourcePolicy: 'Requires canonical dated game observations.',
      releasePolicy: 'Retain series release provenance.',
      tags: ['trend', 'player', 'team'],
    ),
    TerminalModelDefinition(
      id: 'season-standings-derived-v1',
      name: 'Scored-Game Standings Projection',
      category: 'Season Intelligence',
      version: '1.0',
      status: 'implemented',
      inputObjects: ['Game', 'Season', 'Team'],
      inputMetrics: ['points_for', 'points_against', 'point_differential'],
      outputs: ['wins', 'losses', 'record', 'points for', 'points against', 'differential'],
      method: 'Aggregate only completed/scored canonical games inside an explicit season and season type.',
      limitations: 'Scheduled or unscored games are visible but non-decisional.',
      sourcePolicy: 'Requires canonical game and team identity plus explicit scores.',
      releasePolicy: 'Retain the season/game release context.',
      tags: ['season', 'standings'],
    ),
    TerminalModelDefinition(
      id: 'career-alignment-v1',
      name: 'Career-Year Alignment',
      category: 'Player Research',
      version: '1.0',
      status: 'implemented',
      inputObjects: ['PlayerCareer', 'PlayerSeason'],
      inputMetrics: ['career_year_index'],
      outputs: ['calendar alignment', 'career-year alignment', 'peak windows', 'season-type deltas'],
      method: 'Align exact observed seasons by calendar or ordinal career year without era/pace normalization.',
      limitations: 'Does not claim cross-era equivalence beyond the selected observed metrics.',
      sourcePolicy: 'Requires canonical historical player-season identity.',
      releasePolicy: 'Retain each career series release.',
      tags: ['career', 'compare'],
    ),
    TerminalModelDefinition(
      id: 'route-payload-report-v1',
      name: 'RoutePayload Report Generator',
      category: 'Research Workflow',
      version: '1.0',
      status: 'implemented',
      inputObjects: ['RoutePayload'],
      inputMetrics: [],
      outputs: ['report preview', 'Markdown', 'JSON', 'TSV'],
      method: 'Project exact structured payload rows and selected columns into a governed report shell.',
      limitations: 'Does not generate unsupported narrative sports conclusions.',
      sourcePolicy: 'Structured RoutePayload rows are the only tabular source.',
      releasePolicy: 'Preserve source snapshot, blockers and payload release metadata.',
      tags: ['reports', 'reproducibility'],
    ),
    TerminalModelDefinition(
      id: 'rights-intersection-v1',
      name: 'Data Rights Intersection',
      category: 'Governance',
      version: '1.0',
      status: 'implemented',
      inputObjects: ['DataRightsEnvelope'],
      inputMetrics: [],
      outputs: ['display permission', 'export permission', 'API permission', 'redistribution permission', 'territory intersection'],
      method: 'Derived rights take the most restrictive permission and deterministic territory intersection of all inputs.',
      limitations: 'Unknown rights remain unknown; the model does not invent licenses.',
      sourcePolicy: 'Requires explicit rights envelopes.',
      releasePolicy: 'Retain source revision and ingestion-release context where present.',
      tags: ['rights', 'governance'],
    ),
    TerminalModelDefinition(
      id: 'watch-threshold-v1',
      name: 'Deterministic Watch Threshold',
      category: 'Monitoring',
      version: '1.0',
      status: 'implemented',
      inputObjects: ['WatchRule', 'MetricObservation'],
      inputMetrics: [],
      outputs: ['triggered', 'not triggered', 'unavailable'],
      method: 'Evaluate a declared comparison operator against explicit current and, when required, previous numeric observations.',
      limitations: 'No background delivery or source polling is implied.',
      sourcePolicy: 'Requires explicit numeric observations supplied to the evaluator.',
      releasePolicy: 'Rule and observation release labels remain visible.',
      tags: ['watch', 'alerts'],
    ),
    TerminalModelDefinition(
      id: 'research-bundle-v1',
      name: 'Portable Research Bundle',
      category: 'Research Workflow',
      version: '1.0',
      status: 'implemented',
      inputObjects: ['ResearchObject', 'TerminalBoard', 'UniversalQuery', 'DataRightsEnvelope'],
      inputMetrics: [],
      outputs: ['portable JSON bundle', 'dependency manifest', 'rights gate', 'fingerprint'],
      method: 'Compile immutable research, optional boards/queries and explicit registry dependencies into one deterministic package.',
      limitations: 'Serialization does not itself grant export or redistribution rights.',
      sourcePolicy: 'Carries source and rights metadata supplied by the upstream research object.',
      releasePolicy: 'Preserve the exact data release recorded by the research object.',
      dependencies: ['route-payload-report-v1', 'rights-intersection-v1'],
      tags: ['bundle', 'research', 'portability'],
    ),
  ];

  TerminalModelDefinition? byId(String id) {
    final normalized = id.trim().toLowerCase();
    for (final definition in definitions) {
      if (definition.id.toLowerCase() == normalized) return definition;
    }
    return null;
  }

  List<TerminalModelDefinition> search(
    String query, {
    String category = '',
    String status = '',
  }) {
    final normalized = query.trim().toLowerCase();
    final normalizedCategory = category.trim().toLowerCase();
    final normalizedStatus = status.trim().toLowerCase();
    return definitions.where((definition) {
      final haystack = <String>[
        definition.id,
        definition.name,
        definition.category,
        definition.method,
        definition.limitations,
        ...definition.tags,
        ...definition.inputObjects,
        ...definition.inputMetrics,
        ...definition.outputs,
      ].join(' ').toLowerCase();
      return (normalized.isEmpty || haystack.contains(normalized)) &&
          (normalizedCategory.isEmpty || definition.category.toLowerCase() == normalizedCategory) &&
          (normalizedStatus.isEmpty || definition.status.toLowerCase() == normalizedStatus);
    }).toList(growable: false);
  }

  List<TerminalModelDefinition> dependenciesOf(String id) {
    final definition = byId(id);
    if (definition == null) return const [];
    return [
      for (final dependency in definition.dependencies)
        if (byId(dependency) != null) byId(dependency)!,
    ];
  }

  List<String> integrityFailures() {
    final failures = <String>[];
    final ids = <String>{};
    for (final definition in definitions) {
      if (definition.id.trim().isEmpty) {
        failures.add('model id must not be empty');
        continue;
      }
      if (!ids.add(definition.id)) failures.add('duplicate model id: ${definition.id}');
      for (final metric in definition.inputMetrics) {
        if (metricRegistry.byKey(metric) == null) {
          failures.add('${definition.id} references unknown metric: $metric');
        }
      }
      for (final dependency in definition.dependencies) {
        if (!definitions.any((candidate) => candidate.id == dependency)) {
          failures.add('${definition.id} missing model dependency: $dependency');
        }
      }
    }

    final visiting = <String>{};
    final visited = <String>{};
    bool visit(String id) {
      if (visiting.contains(id)) return true;
      if (visited.contains(id)) return false;
      visiting.add(id);
      final definition = byId(id);
      if (definition != null) {
        for (final dependency in definition.dependencies) {
          if (visit(dependency)) return true;
        }
      }
      visiting.remove(id);
      visited.add(id);
      return false;
    }

    for (final definition in definitions) {
      visiting.clear();
      if (visit(definition.id)) {
        failures.add('model dependency cycle involving ${definition.id}');
        break;
      }
    }
    return failures;
  }
}
