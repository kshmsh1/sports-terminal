import 'dart:convert';

import '../models/data_rights_envelope.dart';
import '../models/research_object.dart';
import '../models/terminal_board.dart';
import '../models/terminal_metric_definition.dart';
import '../models/terminal_model_definition.dart';
import '../models/terminal_research_bundle.dart';
import '../models/universal_query.dart';
import 'terminal_metric_registry.dart';
import 'terminal_model_registry.dart';

class TerminalResearchBundleService {
  const TerminalResearchBundleService({
    this.metricRegistry = const TerminalMetricRegistry(),
    this.modelRegistry = const TerminalModelRegistry(),
  });

  final TerminalMetricRegistry metricRegistry;
  final TerminalModelRegistry modelRegistry;

  TerminalResearchBundle compile({
    required ResearchObject research,
    List<TerminalBoard> boards = const [],
    List<UniversalQuery> queries = const [],
    List<DataRightsEnvelope> rightsEnvelopes = const [],
    List<String> metricKeys = const [],
    List<String> modelIds = const [],
    String? createdAtIso,
    String bundleId = '',
  }) {
    final inferredQueries = queries.isEmpty ? _queriesFromResearch(research) : queries;
    final rights = rightsEnvelopes.isEmpty
        ? _rightsFromResearch(research)
        : rightsEnvelopes;
    final requestedMetrics = <String>{
      ...metricKeys,
      ..._metricKeysFromResearch(research),
    };
    final requestedModels = <String>{
      ...modelIds,
      ..._modelIdsFromResearch(research),
    };
    final metrics = _resolveMetrics(requestedMetrics);
    final models = _resolveModels(requestedModels);
    final exportState = _permissionState(
      rights,
      (envelope) => envelope.export,
    );
    final redistributionState = _permissionState(
      rights,
      (envelope) => envelope.redistribution,
    );
    final blockers = <String>[
      if (research.status.toLowerCase() == 'blocked') 'research-object-blocked',
      if (rights.isEmpty) 'rights-unverified',
      if (exportState == TerminalResearchBundlePermissionState.denied)
        'export-rights-denied',
      if (redistributionState == TerminalResearchBundlePermissionState.denied)
        'redistribution-rights-denied',
    ];
    final timestamp = createdAtIso ?? DateTime.now().toUtc().toIso8601String();
    final id = bundleId.trim().isEmpty
        ? '${research.id}@${research.version}'
        : bundleId.trim();
    final provisional = TerminalResearchBundle(
      bundleId: id,
      createdAtIso: timestamp,
      research: research,
      boards: List<TerminalBoard>.unmodifiable(boards),
      metricDefinitions: List<TerminalMetricDefinition>.unmodifiable(metrics),
      modelDefinitions: List<TerminalModelDefinition>.unmodifiable(models),
      queries: List<UniversalQuery>.unmodifiable(inferredQueries),
      rightsEnvelopes: List<DataRightsEnvelope>.unmodifiable(rights),
      exportState: exportState,
      redistributionState: redistributionState,
      blockers: List<String>.unmodifiable(blockers),
      fingerprint: '',
    );
    final fingerprint = _fnv1a32(jsonEncode(_fingerprintPayload(provisional)));
    return TerminalResearchBundle(
      bundleId: provisional.bundleId,
      createdAtIso: provisional.createdAtIso,
      research: provisional.research,
      boards: provisional.boards,
      metricDefinitions: provisional.metricDefinitions,
      modelDefinitions: provisional.modelDefinitions,
      queries: provisional.queries,
      rightsEnvelopes: provisional.rightsEnvelopes,
      exportState: provisional.exportState,
      redistributionState: provisional.redistributionState,
      blockers: provisional.blockers,
      fingerprint: fingerprint,
    );
  }

  String encode(TerminalResearchBundle bundle) =>
      const JsonEncoder.withIndent('  ').convert(bundle.toJson());

