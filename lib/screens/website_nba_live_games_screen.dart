import 'dart:async';

import 'package:flutter/material.dart';

import '../services/nba_live_game_service.dart';

class WebsiteNbaLiveGamesScreen extends StatefulWidget {
  const WebsiteNbaLiveGamesScreen({super.key});

  @override
  State<WebsiteNbaLiveGamesScreen> createState() =>
      _WebsiteNbaLiveGamesScreenState();
}

class _WebsiteNbaLiveGamesScreenState extends State<WebsiteNbaLiveGamesScreen> {
  final _service = NbaLiveGameService();
  late Future<NbaScheduleSnapshot> _scheduleFuture;
  String? _selectedDate;
  String _teamFilter = 'All';
  Map<String, NbaLiveGameState> _live = const {};
  Object? _liveError;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = _loadSchedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<NbaScheduleSnapshot> _loadSchedule() async {
    final schedule = await _service.schedule();
    if (schedule.dates.isNotEmpty) {
      _selectedDate ??= _initialDate(schedule.dates);
      _restartPolling();
    }
    return schedule;
  }

  String _initialDate(List<String> dates) {
    final today = _dateKey(DateTime.now());
    for (final date in dates) {
      if (date.compareTo(today) >= 0) return date;
    }
    return dates.last;
  }

  bool get _selectedIsToday => _selectedDate == _dateKey(DateTime.now());

