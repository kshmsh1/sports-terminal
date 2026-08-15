import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../services/nba_player_career_analytics_engine.dart';
import '../services/nba_player_career_comparison_context_engine.dart';
import '../services/nba_player_career_comparison_discovery_service.dart';
import '../services/nba_player_career_comparison_engine.dart';
import '../services/nba_player_career_comparison_loader.dart';
import '../services/nba_player_career_comparison_metric_engine.dart';
import '../services/nba_player_career_comparison_state_store.dart';
import '../services/nba_player_career_comparison_workflow_service.dart';
import '../widgets/nba_player_career_comparison_chart.dart';
import '../widgets/nba_player_career_comparison_context_panel.dart';
import '../widgets/nba_player_career_comparison_research_workbench.dart';
import '../widgets/nba_player_career_comparison_summary_panel.dart';
import '../widgets/nba_player_career_comparison_table.dart';

const nbaPlayerCareerComparisonBackground = Color(0xFF090D12);
const _ccPanel = Color(0xFF0F151C);
const _ccPanel2 = Color(0xFF141C25);
const _ccLine = Color(0xFF263342);
const _ccText = Color(0xFFE8EDF3);
const _ccMuted = Color(0xFF8895A5);
const _ccBlue = Color(0xFF63A9FF);
const _ccAmber = Color(0xFFE2B866);

class ProductNbaPlayerCareerComparisonScreen extends StatefulWidget {
  const ProductNbaPlayerCareerComparisonScreen({
    super.key,
    required this.leftPlayerKey,
    this.leftPlayerName = 'Player A',
    this.rightPlayerKey = '',
    this.rightPlayerName = 'Player B',
    this.league = 'NBA',
    this.initialSeasonType = 'regular',
    this.initialAlignment = NbaPlayerCareerComparisonAlignment.calendarSeason,
    this.initialMetric = NbaPlayerCareerMetric.pointsPerGame,
    this.loader = const NbaPlayerCareerComparisonLoader(),
    this.discovery = const NbaPlayerCareerComparisonDiscoveryService(),
    this.workflowService = const NbaPlayerCareerComparisonWorkflowService(),
    this.loadPlayer,
    this.loadTeam,
    this.searchLoader,
    this.onOpenPlayer,
    this.onOpenSeason,
  });

  final String leftPlayerKey;
  final String leftPlayerName;
  final String rightPlayerKey;
  final String rightPlayerName;
  final String league;
  final String initialSeasonType;
  final NbaPlayerCareerComparisonAlignment initialAlignment;
  final NbaPlayerCareerMetric initialMetric;
  final NbaPlayerCareerComparisonLoader loader;
  final NbaPlayerCareerComparisonDiscoveryService discovery;
  final NbaPlayerCareerComparisonWorkflowService workflowService;
  final NbaPlayerCareerComparisonDossierLoader? loadPlayer;
  final NbaPlayerCareerComparisonTeamLoader? loadTeam;
  final NbaPlayerComparisonSearchLoader? searchLoader;
  final void Function(String playerKey, String playerName)? onOpenPlayer;
  final ValueChanged<String>? onOpenSeason;

  @override
  State<ProductNbaPlayerCareerComparisonScreen> createState() =>
      _ProductNbaPlayerCareerComparisonScreenState();
}

