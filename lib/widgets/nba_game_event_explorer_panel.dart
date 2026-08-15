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

/// Interactive analyst surface over canonical play-by-play rows.
///
/// Search/filter state is local presentation state; all event matching is owned
/// by [NbaGameEventQueryEngine]. Selecting an event opens a detail inspector and
/// optional workflow actions for the exact event package.
class NbaGameEventExplorerPanel extends StatefulWidget {
  const NbaGameEventExplorerPanel({
    super.key,
    required this.seed,
    required this.game,
    this.onOpenTeam,
    this.onOpenPlayer,
    this.onRouteEvent,
  });

  final NbaTerminalSeedSnapshot seed;
  final NbaGameIntelligenceSnapshot game;
  final ValueChanged<String>? onOpenTeam;
  final void Function(String playerId, String playerName)? onOpenPlayer;
  final void Function(NbaGamePlayByPlayEvent event, String targetRoute)? onRouteEvent;

  @override
  State<NbaGameEventExplorerPanel> createState() => _NbaGameEventExplorerPanelState();
}

class _NbaGameEventExplorerPanelState extends State<NbaGameEventExplorerPanel> {
  final TextEditingController _queryController = TextEditingController();
  NbaPbpEventCategory? _category;
  String _teamId = '';
  String _playerId = '';
  int? _period;
  bool _scoringOnly = false;
  bool _closeOnly = false;
  bool _substitutionsOnly = false;
  bool _ascending = true;
  int? _selectedSequence;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facets = const NbaGameEventQueryEngine().build(
      widget.seed,
      gameId: widget.game.gameId,
    );
    final result = const NbaGameEventQueryEngine().build(
      widget.seed,
      gameId: widget.game.gameId,
      query: _queryController.text,
      category: _category,
      teamId: _teamId,
      playerId: _playerId,
      period: _period,
      scoringOnly: _scoringOnly,
      closeGameOnly: _closeOnly,
      substitutionsOnly: _substitutionsOnly,
      ascending: _ascending,
      limit: 250,
    );
    final selected = _selectedEvent(result.events, facets.events);
    final playerLabels = _playerLabels(widget.seed);

