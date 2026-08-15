import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/models/data_rights_envelope.dart';
import 'package:sports_terminal/models/generated_terminal_report.dart';
import 'package:sports_terminal/models/research_object.dart';
import 'package:sports_terminal/models/terminal_board.dart';
import 'package:sports_terminal/models/terminal_research_bundle.dart';
import 'package:sports_terminal/models/terminal_watch_rule.dart';
import 'package:sports_terminal/services/generated_report_research_service.dart';
import 'package:sports_terminal/services/research_object_service.dart';
import 'package:sports_terminal/services/terminal_board_store.dart';
import 'package:sports_terminal/services/terminal_metric_registry.dart';
import 'package:sports_terminal/services/terminal_model_registry.dart';
import 'package:sports_terminal/services/terminal_research_bundle_service.dart';
import 'package:sports_terminal/services/terminal_watch_rule_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('generated report fingerprint is deterministic and content-sensitive', () {
    final first = _report();
    final same = _report();
    final changed = _report(rows: const [
      {'player': 'A', 'pts': 29},
    ]);

    expect(first.contentFingerprint, same.contentFingerprint);
    expect(first.contentFingerprint, isNot(changed.contentFingerprint));
    expect(first.toMarkdown(), contains('Fingerprint: ${first.contentFingerprint}'));
  });

  test('generated report becomes a release-aware immutable research artifact', () {
    const bridge = GeneratedReportResearchService();
    final research = bridge.fromReport(_report(), authorId: 'analyst-1');

    expect(research.schemaVersion, 2);
    expect(research.artifactType, 'generated-report');
    expect(research.dataRelease, 'release-2026-08-15');
    expect(research.contentFingerprint, _report().contentFingerprint);
    expect(research.artifactPayload['rows'], isNotEmpty);
    expect(research.artifactPayload['modelIds'], ['route-payload-report-v1']);
    expect(research.computedMetrics.map((item) => item['key']), contains('pts'));
    expect(research.computedMetrics.map((item) => item['key']), isNot(contains('mystery')));
  });

  test('research v1 JSON remains backward compatible', () {
    final research = ResearchObject.fromJson({
      'id': 'legacy',
      'version': 3,
      'title': 'Legacy Research',
      'authorId': 'a',
      'createdAtIso': '2026-01-01T00:00:00Z',
      'dataRelease': 'r1',
      'queryDefinitions': <Object>[],
      'selectedEntities': <Object>[],
      'filters': <String, Object>{},
      'computedMetrics': <Object>[],
      'chartSpecs': <Object>[],
      'methodNotes': 'legacy method',
      'citations': <Object>[],
    });

    expect(research.schemaVersion, 1);
    expect(research.artifactType, 'research');
    expect(research.tags, isEmpty);
    expect(research.revisionKey, 'legacy@3');
  });

  test('fingerprint save deduplicates durable research', () async {
    const service = ResearchObjectService();
    const bridge = GeneratedReportResearchService();
    final first = bridge.fromReport(_report(), authorId: 'analyst-1');
    final duplicate = bridge.fromReport(
      _report(),
      authorId: 'analyst-2',
      id: 'different-id-same-content',
    );

    final saved = await service.saveIfNewFingerprint(first);
    final deduped = await service.saveIfNewFingerprint(duplicate);
    final all = await service.loadAll();

    expect(saved.revisionKey, first.revisionKey);
    expect(deduped.revisionKey, first.revisionKey);
    expect(all, hasLength(1));
  });

  test('research revisions are immutable and lineage remains ordered', () async {
    const service = ResearchObjectService();
    final first = _research(id: 'lineage', version: 1, fingerprint: 'fp-1');
    await service.save(first);
    final second = service.revise(first, status: 'reviewed', contentFingerprint: 'fp-2');
    await service.save(second);

    expect(second.version, 2);
    expect(second.previousRevisionKey, 'lineage@1');
    expect((await service.latest('lineage'))?.revisionKey, 'lineage@2');
    expect((await service.lineage('lineage')).map((item) => item.version), [1, 2]);
    expect(() => service.save(second), throwsA(isA<StateError>()));
  });

  test('reproduce and fork preserve extended research metadata', () {
    const service = ResearchObjectService();
    final source = _research(id: 'source', version: 4, fingerprint: 'abc123');
    final reproduced = service.reproduce(source);
    final fork = service.fork(
      source,
      newId: 'forked',
      authorId: 'new-author',
      dataRelease: 'ignored-when-currentData-false',
    );

    expect(reproduced.artifactPayload, source.artifactPayload);
    expect(reproduced.rightsEnvelopes, source.rightsEnvelopes);
    expect(fork.parentResearchId, 'source');
    expect(fork.parentVersion, 4);
    expect(fork.dataRelease, source.dataRelease);
    expect(fork.contentFingerprint, 'abc123');
    expect(fork.status, 'draft');
  });

  test('metric registry resolves aliases and dependency graph is valid', () {
    const registry = TerminalMetricRegistry();

    expect(registry.resolve('points')?.key, 'pts');
    expect(registry.resolve('diff')?.key, 'point_differential');
    expect(
      registry.dependenciesOf('point_differential').map((item) => item.key),
      containsAll(['points_for', 'points_against']),
    );
    expect(registry.search('score margin'), isNotEmpty);
    expect(registry.integrityFailures(), isEmpty);
  });

  test('model registry exposes implemented dependencies with clean integrity', () {
    const registry = TerminalModelRegistry();

    expect(registry.byId('observed-score-flow-v1')?.status, 'implemented');
    expect(registry.search('rights'), isNotEmpty);
    expect(
      registry.dependenciesOf('research-bundle-v1').map((item) => item.id),
      containsAll(['route-payload-report-v1', 'rights-intersection-v1']),
    );
    expect(registry.integrityFailures(), isEmpty);
  });

  test('watch engine evaluates direct and change thresholds', () {
    const service = TerminalWatchRuleService();
    final direct = _watch(
      id: 'direct',
      op: TerminalWatchOperator.greaterThanOrEqual,
      threshold: 25,
    );
    final change = _watch(
      id: 'change',
      op: TerminalWatchOperator.increaseBy,
      threshold: 4,
    );

    expect(
      service.evaluate(direct, currentValue: 25).state,
      TerminalWatchEvaluationState.triggered,
    );
    expect(
      service.evaluate(change, currentValue: 15, previousValue: 10).state,
      TerminalWatchEvaluationState.triggered,
    );
    expect(
      service.evaluate(change, currentValue: 12, previousValue: 10).state,
      TerminalWatchEvaluationState.notTriggered,
    );
  });

  test('watch engine fails closed on missing observations', () {
    const service = TerminalWatchRuleService();
    final change = _watch(
      id: 'missing',
      op: TerminalWatchOperator.absoluteChangeBy,
      threshold: 3,
    );

    expect(
      service.evaluate(change, currentValue: null).state,
      TerminalWatchEvaluationState.unavailable,
    );
    final missingBaseline = service.evaluate(change, currentValue: 8);
    expect(missingBaseline.state, TerminalWatchEvaluationState.unavailable);
    expect(missingBaseline.reason, contains('explicit previous observation'));
  });

  test('watch rules and evaluation history persist locally', () async {
    const service = TerminalWatchRuleService();
    final rule = _watch(
      id: 'persisted',
      op: TerminalWatchOperator.greaterThan,
      threshold: 20,
    );
    await service.save(rule);
    final evaluation = service.evaluate(
      rule,
      currentValue: 24,
      evaluatedAtIso: '2026-08-15T18:00:00Z',
    );
    await service.recordEvaluation(evaluation);

    expect((await service.loadAll()).single.id, 'persisted');
    expect((await service.loadEvaluationHistory()).single.triggered, isTrue);
  });

  test('board append is idempotent and clone strips collaboration/live state', () async {
    const store = TerminalBoardStore();
    const panel = TerminalBoardPanel(
      id: 'p1',
      kind: 'research-report',
      title: 'Research',
      payload: {'researchRevisionKey': 'r@1'},
    );
    final first = await store.appendPanel(
      boardId: 'board',
      boardTitle: 'Board',
      panel: panel,
    );
    final second = await store.appendPanel(
      boardId: 'board',
      boardTitle: 'Board',
      panel: panel,
    );
    final collaborative = first.copyWith(
      collaborators: const ['analyst-2'],
      liveRefresh: true,
    );
    final clone = await store.cloneBoard(
      collaborative,
      newId: 'clone',
      newTitle: 'Clone',
    );

    expect(second.panels, hasLength(1));
    expect(clone.collaborators, isEmpty);
    expect(clone.liveRefresh, isFalse);
    expect(clone.panels.single.payload['researchRevisionKey'], 'r@1');
  });

  test('bundle fingerprint is deterministic and dependency-complete', () {
    const service = TerminalResearchBundleService();
    final research = _research(
      id: 'bundle',
      version: 1,
      fingerprint: 'research-fp',
      computedMetrics: const [
        {'key': 'point_differential'},
      ],
      artifactPayload: const {
        'modelIds': ['research-bundle-v1'],
      },
    );
    const rights = DataRightsEnvelope(
      sourceId: 'licensed-source',
      licenseClass: TerminalLicenseClass.licensedThirdParty,
      display: TerminalDataPermission.allowed,
      export: TerminalDataPermission.allowed,
      api: TerminalDataPermission.conditional,
      redistribution: TerminalDataPermission.conditional,
    );
    final first = service.compile(
      research: research,
      rightsEnvelopes: const [rights],
      createdAtIso: '2026-08-15T18:00:00Z',
    );
    final second = service.compile(
      research: research,
      rightsEnvelopes: const [rights],
      createdAtIso: '2026-08-15T18:00:00Z',
    );

    expect(first.fingerprint, second.fingerprint);
    expect(first.exportState, TerminalResearchBundlePermissionState.allowed);
    expect(
      first.redistributionState,
      TerminalResearchBundlePermissionState.conditional,
    );
    expect(
      first.metricDefinitions.map((item) => item.key),
      containsAll(['point_differential', 'points_for', 'points_against']),
    );
    expect(
      first.modelDefinitions.map((item) => item.id),
      containsAll([
        'research-bundle-v1',
        'route-payload-report-v1',
        'rights-intersection-v1',
      ]),
    );
    expect(service.integrityFailures(first), isEmpty);
  });

  test('bundle rights fail closed for unknown and denied permissions', () {
    const service = TerminalResearchBundleService();
    final research = _research(id: 'rights', version: 1, fingerprint: 'rfp');

    final unknown = service.compile(
      research: research,
      createdAtIso: '2026-08-15T18:00:00Z',
    );
    expect(
      unknown.exportState,
      TerminalResearchBundlePermissionState.unverified,
    );
    expect(unknown.blockers, contains('rights-unverified'));

    const deniedRights = DataRightsEnvelope(
      sourceId: 'restricted',
      licenseClass: TerminalLicenseClass.licensedThirdParty,
      display: TerminalDataPermission.allowed,
      export: TerminalDataPermission.denied,
      api: TerminalDataPermission.denied,
      redistribution: TerminalDataPermission.denied,
    );
    final denied = service.compile(
      research: research,
      rightsEnvelopes: const [deniedRights],
      createdAtIso: '2026-08-15T18:00:00Z',
    );
    expect(denied.exportState, TerminalResearchBundlePermissionState.denied);
    expect(
      denied.redistributionState,
      TerminalResearchBundlePermissionState.denied,
    );
    expect(denied.blockers, contains('export-rights-denied'));
  });
}

