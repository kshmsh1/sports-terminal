import 'data_rights_envelope.dart';
import 'research_object.dart';
import 'terminal_board.dart';
import 'terminal_metric_definition.dart';
import 'terminal_model_definition.dart';
import 'universal_query.dart';

enum TerminalResearchBundlePermissionState {
  allowed,
  conditional,
  denied,
  unverified,
}

class TerminalResearchBundle {
  const TerminalResearchBundle({
    required this.bundleId,
    required this.createdAtIso,
    required this.research,
    required this.boards,
    required this.metricDefinitions,
    required this.modelDefinitions,
    required this.queries,
    required this.rightsEnvelopes,
    required this.exportState,
    required this.redistributionState,
    required this.blockers,
    required this.fingerprint,
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String bundleId;
  final String createdAtIso;
  final ResearchObject research;
  final List<TerminalBoard> boards;
  final List<TerminalMetricDefinition> metricDefinitions;
  final List<TerminalModelDefinition> modelDefinitions;
  final List<UniversalQuery> queries;
  final List<DataRightsEnvelope> rightsEnvelopes;
  final TerminalResearchBundlePermissionState exportState;
  final TerminalResearchBundlePermissionState redistributionState;
  final List<String> blockers;
  final String fingerprint;

  bool get exportAllowed => exportState == TerminalResearchBundlePermissionState.allowed;
  bool get redistributionAllowed =>
      redistributionState == TerminalResearchBundlePermissionState.allowed;

  Map<String, dynamic> toJson({bool includeFingerprint = true}) => {
        'schemaVersion': schemaVersion,
        'bundleId': bundleId,
        'createdAtIso': createdAtIso,
        'research': research.toJson(),
        'boards': [for (final board in boards) board.toJson()],
        'metricDefinitions': [
          for (final definition in metricDefinitions) definition.toJson(),
        ],
        'modelDefinitions': [
          for (final definition in modelDefinitions) definition.toJson(),
        ],
        'queries': [for (final query in queries) query.toJson()],
        'rightsEnvelopes': [
          for (final envelope in rightsEnvelopes) envelope.toJson(),
        ],
        'exportState': exportState.name,
        'redistributionState': redistributionState.name,
        'blockers': blockers,
        if (includeFingerprint) 'fingerprint': fingerprint,
      };
}