    return Container(
      key: ValueKey('game-event-explorer-${widget.game.gameId}'),
      width: double.infinity,
      decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EVENT EXPLORER',
                        style: TextStyle(
                          color: _amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Search and filter the canonical row-level event stream. Close-game filters use explicit Q4/OT score states only.',
                        style: TextStyle(color: _muted, fontSize: 9, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _pill('${result.matchedEvents}/${result.totalEvents} EVENTS', _blue),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('event-explorer-search'),
                  controller: _queryController,
                  onChanged: (_) => setState(() => _selectedSequence = null),
                  style: const TextStyle(color: _text, fontSize: 11),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search event text, player, team, category, source…',
                    hintStyle: const TextStyle(color: _muted, fontSize: 10),
                    prefixIcon: const Icon(Icons.search, size: 17, color: _muted),
                    suffixIcon: _queryController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _queryController.clear();
                              setState(() => _selectedSequence = null);
                            },
                            icon: const Icon(Icons.close, size: 16),
                          ),
                    filled: true,
                    fillColor: _panel2,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _dropdown<NbaPbpEventCategory?>(
                      key: const ValueKey('event-explorer-category'),
                      value: _category,
                      label: 'CATEGORY',
                      items: [
                        const DropdownMenuItem<NbaPbpEventCategory?>(
                          value: null,
                          child: Text('All categories'),
                        ),
                        for (final category in NbaPbpEventCategory.values)
                          DropdownMenuItem<NbaPbpEventCategory?>(
                            value: category,
                            child: Text('${_categoryLabel(category)} (${facets.categoryCounts[category] ?? 0})'),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _category = value;
                        _selectedSequence = null;
                      }),
                    ),
                    _dropdown<int?>(
                      key: const ValueKey('event-explorer-period'),
                      value: _period,
                      label: 'PERIOD',
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All periods')),
                        for (final period in facets.periodCounts.keys.toList()..sort())
                          DropdownMenuItem<int?>(
                            value: period,
                            child: Text('${_periodLabel(period)} (${facets.periodCounts[period]})'),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _period = value;
                        _selectedSequence = null;
                      }),
                    ),
                    _dropdown<String>(
                      key: const ValueKey('event-explorer-team'),
                      value: _teamId,
                      label: 'TEAM',
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All teams')),
                        for (final teamId in facets.teamCounts.keys.toList()..sort())
                          DropdownMenuItem(
                            value: teamId,
                            child: Text('$teamId (${facets.teamCounts[teamId]})'),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _teamId = value ?? '';
                        _selectedSequence = null;
                      }),
                    ),
                    _dropdown<String>(
                      key: const ValueKey('event-explorer-player'),
                      value: _playerId,
                      label: 'PLAYER',
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All players')),
                        for (final playerId in facets.playerCounts.keys.toList()..sort())
                          DropdownMenuItem(
                            value: playerId,
                            child: Text('${playerLabels[playerId] ?? playerId} (${facets.playerCounts[playerId]})'),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _playerId = value ?? '';
                        _selectedSequence = null;
                      }),
                    ),
                    FilterChip(
                      key: const ValueKey('event-explorer-scoring-only'),
                      selected: _scoringOnly,
                      label: const Text('SCORING'),
                      onSelected: (value) => setState(() {
                        _scoringOnly = value;
                        if (value) _substitutionsOnly = false;
                        _selectedSequence = null;
                      }),
                    ),
                    FilterChip(
                      key: const ValueKey('event-explorer-close-only'),
                      selected: _closeOnly,
                      label: const Text('OBSERVED CLOSE'),
                      onSelected: (value) => setState(() {
                        _closeOnly = value;
                        _selectedSequence = null;
                      }),
                    ),
                    FilterChip(
                      key: const ValueKey('event-explorer-substitutions-only'),
                      selected: _substitutionsOnly,
                      label: const Text('SUBSTITUTIONS'),
                      onSelected: (value) => setState(() {
                        _substitutionsOnly = value;
                        if (value) _scoringOnly = false;
                        _selectedSequence = null;
                      }),
                    ),
                    TextButton.icon(
                      key: const ValueKey('event-explorer-order'),
                      onPressed: () => setState(() {
                        _ascending = !_ascending;
                        _selectedSequence = null;
                      }),
                      icon: Icon(_ascending ? Icons.arrow_downward : Icons.arrow_upward, size: 14),
                      label: Text(_ascending ? 'EARLIEST FIRST' : 'LATEST FIRST'),
                    ),
                    if (result.hasActiveFilters)
                      TextButton(
                        key: const ValueKey('event-explorer-clear'),
                        onPressed: _clearFilters,
                        child: const Text('CLEAR FILTERS'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!result.hasEvents)
                  _empty(result)
                else ...[
                  _eventTable(result),
                  if (result.truncated) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Showing ${result.returnedEvents} of ${result.matchedEvents} matching events.',
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                  ],
                ],
                if (selected != null) ...[
                  const SizedBox(height: 12),
                  _EventInspector(
                    event: selected,
                    onOpenTeam: widget.onOpenTeam,
                    onOpenPlayer: widget.onOpenPlayer,
                    onRouteEvent: widget.onRouteEvent,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  NbaGamePlayByPlayEvent? _selectedEvent(
    List<NbaGamePlayByPlayEvent> visible,
    List<NbaGamePlayByPlayEvent> all,
  ) {
    final sequence = _selectedSequence;
    if (sequence == null) return null;
    for (final event in visible) {
      if (event.sequence == sequence) return event;
    }
    for (final event in all) {
      if (event.sequence == sequence) return event;
    }
    return null;
  }

  Widget _eventTable(NbaGameEventQueryResult result) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_panel2),
          headingTextStyle: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900),
          dataTextStyle: const TextStyle(color: _text, fontSize: 9),
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('TIME')),
            DataColumn(label: Text('CATEGORY')),
            DataColumn(label: Text('TEAM')),
            DataColumn(label: Text('PLAYER')),
            DataColumn(label: Text('SCORE')),
            DataColumn(label: Text('DESCRIPTION')),
            DataColumn(label: Text('DETAIL')),
          ],
          rows: [
            for (var index = 0; index < result.events.length; index++)
              _eventRow(result.events[index], index),
          ],
        ),
      );

  DataRow _eventRow(NbaGamePlayByPlayEvent event, int index) {
    final sequence = event.sequence ?? index;
    final selected = _selectedSequence == event.sequence;
    return DataRow(
      selected: selected,
      cells: [
        DataCell(Text(event.sequence?.toString() ?? '—')),
        DataCell(Text('${event.periodLabel} ${event.clock}'.trim())),
        DataCell(Text(event.categoryLabel)),
        DataCell(
          _entityText(
            event.team.abbreviation.isEmpty ? event.team.id : event.team.abbreviation,
            enabled: widget.onOpenTeam != null && event.team.id.isNotEmpty,
            onTap: () => widget.onOpenTeam?.call(event.team.id),
          ),
        ),
        DataCell(
          _entityText(
            event.player.label.isEmpty ? '—' : event.player.label,
            enabled: widget.onOpenPlayer != null && event.player.id.isNotEmpty,
            onTap: () => widget.onOpenPlayer?.call(event.player.id, event.player.label),
          ),
        ),
        DataCell(Text(event.scoreLabel)),
        DataCell(
          SizedBox(
            width: 310,
            child: Text(
              event.description.isEmpty ? '—' : event.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          IconButton(
            key: ValueKey('event-explorer-open-$sequence'),
            tooltip: 'Inspect event',
            onPressed: () => setState(() => _selectedSequence = event.sequence ?? sequence),
            icon: const Icon(Icons.open_in_new, size: 15, color: _blue),
          ),
        ),
      ],
    );
  }

  Widget _empty(NbaGameEventQueryResult result) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
        child: Text(
          result.totalEvents == 0
              ? 'Row-level play-by-play is ${result.availabilityLabel.toLowerCase()} for this game.'
              : 'No canonical events match the active filters.',
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
      );

  void _clearFilters() {
    _queryController.clear();
    setState(() {
      _category = null;
      _teamId = '';
      _playerId = '';
      _period = null;
      _scoringOnly = false;
      _closeOnly = false;
      _substitutionsOnly = false;
      _ascending = true;
      _selectedSequence = null;
    });
  }
}

class _EventInspector extends StatelessWidget {
  const _EventInspector({
    required this.event,
    required this.onOpenTeam,
    required this.onOpenPlayer,
    required this.onRouteEvent,
  });

  final NbaGamePlayByPlayEvent event;
  final ValueChanged<String>? onOpenTeam;
  final void Function(String playerId, String playerName)? onOpenPlayer;
  final void Function(NbaGamePlayByPlayEvent event, String targetRoute)? onRouteEvent;

  @override
  Widget build(BuildContext context) {
    final sequence = event.sequence?.toString() ?? 'unsequenced';
    return Container(
      key: ValueKey('event-explorer-inspector-$sequence'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: _blue.withValues(alpha: .45))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'EVENT $sequence · ${event.periodLabel} ${event.clock} · ${event.categoryLabel}',
                  style: const TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              _pill(event.scoreLabel, event.hasScore ? _green : _muted),
            ],
          ),
          const SizedBox(height: 8),
          if (event.description.isNotEmpty)
            Text(event.description, style: const TextStyle(color: _text, fontSize: 10, height: 1.4)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _datum('TYPE', event.typeLabel),
              _datum('RESULT', event.result.name.toUpperCase()),
              _datum('MARGIN', event.margin == null ? '—' : '${event.margin! >= 0 ? '+' : ''}${event.margin}'),
              _datum('SOURCE', event.sourceId.isEmpty ? '—' : event.sourceId),
              _datum('ELAPSED', event.elapsedGameSeconds == null ? '—' : '${event.elapsedGameSeconds!.toStringAsFixed(1)}s'),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (event.team.id.isNotEmpty)
                _entityButton(
                  label: event.team.abbreviation.isEmpty ? event.team.id : event.team.abbreviation,
                  enabled: onOpenTeam != null,
                  onPressed: () => onOpenTeam?.call(event.team.id),
                ),
              for (final participant in _uniqueParticipants(event))
                _entityButton(
                  label: participant.label,
                  enabled: onOpenPlayer != null && participant.id.isNotEmpty,
                  onPressed: () => onOpenPlayer?.call(participant.id, participant.label),
                ),
            ],
          ),
          if (event.hasExplicitSubstitution) ...[
            const SizedBox(height: 8),
            Text(
              '${event.substitutionIn.label} IN · ${event.substitutionOut.label} OUT',
              style: const TextStyle(color: _amber, fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ],
          if (onRouteEvent != null) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final target in const ['Workspace', 'Python Lab', 'Compare', 'Source Audit'])
                  OutlinedButton(
                    key: ValueKey('event-route-${_routeKey(target)}-$sequence'),
                    onPressed: () => onRouteEvent!(event, target),
                    child: Text(target.toUpperCase()),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Widget _dropdown<T>({
  required Key key,
  required T value,
  required String label,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) =>
    Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w900)),
          DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox.shrink(),
            dropdownColor: _panel2,
            style: const TextStyle(color: _text, fontSize: 9),
            isDense: true,
          ),
        ],
      ),
    );