  void _restartPolling() {
    _timer?.cancel();
    if (!_selectedIsToday) {
      if (mounted) setState(() => _live = const {});
      return;
    }
    unawaited(_refreshLive());
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_refreshLive()),
    );
  }

  Future<void> _refreshLive() async {
    try {
      final next = await _service.todayScoreboard();
      if (!mounted) return;
      setState(() {
        _live = next;
        _liveError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _liveError = error);
    }
  }

  void _selectDate(String date) {
    setState(() {
      _selectedDate = date;
      _live = const {};
      _liveError = null;
    });
    _restartPolling();
  }

  void _moveDate(NbaScheduleSnapshot schedule, int delta) {
    final current = schedule.dates.indexOf(_selectedDate ?? '');
    if (current < 0) return;
    final next = (current + delta).clamp(0, schedule.dates.length - 1);
    if (next != current) _selectDate(schedule.dates[next]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaScheduleSnapshot>(
      future: _scheduleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 460,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _ScheduleError(
            error: snapshot.error,
            onRetry: () => setState(() => _scheduleFuture = _loadSchedule()),
          );
        }
        return _buildPage(context, snapshot.data!);
      },
    );
  }

  Widget _buildPage(BuildContext context, NbaScheduleSnapshot schedule) {
    final colors = Theme.of(context).colorScheme;
    final selectedDate = _selectedDate ??
        (schedule.dates.isEmpty ? '' : schedule.dates.first);
    final dateGames = schedule.forDate(selectedDate);
    final teamOptions = <String>{
      for (final game in schedule.games)
        if (game.homeTricode.isNotEmpty) game.homeTricode.toUpperCase(),
      for (final game in schedule.games)
        if (game.awayTricode.isNotEmpty) game.awayTricode.toUpperCase(),
    }.toList()
      ..sort();
    final games = _teamFilter == 'All'
        ? dateGames
        : dateGames
            .where(
              (game) =>
                  game.homeTricode.toUpperCase() == _teamFilter ||
                  game.awayTricode.toUpperCase() == _teamFilter,
            )
            .toList(growable: false);
    final currentIndex = schedule.dates.indexOf(selectedDate);
    final todayKey = _dateKey(DateTime.now());
    final hasToday = schedule.dates.contains(todayKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Live Games',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
            const Chip(
              avatar: Icon(Icons.calendar_month_rounded, size: 17),
              label: Text('2026-27 schedule'),
            ),
            if (_selectedIsToday)
              const Chip(
                avatar: Icon(Icons.circle, size: 10, color: Colors.redAccent),
                label: Text('15s live refresh'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'The season schedule is materialized locally from the official NBA schedule. Only genuinely live score state uses the NBA live-data feed.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Previous game date',
                  onPressed: currentIndex > 0
                      ? () => _moveDate(schedule, -1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(selectedDate),
                    initialValue: selectedDate.isEmpty ? null : selectedDate,
                    decoration: const InputDecoration(
                      labelText: 'Game date',
                      isDense: true,
                    ),
                    items: [
                      for (final date in schedule.dates)
                        DropdownMenuItem(
                          value: date,
                          child: Text(_dateLabel(date)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _selectDate(value);
                    },
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Next game date',
                  onPressed: currentIndex >= 0 &&
                          currentIndex < schedule.dates.length - 1
                      ? () => _moveDate(schedule, 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                SizedBox(
                  width: 135,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_teamFilter),
                    initialValue: _teamFilter,
                    decoration: const InputDecoration(
                      labelText: 'Team',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'All',
                        child: Text('All teams'),
                      ),
                      for (final team in teamOptions)
                        DropdownMenuItem(value: team, child: Text(team)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _teamFilter = value);
                      }
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: hasToday && !_selectedIsToday
                      ? () => _selectDate(todayKey)
                      : null,
                  icon: const Icon(Icons.today_rounded),
                  label: const Text('Today'),
                ),
                OutlinedButton.icon(
                  onPressed: _selectedIsToday ? _refreshLive : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh live'),
                ),
                Text(
                  _teamFilter == 'All'
                      ? '${games.length} game${games.length == 1 ? '' : 's'}'
                      : '${games.length} $_teamFilter game${games.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_liveError != null && _selectedIsToday) ...[
          const SizedBox(height: 10),
          Text(
            'Live overlay unavailable right now: $_liveError. The official schedule remains available.',
            style: TextStyle(color: colors.error),
          ),
        ],
        const SizedBox(height: 14),
        if (games.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No NBA games match this date and team filter.',
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1080
                  ? 3
                  : constraints.maxWidth >= 700
                      ? 2
                      : 1;
              final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final game in games)
                    SizedBox(
                      width: width,
                      child: _GameCard(
                        game: game,
                        live: _live[game.gameId],
                      ),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 18),
        Text(
          schedule.subjectToChange
              ? 'Official NBA schedule snapshot · subject to change, including NBA Cup-dependent games.'
              : 'Official NBA schedule snapshot.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.live});

  final NbaScheduledGame game;
  final NbaLiveGameState? live;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = live;
    final status = state == null
        ? _scheduledTime(game)
        : state.isLive
            ? '${state.statusText}${state.clock.isEmpty ? '' : ' · ${state.clock}'}'
            : state.statusText.isEmpty
                ? _scheduledTime(game)
                : state.statusText;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (state?.isLive == true) ...[
                  const Icon(Icons.circle, size: 9, color: Colors.redAccent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(
                      color: state?.isLive == true
                          ? Colors.redAccent
                          : colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (game.nationalTv.isNotEmpty)
                  Text(
                    game.nationalTv,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _TeamScoreRow(
              tricode: game.awayTricode,
              name: game.awayTeam,
              score: state?.awayScore,
              record: state?.awayRecord ?? '',
            ),
            const SizedBox(height: 10),
            _TeamScoreRow(
              tricode: game.homeTricode,
              name: game.homeTeam,
              score: state?.homeScore,
              record: state?.homeRecord ?? '',
            ),
            if (game.arena.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                game.arena,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.tricode,
    required this.name,
    required this.score,
    required this.record,
  });

  final String tricode;
  final String name;
  final int? score;
  final String record;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 19,
            child: Text(
              tricode.isEmpty ? '?' : tricode,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (record.isNotEmpty)
                  Text(record, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            score?.toString() ?? '—',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      );
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '2026-27 schedule snapshot unavailable',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '${error ?? ''}\n\nRun `bash scripts/open_terminal.sh` once while online. The launcher materializes the official NBA schedule locally, after which normal schedule browsing is static.',
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[parsed.weekday - 1]}, ${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}

String _scheduledTime(NbaScheduledGame game) {
  if (game.timeEt.isNotEmpty) return game.timeEt;
  final parsed = DateTime.tryParse(game.datetimeUtc);
  if (parsed == null) return 'Scheduled';
  return '${parsed.toLocal().hour.toString().padLeft(2, '0')}:${parsed.toLocal().minute.toString().padLeft(2, '0')}';
}
