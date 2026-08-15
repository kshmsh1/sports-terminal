import 'package:flutter/material.dart';

import '../services/nba_season_benchmark_engine.dart';
import '../services/nba_season_comparison_engine.dart';
import '../services/nba_season_team_distribution_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _bg = Color(0xFF0F151C);
const _panel = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _amber = Color(0xFFE2B866);

typedef NbaHistoricalSeasonLoader = Future<NbaTerminalSeedSnapshot> Function(
  String seasonId,
);

class NbaSeasonCrossSeasonPanel extends StatefulWidget {
  const NbaSeasonCrossSeasonPanel({
    super.key,
    required this.seed,
    required this.seasonId,
    required this.seasonType,
    this.loadHistoricalSeason,
    this.onOpenTeam,
  });

  final NbaTerminalSeedSnapshot seed;
  final String seasonId;
  final String seasonType;
  final NbaHistoricalSeasonLoader? loadHistoricalSeason;
  final ValueChanged<String>? onOpenTeam;

  @override
  State<NbaSeasonCrossSeasonPanel> createState() =>
      _NbaSeasonCrossSeasonPanelState();
}

class _NbaSeasonCrossSeasonPanelState extends State<NbaSeasonCrossSeasonPanel> {
  final TextEditingController _comparisonSeason = TextEditingController();
  NbaSeasonTeamDistributionMetric _metric =
      NbaSeasonTeamDistributionMetric.differential;
  NbaSeasonComparisonResult? _comparison;
  bool _loadingComparison = false;
  String _comparisonError = '';

