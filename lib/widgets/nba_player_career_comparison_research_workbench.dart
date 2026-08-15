import 'package:flutter/material.dart';

import '../services/nba_player_career_analytics_engine.dart';
import '../services/nba_player_career_comparison_distribution_engine.dart';
import '../services/nba_player_career_comparison_engine.dart';
import '../services/nba_player_career_comparison_export_service.dart';
import '../services/nba_player_career_comparison_loader.dart';
import '../services/nba_player_career_comparison_matrix_engine.dart';
import '../services/nba_player_career_comparison_preset_catalog.dart';
import '../services/nba_player_career_comparison_research_store.dart';
import '../services/nba_player_career_comparison_scope_engine.dart';
import '../services/nba_player_career_comparison_state_store.dart';
import '../services/nba_player_career_comparison_watch_service.dart';
import '../services/nba_player_career_peak_window_engine.dart';
import '../services/nba_player_career_season_type_delta_engine.dart';
import 'nba_player_career_comparison_distribution_panel.dart';
import 'nba_player_career_comparison_export_panel.dart';
import 'nba_player_career_comparison_matrix_panel.dart';
import 'nba_player_career_comparison_state_panel.dart';
import 'nba_player_career_comparison_workflow_state_panel.dart';
import 'nba_player_career_peak_window_panel.dart';
import 'nba_player_career_season_type_delta_panel.dart';

class NbaPlayerCareerComparisonResearchWorkbench extends StatefulWidget {
  const NbaPlayerCareerComparisonResearchWorkbench({
    super.key,
    required this.comparison,
    required this.currentBundle,
    required this.metric,
    required this.league,
    required this.seasonType,
    this.loader = const NbaPlayerCareerComparisonLoader(),
    this.loadPlayer,
    this.loadTeam,
    this.onRestore,
    this.stateStore = const NbaPlayerCareerComparisonStateStore(),
    this.watchService = const NbaPlayerCareerComparisonWatchService(),
    this.researchStore = const NbaPlayerCareerComparisonResearchStore(),
  });

  final NbaPlayerCareerComparisonSnapshot comparison;
  final NbaPlayerCareerComparisonBundle currentBundle;
  final NbaPlayerCareerMetric metric;
  final String league;
  final String seasonType;
  final NbaPlayerCareerComparisonLoader loader;
  final NbaPlayerCareerComparisonDossierLoader? loadPlayer;
  final NbaPlayerCareerComparisonTeamLoader? loadTeam;
  final ValueChanged<NbaPlayerCareerComparisonStateItem>? onRestore;
  final NbaPlayerCareerComparisonStateStore stateStore;
  final NbaPlayerCareerComparisonWatchService watchService;
  final NbaPlayerCareerComparisonResearchStore researchStore;

  @override
  State<NbaPlayerCareerComparisonResearchWorkbench> createState() =>
      _NbaPlayerCareerComparisonResearchWorkbenchState();
}

