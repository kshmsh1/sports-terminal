import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_evidence_research_engine.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/website_nba_api_service.dart';

/// Source-verifiable entry point for the larger Sports Terminal research agent.
/// Currently executes one well-defined NBA query family, never free-form guesses.
class NbaAskResearchPanel extends StatefulWidget {
  const NbaAskResearchPanel({super.key});

  @override
  State<NbaAskResearchPanel> createState() => _NbaAskResearchPanelState();
}

class _NbaAskResearchPanelState extends State<NbaAskResearchPanel> {
  final _api = const WebsiteNbaApiService();
  final _planner = const NbaEvidenceResearchEngine();
  final _stats = const NbaStatsWorkstationEngine();
  final _input = TextEditingController();
  int _requestNumber = 0;
  NbaResearchPlan? _plan;
  NbaResearchAnswer? _answer;
  String? _error;
  bool _loading = false;

  static const _examples = <String>[
    'Top 10 players in points per game in 2025-26',
    'Who led assists in the 2024-25 playoffs?',
    'Top 10 players in rebounds per 36 in 2023-24',
    'Top 5 in three-point percentage in 2025-26 with at least 20 games',
  ];

  @override
  void dispose() {
    ++_requestNumber;
    _input.dispose();
    super.dispose();
  }

  void _setExample(String value) {
    _input.text = value;
    _run();
  }