Widget _entityText(String label, {required bool enabled, required VoidCallback onTap}) => InkWell(
      onTap: enabled ? onTap : null,
      child: Text(
        label.isEmpty ? '—' : label,
        style: TextStyle(
          color: enabled ? _blue : _text,
          fontWeight: FontWeight.w800,
          decoration: enabled ? TextDecoration.underline : null,
          decorationColor: _blue,
        ),
      ),
    );

Widget _entityButton({required String label, required bool enabled, required VoidCallback onPressed}) =>
    OutlinedButton(
      onPressed: enabled ? onPressed : null,
      child: Text(label),
    );

Widget _pill(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );

Widget _datum(String label, String value) => RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 9),
        children: [
          TextSpan(text: '$label ', style: const TextStyle(color: _muted)),
          TextSpan(text: value, style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
        ],
      ),
    );

Map<String, String> _playerLabels(NbaTerminalSeedSnapshot seed) {
  final result = <String, String>{};
  for (final row in seed.players) {
    final id = _first(row, const ['player_id', 'playerId', 'person_id', 'id']);
    if (id.isEmpty) continue;
    final name = _first(row, const ['player_name', 'playerName', 'display_name', 'full_name', 'name']);
    result[id] = name.isEmpty ? id : name;
  }
  return result;
}