class _NbaPlayerCareerComparisonResearchWorkbenchState
    extends State<NbaPlayerCareerComparisonResearchWorkbench> {
  String _presetId = '';
  bool _sharedOnly = false;
  int _peakWindow = 3;
  late Future<NbaPlayerCareerComparisonState> _stateFuture;
  late Future<bool> _watchedFuture;
  late Future<NbaPlayerCareerComparisonResearchCheckpoint?> _researchFuture;
  Future<NbaPlayerCareerComparisonBundle>? _oppositeFuture;

  @override
  void initState() {
    super.initState();
    _refreshPersistentState(record: true);
    _oppositeFuture = _loadOpposite();
  }

  @override
  void didUpdateWidget(
    covariant NbaPlayerCareerComparisonResearchWorkbench oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (_identity(oldWidget) != _identity(widget) ||
        oldWidget.metric != widget.metric ||
        oldWidget.seasonType != widget.seasonType ||
        oldWidget.comparison.alignment != widget.comparison.alignment) {
      _presetId = '';
      _sharedOnly = false;
      _refreshPersistentState(record: true);
      _oppositeFuture = _loadOpposite();
    }
  }

  String _identity(NbaPlayerCareerComparisonResearchWorkbench value) =>
      '${value.comparison.left.playerKey}|${value.comparison.right.playerKey}';

  NbaPlayerCareerComparisonStateItem _item() =>
      NbaPlayerCareerComparisonStateItem(
        leftPlayerKey: widget.comparison.left.playerKey,
        leftPlayerName: widget.comparison.left.playerName,
        rightPlayerKey: widget.comparison.right.playerKey,
        rightPlayerName: widget.comparison.right.playerName,
        seasonType: widget.seasonType,
        alignment: widget.comparison.alignment,
        metric: widget.metric,
        sharedOnly: _effectiveSharedOnly,
        presetId: _presetId,
      );

  bool get _effectiveSharedOnly =>
      widget.comparison.alignment ==
              NbaPlayerCareerComparisonAlignment.calendarSeason &&
          _sharedOnly;

  List<NbaPlayerCareerMetric> get _matrixMetrics {
    final preset = const NbaPlayerCareerComparisonPresetCatalog().resolve(_presetId);
    return preset?.metrics ?? const [
      NbaPlayerCareerMetric.pointsPerGame,
      NbaPlayerCareerMetric.reboundsPerGame,
      NbaPlayerCareerMetric.assistsPerGame,
      NbaPlayerCareerMetric.trueShootingPct,
      NbaPlayerCareerMetric.playerEfficiencyRating,
      NbaPlayerCareerMetric.winShares,
      NbaPlayerCareerMetric.boxPlusMinus,
      NbaPlayerCareerMetric.valueOverReplacement,
    ];
  }

  void _refreshPersistentState({bool record = false}) {
    _stateFuture = record
        ? widget.stateStore.record(_item())
        : widget.stateStore.load();
    _watchedFuture = widget.watchService.isWatched(
      comparison: widget.comparison,
      league: widget.league,
      seasonType: widget.seasonType,
      sharedOnly: _effectiveSharedOnly,
    );
    _researchFuture = widget.researchStore.load();
  }

  Future<NbaPlayerCareerComparisonBundle>? _loadOpposite() {
    if (widget.comparison.left.playerKey.isEmpty ||
        widget.comparison.right.playerKey.isEmpty) {
      return null;
    }
    final opposite = widget.seasonType == 'playoffs' ? 'regular' : 'playoffs';
    return widget.loader.load(
      leftPlayerKey: widget.comparison.left.playerKey,
      rightPlayerKey: widget.comparison.right.playerKey,
      league: widget.league,
      seasonType: opposite,
      loadPlayer: widget.loadPlayer,
      loadTeam: widget.loadTeam,
    );
  }

  void _applyPreset(NbaPlayerCareerComparisonPreset preset) {
    setState(() {
      _presetId = preset.id;
      _sharedOnly = preset.sharedOnly &&
          widget.comparison.alignment ==
              NbaPlayerCareerComparisonAlignment.calendarSeason;
      _peakWindow = preset.peakWindow.clamp(1, 10).toInt();
      _refreshPersistentState(record: true);
    });
  }

  void _restore(NbaPlayerCareerComparisonStateItem item) {
    widget.onRestore?.call(item);
  }

  Future<void> _toggleSaved() async {
    final next = await widget.stateStore.toggleSaved(_item());
    if (!mounted) return;
    setState(() => _stateFuture = Future.value(next));
  }

  Future<void> _toggleWatch() async {
    await widget.watchService.toggle(
      comparison: widget.comparison,
      league: widget.league,
      seasonType: widget.seasonType,
      sharedOnly: _effectiveSharedOnly,
    );
    if (!mounted) return;
    setState(() {
      _watchedFuture = widget.watchService.isWatched(
        comparison: widget.comparison,
        league: widget.league,
        seasonType: widget.seasonType,
        sharedOnly: _effectiveSharedOnly,
      );
    });
  }

  Future<void> _activateResearch() async {
    final checkpoint = await widget.researchStore.activate(
      NbaPlayerCareerComparisonResearchCheckpoint(
        leftPlayerKey: widget.comparison.left.playerKey,
        leftPlayerName: widget.comparison.left.playerName,
        rightPlayerKey: widget.comparison.right.playerKey,
        rightPlayerName: widget.comparison.right.playerName,
        league: widget.league,
        seasonType: widget.seasonType,
        alignment: widget.comparison.alignment,
        metric: widget.metric,
        sharedOnly: _effectiveSharedOnly,
        presetId: _presetId,
      ),
    );
    if (!mounted) return;
    setState(() => _researchFuture = Future.value(checkpoint));
  }

  bool _isActiveResearch(
    NbaPlayerCareerComparisonResearchCheckpoint? checkpoint,
  ) {
    if (checkpoint == null) return false;
    final item = _item();
    return checkpoint.leftPlayerKey == item.leftPlayerKey &&
        checkpoint.rightPlayerKey == item.rightPlayerKey &&
        checkpoint.seasonType == item.seasonType &&
        checkpoint.alignment == item.alignment &&
        checkpoint.metric == item.metric &&
        checkpoint.sharedOnly == item.sharedOnly;
  }

  @override
  Widget build(BuildContext context) {
    final scope = const NbaPlayerCareerComparisonScopeEngine().build(
      widget.comparison,
      sharedOnly: _effectiveSharedOnly,
    );
    final matrix = const NbaPlayerCareerComparisonMatrixEngine().build(
      scope,
      metrics: _matrixMetrics,
    );
    final distribution =
        const NbaPlayerCareerComparisonDistributionEngine().build(
      scope,
      metric: widget.metric,
    );
    final peak = const NbaPlayerCareerPeakWindowEngine().build(
      left: widget.comparison.left,
      right: widget.comparison.right,
      metric: widget.metric,
      window: _peakWindow,
    );
    final export = const NbaPlayerCareerComparisonExportService().build(
      matrix: matrix,
      distribution: distribution,
      peak: peak,
      league: widget.league,
      seasonType: widget.seasonType,
    );

    return Column(
      key: const ValueKey('career-comparison-research-workbench'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _scopeControls(),
        const SizedBox(height: 12),
        FutureBuilder<NbaPlayerCareerComparisonState>(
          future: _stateFuture,
          builder: (context, snapshot) => NbaPlayerCareerComparisonStatePanel(
            state: snapshot.data ?? const NbaPlayerCareerComparisonState(),
            activePresetId: _presetId,
            onApplyPreset: _applyPreset,
            onRestore: _restore,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<bool>(
          future: _watchedFuture,
          builder: (context, watchedSnapshot) =>
              FutureBuilder<NbaPlayerCareerComparisonResearchCheckpoint?>(
            future: _researchFuture,
            builder: (context, researchSnapshot) =>
                FutureBuilder<NbaPlayerCareerComparisonState>(
              future: _stateFuture,
              builder: (context, stateSnapshot) {
                final state = stateSnapshot.data ?? const NbaPlayerCareerComparisonState();
                final saved = state.saved.any(
                  (candidate) => candidate.signature == _item().signature,
                );
                return NbaPlayerCareerComparisonWorkflowStatePanel(
                  saved: saved,
                  watched: watchedSnapshot.data ?? false,
                  activeResearch: _isActiveResearch(researchSnapshot.data),
                  onToggleSaved: () => _toggleSaved(),
                  onToggleWatch: () => _toggleWatch(),
                  onActivateResearch: () => _activateResearch(),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        NbaPlayerCareerComparisonMatrixPanel(
          result: matrix,
          leftLabel: widget.comparison.left.playerName,
          rightLabel: widget.comparison.right.playerName,
        ),
        const SizedBox(height: 12),
        NbaPlayerCareerPeakWindowPanel(
          result: peak,
          leftLabel: widget.comparison.left.playerName,
          rightLabel: widget.comparison.right.playerName,
        ),
        const SizedBox(height: 12),
        NbaPlayerCareerComparisonDistributionPanel(
          result: distribution,
          leftLabel: widget.comparison.left.playerName,
          rightLabel: widget.comparison.right.playerName,
        ),
        const SizedBox(height: 12),
        _seasonTypeDelta(),
        const SizedBox(height: 12),
        NbaPlayerCareerComparisonExportPanel(bundle: export),
      ],
    );
  }

  Widget _scopeControls() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F151C),
          border: Border.all(color: const Color(0xFF263342)),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'RESEARCH SCOPE',
              style: TextStyle(
                color: Color(0xFFE2B866),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            FilterChip(
              key: const ValueKey('career-comparison-shared-season-filter'),
              selected: _effectiveSharedOnly,
              onSelected: widget.comparison.alignment ==
                      NbaPlayerCareerComparisonAlignment.calendarSeason
                  ? (selected) => setState(() {
                        _sharedOnly = selected;
                        _refreshPersistentState(record: true);
                      })
                  : null,
              label: const Text('SHARED CALENDAR SEASONS ONLY'),
            ),
            DropdownButton<int>(
              key: const ValueKey('career-comparison-peak-window-size'),
              value: _peakWindow,
              dropdownColor: const Color(0xFF141C25),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1-SEASON PEAK')),
                DropdownMenuItem(value: 2, child: Text('2-SEASON PEAK')),
                DropdownMenuItem(value: 3, child: Text('3-SEASON PEAK')),
                DropdownMenuItem(value: 5, child: Text('5-SEASON PEAK')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _peakWindow = value);
              },
            ),
          ],
        ),
      );

  Widget _seasonTypeDelta() {
    final oppositeFuture = _oppositeFuture;
    if (oppositeFuture == null) {
      return const _WorkbenchNotice('Regular/Playoffs comparison unavailable.');
    }
    return FutureBuilder<NbaPlayerCareerComparisonBundle>(
      future: oppositeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _WorkbenchNotice('Loading opposite season-type evidence…');
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _WorkbenchNotice(
            'Opposite season-type evidence unavailable: ${snapshot.error}',
          );
        }
        final opposite = snapshot.data!;
        final currentIsPlayoffs = widget.seasonType == 'playoffs';
        final result = const NbaPlayerCareerSeasonTypeDeltaEngine().build(
          leftRegular: currentIsPlayoffs
              ? opposite.leftCareer
              : widget.currentBundle.leftCareer,
          leftPlayoffs: currentIsPlayoffs
              ? widget.currentBundle.leftCareer
              : opposite.leftCareer,
          rightRegular: currentIsPlayoffs
              ? opposite.rightCareer
              : widget.currentBundle.rightCareer,
          rightPlayoffs: currentIsPlayoffs
              ? widget.currentBundle.rightCareer
              : opposite.rightCareer,
          metric: widget.metric,
        );
        return NbaPlayerCareerSeasonTypeDeltaPanel(
          result: result,
          leftLabel: widget.comparison.left.playerName,
          rightLabel: widget.comparison.right.playerName,
        );
      },
    );
  }
}

class _WorkbenchNotice extends StatelessWidget {
  const _WorkbenchNotice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F151C),
          border: Border.all(color: const Color(0xFF263342)),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Color(0xFF8895A5), fontSize: 10),
        ),
      );
}