GeneratedTerminalReport _report({
  List<Map<String, dynamic>> rows = const [
    {'player': 'A', 'pts': 28, 'mystery': 5},
  ],
}) {
  return GeneratedTerminalReport(
    title: 'Scoring Report',
    subtitle: 'Source-backed scoring rows.',
    sourceObjectType: 'PlayerStatTable',
    sourceObjectId: 'leaders',
    sourceSnapshot: 'snapshot-1',
    readinessState: 'Ready',
    coverage: GeneratedTerminalReportCoverage.ready,
    filterSummary: 'season=2025-26',
    blockers: const [],
    createdAtIso: '2026-08-15T17:00:00Z',
    schemaVersion: 2,
    columns: const [
      GeneratedTerminalReportColumn(key: 'player', label: 'Player'),
      GeneratedTerminalReportColumn(key: 'pts', label: 'Points', dataType: 'number'),
      GeneratedTerminalReportColumn(key: 'mystery', label: 'Mystery', dataType: 'number'),
    ],
    rows: rows,
    metadata: const {
      'dataRelease': 'release-2026-08-15',
    },
    methodNote: 'Exact structured rows only.',
  );
}

ResearchObject _research({
  required String id,
  required int version,
  required String fingerprint,
  List<Map<String, dynamic>> computedMetrics = const [],
  Map<String, dynamic> artifactPayload = const {},
}) {
  return ResearchObject(
    id: id,
    version: version,
    title: 'Research $id',
    authorId: 'author',
    createdAtIso: '2026-08-15T17:00:00Z',
    dataRelease: 'release-1',
    queryDefinitions: const [],
    selectedEntities: const [
      {'objectType': 'Player', 'objectId': 'p1'},
    ],
    filters: const {},
    computedMetrics: computedMetrics,
    chartSpecs: const [],
    methodNotes: 'Observed inputs only.',
    citations: const [],
    artifactType: 'generated-report',
    artifactPayload: artifactPayload,
    tags: const ['research'],
    status: 'ready',
    contentFingerprint: fingerprint,
    rightsEnvelopes: const [],
    summary: 'Research summary',
  );
}

TerminalWatchRule _watch({
  required String id,
  required TerminalWatchOperator op,
  required double threshold,
}) {
  return TerminalWatchRule(
    id: id,
    title: 'Watch $id',
    metricKey: 'pts',
    op: op,
    threshold: threshold,
    createdAtIso: '2026-08-15T17:00:00Z',
  );
}
