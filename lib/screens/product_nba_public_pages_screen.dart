import 'package:flutter/material.dart';

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
  State<ProductNbaBasicStatsScreen> createState() => _ProductNbaBasicStatsScreenState();
}

class _ProductNbaBasicStatsScreenState extends State<ProductNbaBasicStatsScreen> {
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();
  String _team = 'All';
  String _position = 'All';
  String _sort = 'pts';
  bool _descending = true;

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
            return _Panel(child: Text('Stats unavailable: ${snapshot.error}', style: const TextStyle(color: _pMuted)));
          }
          final rows = _engine.buildRows(snapshot.data!, basis: NbaStatsBasis.perGame, seasonType: NbaStatsSeasonType.regular);
          final teams = <String>{'All'};
          for (final row in rows) {
            teams.addAll(row.team.split(RegExp(r'[,/ ]+')).where((v) => v.isNotEmpty && v != '—'));
          }
          final q = _search.text.trim().toLowerCase();
          final visible = rows.where((row) {
            if (q.isNotEmpty && !'${row.player} ${row.team}'.toLowerCase().contains(q)) return false;
            if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
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
                body: 'The public Stats page stays intentionally simple. Every player and team is a first-class navigation target; the full research workstation now lives under Advanced Stats.',
              ),
              const SizedBox(height: 14),
              _Panel(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: _pText),
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search players…', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    _Drop(value: _team, values: teams.toList()..sort(), onChanged: (v) => setState(() => _team = v)),
                    _Drop(value: _position, values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'], onChanged: (v) => setState(() => _position = v)),
                    Text('${visible.length} players', style: const TextStyle(color: _pMuted, fontWeight: FontWeight.w800)),
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
  const _BasicTable({required this.rows, required this.sortKey, required this.descending, required this.onSort});
  final List<NbaStatsRow> rows;
  final String sortKey;
  final bool descending;
  final ValueChanged<String> onSort;

  static const metrics = <(String, String)>[
    ('gp', 'GP'), ('min', 'MIN'), ('pts', 'PTS'), ('reb', 'REB'), ('ast', 'AST'), ('stl', 'STL'), ('blk', 'BLK'), ('tov', 'TOV'), ('fg_pct', 'FG%'), ('three_pct', '3P%'), ('ft_pct', 'FT%'),
  ];

  @override
  Widget build(BuildContext context) => _Panel(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(72),
            columnWidths: const {0: FixedColumnWidth(220), 1: FixedColumnWidth(74), 2: FixedColumnWidth(52)},
            border: const TableBorder(horizontalInside: BorderSide(color: _pLine, width: .5)),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _pPanel2),
                children: [
                  const _Head('PLAYER'), const _Head('TEAM'), const _Head('POS'),
                  for (final metric in metrics)
                    InkWell(
                      onTap: () => onSort(metric.$1),
                      child: _Head('${metric.$2}${sortKey == metric.$1 ? (descending ? ' ↓' : ' ↑') : ''}'),
                    ),
                ],
              ),
              for (final row in rows)
                TableRow(children: [
                  _EntityCell(
                    label: row.player,
                    onTap: () => openNbaPlayerPage(context, row.playerId, row.player),
                  ),
                  _EntityCell(
                    label: row.team,
                    onTap: () => openNbaTeamPage(context, row.team.split(RegExp(r'[,/ ]+')).first, row.team.split(RegExp(r'[,/ ]+')).first),
                  ),
                  _Cell(row.position),
                  for (final metric in metrics) _Cell(_format(row.value(metric.$1), metric.$1)),
                ]),
            ],
          ),
        ),
      );
}

Future<void> openNbaPlayerPage(BuildContext context, String playerId, String playerName) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(name: '/nba/players/${Uri.encodeComponent(playerId)}'),
      builder: (_) => Scaffold(
        backgroundColor: _pBg,
        appBar: AppBar(backgroundColor: _pPanel, foregroundColor: _pText, title: Text(playerName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1500), child: ProductNbaPlayerPage(playerId: playerId, playerName: playerName))),
        ),
      ),
    ),
  );
}

Future<void> openNbaTeamPage(BuildContext context, String teamId, String teamName) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: RouteSettings(name: '/nba/teams/${Uri.encodeComponent(teamId)}'),
      builder: (_) => Scaffold(
        backgroundColor: _pBg,
        appBar: AppBar(backgroundColor: _pPanel, foregroundColor: _pText, title: Text(teamName)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1500), child: ProductNbaTeamPage(teamId: teamId))),
        ),
      ),
    ),
  );
}

