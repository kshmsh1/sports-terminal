import 'package:flutter/material.dart';

import '../services/nba_game_event_query_engine.dart';
import '../services/nba_game_intelligence_engine.dart';
import '../services/nba_game_play_by_play_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);

typedef NbaGameEventBatchRouteCallback = void Function(
  NbaGameEventQueryResult result,
  String targetRoute,
);

/// Batch-routing companion to Event Explorer.
///
/// This is intentionally a compact export surface rather than a second event
/// table. It applies the same canonical query engine, reports the exact matched
/// row count, and hands that exact selection to shared RoutePayload workflows.
class NbaGameEventBatchExportPanel extends StatefulWidget {
  const NbaGameEventBatchExportPanel({
    super.key,
    required this.seed,
    required this.game,
    required this.onRouteSelection,
  });

  final NbaTerminalSeedSnapshot seed;
  final NbaGameIntelligenceSnapshot game;
  final NbaGameEventBatchRouteCallback onRouteSelection;

  @override
  State<NbaGameEventBatchExportPanel> createState() =>
      _NbaGameEventBatchExportPanelState();
}

class _NbaGameEventBatchExportPanelState
    extends State<NbaGameEventBatchExportPanel> {
  final TextEditingController _query = TextEditingController();
  NbaPbpEventCategory? _category;
  String _teamId = '';
  int? _period;
  bool _scoringOnly = false;
  bool _closeOnly = false;
  bool _substitutionsOnly = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = const NbaGameEventQueryEngine().build(
      widget.seed,
      gameId: widget.game.gameId,
    );
    final result = const NbaGameEventQueryEngine().build(
      widget.seed,
      gameId: widget.game.gameId,
      query: _query.text,
      category: _category,
      teamId: _teamId,
      period: _period,
      scoringOnly: _scoringOnly,
      closeGameOnly: _closeOnly,
      substitutionsOnly: _substitutionsOnly,
      ascending: true,
      limit: 250,
    );

    return Container(
      key: ValueKey('game-event-batch-export-${widget.game.gameId}'),
      width: double.infinity,
      decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EVENT EXPLORER / BATCH EXPORT',
                        style: TextStyle(
                          color: _amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Package a filtered set of canonical event rows into Workspace, Python Lab, Compare or Source Audit. The routed rows are exactly the visible query selection.',
                        style: TextStyle(color: _muted, fontSize: 9, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _pill('${result.matchedEvents}/${result.totalEvents} MATCHED', _blue),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('event-batch-export-search'),
              controller: _query,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: _text, fontSize: 10),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 16),
                hintText: 'Filter event description, identity, category or source…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dropdown<NbaPbpEventCategory?>(
                  key: const ValueKey('event-batch-export-category'),
                  value: _category,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All categories')),
                    for (final category in NbaPbpEventCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Text('${_categoryLabel(category)} (${all.categoryCounts[category] ?? 0})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
                _dropdown<String>(
                  key: const ValueKey('event-batch-export-team'),
                  value: _teamId,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All teams')),
                    for (final teamId in all.teamCounts.keys.toList()..sort())
                      DropdownMenuItem(
                        value: teamId,
                        child: Text('$teamId (${all.teamCounts[teamId]})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _teamId = value ?? ''),
                ),
                _dropdown<int?>(
                  key: const ValueKey('event-batch-export-period'),
                  value: _period,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All periods')),
                    for (final period in all.periodCounts.keys.toList()..sort())
                      DropdownMenuItem(
                        value: period,
                        child: Text('${_periodLabel(period)} (${all.periodCounts[period]})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _period = value),
                ),
                FilterChip(
                  key: const ValueKey('event-batch-export-scoring'),
                  selected: _scoringOnly,
                  label: const Text('SCORING'),
                  onSelected: (value) => setState(() {
                    _scoringOnly = value;
                    if (value) _substitutionsOnly = false;
                  }),
                ),
                FilterChip(
                  key: const ValueKey('event-batch-export-close'),
                  selected: _closeOnly,
                  label: const Text('OBSERVED CLOSE'),
                  onSelected: (value) => setState(() => _closeOnly = value),
                ),
                FilterChip(
                  key: const ValueKey('event-batch-export-substitutions'),
                  selected: _substitutionsOnly,
                  label: const Text('SUBSTITUTIONS'),
                  onSelected: (value) => setState(() {
                    _substitutionsOnly = value;
                    if (value) _scoringOnly = false;
                  }),
                ),
                if (_hasFilters)
                  TextButton(
                    key: const ValueKey('event-batch-export-clear'),
                    onPressed: _clear,
                    child: const Text('CLEAR'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(result.availabilityLabel, result.hasEvents ? _green : _amber),
                  Text(
                    result.filterSummary,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                  for (final target in const [
                    'Workspace',
                    'Python Lab',
                    'Compare',
                    'Source Audit',
                  ])
                    OutlinedButton(
                      key: ValueKey('event-batch-route-${_targetKey(target)}'),
                      onPressed: result.events.isEmpty
                          ? null
                          : () => widget.onRouteSelection(result, target),
                      child: Text('SEND TO ${target.toUpperCase()}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasFilters =>
      _query.text.trim().isNotEmpty ||
      _category != null ||
      _teamId.isNotEmpty ||
      _period != null ||
      _scoringOnly ||
      _closeOnly ||
      _substitutionsOnly;

  void _clear() {
    _query.clear();
    setState(() {
      _category = null;
      _teamId = '';
      _period = null;
      _scoringOnly = false;
      _closeOnly = false;
      _substitutionsOnly = false;
    });
  }
}

Widget _dropdown<T>({
  required Key key,
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return SizedBox(
    width: 170,
    child: DropdownButtonFormField<T>(
      key: key,
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(color: _text, fontSize: 9),
      dropdownColor: _panel2,
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
    ),
  );
}

Widget _pill(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );

String _categoryLabel(NbaPbpEventCategory category) => category.name
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}')
    .toUpperCase();

String _periodLabel(int period) => period <= 4 ? 'Q$period' : 'OT${period - 4}';

String _targetKey(String target) => target.toLowerCase().replaceAll(' ', '-');