  List<String> integrityFailures(TerminalResearchBundle bundle) {
    final failures = <String>[];
    if (bundle.bundleId.trim().isEmpty) failures.add('bundle id is required');
    if (bundle.research.id.trim().isEmpty) failures.add('research id is required');
    if (bundle.fingerprint.trim().isEmpty) failures.add('fingerprint is required');
    if (bundle.metricDefinitions.any((item) => metricRegistry.byKey(item.key) == null)) {
      failures.add('bundle contains an unregistered metric definition');
    }
    if (bundle.modelDefinitions.any((item) => modelRegistry.byId(item.id) == null)) {
      failures.add('bundle contains an unregistered model definition');
    }
    final expected = _fnv1a32(jsonEncode(_fingerprintPayload(bundle)));
    if (expected != bundle.fingerprint) failures.add('bundle fingerprint mismatch');
    return failures;
  }

  Map<String, dynamic> _fingerprintPayload(TerminalResearchBundle bundle) {
    final payload = Map<String, dynamic>.from(
      bundle.toJson(includeFingerprint: false),
    );
    // Wrapper identity/timing do not alter the digest of the research package.
    payload.remove('bundleId');
    payload.remove('createdAtIso');
    return payload;
  }

  List<String> _metricKeysFromResearch(ResearchObject research) => [
        for (final item in research.computedMetrics)
          if ((item['key']?.toString() ?? '').trim().isNotEmpty)
            item['key'].toString(),
      ];

  List<String> _modelIdsFromResearch(ResearchObject research) {
    final raw = research.artifactPayload['modelIds'];
    if (raw is! List) return const [];
    return [for (final value in raw) value.toString()];
  }

  List<UniversalQuery> _queriesFromResearch(ResearchObject research) {
    final queries = <UniversalQuery>[];
    for (final raw in research.queryDefinitions) {
      if (!raw.containsKey('objectType')) continue;
      try {
        queries.add(UniversalQuery.fromJson(raw));
      } catch (_) {
        // Non-UniversalQuery research definitions stay attached to ResearchObject only.
      }
    }
    return queries;
  }

  List<DataRightsEnvelope> _rightsFromResearch(ResearchObject research) {
    final rights = <DataRightsEnvelope>[];
    for (final raw in research.rightsEnvelopes) {
      try {
        rights.add(DataRightsEnvelope.fromJson(raw));
      } catch (_) {
        // Malformed rights metadata is not upgraded into permission.
      }
    }
    return rights;
  }

  List<TerminalMetricDefinition> _resolveMetrics(Set<String> requested) {
    final resolved = <String>{};
    void add(String key) {
      final definition = metricRegistry.resolve(key);
      if (definition == null || !resolved.add(definition.key)) return;
      for (final dependency in definition.dependencies) {
        add(dependency);
      }
    }
    for (final key in requested) {
      add(key);
    }
    return [
      for (final definition in TerminalMetricRegistry.definitions)
        if (resolved.contains(definition.key)) definition,
    ];
  }

  List<TerminalModelDefinition> _resolveModels(Set<String> requested) {
    final resolved = <String>{};
    void add(String id) {
      final definition = modelRegistry.byId(id);
      if (definition == null || !resolved.add(definition.id)) return;
      for (final dependency in definition.dependencies) {
        add(dependency);
      }
    }
    for (final id in requested) {
      add(id);
    }
    return [
      for (final definition in TerminalModelRegistry.definitions)
        if (resolved.contains(definition.id)) definition,
    ];
  }

  TerminalResearchBundlePermissionState _permissionState(
    List<DataRightsEnvelope> rights,
    TerminalDataPermission Function(DataRightsEnvelope envelope) select,
  ) {
    if (rights.isEmpty) return TerminalResearchBundlePermissionState.unverified;
    var conditional = false;
    var unknown = false;
    for (final envelope in rights) {
      final permission = select(envelope);
      if (permission == TerminalDataPermission.denied) {
        return TerminalResearchBundlePermissionState.denied;
      }
      if (permission == TerminalDataPermission.conditional) conditional = true;
      if (permission == TerminalDataPermission.unknown) unknown = true;
    }
    if (unknown) return TerminalResearchBundlePermissionState.unverified;
    if (conditional) return TerminalResearchBundlePermissionState.conditional;
    return TerminalResearchBundlePermissionState.allowed;
  }
}

String _fnv1a32(String input) {
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