  @override
  void dispose() {
    _comparisonSeason.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NbaSeasonCrossSeasonPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seasonId != widget.seasonId ||
        oldWidget.seasonType != widget.seasonType) {
      _comparison = null;
      _comparisonError = '';
    }
  }

  Future<void> _compare() async {
    final requested = _comparisonSeason.text.trim();
    if (requested.isEmpty) {
      setState(() => _comparisonError = 'Enter an explicit comparison season ID.');
      return;
    }
    if (requested == widget.seasonId.trim()) {
      setState(() => _comparisonError = 'Choose a different explicit season ID.');
      return;
    }
    setState(() {
      _loadingComparison = true;
      _comparisonError = '';
    });
    try {
      final loader = widget.loadHistoricalSeason ??
          (seasonId) => const NbaTerminalSeedRepository().loadHistoricalSeason(
                seasonId,
                league: 'NBA',
                seasonType: _seedSeasonType(widget.seasonType),
              );
      final other = await loader(requested);
      final result = const NbaSeasonComparisonEngine().build(
        leftSeed: other,
        leftSeasonId: requested,
        rightSeed: widget.seed,
        rightSeasonId: widget.seasonId,
        seasonType: widget.seasonType,
      );
      if (!mounted) return;
      setState(() {
        _comparison = result;
        _loadingComparison = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _comparison = null;
        _loadingComparison = false;
        _comparisonError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final benchmark = const NbaSeasonBenchmarkEngine().build(
      widget.seed,
      seasonId: widget.seasonId,
      seasonType: widget.seasonType,
      metric: _metric,
    );
    return Container(
      key: const ValueKey('season-cross-season-workbench'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _bg, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CROSS-SEASON INTELLIGENCE',
            style: TextStyle(
              color: _amber,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Benchmark teams inside this exact season, or compare against one explicitly requested canonical season. No adjacent season is guessed automatically.',
            style: TextStyle(color: _muted, fontSize: 9, height: 1.4),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final benchmarkPanel = _benchmark(benchmark);
            final comparePanel = _comparisonPanel();
            if (constraints.maxWidth < 980) {
              return Column(children: [
                benchmarkPanel,
                const SizedBox(height: 10),
                comparePanel,
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: benchmarkPanel),
                const SizedBox(width: 10),
                Expanded(child: comparePanel),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _benchmark(NbaSeasonBenchmarkResult result) => _section(
        'LEAGUE BENCHMARK',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<NbaSeasonTeamDistributionMetric>(
              key: const ValueKey('season-benchmark-metric'),
              value: _metric,
              dropdownColor: _panel,
              style: const TextStyle(color: _text, fontSize: 9),
              items: [
                for (final metric in NbaSeasonTeamDistributionMetric.values)
                  DropdownMenuItem(value: metric, child: Text(metric.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _metric = value);
              },
            ),
            const SizedBox(height: 8),
            if (!result.available)
              const Text(
                'No scored team observations are available for benchmarking.',
                style: TextStyle(color: _muted, fontSize: 9),
              )
            else ...[
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _chip('TEAMS', '${result.teamCount}'),
                  _chip('MEAN', _value(result.mean)),
                  _chip('MEDIAN', _value(result.median)),
                ],
              ),
              const SizedBox(height: 7),
              for (final row in result.rows.take(10))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '#${row.rankLabel}',
                          style: const TextStyle(color: _muted, fontSize: 8),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          key: ValueKey('season-benchmark-team-${row.teamId}'),
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: widget.onOpenTeam == null
                              ? null
                              : () => widget.onOpenTeam!(row.teamId),
                          child: Text(row.abbreviation),
                        ),
                      ),
                      Text(
                        '${row.value.toStringAsFixed(_metric == NbaSeasonTeamDistributionMetric.winPct ? 3 : 1)} · ${row.percentile.toStringAsFixed(0)}p',
                        style: const TextStyle(
                          color: _text,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );

  Widget _comparisonPanel() => _section(
        'EXPLICIT SEASON COMPARISON',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('season-comparison-id'),
                    controller: _comparisonSeason,
                    onSubmitted: (_) => _compare(),
                    style: const TextStyle(color: _text, fontSize: 10),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 2024-25',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                FilledButton(
                  key: const ValueKey('season-run-comparison'),
                  onPressed: _loadingComparison ? null : _compare,
                  child: const Text('COMPARE'),
                ),
              ],
            ),
            if (_loadingComparison) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (_comparisonError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _comparisonError,
                style: const TextStyle(color: Colors.redAccent, fontSize: 8),
              ),
            ],
            if (_comparison != null) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _chip('BASE', _comparison!.leftSeasonId),
                  _chip('FOCAL', _comparison!.rightSeasonId),
                  _chip('COMMON TEAMS', '${_comparison!.commonTeamCount}'),
                  _chip('PF/G Δ', _signed(_comparison!.leaguePointsForDelta)),
                ],
              ),
              const SizedBox(height: 7),
              if (!_comparison!.hasComparableTeams)
                const Text(
                  'The two explicit season scopes have no common canonical team identities.',
                  style: TextStyle(color: _muted, fontSize: 9),
                )
              else
                for (final row in _comparison!.commonTeams.take(10))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            key: ValueKey('season-comparison-team-${row.teamId}'),
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: widget.onOpenTeam == null
                                ? null
                                : () => widget.onOpenTeam!(row.teamId),
                            child: Text(row.abbreviation),
                          ),
                        ),
                        Text(
                          'WIN% ${_signed(row.winPctDelta, decimals: 3)} · DIFF ${_signed(row.differentialDelta)}',
                          style: const TextStyle(color: _text, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
              if (_comparison!.onlyLeftTeams.isNotEmpty ||
                  _comparison!.onlyRightTeams.isNotEmpty) ...[
                const Divider(color: _line),
                Text(
                  'Identity coverage · base-only ${_comparison!.onlyLeftTeams.length} · focal-only ${_comparison!.onlyRightTeams.length}',
                  style: const TextStyle(color: _muted, fontSize: 8),
                ),
              ],
            ],
          ],
        ),
      );

  Widget _section(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _blue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: _bg, border: Border.all(color: _line)),
        child: Text(
          '$label $value',
          style: const TextStyle(color: _text, fontSize: 8),
        ),
      );

  String _value(double? value) => value == null ? '—' : value.toStringAsFixed(1);
  String _signed(double value, {int decimals = 1}) =>
      '${value > 0 ? '+' : ''}${value.toStringAsFixed(decimals)}';
}

String _seedSeasonType(String seasonType) {
  final normalized = seasonType.trim().toLowerCase();
  if (normalized.contains('playoff')) return 'playoffs';
  if (normalized == 'all' || normalized.contains('combined')) return 'combined';
  return 'regular';
}