class ProductNbaPlayerPage extends StatefulWidget {
  const ProductNbaPlayerPage({super.key, required this.playerId, required this.playerName});
  final String playerId;
  final String playerName;

  @override
  State<ProductNbaPlayerPage> createState() => _ProductNbaPlayerPageState();
}

class _ProductNbaPlayerPageState extends State<ProductNbaPlayerPage> {
  final _engine = const NbaStatsWorkstationEngine();
  String category = 'Basic';
  String basis = 'Per Game';

  static const categories = <String, List<String>>{
    'Basic': ['gp', 'min', 'pts', 'reb', 'ast', 'stl', 'blk', 'tov', 'pf'],
    'Shooting': ['fgm', 'fga', 'fg_pct', 'two_pm', 'two_pa', 'two_pct', 'three_pm', 'three_pa', 'three_pct', 'ftm', 'fta', 'ft_pct'],
    'Efficiency': ['efg_pct', 'ts_pct', 'ft_rate', 'three_rate'],
    'Impact': ['bpm', 'scoring_load'],
  };

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const _Panel(child: Center(child: CircularProgressIndicator()));
          final selectedBasis = switch (basis) {
            'Totals' => NbaStatsBasis.totals,
            'Per 36' => NbaStatsBasis.per36,
            'Per 100' => NbaStatsBasis.per100,
            _ => NbaStatsBasis.perGame,
          };
          final rows = _engine.buildRows(snapshot.data!, basis: selectedBasis, seasonType: NbaStatsSeasonType.regular);
          final row = rows.where((r) => r.playerId == widget.playerId || r.player == widget.playerName).firstOrNull;
          if (row == null) return _Panel(child: Text('${widget.playerName} is not available in the active data scope.', style: const TextStyle(color: _pMuted)));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Hero(eyebrow: 'NBA / PLAYER', title: row.player, body: '${row.team} · ${row.position} · first-class player profile linked from every entity surface.'),
            const SizedBox(height: 12),
            _Panel(child: Wrap(spacing: 10, runSpacing: 10, children: [
              _Drop(value: category, values: categories.keys.toList(), onChanged: (v) => setState(() => category = v)),
              _Drop(value: basis, values: const ['Per Game', 'Totals', 'Per 36', 'Per 100'], onChanged: (v) => setState(() => basis = v)),
              for (final team in row.team.split(RegExp(r'[,/ ]+')).where((v) => v.isNotEmpty))
                ActionChip(label: Text(team), avatar: const Icon(Icons.groups_rounded, size: 16), onPressed: () => openNbaTeamPage(context, team, team)),
            ])),
            const SizedBox(height: 12),
            _MetricCards(row: row, keys: categories[category] ?? const []),
            const SizedBox(height: 12),
            _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Section('PLAYER WORKSPACE'),
              const SizedBox(height: 8),
              const Text('This page is designed to become the permanent home for bio, season-by-season history, game logs, splits, shooting, tracking, advanced models, contracts, transactions, awards, articles, community discussion, fantasy notes and saved research.', style: TextStyle(color: _pMuted, height: 1.5)),
            ])),
          ]);
        },
      );
}

