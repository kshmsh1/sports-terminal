import 'package:flutter/material.dart';

import '../services/nba_game_schedule_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _sBg = Color(0xFF090D12);
const _sPanel = Color(0xFF0F151C);
const _sPanel2 = Color(0xFF141C25);
const _sLine = Color(0xFF263342);
const _sText = Color(0xFFE8EDF3);
const _sMuted = Color(0xFF8895A5);
const _sBlue = Color(0xFF63A9FF);
const _sGreen = Color(0xFF69C99A);
const _sAmber = Color(0xFFE2B866);

typedef NbaScheduleGameOpenCallback = void Function(
  String gameId,
  String gameLabel,
);

class ProductNbaScheduleScreen extends StatefulWidget {
  const ProductNbaScheduleScreen({
    super.key,
    this.loadSeed,
    this.onOpenGame,
    this.onOpenTeam,
    this.initialTeamId = 'All',
    this.initialQuery = '',
    this.initialSeasonType = 'All',
    this.initialAscending = true,
  });

  final Future<NbaTerminalSeedSnapshot> Function()? loadSeed;
  final NbaScheduleGameOpenCallback? onOpenGame;
  final ValueChanged<String>? onOpenTeam;
  final String initialTeamId;
  final String initialQuery;
  final String initialSeasonType;
  final bool initialAscending;

  @override
  State<ProductNbaScheduleScreen> createState() => _ProductNbaScheduleScreenState();
}