class _ProductNbaPlayerCareerComparisonScreenState
    extends State<ProductNbaPlayerCareerComparisonScreen> {
  final TextEditingController _query = TextEditingController();
  late String _leftKey;
  late String _leftName;
  late String _rightKey;
  late String _rightName;
  late String _seasonType;
  late NbaPlayerCareerComparisonAlignment _alignment;
  late NbaPlayerCareerMetric _metric;
  Future<NbaPlayerCareerComparisonBundle>? _bundleFuture;
  List<NbaPlayerCareerComparisonCandidate> _candidates = const [];
  bool _searching = false;
  String _searchError = '';

  @override
  void initState() {
    super.initState();
    _leftKey = widget.leftPlayerKey.trim();
    _leftName = widget.leftPlayerName.trim().isEmpty
        ? 'Player A'
        : widget.leftPlayerName.trim();
    _rightKey = widget.rightPlayerKey.trim();
    _rightName = widget.rightPlayerName.trim().isEmpty
        ? 'Player B'
        : widget.rightPlayerName.trim();
    _seasonType = widget.initialSeasonType.trim().toLowerCase() == 'playoffs'
        ? 'playoffs'
        : 'regular';
    _alignment = widget.initialAlignment;
    _metric = widget.initialMetric;
    _reload();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _reload() {
    if (_leftKey.isEmpty || _rightKey.isEmpty) {
      _bundleFuture = null;
      return;
    }
    _bundleFuture = widget.loader.load(
      leftPlayerKey: _leftKey,
      rightPlayerKey: _rightKey,
      league: widget.league,
      seasonType: _seasonType,
      loadPlayer: widget.loadPlayer,
      loadTeam: widget.loadTeam,
    );
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() {
        _candidates = const [];
        _searchError = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = '';
    });
    try {
      final rows = await widget.discovery.search(
        query,
        league: widget.league,
        loader: widget.searchLoader,
      );
      if (!mounted) return;
      setState(() {
        _candidates = rows.where((row) => row.playerKey != _leftKey).toList();
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = error.toString();
        _candidates = const [];
      });
    }
  }

  void _selectRight(NbaPlayerCareerComparisonCandidate candidate) {
    setState(() {
      _rightKey = candidate.playerKey;
      _rightName = candidate.playerName;
      _query.clear();
      _candidates = const [];
      _reload();
    });
  }

  void _swap() {
    if (_rightKey.isEmpty) return;
    setState(() {
      final key = _leftKey;
      final name = _leftName;
      _leftKey = _rightKey;
      _leftName = _rightName;
      _rightKey = key;
      _rightName = name;
      _reload();
    });
  }

  void _changeSeasonType(String type) {
    final normalized = type == 'playoffs' ? 'playoffs' : 'regular';
    if (normalized == _seasonType) return;
    setState(() {
      _seasonType = normalized;
      _reload();
    });
  }

  void _restoreComparison(NbaPlayerCareerComparisonStateItem item) {
    setState(() {
      _leftKey = item.leftPlayerKey;
      _leftName = item.leftPlayerName.isEmpty ? item.leftPlayerKey : item.leftPlayerName;
      _rightKey = item.rightPlayerKey;
      _rightName = item.rightPlayerName.isEmpty ? item.rightPlayerKey : item.rightPlayerName;
      _seasonType = item.seasonType == 'playoffs' ? 'playoffs' : 'regular';
      _alignment = item.alignment;
      _metric = item.metric;
      _query.clear();
      _candidates = const [];
      _reload();
    });
  }

  void _route(
    NbaPlayerCareerComparisonSnapshot comparison,
    NbaPlayerCareerComparisonMetricResult metric,
    NbaPlayerCareerComparisonContextResult contextResult,
    String target,
  ) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      _notice('Shared RoutePayload state is unavailable in this shell.');
      return;
    }
    final payload = widget.workflowService.package(
      comparison: comparison,
      metric: metric,
      context: contextResult,
      targetRoute: target,
      league: widget.league,
      seasonType: _seasonType,
    );
    controller.setActivePayload(
      payload,
      origin:
          'NBA Player Career Comparison · ${comparison.left.playerName} vs ${comparison.right.playerName}',
    );
    _notice('${payload.displayLabel} routed to $target.');
  }

  void _notice(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('nba-player-career-comparison-$_leftKey-$_rightKey'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(),
        const SizedBox(height: 12),
        _controls(),
        if (_rightKey.isEmpty ||
            _candidates.isNotEmpty ||
            _searching ||
            _searchError.isNotEmpty) ...[
          const SizedBox(height: 12),
          _discoveryPanel(),
        ],
        if (_bundleFuture != null) ...[
          const SizedBox(height: 12),
          FutureBuilder<NbaPlayerCareerComparisonBundle>(
            future: _bundleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _ComparisonPanel(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _ComparisonPanel(
                  child: Text(
                    'Career comparison unavailable: ${snapshot.error}',
                    style: const TextStyle(color: _ccMuted),
                  ),
                );
              }
              return _research(snapshot.data!);
            },
          ),
        ],
      ],
    );
  }

  Widget _hero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _ccPanel,
          border: Border.all(color: _ccLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NBA / HISTORICAL PLAYER CAREER COMPARISON',
              style: TextStyle(
                color: _ccBlue,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _rightKey.isEmpty
                  ? '$_leftName vs SELECT PLAYER'
                  : '$_leftName vs $_rightName',
              style: const TextStyle(
                color: _ccText,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Compare canonical historical careers using exact source-backed season values. Calendar and career-year views are separate; no era, pace, age, role, possession, ruleset or award-equivalence normalization is applied.',
              style: TextStyle(color: _ccMuted, height: 1.45),
            ),
          ],
        ),
      );

  Widget _controls() => _ComparisonPanel(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              key: const ValueKey('career-comparison-season-type'),
              value: _seasonType,
              dropdownColor: _ccPanel2,
              style: const TextStyle(color: _ccText),
              items: const [
                DropdownMenuItem(
                  value: 'regular',
                  child: Text('REGULAR SEASON'),
                ),
                DropdownMenuItem(value: 'playoffs', child: Text('PLAYOFFS')),
              ],
              onChanged: (value) {
                if (value != null) _changeSeasonType(value);
              },
            ),
            DropdownButton<NbaPlayerCareerComparisonAlignment>(
              key: const ValueKey('career-comparison-alignment'),
              value: _alignment,
              dropdownColor: _ccPanel2,
              style: const TextStyle(color: _ccText),
              items: [
                for (final alignment in NbaPlayerCareerComparisonAlignment.values)
                  DropdownMenuItem(
                    value: alignment,
                    child: Text(alignment.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _alignment = value);
              },
            ),
            DropdownButton<NbaPlayerCareerMetric>(
              key: const ValueKey('career-comparison-metric'),
              value: _metric,
              dropdownColor: _ccPanel2,
              style: const TextStyle(color: _ccText),
              items: [
                for (final metric in NbaPlayerCareerMetric.values)
                  DropdownMenuItem(value: metric, child: Text(metric.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _metric = value);
              },
            ),
            OutlinedButton.icon(
              key: const ValueKey('career-comparison-swap'),
              onPressed: _rightKey.isEmpty ? null : _swap,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('SWAP'),
            ),
            if (widget.onOpenPlayer != null)
              TextButton(
                onPressed: () => widget.onOpenPlayer!(_leftKey, _leftName),
                child: Text('OPEN ${_leftName.toUpperCase()}'),
              ),
            if (widget.onOpenPlayer != null && _rightKey.isNotEmpty)
              TextButton(
                onPressed: () => widget.onOpenPlayer!(_rightKey, _rightName),
                child: Text('OPEN ${_rightName.toUpperCase()}'),
              ),
          ],
        ),
      );

  Widget _discoveryPanel() => _ComparisonPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECT COMPARISON PLAYER',
              style: TextStyle(
                color: _ccAmber,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('career-comparison-player-query'),
                    controller: _query,
                    onSubmitted: (_) => _search(),
                    style: const TextStyle(color: _ccText),
                    decoration: const InputDecoration(
                      hintText: 'Search canonical historical Players…',
                      hintStyle: TextStyle(color: _ccMuted),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('career-comparison-player-search'),
                  onPressed: _search,
                  child: const Text('SEARCH'),
                ),
              ],
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_searchError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Historical Player search unavailable: $_searchError',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            for (final candidate in _candidates)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  candidate.playerName,
                  style: const TextStyle(
                    color: _ccText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  [candidate.position, candidate.lastSeason, candidate.leagueId]
                      .where((value) => value.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(color: _ccMuted),
                ),
                trailing: TextButton(
                  key: ValueKey(
                    'career-comparison-select-${candidate.playerKey}',
                  ),
                  onPressed: () => _selectRight(candidate),
                  child: const Text('COMPARE'),
                ),
              ),
          ],
        ),
      );

  Widget _research(NbaPlayerCareerComparisonBundle bundle) {
    final comparison = const NbaPlayerCareerComparisonEngine().build(
      left: bundle.leftCareer,
      right: bundle.rightCareer,
      alignment: _alignment,
    );
    final metric = const NbaPlayerCareerComparisonMetricEngine().build(
      comparison,
      metric: _metric,
    );
    final contextResult = const NbaPlayerCareerComparisonContextEngine().build(
      left: bundle.leftContext,
      right: bundle.rightContext,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComparisonPanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final target in const [
                'Workspace',
                'Python Lab',
                'Compare',
                'Source Audit',
              ])
                OutlinedButton(
                  key: ValueKey(
                    'career-comparison-route-${target.toLowerCase().replaceAll(' ', '-')}',
                  ),
                  onPressed: () =>
                      _route(comparison, metric, contextResult, target),
                  child: Text(target.toUpperCase()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        NbaPlayerCareerComparisonSummaryPanel(
          comparison: comparison,
          metric: metric,
        ),
        const SizedBox(height: 12),
        _ComparisonPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OBSERVED CAREER TREND',
                style: TextStyle(
                  color: _ccAmber,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              NbaPlayerCareerComparisonChart(
                leftLabel: comparison.left.playerName,
                rightLabel: comparison.right.playerName,
                metricLabel: metric.metric.label,
                points: metric.points,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        NbaPlayerCareerComparisonTable(
          comparison: comparison,
          metric: metric,
          onOpenLeftSeason: widget.onOpenSeason,
          onOpenRightSeason: widget.onOpenSeason,
        ),
        const SizedBox(height: 12),
        NbaPlayerCareerComparisonContextPanel(
          left: comparison.left,
          right: comparison.right,
          context: contextResult,
        ),
        const SizedBox(height: 12),
        NbaPlayerCareerComparisonResearchWorkbench(
          comparison: comparison,
          currentBundle: bundle,
          metric: _metric,
          league: widget.league,
          seasonType: _seasonType,
          loader: widget.loader,
          loadPlayer: widget.loadPlayer,
          loadTeam: widget.loadTeam,
          onRestore: _restoreComparison,
        ),
        const SizedBox(height: 12),
        _ComparisonPanel(
          child: Text(
            'SOURCE BOUNDARY · ${comparison.left.playerName}: ${comparison.left.tenureCoverageLabel} · ${comparison.right.playerName}: ${comparison.right.tenureCoverageLabel} · ${contextResult.boundaryLabel}',
            style: const TextStyle(color: _ccMuted, fontSize: 9, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _ccPanel,
          border: Border.all(color: _ccLine),
        ),
        child: child,
      );
}
