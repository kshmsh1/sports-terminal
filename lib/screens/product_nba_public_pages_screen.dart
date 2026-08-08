import 'package:flutter/material.dart';

import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _pBg = Color(0xFF090D12);
const _pPanel = Color(0xFF0F151C);
const _pPanel2 = Color(0xFF141C25);
const _pLine = Color(0xFF263342);
const _pText = Color(0xFFE8EDF3);
const _pMuted = Color(0xFF8895A5);
const _pBlue = Color(0xFF63A9FF);
const _pGreen = Color(0xFF69C99A);
const _pAmber = Color(0xFFE2B866);

class ProductNbaBasicStatsScreen extends StatefulWidget {
  const ProductNbaBasicStatsScreen({super.key});

  @override
  State<ProductNbaBasicStatsScreen> createState() =>
      _ProductNbaBasicStatsScreenState();
}

class _ProductNbaBasicStatsScreenState extends State<ProductNbaBasicStatsScreen> {
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final TextEditingController _search = TextEditingController();
  String _team = 'All';
  String _position = 'All';
  String _sort = 'pts';
  bool _descending = true;
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _Panel(child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Panel(
              child: Text(
                'Stats unavailable: ${snapshot.error}',
                style: const TextStyle(color: _pMuted),
              ),
            );
          }
          final rows = _engine.buildRows(
            snapshot.data!,
            basis: NbaStatsBasis.perGame,
            seasonType: _seasonType,
          );
          final teams = <String>{'All'};
          for (final row in rows) {
            teams.addAll(
              row.team
                  .split(RegExp(r'[,/ ]+'))
                  .where((value) => value.isNotEmpty && value != '—'),
            );
          }
          final query = _search.text.trim().toLowerCase();
          final visible = rows.where((row) {
            if (query.isNotEmpty &&
                !'${row.player} ${row.team}'.toLowerCase().contains(query)) {
              return false;
            }
            if (_team != 'All' &&
                !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) {
              return false;
            }
            if (_position != 'All' && row.position != _position) return false;
            return true;
          }).toList();
          _engine.sortRows(visible, _sort, descending: _descending);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Hero(
                eyebrow: 'NBA / STATS',
                title: 'Basic player statistics',
                body:
                    'A clean league table for core production. Regular Season is the default; Playoffs is always kept separate. Every player and team name is a navigation target, while the full metric system lives under Advanced Stats.',
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _EnumDrop<NbaStatsSeasonType>(
                      value: _seasonType,
                      values: const [
                        NbaStatsSeasonType.regular,
                        NbaStatsSeasonType.playoffs,
                      ],
                      label: (value) => value.label,
                      onChanged: (value) =>
                          setState(() => _seasonType = value),
                    ),
                    SizedBox(
                      width: 245,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: _pText),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search players…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    _Drop(
                      value: _team,
                      values: teams.toList()..sort(),
                      onChanged: (value) => setState(() => _team = value),
                    ),
                    _Drop(
                      value: _position,
                      values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'],
                      onChanged: (value) => setState(() => _position = value),
                    ),
                    Text(
                      '${visible.length} players',
                      style: const TextStyle(
                        color: _pMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _BasicTable(
                rows: visible,
                sortKey: _sort,
                descending: _descending,
                onSort: (key) => setState(() {
                  if (_sort == key) {
                    _descending = !_descending;
                  } else {
                    _sort = key;
                    _descending = true;
                  }
                }),
              ),
            ],
          );
        },
      );
}

class _BasicTable extends StatelessWidget {
  const _BasicTable({
    required this.rows,
    required this.sortKey,
    required this.descending,
    required this.onSort,
  });

  final List<NbaStatsRow> rows;
  final String sortKey;
  final bool descending;
  final ValueChanged<String> onSort;

  static const metrics = <(String, String)>[
    ('min', 'MPG'),
    ('pts', 'PPG'),
    ('reb', 'RPG'),
    ('ast', 'APG'),
    ('stl', 'SPG'),
    ('blk', 'BPG'),
    ('tov', 'TPG'),
    ('pf', 'PF'),
    ('fg_pct', 'FG%'),
    ('three_pct', '3P%'),
    ('ft_pct', 'FT%'),
  ];

