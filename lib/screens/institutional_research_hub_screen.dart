import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/research_object.dart';
import '../models/terminal_board.dart';
import '../models/terminal_metric_definition.dart';
import '../models/terminal_model_definition.dart';
import '../models/terminal_research_bundle.dart';
import '../models/terminal_watch_rule.dart';
import '../services/research_object_service.dart';
import '../services/terminal_board_store.dart';
import '../services/terminal_metric_registry.dart';
import '../services/terminal_model_registry.dart';
import '../services/terminal_research_bundle_service.dart';
import '../services/terminal_watch_rule_service.dart';
import '../widgets/terminal_primitives.dart';

class InstitutionalResearchHubScreen extends StatefulWidget {
  const InstitutionalResearchHubScreen({
    super.key,
    required this.session,
    this.researchService = const ResearchObjectService(),
    this.boardStore = const TerminalBoardStore(),
    this.metricRegistry = const TerminalMetricRegistry(),
    this.modelRegistry = const TerminalModelRegistry(),
    this.watchService = const TerminalWatchRuleService(),
    this.bundleService = const TerminalResearchBundleService(),
  });

  final AppSession session;
  final ResearchObjectService researchService;
  final TerminalBoardStore boardStore;
  final TerminalMetricRegistry metricRegistry;
  final TerminalModelRegistry modelRegistry;
  final TerminalWatchRuleService watchService;
  final TerminalResearchBundleService bundleService;

  @override
  State<InstitutionalResearchHubScreen> createState() =>
      _InstitutionalResearchHubScreenState();
}