class ProductNbaTeamPage extends StatelessWidget {
  const ProductNbaTeamPage({super.key, required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const _Panel(child: Center(child: CircularProgressIndicator()));
          final data = snapshot.data!;
          final team = data.teamRecords.where((r) => '${r['team_id']}' == teamId).firstOrNull;
          final players = const NbaStatsWorkstationEngine().buildRows(data).where((r) => r.team.split(RegExp(r'[,/ ]+')).contains(teamId)).toList()
            ..sort((a, b) => (b.value('pts') ?? 0).compareTo(a.value('pts') ?? 0));
          final games = data.teamGameLogs.where((r) => '${r['team_id']}' == teamId).toList().reversed.take(15).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Hero(eyebrow: 'NBA / TEAM', title: teamId, body: 'Roster, team performance, recent games, transactions, cap, draft assets, articles and community are consolidated into one permanent team route.'),
            const SizedBox(height: 12),
            if (team != null)
              Wrap(spacing: 10, runSpacing: 10, children: [
                _Kpi('Record', '${team['wins'] ?? '—'}-${team['losses'] ?? '—'}'),
                _Kpi('PPG', _value(team['points_per_game'])),
                _Kpi('Opp PPG', _value(team['opponent_points_per_game'])),
                _Kpi('Margin', _value(team['average_margin'])),
              ]),
            const SizedBox(height: 12),
            _Panel(padding: EdgeInsets.zero, child: Table(
              columnWidths: const {0: FlexColumnWidth(3)},
              children: [
                const TableRow(decoration: BoxDecoration(color: _pPanel2), children: [_Head('ROSTER'), _Head('POS'), _Head('GP'), _Head('PTS'), _Head('REB'), _Head('AST')]),
                for (final row in players)
                  TableRow(children: [
                    _EntityCell(label: row.player, onTap: () => openNbaPlayerPage(context, row.playerId, row.player)),
                    _Cell(row.position), _Cell(_format(row.value('gp'), 'gp')), _Cell(_format(row.value('pts'), 'pts')), _Cell(_format(row.value('reb'), 'reb')), _Cell(_format(row.value('ast'), 'ast')),
                  ]),
              ],
            )),
            const SizedBox(height: 12),
            _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Section('RECENT GAMES'),
              const SizedBox(height: 8),
              for (final game in games)
                Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
                  SizedBox(width: 105, child: Text('${game['game_date'] ?? '—'}', style: const TextStyle(color: _pMuted))),
                  Expanded(child: Text('${game['opponent_team_id'] ?? '—'} · ${game['result'] ?? '—'}', style: const TextStyle(color: _pText, fontWeight: FontWeight.w800))),
                  Text('${game['points'] ?? '—'} PTS', style: const TextStyle(color: _pBlue, fontWeight: FontWeight.w900)),
                ])),
            ])),
          ]);
        },
      );
}

class ProductNbaHubV2Screen extends StatefulWidget {
  const ProductNbaHubV2Screen({super.key});
  @override
  State<ProductNbaHubV2Screen> createState() => _ProductNbaHubV2ScreenState();
}

class _ProductNbaHubV2ScreenState extends State<ProductNbaHubV2Screen> {
  final search = TextEditingController();
  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
    future: const NbaTerminalSeedRepository().load(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const _Panel(child: Center(child: CircularProgressIndicator()));
      final data = snapshot.data!;
      final q = search.text.trim().toLowerCase();
      final rows = const NbaStatsWorkstationEngine().buildRows(data);
      final players = rows.where((r) => q.isEmpty || '${r.player} ${r.team}'.toLowerCase().contains(q)).toList()..sort((a,b)=>(b.value('pts')??0).compareTo(a.value('pts')??0));
      final teams = data.teamRecords.where((r) => q.isEmpty || '${r['team_id']}'.toLowerCase().contains(q)).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Hero(eyebrow: 'NBA HUB', title: 'The league operating homepage', body: 'A complete entry point for teams, players, standings, games, leaders, awards, transactions, research, editorial and community—built around linked NBA entities rather than dead-end tables.'),
        const SizedBox(height: 12),
        _Panel(child: TextField(controller: search, onChanged: (_) => setState(() {}), style: const TextStyle(color: _pText), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search the NBA universe…', border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Kpi('Teams', '${data.teams.length}'), _Kpi('Players', '${rows.length}'), _Kpi('Games', '${data.games.length}'), _Kpi('PBP', '${data.playByPlayEvents}'),
        ]),
        const SizedBox(height: 12),
        const _Section('TEAMS'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final team in teams)
            ActionChip(avatar: const Icon(Icons.shield_outlined, size: 17), label: Text('${team['team_id']} · ${team['wins']}-${team['losses']}'), onPressed: () => openNbaTeamPage(context, '${team['team_id']}', '${team['team_id']}')),
        ]),
        const SizedBox(height: 16),
        const _Section('PLAYER LEADERS'),
        const SizedBox(height: 8),
        _Panel(padding: EdgeInsets.zero, child: Column(children: [
          for (final row in players.take(25))
            InkWell(onTap: () => openNbaPlayerPage(context, row.playerId, row.player), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), child: Row(children: [
              Expanded(child: Text(row.player, style: const TextStyle(color: _pText, fontWeight: FontWeight.w800))),
              InkWell(onTap: () => openNbaTeamPage(context, row.team.split(RegExp(r'[,/ ]+')).first, row.team), child: Text(row.team, style: const TextStyle(color: _pBlue, fontWeight: FontWeight.w800))),
              const SizedBox(width: 18), Text('${_format(row.value('pts'),'pts')} PPG', style: const TextStyle(color: _pAmber, fontWeight: FontWeight.w900)),
            ]))),
        ])),
        const SizedBox(height: 16),
        const _Section('LEAGUE MODULES'),
        const SizedBox(height: 8),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          _Module('Standings', Icons.format_list_numbered_rounded), _Module('Schedule & Scores', Icons.calendar_month_rounded), _Module('Transactions', Icons.swap_horiz_rounded), _Module('Awards & Voting', Icons.emoji_events_rounded), _Module('Draft', Icons.school_rounded), _Module('Injuries', Icons.health_and_safety_outlined), _Module('Contracts & Cap', Icons.account_balance_wallet_outlined), _Module('Historical Records', Icons.history_rounded),
        ]),
      ]);
    },
  );
}