  @override
  Widget build(BuildContext context) => _Panel(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(70),
            columnWidths: const {
              0: FixedColumnWidth(214),
              1: FixedColumnWidth(70),
              2: FixedColumnWidth(48),
            },
            border: const TableBorder(
              horizontalInside: BorderSide(color: _pLine, width: .5),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _pPanel2),
                children: [
                  const _Head('PLAYER'),
                  const _Head('TEAM'),
                  const _Head('POS'),
                  for (final metric in metrics)
                    InkWell(
                      onTap: () => onSort(metric.$1),
                      child: _Head(
                        '${metric.$2}${sortKey == metric.$1 ? (descending ? ' ↓' : ' ↑') : ''}',
                      ),
                    ),
                ],
              ),
              for (final row in rows)
                TableRow(
                  children: [
                    _EntityCell(
                      label: row.player,
                      onTap: () =>
                          openNbaPlayerPage(context, row.playerId, row.player),
                    ),
                    _EntityCell(
                      label: row.team,
                      onTap: () {
                        final id = _primaryTeam(row.team);
                        openNbaTeamPage(context, id, id);
                      },
                    ),
                    _Cell(row.position),
                    for (final metric in metrics)
                      _Cell(_format(row.value(metric.$1), metric.$1)),
                  ],
                ),
            ],
          ),
        ),
      );
}

Future<void> openNbaPlayerPage(
  BuildContext context,
  String playerId,
  String playerName,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/players/${Uri.encodeComponent(playerId)}',
      ),
      builder: (_) => Scaffold(
        backgroundColor: _pBg,
        appBar: AppBar(
          backgroundColor: _pPanel,
          foregroundColor: _pText,
          title: Text(playerName),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: ProductNbaPlayerPage(
                playerId: playerId,
                playerName: playerName,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> openNbaTeamPage(
  BuildContext context,
  String teamId,
  String teamName,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(
        name: '/nba/teams/${Uri.encodeComponent(teamId)}',
      ),
      builder: (_) => Scaffold(
        backgroundColor: _pBg,
        appBar: AppBar(
          backgroundColor: _pPanel,
          foregroundColor: _pText,
          title: Text(teamName),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: ProductNbaTeamPage(teamId: teamId),
            ),
          ),
        ),
      ),
    ),
  );
}