class _InstitutionalResearchHubScreenState
    extends State<InstitutionalResearchHubScreen> {
  final _researchQueryController = TextEditingController();
  final _metricQueryController = TextEditingController();
  final _modelQueryController = TextEditingController();
  final _watchTitleController = TextEditingController();
  final _watchMetricController = TextEditingController(text: 'pts');
  final _watchThresholdController = TextEditingController();
  final _watchCurrentController = TextEditingController();
  final _watchPreviousController = TextEditingController();

  List<ResearchObject> _research = const [];
  List<TerminalWatchRule> _watches = const [];
  List<TerminalWatchEvaluation> _watchHistory = const [];
  TerminalWatchOperator _watchOperator = TerminalWatchOperator.greaterThan;
  String _selectedWatchId = '';
  String _statusMessage = '';
  String _researchQuery = '';
  String _metricQuery = '';
  String _modelQuery = '';
  bool _loading = true;
  TerminalResearchBundle? _bundle;
  String _bundlePreview = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _researchQueryController.dispose();
    _metricQueryController.dispose();
    _modelQueryController.dispose();
    _watchTitleController.dispose();
    _watchMetricController.dispose();
    _watchThresholdController.dispose();
    _watchCurrentController.dispose();
    _watchPreviousController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final values = await Future.wait<dynamic>([
      widget.researchService.latestAll(),
      widget.watchService.loadAll(),
      widget.watchService.loadEvaluationHistory(),
    ]);
    if (!mounted) return;
    final watches = values[1] as List<TerminalWatchRule>;
    setState(() {
      _research = values[0] as List<ResearchObject>;
      _watches = watches;
      _watchHistory = values[2] as List<TerminalWatchEvaluation>;
      if (_selectedWatchId.isEmpty ||
          !watches.any((item) => item.id == _selectedWatchId)) {
        _selectedWatchId = watches.isEmpty ? '' : watches.first.id;
      }
      _loading = false;
    });
  }

  Future<void> _fork(ResearchObject source) async {
    if (source.dataRelease.trim().isEmpty) {
      setState(() {
        _statusMessage =
            'Fork blocked: this research object has no explicit data release to preserve.';
      });
      return;
    }
    final fork = widget.researchService.fork(
      source,
      newId:
          '${source.id}-fork-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      authorId: widget.session.userId,
      dataRelease: source.dataRelease,
    );
    await widget.researchService.save(fork);
    if (!mounted) return;
    setState(() => _statusMessage = 'Fork saved: ${fork.revisionKey}');
    await _reload();
  }

  Future<void> _reviseStatus(ResearchObject source, String status) async {
    final revision = widget.researchService.revise(source, status: status);
    await widget.researchService.save(revision);
    if (!mounted) return;
    setState(() => _statusMessage =
        'Immutable revision saved: ${revision.revisionKey} · $status');
    await _reload();
  }

  void _reproduce(ResearchObject source) {
    final reproduced = widget.researchService.reproduce(source);
    setState(() {
      _statusMessage =
          'Reproduced ${reproduced.revisionKey} against exact release ${reproduced.releaseLabel}.';
    });
  }

  Future<void> _addResearchToBoard(ResearchObject research) async {
    final panel = TerminalBoardPanel(
      id: 'research-${research.revisionKey}',
      kind: research.artifactType,
      title: research.title,
      payload: {
        'researchRevisionKey': research.revisionKey,
        'contentFingerprint': research.contentFingerprint,
        'dataRelease': research.dataRelease,
        'status': research.status,
        'research': research.toJson(),
      },
      width: 2,
      height: 2,
    );
    final board = await widget.boardStore.appendPanel(
      boardId: 'institutional-research-board',
      boardTitle: 'Institutional Research Board',
      description: 'Durable Sports Terminal research objects and reports.',
      panel: panel,
    );
    if (!mounted) return;
    setState(() => _statusMessage =
        'Added ${research.revisionKey} to ${board.title} (${board.panels.length} panels).');
  }

  Future<void> _buildBundle(ResearchObject research) async {
    final boards = await widget.boardStore.loadAll();
    final bundle = widget.bundleService.compile(
      research: research,
      boards: boards
          .where((board) => board.panels.any((panel) =>
              panel.payload['researchRevisionKey'] == research.revisionKey))
          .toList(growable: false),
    );
    final failures = widget.bundleService.integrityFailures(bundle);
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _bundlePreview = widget.bundleService.encode(bundle);
      _statusMessage = failures.isEmpty
          ? 'Portable bundle compiled: ${bundle.fingerprint}'
          : 'Bundle integrity failure: ${failures.join(', ')}';
    });
  }

  Future<void> _saveWatch() async {
    final threshold = double.tryParse(_watchThresholdController.text.trim());
    if (threshold == null) {
      setState(() => _statusMessage = 'Watch threshold must be numeric.');
      return;
    }
    final metric = widget.metricRegistry.resolve(_watchMetricController.text);
    if (metric == null) {
      setState(() => _statusMessage =
          'Watch metric is not registered: ${_watchMetricController.text.trim()}');
      return;
    }
    final now = DateTime.now().toUtc();
    final rule = TerminalWatchRule(
      id: 'watch-${now.microsecondsSinceEpoch}',
      title: _watchTitleController.text.trim().isEmpty
          ? '${metric.name} ${_watchOperator.label} $threshold'
          : _watchTitleController.text.trim(),
      metricKey: metric.key,
      op: _watchOperator,
      threshold: threshold,
      createdAtIso: now.toIso8601String(),
      tags: const ['research-os'],
    );
    await widget.watchService.save(rule);
    _watchTitleController.clear();
    _watchThresholdController.clear();
    if (!mounted) return;
    setState(() {
      _selectedWatchId = rule.id;
      _statusMessage = 'Watch saved: ${rule.title}';
    });
    await _reload();
  }

  Future<void> _evaluateWatch() async {
    if (_selectedWatchId.isEmpty) return;
    final rule = _watches.firstWhere((item) => item.id == _selectedWatchId);
    final current = double.tryParse(_watchCurrentController.text.trim());
    final previousText = _watchPreviousController.text.trim();
    final previous = previousText.isEmpty ? null : double.tryParse(previousText);
    final evaluation = widget.watchService.evaluate(
      rule,
      currentValue: current,
      previousValue: previous,
    );
    await widget.watchService.recordEvaluation(evaluation);
    if (!mounted) return;
    setState(() {
      _statusMessage =
          '${evaluation.state.name.toUpperCase()}: ${evaluation.reason}';
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: ColoredBox(
        color: terminalBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Institutional Research OS',
                    subtitle:
                        'Durable research, metric and model registries, deterministic watches, Boards, lineage and portable rights-aware bundles on top of the canonical Sports Terminal object graph.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InfoPill(label: '${_research.length} latest research objects'),
                      InfoPill(
                          label:
                              '${TerminalMetricRegistry.definitions.length} registered metrics'),
                      InfoPill(
                          label:
                              '${TerminalModelRegistry.definitions.length} registered models'),
                      InfoPill(label: '${_watches.length} watch rules'),
                      if (_bundle != null)
                        InfoPill(label: 'Bundle ${_bundle!.fingerprint}'),
                    ],
                  ),
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _statusMessage,
                      key: const ValueKey('research-os-status'),
                      style: const TextStyle(color: terminalAccent),
                    ),
                  ],
                ],
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'RESEARCH LIBRARY'),
                Tab(text: 'METRIC REGISTRY'),
                Tab(text: 'MODEL REGISTRY'),
                Tab(text: 'WATCHES'),
                Tab(text: 'BUNDLES'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildResearchLibrary(),
                        _buildMetricRegistry(),
                        _buildModelRegistry(),
                        _buildWatches(),
                        _buildBundles(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResearchLibrary() {
    final normalized = _researchQuery.trim().toLowerCase();
    final filtered = _research.where((item) {
      final haystack = <String>[
        item.title,
        item.summary,
        item.artifactType,
        item.status,
        item.dataRelease,
        item.contentFingerprint,
        ...item.tags,
      ].join(' ').toLowerCase();
      return normalized.isEmpty || haystack.contains(normalized);
    }).toList(growable: false);
    return _tabScroll([
      TerminalCard(
        child: TextField(
          controller: _researchQueryController,
          onChanged: (value) => setState(() => _researchQuery = value),
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Search title, release, tag, status, fingerprint...'),
        ),
      ),
      const SizedBox(height: 14),
      if (filtered.isEmpty)
        const TerminalCard(
          child: Text(
            'No saved research objects match this filter. Generated reports can now be saved directly from Reports.',
            style: TextStyle(color: terminalTextSoft),
          ),
        )
      else
        for (final item in filtered) ...[
          _researchCard(item),
          const SizedBox(height: 12),
        ],
    ]);
  }

  Widget _researchCard(ResearchObject item) => TerminalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                InfoPill(label: item.status.toUpperCase()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.summary.isEmpty ? item.methodNotes : item.summary,
              style: const TextStyle(color: terminalTextSoft, height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoPill(label: item.revisionKey),
                InfoPill(label: item.artifactType),
                InfoPill(label: item.releaseLabel),
                if (item.contentFingerprint.isNotEmpty)
                  InfoPill(label: 'FP ${item.contentFingerprint}'),
                if (item.isFork)
                  InfoPill(
                      label:
                          'Fork of ${item.parentResearchId}@${item.parentVersion}'),
                if (item.previousRevisionKey.isNotEmpty)
                  InfoPill(label: 'Prev ${item.previousRevisionKey}'),
                ...item.tags.take(5).map((tag) => InfoPill(label: tag)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _reproduce(item),
                  child: const Text('REPRODUCE'),
                ),
                OutlinedButton(
                  onPressed: () => _fork(item),
                  child: const Text('FORK'),
                ),
                OutlinedButton(
                  onPressed: () => _reviseStatus(item, 'archived'),
                  child: const Text('ARCHIVE REVISION'),
                ),
                OutlinedButton(
                  onPressed: () => _addResearchToBoard(item),
                  child: const Text('ADD TO BOARD'),
                ),
                FilledButton(
                  onPressed: () => _buildBundle(item),
                  child: const Text('BUILD BUNDLE'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildMetricRegistry() {
    final metrics = widget.metricRegistry.search(_metricQuery);
    final failures = widget.metricRegistry.integrityFailures();
    return _tabScroll([
      TerminalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _metricQueryController,
              onChanged: (value) => setState(() => _metricQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Search metric key, alias, method, object type...'),
            ),
            const SizedBox(height: 10),
            InfoPill(
              label: failures.isEmpty
                  ? 'REGISTRY INTEGRITY PASS'
                  : '${failures.length} INTEGRITY FAILURE(S)',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      for (final metric in metrics) ...[
        _metricCard(metric),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _metricCard(TerminalMetricDefinition metric) => TerminalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  '${metric.name} · ${metric.key}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900),
                ),
              ),
              InfoPill(label: metric.category),
            ]),
            const SizedBox(height: 8),
            Text(metric.description,
                style: const TextStyle(color: terminalTextSoft, height: 1.4)),
            const SizedBox(height: 10),
            _detail('Method', metric.method),
            _detail('Source', metric.sourcePolicy),
            _detail('Release', metric.releasePolicy),
            _detail('Coverage', metric.coveragePolicy),
            if (metric.formula.isNotEmpty) _detail('Formula', metric.formula),
            if (metric.dependencies.isNotEmpty)
              _detail('Dependencies', metric.dependencies.join(', ')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...metric.objectTypes.map((value) => InfoPill(label: value)),
                ...metric.aliases.map((value) => InfoPill(label: 'alias: $value')),
              ],
            ),
          ],
        ),
      );

  Widget _buildModelRegistry() {
    final models = widget.modelRegistry.search(_modelQuery);
    final failures = widget.modelRegistry.integrityFailures();
    return _tabScroll([
      TerminalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _modelQueryController,
              onChanged: (value) => setState(() => _modelQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Search model, method, input, output, limitation...'),
            ),
            const SizedBox(height: 10),
            InfoPill(
              label: failures.isEmpty
                  ? 'REGISTRY INTEGRITY PASS'
                  : '${failures.length} INTEGRITY FAILURE(S)',
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      for (final model in models) ...[
        _modelCard(model),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _modelCard(TerminalModelDefinition model) => TerminalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  model.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900),
                ),
              ),
              InfoPill(label: model.status.toUpperCase()),
            ]),
            const SizedBox(height: 6),
            Text('${model.id} · v${model.version} · ${model.category}',
                style: const TextStyle(color: terminalTextMuted)),
            const SizedBox(height: 10),
            _detail('Method', model.method),
            _detail('Limitations', model.limitations),
            _detail('Source', model.sourcePolicy),
            _detail('Release', model.releasePolicy),
            _detail('Inputs', model.inputObjects.join(', ')),
            _detail('Metric Inputs',
                model.inputMetrics.isEmpty ? 'None declared' : model.inputMetrics.join(', ')),
            _detail('Outputs', model.outputs.join(', ')),
            if (model.dependencies.isNotEmpty)
              _detail('Model Dependencies', model.dependencies.join(', ')),
          ],
        ),
      );

  Widget _buildWatches() {
    return _tabScroll([
      TerminalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deterministic Watch Rule Builder',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Rules evaluate only explicit numeric observations supplied to the evaluator. No polling, live feed, or notification delivery is implied.',
              style: TextStyle(color: terminalTextSoft, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _watchTitleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Watch title (optional)'),
                    )),
                SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _watchMetricController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Registered metric key'),
                    )),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<TerminalWatchOperator>(
                    value: _watchOperator,
                    dropdownColor: terminalPanelDark,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dropdownDecoration('Operator'),
                    items: [
                      for (final op in TerminalWatchOperator.values)
                        DropdownMenuItem(value: op, child: Text(op.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _watchOperator = value);
                    },
                  ),
                ),
                SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _watchThresholdController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Threshold'),
                    )),
                FilledButton(onPressed: _saveWatch, child: const Text('SAVE WATCH')),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (_watches.isEmpty)
        const TerminalCard(
          child: Text('No watch rules saved.',
              style: TextStyle(color: terminalTextSoft)),
        )
      else ...[
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('One-Shot Evaluation',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 340,
                    child: DropdownButtonFormField<String>(
                      value: _selectedWatchId,
                      dropdownColor: terminalPanelDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dropdownDecoration('Watch rule'),
                      items: [
                        for (final rule in _watches)
                          DropdownMenuItem(
                              value: rule.id,
                              child: Text(rule.title,
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedWatchId = value ?? ''),
                    ),
                  ),
                  SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _watchCurrentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Current value'),
                      )),
                  SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _watchPreviousController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Previous value'),
                      )),
                  FilledButton(
                      onPressed: _evaluateWatch,
                      child: const Text('EVALUATE')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final rule in _watches) ...[
          TerminalCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rule.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                          '${rule.metricKey} ${rule.op.label} ${rule.threshold} · ${rule.scopeLabel}',
                          style: const TextStyle(color: terminalTextSoft)),
                      if (rule.sourceRelease.isNotEmpty)
                        Text('Release: ${rule.sourceRelease}',
                            style: const TextStyle(color: terminalTextMuted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete watch',
                  onPressed: () async {
                    await widget.watchService.delete(rule.id);
                    await _reload();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
      if (_watchHistory.isNotEmpty) ...[
        const SizedBox(height: 4),
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Evaluation History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              for (final item in _watchHistory.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '${item.evaluatedAtIso} · ${item.ruleId} · ${item.state.name.toUpperCase()} · ${item.reason}',
                    style: const TextStyle(color: terminalTextSoft),
                  ),
                ),
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _buildBundles() => _tabScroll([
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Portable Research Bundle',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                'A bundle carries one immutable Research Object plus attached Boards, UniversalQuery definitions, registered metric/model dependencies and explicit rights envelopes. Serialization never upgrades unknown rights into permission.',
                style: TextStyle(color: terminalTextSoft, height: 1.4),
              ),
              if (_bundle != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoPill(label: 'FP ${_bundle!.fingerprint}'),
                    InfoPill(label: 'EXPORT ${_bundle!.exportState.name.toUpperCase()}'),
                    InfoPill(
                        label:
                            'REDISTRIBUTE ${_bundle!.redistributionState.name.toUpperCase()}'),
                    InfoPill(
                        label:
                            '${_bundle!.metricDefinitions.length} metric definition(s)'),
                    InfoPill(
                        label:
                            '${_bundle!.modelDefinitions.length} model definition(s)'),
                    InfoPill(label: '${_bundle!.boards.length} board(s)'),
                    InfoPill(label: '${_bundle!.queries.length} query definition(s)'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        TerminalCard(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: terminalPanelDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: terminalBorder),
            ),
            child: SelectableText(
              _bundlePreview.isEmpty
                  ? 'Choose BUILD BUNDLE on a Research Library object to inspect its portable package here.'
                  : _bundlePreview,
              key: const ValueKey('research-bundle-preview'),
              style: const TextStyle(
                color: Color(0xFFDDE6F1),
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ),
      ]);

  Widget _tabScroll(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(
                      color: terminalTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: Text(value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      color: terminalTextSoft, height: 1.35)),
            ),
          ],
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: terminalTextMuted),
        filled: true,
        fillColor: terminalPanelDark,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: terminalBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: terminalAccent),
        ),
      );

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: terminalTextMuted),
        filled: true,
        fillColor: terminalPanelDark,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: terminalBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: terminalAccent),
        ),
      );
}