class ProductNbaAwardsCenterScreen extends StatefulWidget {
  const ProductNbaAwardsCenterScreen({super.key});
  @override
  State<ProductNbaAwardsCenterScreen> createState() => _ProductNbaAwardsCenterScreenState();
}

class _ProductNbaAwardsCenterScreenState extends State<ProductNbaAwardsCenterScreen> {
  String query = '';
  String group = 'All';

  static const awards = <(String, String, String)>[
    ('MVP', 'Season Awards', 'Most Valuable Player · Michael Jordan Trophy'),
    ('ROY', 'Season Awards', 'Rookie of the Year · Wilt Chamberlain Trophy'),
    ('DPOY', 'Season Awards', 'Defensive Player of the Year · Hakeem Olajuwon Trophy'),
    ('6MOY', 'Season Awards', 'Sixth Man of the Year · John Havlicek Trophy'),
    ('MIP', 'Season Awards', 'Most Improved Player · George Mikan Trophy'),
    ('Clutch POY', 'Season Awards', 'Clutch Player of the Year · Jerry West Trophy'),
    ('Sportsmanship', 'Season Awards', 'Sportsmanship Award · Joe Dumars Trophy'),
    ('Teammate', 'Season Awards', 'Twyman-Stokes Teammate of the Year'),
    ('Hustle', 'Season Awards', 'NBA Hustle Award'),
    ('Social Justice', 'Season Awards', 'Social Justice Champion · Kareem Abdul-Jabbar Trophy'),
    ('Citizenship', 'Season Awards', 'J. Walter Kennedy Citizenship Award'),
    ('Coach', 'Season Awards', 'Coach of the Year · Red Auerbach Trophy'),
    ('Executive', 'Season Awards', 'Executive of the Year'),
    ('Best Record', 'Season Awards', 'Best Regular Season Record · Maurice Podoloff Trophy'),
    ('Finals MVP', 'Postseason', 'NBA Finals MVP · Bill Russell Trophy'),
    ('East Finals MVP', 'Postseason', 'Eastern Conference Finals MVP · Larry Bird Trophy'),
    ('West Finals MVP', 'Postseason', 'Western Conference Finals MVP · Magic Johnson Trophy'),
    ('NBA Cup MVP', 'Postseason', 'In-Season Tournament / NBA Cup MVP'),
    ('All-Star MVP', 'All-Star', 'NBA All-Star Game MVP · Kobe Bryant Trophy'),
    ('All-Star', 'All-Star', 'NBA All-Star selections'),
    ('All-NBA 1st', 'Honors', 'All-NBA First Team'),
    ('All-NBA 2nd', 'Honors', 'All-NBA Second Team'),
    ('All-NBA 3rd', 'Honors', 'All-NBA Third Team'),
    ('All-Defense 1st', 'Honors', 'All-Defensive First Team'),
    ('All-Defense 2nd', 'Honors', 'All-Defensive Second Team'),
    ('All-Rookie 1st', 'Honors', 'All-Rookie First Team'),
    ('All-Rookie 2nd', 'Honors', 'All-Rookie Second Team'),
    ('All-Tournament', 'Honors', 'NBA Cup / In-Season Tournament All-Tournament Team'),
    ('Player of Month', 'Periodic', 'Player of the Month'),
    ('Rookie of Month', 'Periodic', 'Rookie of the Month'),
    ('Defensive POTM', 'Periodic', 'Defensive Player of the Month'),
    ('Player of Week', 'Periodic', 'Player of the Week'),
    ('Hall of Fame', 'Legacy', 'Naismith Memorial Basketball Hall of Fame'),
  ];