class _ProductNbaScheduleScreenState extends State<ProductNbaScheduleScreen> {
  static const _engine = NbaGameScheduleEngine();
  late final TextEditingController _search;
  late Future<NbaTerminalSeedSnapshot> _seedFuture;
  late String _team;
  String _status = 'All';
  late String _seasonType;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  late bool _ascending;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery.trim());
    _team = _normalizedInitial(widget.initialTeamId);
    _seasonType = _normalizedInitial(widget.initialSeasonType);
    _ascending = widget.initialAscending;
    _seedFuture = _load();
  }

  @override
  void didUpdateWidget(ProductNbaScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadSeed != widget.loadSeed) {
      _seedFuture = _load();
    }
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialTeamId != widget.initialTeamId ||
        oldWidget.initialSeasonType != widget.initialSeasonType ||
        oldWidget.initialAscending != widget.initialAscending) {
      _search.text = widget.initialQuery.trim();
      _team = _normalizedInitial(widget.initialTeamId);
      _seasonType = _normalizedInitial(widget.initialSeasonType);
      _ascending = widget.initialAscending;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<NbaTerminalSeedSnapshot> _load() =>
      widget.loadSeed?.call() ?? const NbaTerminalSeedRepository().load();

  void _refresh() {
    setState(() => _seedFuture = _load());
  }

  Future<void> _pickFrom() async {
    final picked = await _pickDate(_dateFrom ?? _dateTo ?? DateTime.now());
    if (picked == null || !mounted) return;
    setState(() {
      _dateFrom = picked;
      if (_dateTo != null && picked.isAfter(_dateTo!)) _dateTo = picked;
    });
  }

  Future<void> _pickTo() async {
    final picked = await _pickDate(_dateTo ?? _dateFrom ?? DateTime.now());
    if (picked == null || !mounted) return;
    setState(() {
      _dateTo = picked;
      if (_dateFrom != null && picked.isBefore(_dateFrom!)) _dateFrom = picked;
    });
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1946),
        lastDate: DateTime(2100),
      );

  void _clearFilters() {
    setState(() {
      _search.clear();
      _team = 'All';
      _status = 'All';
      _seasonType = 'All';
      _dateFrom = null;
      _dateTo = null;
      _ascending = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _sBg,
      child: FutureBuilder<NbaTerminalSeedSnapshot>(
        future: _seedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ScheduleState(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _ScheduleState(
              child: _ScheduleError(
                message: 'Schedule data unavailable: ${snapshot.error}',
                onRetry: _refresh,
              ),
            );
          }

          final all = _engine.build(snapshot.data!);
          final result = _engine.build(
            snapshot.data!,
            query: _search.text,
            teamId: _team,
            status: _status,
            seasonType: _seasonType,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            ascending: _ascending,
          );
          final teamOptions = ['All', ...all.teamOptions];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(result),
              const SizedBox(height: 12),
              _filters(
                teamOptions: teamOptions,
                statusOptions: all.statusOptions,
                seasonTypeOptions: all.seasonTypeOptions,
              ),
              const SizedBox(height: 12),
              _summary(result),
              const SizedBox(height: 12),
              if (result.rows.isEmpty)
                const _SchedulePanel(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 42),
                    child: Center(
                      child: Text(
                        'No canonical games match the active schedule filters.',
                        style: TextStyle(color: _sMuted),
                      ),
                    ),
                  ),
                )
              else
                _scheduleTable(result.rows),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(NbaGameScheduleResult result) {
    return _SchedulePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NBA / SCHEDULE',
            style: TextStyle(
              color: _sBlue,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Canonical game calendar',
            style: TextStyle(
              color: _sText,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Search and filter the active NBA game universe without creating a second schedule dataset. Every row stays attached to canonical game and team identities, while missing scores or source fields remain visibly unavailable.',
            style: TextStyle(color: _sMuted, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(result.historicalContext ? 'HISTORICAL CONTEXT' : 'CURRENT CONTEXT', _sBlue),
              _pill(result.datasetStatus.toUpperCase(), _sGreen),
              _pill('VALIDATION ${result.validationStatus.toUpperCase()}', _sGreen),
              if (_team != 'All') _pill('TEAM $_team', _sBlue),
              if (_seasonType != 'All') _pill(_seasonType.toUpperCase(), _sBlue),
              if (_search.text.trim().isNotEmpty) _pill('QUERY ${_search.text.trim()}', _sBlue),
              if (result.usedFallbackDataset) _pill('FALLBACK DATASET', _sAmber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters({
    required List<String> teamOptions,
    required List<String> statusOptions,
    required List<String> seasonTypeOptions,
  }) {
    return _SchedulePanel(
      child: Wrap(
        spacing: 9,
        runSpacing: 9,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              key: const ValueKey('schedule-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: _sText),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Game, team, venue, date…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _ScheduleDrop(
            label: 'Team',
            value: teamOptions.contains(_team) ? _team : 'All',
            values: teamOptions,
            onChanged: (value) => setState(() => _team = value),
          ),
          _ScheduleDrop(
            label: 'Status',
            value: statusOptions.contains(_status) ? _status : 'All',
            values: statusOptions,
            onChanged: (value) => setState(() => _status = value),
          ),
          _ScheduleDrop(
            label: 'Season type',
            value: seasonTypeOptions.contains(_seasonType) ? _seasonType : 'All',
            values: seasonTypeOptions,
            onChanged: (value) => setState(() => _seasonType = value),
          ),
          OutlinedButton.icon(
            onPressed: _pickFrom,
            icon: const Icon(Icons.calendar_month_rounded, size: 17),
            label: Text(_dateFrom == null ? 'From date' : 'From ${_dateLabel(_dateFrom!)}'),
          ),
          OutlinedButton.icon(
            onPressed: _pickTo,
            icon: const Icon(Icons.event_rounded, size: 17),
            label: Text(_dateTo == null ? 'To date' : 'To ${_dateLabel(_dateTo!)}'),
          ),
          IconButton(
            tooltip: _ascending ? 'Oldest first' : 'Newest first',
            onPressed: () => setState(() => _ascending = !_ascending),
            icon: Icon(
              _ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: _sBlue,
            ),
          ),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _summary(NbaGameScheduleResult result) {
    return _SchedulePanel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _metric('Games', '${result.rows.length}', 'Visible canonical rows'),
          _metric('Completed', '${result.completedGames}', 'Rows with both scores'),
          _metric('Scheduled', '${result.scheduledGames}', 'Score unavailable / future'),
          _metric('Teams', '${result.uniqueTeams}', 'Visible team identities'),
        ],
      ),
    );
  }

  Widget _scheduleTable(List<NbaGameScheduleRow> rows) {
    return _SchedulePanel(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_sPanel2),
          headingTextStyle: const TextStyle(
            color: _sMuted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
          dataTextStyle: const TextStyle(color: _sText, fontSize: 11),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('DATE')),
            DataColumn(label: Text('MATCHUP')),
            DataColumn(label: Text('SCORE')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('TYPE')),
            DataColumn(label: Text('LOCATION')),
            DataColumn(label: Text('SOURCE')),
            DataColumn(label: Text('GAME')),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  DataCell(Text(row.gameDate.isEmpty ? '—' : row.gameDate)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _teamLink(row.awayTeamId, row.awayTeamAbbreviation),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('@', style: TextStyle(color: _sMuted)),
                        ),
                        _teamLink(row.homeTeamId, row.homeTeamAbbreviation),
                      ],
                    ),
                  ),
                  DataCell(Text(row.scoreLabel)),
                  DataCell(Text(row.status.isEmpty ? '—' : row.status)),
                  DataCell(Text(row.seasonType.isEmpty ? '—' : row.seasonType)),
                  DataCell(
                    SizedBox(
                      width: 210,
                      child: Text(
                        row.locationLabel.isEmpty ? '—' : row.locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(row.sourceId.isEmpty ? '—' : row.sourceId)),
                  DataCell(
                    TextButton.icon(
                      key: ValueKey('schedule-game-${row.gameId}'),
                      onPressed: widget.onOpenGame == null
                          ? null
                          : () => widget.onOpenGame!(row.gameId, row.matchupLabel),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _teamLink(String teamId, String label) {
    final enabled = teamId.isNotEmpty && widget.onOpenTeam != null;
    return InkWell(
      onTap: enabled ? () => widget.onOpenTeam!(teamId) : null,
      child: Text(
        label.isEmpty ? (teamId.isEmpty ? '—' : teamId) : label,
        style: TextStyle(
          color: enabled ? _sBlue : _sText,
          fontWeight: FontWeight.w900,
          decoration: enabled ? TextDecoration.underline : null,
          decorationColor: _sBlue,
        ),
      ),
    );
  }

  Widget _metric(String label, String value, String detail) => Container(
        width: 178,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _sPanel2, border: Border.all(color: _sLine)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(color: _sMuted, fontSize: 8, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: _sText, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(color: _sMuted, fontSize: 9)),
          ],
        ),
      );

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      );
}

class _ScheduleDrop extends StatelessWidget {
  const _ScheduleDrop({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        constraints: const BoxConstraints(minWidth: 145, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: _sPanel2, border: Border.all(color: _sLine)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: _sPanel2,
            style: const TextStyle(color: _sText),
            hint: Text(label),
            items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item))],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _sPanel, border: Border.all(color: _sLine)),
        child: child,
      );
}

class _ScheduleState extends StatelessWidget {
  const _ScheduleState({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 360),
        color: _sBg,
        padding: const EdgeInsets.all(22),
        child: child,
      );
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, color: _sMuted, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _sMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}

String _normalizedInitial(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'All' : trimmed;
}

String _dateLabel(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