class ProductNbaPlayerPage extends StatefulWidget {
  const ProductNbaPlayerPage({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  final String playerId;
  final String playerName;

  @override
  State<ProductNbaPlayerPage> createState() => _ProductNbaPlayerPageState();
}

class _ProductNbaPlayerPageState extends State<ProductNbaPlayerPage> {
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final NbaTerminalMetricResolver _resolver = const NbaTerminalMetricResolver();
  String _familyId = 'basic';
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _Panel(child: Center(child: CircularProgressIndicator()));
          }
          final rows = _engine.buildRows(
            snapshot.data!,
            basis: _basis,
            seasonType: _seasonType,
          );
          final row = rows
              .where(
                (candidate) =>
                    candidate.playerId == widget.playerId ||
                    candidate.player == widget.playerName,
              )
              .firstOrNull;
          if (row == null) {
            return _Panel(
              child: Text(
                '${widget.playerName} is not available in the active ${_seasonType.label} scope.',
                style: const TextStyle(color: _pMuted),
              ),
            );
          }
          final family = nbaTerminalFamily(_familyId);
          final keys = nbaVisibleMetricKeys(family, _expanded);
          final available = keys
              .where((key) => _resolver.isAvailable(row, key))
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                eyebrow: 'NBA / PLAYER',
                title: row.player,
                body:
                    '${row.team} · ${row.position} · a single-player version of the Advanced Stats taxonomy. Switch stat family, rate basis and Regular Season/Playoffs without leaving the player dossier.',
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _FamilyDrop(
                          value: _familyId,
                          onChanged: (value) => setState(() {
                            _familyId = value;
                            _expanded.clear();
                          }),
                        ),
                        _EnumDrop<NbaStatsBasis>(
                          value: _basis,
                          values: NbaStatsBasis.values,
                          label: (value) => value.label,
                          onChanged: (value) => setState(() => _basis = value),
                        ),
                        _EnumDrop<NbaStatsSeasonType>(
                          value: _seasonType,
                          values: const [
                            NbaStatsSeasonType.regular,
                            NbaStatsSeasonType.playoffs,
                          ],
                          label: (value) => value.label,
                          onChanged: (value) =>
                              setState(() => _seasonType = value),
                        ),
                        _StatusPill('$available/${keys.length} populated'),
                        for (final team in row.team
                            .split(RegExp(r'[,/ ]+'))
                            .where((value) => value.isNotEmpty && value != '—'))
                          ActionChip(
                            label: Text(team),
                            avatar: const Icon(Icons.groups_rounded, size: 16),
                            onPressed: () =>
                                openNbaTeamPage(context, team, team),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      family.description,
                      style: const TextStyle(color: _pMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _PlayerMetricGrid(
                row: row,
                family: family,
                keys: keys,
                resolver: _resolver,
                expanded: _expanded,
                onExpand: (key) => setState(() {
                  if (!_expanded.add(key)) _expanded.remove(key);
                }),
              ),
              const SizedBox(height: 12),
              _PlayerGlossary(family: family),
              const SizedBox(height: 12),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Section('PLAYER WORKSPACE'),
                    SizedBox(height: 8),
                    Text(
                      'This permanent player route is the consolidation point for statistics, game logs, historical seasons, shooting and tracking, impact models, awards, contracts, transactions, injuries, articles, community discussion, fantasy notes and saved research. Metrics with no authoritative source remain visibly unavailable rather than being fabricated.',
                      style: TextStyle(color: _pMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _PlayerMetricGrid extends StatelessWidget {
  const _PlayerMetricGrid({
    required this.row,
    required this.family,
    required this.keys,
    required this.resolver,
    required this.expanded,
    required this.onExpand,
  });

  final NbaStatsRow row;
  final NbaTerminalStatFamily family;
  final List<String> keys;
  final NbaTerminalMetricResolver resolver;
  final Set<String> expanded;
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final key in keys)
              _PlayerMetricCard(
                metricKey: key,
                value: resolver.format(row, key),
                available: resolver.isAvailable(row, key),
                expanded: expanded.contains(key),
                onExpand: _expandable(key) ? () => onExpand(key) : null,
              ),
          ],
        ),
      );

  bool _expandable(String key) {
    final metric = nbaTerminalMetricByKey[key];
    return (family.expansionOverrides[key]?.isNotEmpty ?? false) ||
        (metric?.children.isNotEmpty ?? false);
  }
}

class _PlayerMetricCard extends StatelessWidget {
  const _PlayerMetricCard({
    required this.metricKey,
    required this.value,
    required this.available,
    required this.expanded,
    this.onExpand,
  });

  final String metricKey;
  final String value;
  final bool available;
  final bool expanded;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final metric = nbaTerminalMetricByKey[metricKey];
    return Container(
      width: 174,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _pPanel2,
        border: Border.all(color: available ? _pLine : _pLine.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric?.shortLabel ?? metricKey.toUpperCase(),
                  style: const TextStyle(
                    color: _pMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onExpand != null)
                InkWell(
                  onTap: onExpand,
                  child: Icon(
                    expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    color: _pAmber,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: available ? _pText : _pMuted,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric?.label ?? metricKey,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _pMuted, fontSize: 9, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _PlayerGlossary extends StatelessWidget {
  const _PlayerGlossary({required this.family});

  final NbaTerminalStatFamily family;

  @override
  Widget build(BuildContext context) {
    final keys = <String>{
      ...family.metrics,
      for (final key in family.metrics)
        ...(family.expansionOverrides[key] ??
            nbaTerminalMetricByKey[key]?.children ??
            const <String>[]),
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section('${family.label.toUpperCase()} GLOSSARY'),
          const SizedBox(height: 8),
          for (final key in keys)
            if (nbaTerminalMetricByKey[key] case final metric?)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: _pMuted, fontSize: 10, height: 1.4),
                    children: [
                      TextSpan(
                        text: '${metric.shortLabel} — ',
                        style: const TextStyle(
                          color: _pText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(text: metric.description),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class ProductNbaTeamPage extends StatefulWidget {
  const ProductNbaTeamPage({super.key, required this.teamId});

  final String teamId;

  @override
  State<ProductNbaTeamPage> createState() => _ProductNbaTeamPageState();
}

class _ProductNbaTeamPageState extends State<ProductNbaTeamPage> {
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _Panel(child: Center(child: CircularProgressIndicator()));
          }
          final data = snapshot.data!;
          final team = data.teamRecords
              .where((record) => '${record['team_id']}' == widget.teamId)
              .firstOrNull;
          final players = const NbaStatsWorkstationEngine()
              .buildRows(data, seasonType: _seasonType)
              .where(
                (row) => row.team
                    .split(RegExp(r'[,/ ]+'))
                    .contains(widget.teamId),
              )
              .toList()
            ..sort(
              (left, right) =>
                  (right.value('pts') ?? 0).compareTo(left.value('pts') ?? 0),
            );
          final games = data.teamGameLogs
              .where((record) => '${record['team_id']}' == widget.teamId)
              .toList()
              .reversed
              .take(15)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                eyebrow: 'NBA / TEAM',
                title: widget.teamId,
                body:
                    'Roster, performance, recent games and linked league entities consolidated into one permanent team route. Front-office, draft, contract, editorial and community objects can attach to this identity.',
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _EnumDrop<NbaStatsSeasonType>(
                      value: _seasonType,
                      values: const [
                        NbaStatsSeasonType.regular,
                        NbaStatsSeasonType.playoffs,
                      ],
                      label: (value) => value.label,
                      onChanged: (value) =>
                          setState(() => _seasonType = value),
                    ),
                    if (team != null) ...[
                      _Kpi('Record', '${team['wins'] ?? '—'}-${team['losses'] ?? '—'}'),
                      _Kpi('PPG', _value(team['points_per_game'])),
                      _Kpi('Opp PPG', _value(team['opponent_points_per_game'])),
                      _Kpi('Margin', _value(team['average_margin'])),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Panel(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 850,
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(3)},
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: _pPanel2),
                          children: [
                            _Head('ROSTER'),
                            _Head('POS'),
                            _Head('GP'),
                            _Head('PPG'),
                            _Head('RPG'),
                            _Head('APG'),
                          ],
                        ),
                        for (final row in players)
                          TableRow(
                            children: [
                              _EntityCell(
                                label: row.player,
                                onTap: () => openNbaPlayerPage(
                                  context,
                                  row.playerId,
                                  row.player,
                                ),
                              ),
                              _Cell(row.position),
                              _Cell(_format(row.value('gp'), 'gp')),
                              _Cell(_format(row.value('pts'), 'pts')),
                              _Cell(_format(row.value('reb'), 'reb')),
                              _Cell(_format(row.value('ast'), 'ast')),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Section('RECENT GAMES'),
                    const SizedBox(height: 8),
                    for (final game in games)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 105,
                              child: Text(
                                '${game['game_date'] ?? '—'}',
                                style: const TextStyle(color: _pMuted),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  final opponent =
                                      '${game['opponent_team_id'] ?? ''}';
                                  if (opponent.isNotEmpty && opponent != '—') {
                                    openNbaTeamPage(
                                      context,
                                      opponent,
                                      opponent,
                                    );
                                  }
                                },
                                child: Text(
                                  '${game['opponent_team_id'] ?? '—'} · ${game['result'] ?? '—'}',
                                  style: const TextStyle(
                                    color: _pBlue,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              '${game['points'] ?? '—'} PTS',
                              style: const TextStyle(
                                color: _pText,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class ProductNbaHubV2Screen extends StatefulWidget {
  const ProductNbaHubV2Screen({super.key});

  @override
  State<ProductNbaHubV2Screen> createState() => _ProductNbaHubV2ScreenState();
}

class _ProductNbaHubV2ScreenState extends State<ProductNbaHubV2Screen> {
  final TextEditingController search = TextEditingController();
  NbaStatsSeasonType seasonType = NbaStatsSeasonType.regular;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _Panel(child: Center(child: CircularProgressIndicator()));
          }
          final data = snapshot.data!;
          final query = search.text.trim().toLowerCase();
          final rows = const NbaStatsWorkstationEngine()
              .buildRows(data, seasonType: seasonType);
          final players = rows
              .where(
                (row) =>
                    query.isEmpty ||
                    '${row.player} ${row.team}'.toLowerCase().contains(query),
              )
              .toList()
            ..sort(
              (left, right) =>
                  (right.value('pts') ?? 0).compareTo(left.value('pts') ?? 0),
            );
          final teams = data.teamRecords
              .where(
                (record) =>
                    query.isEmpty ||
                    '${record['team_id']} ${record['team_name'] ?? ''}'
                        .toLowerCase()
                        .contains(query),
              )
              .toList();
          final ppg = [...rows]
            ..sort((a, b) => (b.value('pts') ?? 0).compareTo(a.value('pts') ?? 0));
          final rpg = [...rows]
            ..sort((a, b) => (b.value('reb') ?? 0).compareTo(a.value('reb') ?? 0));
          final apg = [...rows]
            ..sort((a, b) => (b.value('ast') ?? 0).compareTo(a.value('ast') ?? 0));
          final standings = [...data.teamRecords]
            ..sort((a, b) => _winPct(b).compareTo(_winPct(a)));
          final recentGames = data.games.reversed.take(12).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Hero(
                eyebrow: 'NBA HUB',
                title: 'The league operating homepage',
                body:
                    'A data-first command page for the NBA: canonical teams and players, standings, schedule context, leaders, historical research, awards, transactions, front-office workflows, editorial and community. Entity names stay linked throughout the experience.',
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _EnumDrop<NbaStatsSeasonType>(
                      value: seasonType,
                      values: const [
                        NbaStatsSeasonType.regular,
                        NbaStatsSeasonType.playoffs,
                      ],
                      label: (value) => value.label,
                      onChanged: (value) => setState(() => seasonType = value),
                    ),
                    SizedBox(
                      width: 330,
                      child: TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: _pText),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search players and teams…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    _Kpi('Teams', '${data.teams.length}'),
                    _Kpi('Players', '${rows.length}'),
                    _Kpi('Games', '${data.games.length}'),
                    _Kpi('PBP', '${data.playByPlayEvents}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _Section('TEAMS'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final team in teams)
                    ActionChip(
                      avatar: const Icon(Icons.shield_outlined, size: 16),
                      label: Text(
                        '${team['team_id']} · ${team['wins'] ?? '—'}-${team['losses'] ?? '—'}',
                      ),
                      onPressed: () => openNbaTeamPage(
                        context,
                        '${team['team_id']}',
                        '${team['team_name'] ?? team['team_id']}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final leaders = [
                    _LeaderBlock('SCORING', 'PPG', ppg, 'pts'),
                    _LeaderBlock('REBOUNDING', 'RPG', rpg, 'reb'),
                    _LeaderBlock('PLAYMAKING', 'APG', apg, 'ast'),
                  ];
                  if (constraints.maxWidth < 980) {
                    return Column(
                      children: [
                        for (final block in leaders) ...[
                          _LeaderPanel(block: block),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < leaders.length; index++) ...[
                        if (index > 0) const SizedBox(width: 10),
                        Expanded(child: _LeaderPanel(block: leaders[index])),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const _Section('LEAGUE TABLE'),
              const SizedBox(height: 8),
              _Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0;
                        index < standings.take(30).length;
                        index++)
                      _StandingRow(
                        rank: index + 1,
                        record: standings[index],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _Section('RECENT GAMES'),
              const SizedBox(height: 8),
              _Panel(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final game in recentGames) _GameCard(game: game),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _Section('NBA TERMINAL MODULES'),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Module('Advanced Stats', Icons.analytics_rounded),
                  _Module('Awards & Voting', Icons.emoji_events_rounded),
                  _Module('Trade Machine', Icons.swap_horiz_rounded),
                  _Module('Contracts & Cap', Icons.account_balance_wallet_outlined),
                  _Module('Draft Assets', Icons.school_rounded),
                  _Module('Historical Intelligence', Icons.history_rounded),
                  _Module('Team Publications', Icons.newspaper_rounded),
                  _Module('Community', Icons.forum_rounded),
                ],
              ),
            ],
          );
        },
      );
}

class _LeaderBlock {
  const _LeaderBlock(this.title, this.unit, this.rows, this.key);
  final String title;
  final String unit;
  final List<NbaStatsRow> rows;
  final String key;
}

class _LeaderPanel extends StatelessWidget {
  const _LeaderPanel({required this.block});
  final _LeaderBlock block;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(block.title),
            const SizedBox(height: 7),
            for (var index = 0;
                index < block.rows.take(5).length;
                index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: _pMuted),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => openNbaPlayerPage(
                          context,
                          block.rows[index].playerId,
                          block.rows[index].player,
                        ),
                        child: Text(
                          block.rows[index].player,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _pBlue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${_format(block.rows[index].value(block.key), block.key)} ${block.unit}',
                      style: const TextStyle(
                        color: _pText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.rank, required this.record});
  final int rank;
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final id = '${record['team_id'] ?? '—'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _pLine, width: .5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('$rank', style: const TextStyle(color: _pMuted)),
          ),
          Expanded(
            child: InkWell(
              onTap: () => openNbaTeamPage(context, id, id),
              child: Text(
                id,
                style: const TextStyle(
                  color: _pBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${record['wins'] ?? '—'}-${record['losses'] ?? '—'}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: _pText, fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              _winPct(record).toStringAsFixed(3).replaceFirst('0.', '.'),
              textAlign: TextAlign.right,
              style: const TextStyle(color: _pMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});
  final Map<String, dynamic> game;

  @override
  Widget build(BuildContext context) {
    final home = _firstText(game, const ['home_team_id', 'home_team', 'home']);
    final away = _firstText(game, const ['away_team_id', 'away_team', 'away', 'visitor_team_id']);
    final date = _firstText(game, const ['game_date', 'date', 'gameDate']);
    final status = _firstText(game, const ['status', 'game_status_text', 'result']);
    return Container(
      width: 250,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: _pPanel2, border: Border.all(color: _pLine)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date == '—' ? 'NBA GAME' : date,
            style: const TextStyle(
              color: _pMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          _GameTeamLink(label: away),
          const SizedBox(height: 4),
          _GameTeamLink(label: home),
          if (status != '—') ...[
            const SizedBox(height: 7),
            Text(status, style: const TextStyle(color: _pAmber, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _GameTeamLink extends StatelessWidget {
  const _GameTeamLink({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: label == '—' ? null : () => openNbaTeamPage(context, label, label),
        child: Text(
          label,
          style: TextStyle(
            color: label == '—' ? _pMuted : _pBlue,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.eyebrow, required this.title, required this.body});
  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: _pPanel, border: Border.all(color: _pLine)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: _pBlue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                color: _pText,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: _pMuted, height: 1.45)),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _pPanel, border: Border.all(color: _pLine)),
        child: child,
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 142,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _pPanel2, border: Border.all(color: _pLine)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: _pMuted,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: _pText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _Drop extends StatelessWidget {
  const _Drop({required this.value, required this.values, required this.onChanged});
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: _pPanel2, border: Border.all(color: _pLine)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: values.contains(value) ? value : values.first,
            isExpanded: true,
            dropdownColor: _pPanel2,
            style: const TextStyle(color: _pText),
            items: [
              for (final item in values)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _FamilyDrop extends StatelessWidget {
  const _FamilyDrop({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        width: 235,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: _pPanel2, border: Border.all(color: _pLine)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: _pPanel2,
            style: const TextStyle(color: _pText),
            items: [
              for (final family in nbaTerminalStatFamilies)
                DropdownMenuItem(value: family.id, child: Text(family.label)),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _EnumDrop<T> extends StatelessWidget {
  const _EnumDrop({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        constraints: const BoxConstraints(minWidth: 135, maxWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: _pPanel2, border: Border.all(color: _pLine)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: _pPanel2,
            style: const TextStyle(color: _pText),
            items: [
              for (final item in values)
                DropdownMenuItem(value: item, child: Text(label(item))),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _pPanel2,
          border: Border.all(color: _pGreen.withValues(alpha: .6)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _pGreen,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            color: _pMuted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _pText,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _EntityCell extends StatelessWidget {
  const _EntityCell({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _pBlue,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.underline,
              decorationColor: _pBlue,
            ),
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _pAmber,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .7,
        ),
      );
}

class _Module extends StatelessWidget {
  const _Module(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 196,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _pPanel, border: Border.all(color: _pLine)),
        child: Row(
          children: [
            Icon(icon, color: _pBlue),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _pText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

String _format(double? value, String key) {
  if (value == null) return '—';
  if (key == 'gp') return value.round().toString();
  if (key.contains('pct') || key == 'ft_rate' || key == 'three_rate') {
    return '${(value.abs() <= 1.5 ? value * 100 : value).toStringAsFixed(1)}%';
  }
  return value.toStringAsFixed(1);
}

String _value(Object? value) =>
    value is num ? value.toStringAsFixed(1) : (value?.toString() ?? '—');

String _primaryTeam(String value) => value
    .split(RegExp(r'[,/ ]+'))
    .where((part) => part.isNotEmpty && part != '—')
    .firstOrNull ??
    value;

double _winPct(Map<String, dynamic> record) {
  final wins = _number(record['wins']);
  final losses = _number(record['losses']);
  final games = wins + losses;
  return games <= 0 ? 0 : wins / games;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

String _firstText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = '${row[key] ?? ''}'.trim();
    if (value.isNotEmpty && value != 'null') return value;
  }
  return '—';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