  @override
  Widget build(BuildContext context) {
    final groups = ['All', ...{for (final item in awards) item.$2}];
    final visible = awards.where((a) => (group == 'All' || a.$2 == group) && (query.isEmpty || '${a.$1} ${a.$3}'.toLowerCase().contains(query.toLowerCase()))).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Hero(eyebrow: 'NBA / AWARDS', title: 'Awards, honors and voting archive', body: 'Every annual NBA award and major honor gets its own durable page, including winner history, voting shares where available, team selections and linked player profiles.'),
      const SizedBox(height: 12),
      _Panel(child: Wrap(spacing: 8, runSpacing: 8, children: [
        SizedBox(width: 250, child: TextField(onChanged: (v) => setState(() => query = v), style: const TextStyle(color: _pText), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Find an award…', border: OutlineInputBorder(), isDense: true))),
        _Drop(value: group, values: groups, onChanged: (v) => setState(() => group = v)),
      ])),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final award in visible)
          SizedBox(width: 310, child: _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(award.$2.toUpperCase(), style: const TextStyle(color: _pBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
            const SizedBox(height: 7),
            Text(award.$1, style: const TextStyle(color: _pText, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(award.$3, style: const TextStyle(color: _pMuted, height: 1.35)),
            const SizedBox(height: 10),
            const Text('Winner history · voting · linked players · season filter', style: TextStyle(color: _pGreen, fontSize: 10, fontWeight: FontWeight.w800)),
          ]))),
      ]),
      const SizedBox(height: 12),
      const _Panel(child: Text('Data contract: the historical warehouse already contains Basketball-Reference-derived award shares, end-of-season teams, All-Star selections and draft-era history. This surface intentionally defines the full product taxonomy now; the next ingestion projection should materialize those source tables into canonical award and voting facts rather than scrape pages at runtime.', style: TextStyle(color: _pMuted, height: 1.5))),
    ]);
  }
}

class _MetricCards extends StatelessWidget {
  const _MetricCards({required this.row, required this.keys});
  final NbaStatsRow row;
  final List<String> keys;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [for (final key in keys) _Kpi(key.toUpperCase(), _format(row.value(key), key))]);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.eyebrow, required this.title, required this.body});
  final String eyebrow; final String title; final String body;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: _pPanel, border: Border.all(color: _pLine)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(eyebrow, style: const TextStyle(color: _pBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 7), Text(title, style: const TextStyle(color: _pText, fontSize: 29, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(body, style: const TextStyle(color: _pMuted, height: 1.45)),
  ]));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child; final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _pPanel, border: Border.all(color: _pLine)), child: child);
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value); final String label; final String value;
  @override
  Widget build(BuildContext context) => Container(width: 150, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _pPanel2, border: Border.all(color: _pLine)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: _pMuted, fontSize: 9, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(value, style: const TextStyle(color: _pText, fontSize: 18, fontWeight: FontWeight.w900))]));
}

class _Drop extends StatelessWidget {
  const _Drop({required this.value, required this.values, required this.onChanged});
  final String value; final List<String> values; final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(height: 42, constraints: const BoxConstraints(minWidth: 120, maxWidth: 230), padding: const EdgeInsets.symmetric(horizontal: 9), decoration: BoxDecoration(color: _pPanel2, border: Border.all(color: _pLine)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: values.contains(value) ? value : values.first, dropdownColor: _pPanel2, style: const TextStyle(color: _pText), items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item))], onChanged: (v) { if (v != null) onChanged(v); })));
}

class _Head extends StatelessWidget {
  const _Head(this.text); final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10), child: Text(text, maxLines: 1, style: const TextStyle(color: _pMuted, fontSize: 9, fontWeight: FontWeight.w900)));
}

class _Cell extends StatelessWidget {
  const _Cell(this.text); final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _pText, fontSize: 10, fontWeight: FontWeight.w700)));
}

class _EntityCell extends StatelessWidget {
  const _EntityCell({required this.label, required this.onTap}); final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _pBlue, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: _pBlue))));
}

class _Section extends StatelessWidget {
  const _Section(this.text); final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: _pAmber, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .7));
}

class _Module extends StatelessWidget {
  const _Module(this.label, this.icon); final String label; final IconData icon;
  @override
  Widget build(BuildContext context) => Container(width: 190, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _pPanel, border: Border.all(color: _pLine)), child: Row(children: [Icon(icon, color: _pBlue), const SizedBox(width: 9), Expanded(child: Text(label, style: const TextStyle(color: _pText, fontWeight: FontWeight.w800)))]));
}

String _format(double? value, String key) {
  if (value == null) return '—';
  if (key == 'gp') return value.round().toString();
  if (key.contains('pct') || key == 'ft_rate' || key == 'three_rate') return '${(value.abs() <= 1.5 ? value * 100 : value).toStringAsFixed(1)}%';
  return value.toStringAsFixed(1);
}
String _value(Object? v) => v is num ? v.toStringAsFixed(1) : (v?.toString() ?? '—');

extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