  Future<void> _run() async {
    final question = _input.text.trim();
    if (question.isEmpty) return;
    final request = ++_requestNumber;
    setState(() {
      _loading = true;
      _plan = null;
      _answer = null;
      _error = null;
    });
    try {
      final seasons = await _api.seasons();
      if (request != _requestNumber || !mounted) return;
      if (seasons.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No indexed NBA seasons are available in this static build.';
        });
        return;
      }
      final available = seasons.where((item) => item.rowCount > 0).toList();
      final defaultSeason = available.isNotEmpty
          ? available.first.id : seasons.first.id;
      final plan = _planner.parse(question, defaultSeason: defaultSeason);
      if (!plan.supported) {
        setState(() {
          _plan = plan;
          _loading = false;
        });
        return;
      }
      if (!seasons.any((item) => item.id == plan.season)) {
        setState(() {
          _plan = plan;
          _error = 'Season ${plan.season} is not in the current local NBA archive.';
          _loading = false;
        });
        return;
      }
      final snapshot = await _api.seasonSnapshot(plan.season,
        seasonType: plan.seasonType == NbaStatsSeasonType.playoffs
            ? 'playoffs' : 'regular');
      if (request != _requestNumber || !mounted) return;
      final rows = _stats.buildRows(snapshot,
        seasonType: plan.seasonType, basis: plan.basis);
      final answer = _planner.execute(plan, rows);
      setState(() {
        _plan = plan;
        _answer = answer;
        _loading = false;
      });
    } catch (_) {
      if (request != _requestNumber || !mounted) return;
      setState(() {
        _error = 'The requested static season shard could not be read. '
            'Verify that historical assets are materialized before starting Flutter.';
        _loading = false;
      });
    }
  }

  void _copyFindings(NbaResearchAnswer answer) {
    final plan = answer.plan;
    final metric = _stats.metric(plan.metric);
    final lines = <String>[
      'Sports Terminal — source-backed NBA research',
      'Question: ${plan.question}',
      'Season: ${plan.season} · ${plan.seasonType.label} · ${plan.basis.label}',
      'Metric: ${metric.label} · Min games: ${plan.minGames}',
      'Population: ${answer.qualifiedCount} qualifying players of ${answer.evaluatedCount}',
      'Dataset: data/nba_static/${plan.sourcePath}',
      '',
      for (var i = 0; i < answer.findings.length; i++)
        '${i + 1}. ${answer.findings[i].row.player} '
        '(${answer.findings[i].row.team}) — '
        '${_stats.formatValue(plan.metric, answer.findings[i].metricValue)} '
        'in ${_stats.formatValue('gp', answer.findings[i].row.value('gp'))} GP',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Research table and methodology copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.manage_search_rounded, color: scheme.primary, size: 26),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ask NBA Research', style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
                Text('Questions become verified queries, not ungrounded AI claims.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            )),
            const Tooltip(
              message: 'Answers are computed from static NBA player-season data. '
                  'Tracking, live and betting questions are not yet supported.',
              child: Icon(Icons.verified_user_outlined, size: 20),
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            minLines: 2,
            maxLines: 3,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(),
            decoration: const InputDecoration(
              labelText: 'Your basketball research question',
              hintText: 'Who led the NBA in assists in the 2024-25 playoffs?',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _run,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Run research'),
              ),
              if (_input.text.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    ++_requestNumber;
                    _input.clear();
                    _answer = null;
                    _plan = null;
                    _error = null;
                    _loading = false;
                  }),
                  child: const Text('Clear'),
                ),
              Text('NBA season leaderboards · read-only',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          Text('TRY A VERIFIED QUERY',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
              letterSpacing: .8, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7,
            children: [
              for (final example in _examples)
                ActionChip(
                  avatar: const Icon(Icons.north_east_rounded, size: 15),
                  label: Text(example, maxLines: 2),
                  onPressed: _loading ? null : () => _setExample(example),
                ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 24),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 8),
            Text('Loading and evaluating the historical NBA season data…',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          if (_plan != null && !_loading) ...[
            const SizedBox(height: 20),
            if (!_plan!.supported)
              _ResearchMessage(
                icon: Icons.info_outline_rounded,
                title: 'This question needs a different dataset or query family',
                detail: _plan!.explanation,
              ),
            if (_error != null) _ResearchMessage(
              icon: Icons.warning_amber_outlined,
              title: 'Verified result unavailable', detail: _error!),
          ],
          if (_error != null && _plan == null && !_loading) ...[
            const SizedBox(height: 20),
            _ResearchMessage(
              icon: Icons.warning_amber_outlined,
              title: 'Research data unavailable', detail: _error!),
          ],
          if (_answer != null && !_loading) ...[
            const SizedBox(height: 20),
            _buildAnswer(context, _answer!),
          ],
        ]),
      ),
    );
  }

  Widget _buildAnswer(BuildContext context, NbaResearchAnswer answer) {
    final scheme = Theme.of(context).colorScheme;
    final plan = answer.plan;
    final metric = _stats.metric(plan.metric);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${metric.label} · ${plan.season}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900)),
          Chip(label: Text('${plan.seasonType.label} · ${plan.basis.label}')),
          OutlinedButton.icon(
            onPressed: () => _copyFindings(answer),
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Copy with source'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text('${answer.qualifiedCount} qualifying players of '
          '${answer.evaluatedCount} indexed player identities · '
          'minimum ${plan.minGames} games'
          '${plan.minimumMetric == null ? '' : ' · at least ${plan.minimumMetric} ${metric.shortLabel}'}',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      if (!answer.hasResults)
        const _ResearchMessage(
          icon: Icons.search_off_rounded,
          title: 'No qualifying observations',
          detail: 'The indexed season has no players meeting these filters. '
              'Try lowering the qualification threshold or using another season.',
        )
      else SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 56,
          columns: [
            const DataColumn(label: Text('#')),
            const DataColumn(label: Text('PLAYER')),
            const DataColumn(label: Text('TEAM')),
            DataColumn(label: Text(metric.shortLabel)),
            const DataColumn(label: Text('GP')),
          ],
          rows: [
            for (var i = 0; i < answer.findings.length; i++)
              DataRow(cells: [
                DataCell(Text('${i + 1}')),
                DataCell(SizedBox(width: 210,
                  child: Text(answer.findings[i].row.player,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)))),
                DataCell(Text(answer.findings[i].row.team)),
                DataCell(Text(_stats.formatValue(plan.metric,
                    answer.findings[i].metricValue),
                    style: const TextStyle(fontWeight: FontWeight.w900))),
                DataCell(Text(_stats.formatValue('gp',
                    answer.findings[i].row.value('gp')))),
              ]),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .06),
          border: Border.all(color: scheme.outline.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOW THIS ANSWER WAS PRODUCED',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                color: scheme.onSurfaceVariant)),
            const SizedBox(height: 7),
            Text('Source: bundled canonical NBA player-season totals'),
            Text('Dataset: data/nba_static/${plan.sourcePath}'),
            Text('Calculation: ${metric.label} · ${plan.basis.label}'
              ' · ${plan.descending ? 'descending' : 'ascending'} ranking'),
            Text('Qualification: GP ≥ ${plan.minGames}; valid non-null metric; '
                'duplicates consolidated by player ID.'),
            const SizedBox(height: 6),
            Text('Not included: defender tracking, lineup effects, live odds '
                'or inferred missing statistics. Possession-based rates '
                'may contain estimates where the source records indicate so.',
              style: TextStyle(fontSize: 12, height: 1.35,
                color: scheme.onSurfaceVariant)),
          ]),
      ),
    ]);
  }
}

class _ResearchMessage extends StatelessWidget {
  const _ResearchMessage({
    required this.icon, required this.title, required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 23),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(detail),
          ],
        )),
      ],
    ),
  );
}
