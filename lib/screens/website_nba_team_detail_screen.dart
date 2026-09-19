import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_live_game_service.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/website_nba_api_service.dart';

typedef TeamPlayerOpenCallback = void Function(
  BuildContext context,
  String playerKey,
  String playerName,
);

class WebsiteNbaTeamDetailScreen extends StatefulWidget {
  const WebsiteNbaTeamDetailScreen({
    super.key,
    required this.session,
    required this.teamKey,
    required this.teamName,
    required this.onOpenPlayer,
  });

  final AppSession session;
  final String teamKey;
  final String teamName;
  final TeamPlayerOpenCallback onOpenPlayer;

  @override
  State<WebsiteNbaTeamDetailScreen> createState() =>
      _WebsiteNbaTeamDetailScreenState();
}

class _WebsiteNbaTeamDetailScreenState
    extends State<WebsiteNbaTeamDetailScreen> {
  final _api = const WebsiteNbaApiService();
  final _engine = const NbaStatsWorkstationEngine();
  final _contracts = const NbaTradeContractRepository();
  final _live = NbaLiveGameService();
  late Future<_TeamDetailData> _future;
  String _historySegment = 'regular';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TeamDetailData> _load() async {
    final dossier = await _api.teamDossier(widget.teamKey);
    final profile = _map(dossier['profile']);
    final abbreviation = _text(profile['abbreviation']).toUpperCase();

    NbaTradeContractSnapshot? contractSnapshot;
    try {
      contractSnapshot = await _contracts.load();
    } catch (_) {
      contractSnapshot = null;
    }

    List<NbaStatsRow> latestRows = const [];
    try {
      final snapshot = await _api.seasonSnapshot('2025-26');
      latestRows = _engine.buildRows(
        snapshot,
        basis: NbaStatsBasis.perGame,
        seasonType: NbaStatsSeasonType.regular,
      );
    } catch (_) {
      latestRows = const [];
    }

    NbaScheduleSnapshot? schedule;
    String scheduleError = '';
    try {
      schedule = await _live.schedule();
    } catch (error) {
      scheduleError = error.toString();
    }

    final latestByName = <String, NbaStatsRow>{
      for (final row in latestRows) _nameToken(row.player): row,
    };
    final roster = <_RosterRow>[];
    if (contractSnapshot != null && abbreviation.isNotEmpty) {
      for (final contract in contractSnapshot.forTeam(abbreviation, '2026-27')) {
        final previous = latestByName[_nameToken(contract.player)];
        roster.add(
          _RosterRow(
            player: contract.player,
            playerKey: previous?.playerId ?? '',
            position: previous?.position ?? '—',
            salary: contract.salaryFor('2026-27'),
            guaranteed: contract.guaranteed,
            previousGames: previous?.value('gp'),
            previousMinutes: previous?.value('min'),
            previousPoints: previous?.value('pts'),
            sourceLabel: contract.sourceLabel,
          ),
        );
      }
      roster.sort((a, b) {
        final minutes = (b.previousMinutes ?? -1).compareTo(a.previousMinutes ?? -1);
        return minutes != 0 ? minutes : b.salary.compareTo(a.salary);
      });
    }

    final scheduleRows = schedule == null || abbreviation.isEmpty
        ? const <NbaScheduledGame>[]
        : schedule.games
            .where(
              (game) =>
                  game.homeTricode.toUpperCase() == abbreviation ||
                  game.awayTricode.toUpperCase() == abbreviation,
            )
            .toList(growable: false);

    final injuries = _firstMapList(
      dossier,
      const ['injuries_2026_27', 'current_injuries', 'injuries'],
    );
    final transactions = _firstMapList(
      dossier,
      const ['transactions_2026_27', 'current_transactions', 'transactions'],
    );

    return _TeamDetailData(
      dossier: dossier,
      roster: roster,
      schedule: scheduleRows,
      scheduleSource: schedule?.source ?? '',
      scheduleError: scheduleError,
      injuries: injuries,
      transactions: transactions,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sports Terminal')),
        body: FutureBuilder<_TeamDetailData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.teamName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text('Team page unavailable: ${snapshot.error}'),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => setState(() => _future = _load()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return _buildContent(context, snapshot.data!);
          },
        ),
      );

  Widget _buildContent(BuildContext context, _TeamDetailData data) {
    final profile = _map(data.dossier['profile']);
    final franchise = _map(data.dossier['franchise']);
    final allSeasons = _maps(data.dossier['seasons']);
    final history = allSeasons
        .where(
          (row) => _text(row['season_type'], 'regular') == _historySegment,
        )
        .toList(growable: false);
    final notablePlayers = _maps(data.dossier['notable_players']);
    final recentGames = _maps(data.dossier['recent_games']);
    final name = _text(profile['canonical_name'], widget.teamName);
    final abbreviation = _text(profile['abbreviation']);
    final colors = Theme.of(context).colorScheme;
    final rosterPayroll = data.roster.fold<double>(
      0,
      (sum, row) => sum + row.salary,
    );
    final knownGuaranteed = data.roster.fold<double>(
      0,
      (sum, row) => sum + (row.guaranteed ?? 0),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      abbreviation.isEmpty ? 'NBA' : abbreviation,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            abbreviation,
                            _text(franchise['canonical_name']),
                            '2026–27 Team Hub',
                          ].where((value) => value.isNotEmpty).join(' · '),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SummaryStrip(
                items: [
                  _SummaryValue('2026–27 roster', '${data.roster.length}'),
                  _SummaryValue('2026–27 payroll', _money(rosterPayroll)),
                  _SummaryValue('Known guaranteed', _money(knownGuaranteed)),
                  _SummaryValue('2026–27 games', '${data.schedule.length}'),
                  _SummaryValue('Historical seasons', '${_uniqueSeasons(allSeasons)}'),
                  _SummaryValue('Team key', widget.teamKey),
                ],
              ),
              const SizedBox(height: 18),
              _RosterFinancialSummary(rows: data.roster),
              const SizedBox(height: 30),
              const _SectionTitle('2026–27 depth chart'),
              const SizedBox(height: 6),
              Text(
                'Position groups use the latest source-backed player position and prior-season minutes where available. They are a roster visualization, not an official coaching depth chart.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              _DepthChartTable(roster: data.roster),
              const SizedBox(height: 30),
              const _SectionTitle('2026–27 roster'),
              const SizedBox(height: 10),
              _RosterTable(
                rows: data.roster,
                onPlayer: (row) {
                  if (row.playerKey.isEmpty) return;
                  widget.onOpenPlayer(
                    context,
                    row.playerKey,
                    row.player,
                  );
                },
              ),
              const SizedBox(height: 30),
              const _SectionTitle('Injuries'),
              const SizedBox(height: 10),
              _InjuriesTable(rows: data.injuries),
              const SizedBox(height: 30),
              const _SectionTitle('Transactions'),
              const SizedBox(height: 10),
              _TransactionsTable(rows: data.transactions),
              const SizedBox(height: 30),
              const _SectionTitle('2026–27 schedule'),
              if (data.scheduleSource.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  'Schedule source: ${data.scheduleSource}. Future dates remain subject to league changes.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 10),
              _ScheduleTable(
                rows: data.schedule,
                unavailableReason: data.scheduleError,
                team: abbreviation,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Season history',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'regular', label: Text('Regular Season')),
                      ButtonSegment(value: 'playoffs', label: Text('Playoffs')),
                    ],
                    selected: {_historySegment},
                    onSelectionChanged: (value) =>
                        setState(() => _historySegment = value.first),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SeasonHistoryTable(rows: history),
              const SizedBox(height: 30),
              const _SectionTitle('Notable players'),
              const SizedBox(height: 10),
              _NotablePlayers(
                rows: notablePlayers,
                onPlayer: (row) {
                  final key = _text(row['player_key']);
                  if (key.isEmpty) return;
                  widget.onOpenPlayer(
                    context,
                    key,
                    _text(row['player_name'], 'Player'),
                  );
                },
              ),
              const SizedBox(height: 30),
              const _SectionTitle('Recent historical games'),
              const SizedBox(height: 10),
              _HistoricalGames(rows: recentGames),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamDetailData {
  const _TeamDetailData({
    required this.dossier,
    required this.roster,
    required this.schedule,
    required this.scheduleSource,
    required this.scheduleError,
    required this.injuries,
    required this.transactions,
  });

  final Map<String, dynamic> dossier;
  final List<_RosterRow> roster;
  final List<NbaScheduledGame> schedule;
  final String scheduleSource;
  final String scheduleError;
  final List<Map<String, dynamic>> injuries;
  final List<Map<String, dynamic>> transactions;
}

class _RosterRow {
  const _RosterRow({
    required this.player,
    required this.playerKey,
    required this.position,
    required this.salary,
    required this.guaranteed,
    required this.previousGames,
    required this.previousMinutes,
    required this.previousPoints,
    required this.sourceLabel,
  });

  final String player;
  final String playerKey;
  final String position;
  final double salary;
  final double? guaranteed;
  final double? previousGames;
  final double? previousMinutes;
  final double? previousPoints;
  final String sourceLabel;
}

class _SummaryValue {
  const _SummaryValue(this.label, this.value);
  final String label;
  final String value;
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.items});
  final List<_SummaryValue> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 800
              ? (constraints.maxWidth - 36) / 4
              : constraints.maxWidth >= 480
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _RosterFinancialSummary extends StatelessWidget {
  const _RosterFinancialSummary({required this.rows});

  final List<_RosterRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final ordered = [...rows]
      ..sort((a, b) => b.salary.compareTo(a.salary));
    final payroll = rows.fold<double>(0, (sum, row) => sum + row.salary);
    final guaranteed =
        rows.fold<double>(0, (sum, row) => sum + (row.guaranteed ?? 0));
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final totals = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Roster financial snapshot',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Salary rows reflect the current 2026–27 contract snapshot loaded into Sports Terminal.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Text(
                  _money(payroll),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  'Known guaranteed: ${_money(guaranteed)}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            );
            final leaders = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Largest 2026–27 cap hits',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (final row in ordered.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.player,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _money(row.salary),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  totals,
                  const SizedBox(height: 18),
                  leaders,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: totals),
                const SizedBox(width: 28),
                Expanded(child: leaders),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DepthChartTable extends StatelessWidget {
  const _DepthChartTable({required this.roster});
  final List<_RosterRow> roster;

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty) {
      return const _EmptyCard(
        'The 2026–27 salary/roster seed does not contain a source-backed roster for this team yet.',
      );
    }
    final groups = <String, List<_RosterRow>>{
      'PG': [],
      'SG': [],
      'SF': [],
      'PF': [],
      'C': [],
      'UTIL': [],
    };
    for (final row in roster) {
      groups[_positionBucket(row.position)]!.add(row);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Position')),
            DataColumn(label: Text('1')),
            DataColumn(label: Text('2')),
            DataColumn(label: Text('3')),
            DataColumn(label: Text('Other')),
          ],
          rows: [
            for (final entry in groups.entries)
              if (entry.value.isNotEmpty)
                DataRow(
                  cells: [
                    DataCell(Text(entry.key)),
                    DataCell(Text(_depthName(entry.value, 0))),
                    DataCell(Text(_depthName(entry.value, 1))),
                    DataCell(Text(_depthName(entry.value, 2))),
                    DataCell(Text(
                      entry.value.length <= 3
                          ? '—'
                          : entry.value.skip(3).map((row) => row.player).join(', '),
                    )),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class _RosterTable extends StatelessWidget {
  const _RosterTable({required this.rows, required this.onPlayer});
  final List<_RosterRow> rows;
  final ValueChanged<_RosterRow> onPlayer;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyCard(
        'No source-backed 2026–27 roster rows are available for this team in the current release.',
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Player')),
            DataColumn(label: Text('Pos')),
            DataColumn(numeric: true, label: Text('2026–27 Salary')),
            DataColumn(numeric: true, label: Text('Guaranteed')),
            DataColumn(numeric: true, label: Text('2025–26 GP')),
            DataColumn(numeric: true, label: Text('2025–26 MPG')),
            DataColumn(numeric: true, label: Text('2025–26 PPG')),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  DataCell(
                    TextButton(
                      onPressed: row.playerKey.isEmpty ? null : () => onPlayer(row),
                      child: Text(row.player),
                    ),
                  ),
                  DataCell(Text(row.position)),
                  DataCell(Text(_money(row.salary))),
                  DataCell(Text(row.guaranteed == null ? '—' : _money(row.guaranteed!))),
                  DataCell(Text(_whole(row.previousGames))),
                  DataCell(Text(_one(row.previousMinutes))),
                  DataCell(Text(_one(row.previousPoints))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InjuriesTable extends StatelessWidget {
  const _InjuriesTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyCard(
        'Injury data has not been materialized for the 2026–27 team feed yet. This table is ready for player, status, injury, report date, and expected-return fields when that source is connected.',
      );
    }
    return _GenericTable(
      columns: const ['Player', 'Status', 'Injury', 'Reported', 'Return'],
      rows: [
        for (final row in rows)
          [
            _textAny(row, const ['player_name', 'player']),
            _textAny(row, const ['status', 'designation']),
            _textAny(row, const ['injury', 'description', 'reason']),
            _textAny(row, const ['report_date', 'date']),
            _textAny(row, const ['expected_return', 'return_date']),
          ],
      ],
    );
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyCard(
        'No 2026–27 transaction feed is materialized for this team yet. The table is ready for signings, waivers, trades, assignments, options, and contract-status changes.',
      );
    }
    return _GenericTable(
      columns: const ['Date', 'Type', 'Player / Asset', 'Details'],
      rows: [
        for (final row in rows)
          [
            _textAny(row, const ['date', 'transaction_date']),
            _textAny(row, const ['type', 'transaction_type']),
            _textAny(row, const ['player_name', 'asset', 'subject']),
            _textAny(row, const ['details', 'description', 'notes']),
          ],
      ],
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({
    required this.rows,
    required this.unavailableReason,
    required this.team,
  });

  final List<NbaScheduledGame> rows;
  final String unavailableReason;
  final String team;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyCard(
        unavailableReason.isEmpty
            ? 'No 2026–27 games are present in the current schedule snapshot for $team.'
            : unavailableReason,
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Matchup')),
            DataColumn(label: Text('Time (ET)')),
            DataColumn(label: Text('Arena')),
            DataColumn(label: Text('National TV')),
          ],
          rows: [
            for (final game in rows)
              DataRow(
                cells: [
                  DataCell(Text(game.date)),
                  DataCell(Text('${game.awayTricode} at ${game.homeTricode}')),
                  DataCell(Text(game.timeEt.isEmpty ? 'TBD' : game.timeEt)),
                  DataCell(Text(game.arena.isEmpty ? '—' : game.arena)),
                  DataCell(Text(game.nationalTv.isEmpty ? '—' : game.nationalTv)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SeasonHistoryTable extends StatelessWidget {
  const _SeasonHistoryTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final ordered = [...rows]
      ..sort((a, b) => _text(b['season_id']).compareTo(_text(a['season_id'])));
    if (ordered.isEmpty) {
      return const _EmptyCard('No source-backed season rows are available.');
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Season')),
            DataColumn(numeric: true, label: Text('W')),
            DataColumn(numeric: true, label: Text('L')),
            DataColumn(numeric: true, label: Text('Win%')),
            DataColumn(numeric: true, label: Text('ORtg')),
            DataColumn(numeric: true, label: Text('DRtg')),
            DataColumn(numeric: true, label: Text('Net')),
            DataColumn(numeric: true, label: Text('Pace')),
            DataColumn(numeric: true, label: Text('SRS')),
          ],
          rows: [
            for (final row in ordered)
              DataRow(
                cells: [
                  DataCell(Text(_text(row['season_id']))),
                  DataCell(Text(_whole(_number(row['wins'])))),
                  DataCell(Text(_whole(_number(row['losses'])))),
                  DataCell(Text(_percent(_number(row['win_pct'])))),
                  DataCell(Text(_one(_number(row['ortg'])))),
                  DataCell(Text(_one(_number(row['drtg'])))),
                  DataCell(Text(_signed(_number(row['net_rtg'])))),
                  DataCell(Text(_one(_number(row['pace'])))),
                  DataCell(Text(_signed(_number(row['srs'])))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NotablePlayers extends StatelessWidget {
  const _NotablePlayers({required this.rows, required this.onPlayer});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onPlayer;

  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const _EmptyCard(
          'No source-backed player history is available for this team.',
        )
      : Card(
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                ListTile(
                  title: Text(_text(rows[index]['player_name'], 'Player')),
                  subtitle: Text(
                    '${_text(rows[index]['first_season'])} – ${_text(rows[index]['last_season'])}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onPlayer(rows[index]),
                ),
                if (index != rows.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
}

class _HistoricalGames extends StatelessWidget {
  const _HistoricalGames({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const _EmptyCard(
          'No source-backed recent historical game rows are available for this team.',
        )
      : Card(
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                ListTile(
                  title: Text(
                    '${_text(rows[index]['away_team_name'])} at ${_text(rows[index]['home_team_name'])}',
                  ),
                  subtitle: Text(_text(rows[index]['game_date'])),
                  trailing: Text(
                    '${_whole(_number(rows[index]['away_score']))} – ${_whole(_number(rows[index]['home_score']))}',
                  ),
                ),
                if (index != rows.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
}

class _GenericTable extends StatelessWidget {
  const _GenericTable({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [for (final column in columns) DataColumn(label: Text(column))],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [for (final value in row) DataCell(Text(value.isEmpty ? '—' : value))],
                ),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(message),
          ),
        ),
      );
}

String _depthName(List<_RosterRow> rows, int index) =>
    index < rows.length ? rows[index].player : '—';

String _positionBucket(String value) {
  final upper = value.toUpperCase().replaceAll(' ', '');
  for (final key in const ['PG', 'SG', 'SF', 'PF']) {
    if (upper.contains(key)) return key;
  }
  if (upper == 'C' || upper.contains('CENTER')) return 'C';
  if (upper == 'G') return 'PG';
  if (upper == 'F') return 'SF';
  return 'UTIL';
}

int _uniqueSeasons(List<Map<String, dynamic>> rows) =>
    rows.map((row) => _text(row['season_id'])).where((value) => value.isNotEmpty).toSet().length;

List<Map<String, dynamic>> _firstMapList(
  Map<String, dynamic> source,
  List<String> keys,
) {
  for (final key in keys) {
    final rows = _maps(source[key]);
    if (rows.isNotEmpty) return rows;
  }
  return const [];
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _map(item),
  ];
}

String _textAny(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = _text(row[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _nameToken(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _money(double value) => '\$${(value / 1000000).toStringAsFixed(2)}M';
String _one(double? value) => value == null ? '—' : value.toStringAsFixed(1);
String _whole(double? value) => value == null ? '—' : value.round().toString();
String _signed(double? value) => value == null
    ? '—'
    : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
String _percent(double? value) {
  if (value == null) return '—';
  final normalized = value.abs() > 1.5 ? value / 100 : value;
  return '${(normalized * 100).toStringAsFixed(1)}%';
}