List<NbaPbpPlayerIdentity> _uniqueParticipants(NbaGamePlayByPlayEvent event) {
  final result = <String, NbaPbpPlayerIdentity>{};
  for (final player in [
    event.player,
    event.secondaryPlayer,
    event.tertiaryPlayer,
    event.substitutionOut,
    event.substitutionIn,
  ]) {
    if (player.isEmpty) continue;
    final key = player.id.trim().isNotEmpty ? player.id.trim().toUpperCase() : player.label.toUpperCase();
    result[key] = player;
  }
  return result.values.toList(growable: false);
}

String _first(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value == null || value is Map || value is Iterable) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null' && text != '—') return text;
  }
  return '';
}

String _categoryLabel(NbaPbpEventCategory category) => switch (category) {
      NbaPbpEventCategory.madeFieldGoal => 'Made FG',
      NbaPbpEventCategory.missedFieldGoal => 'Missed FG',
      NbaPbpEventCategory.freeThrow => 'Free throw',
      NbaPbpEventCategory.rebound => 'Rebound',
      NbaPbpEventCategory.turnover => 'Turnover',
      NbaPbpEventCategory.foul => 'Foul',
      NbaPbpEventCategory.violation => 'Violation',
      NbaPbpEventCategory.substitution => 'Substitution',
      NbaPbpEventCategory.timeout => 'Timeout',
      NbaPbpEventCategory.jumpBall => 'Jump ball',
      NbaPbpEventCategory.periodStart => 'Period start',
      NbaPbpEventCategory.periodEnd => 'Period end',
      NbaPbpEventCategory.review => 'Review',
      NbaPbpEventCategory.ejection => 'Ejection',
      NbaPbpEventCategory.other => 'Other',
    };

String _periodLabel(int period) => period <= 4 ? 'Q$period' : 'OT${period - 4}';
String _routeKey(String target) => target.toLowerCase().replaceAll(' ', '-');
