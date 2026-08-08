import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import 'product_nba_awards_screen.dart';
import 'product_nba_entity_pages_v2.dart';

const _hubPanel = Color(0xFF0F151C);
const _hubPanel2 = Color(0xFF141C25);
const _hubLine = Color(0xFF263342);
const _hubText = Color(0xFFE8EDF3);
const _hubMuted = Color(0xFF8895A5);
const _hubBlue = Color(0xFF63A9FF);
const _hubGreen = Color(0xFF69C99A);
const _hubAmber = Color(0xFFE2B866);

enum _HubSection { overview, players, teams, standings, games, leaders, awards, data }

extension on _HubSection {
  String get label => switch (this) {
    _HubSection.overview => 'Overview',
    _HubSection.players => 'Players',
    _HubSection.teams => 'Teams',
    _HubSection.standings => 'Standings',
    _HubSection.games => 'Schedule & Results',
    _HubSection.leaders => 'Leaders',
    _HubSection.awards => 'Awards & Voting',
    _HubSection.data => 'League Data',
  };
  IconData get icon => switch (this) {
    _HubSection.overview => Icons.dashboard_rounded,
    _HubSection.players => Icons.people_alt_rounded,
    _HubSection.teams => Icons.groups_rounded,
    _HubSection.standings => Icons.format_list_numbered_rounded,
    _HubSection.games => Icons.calendar_month_rounded,
    _HubSection.leaders => Icons.emoji_events_rounded,
    _HubSection.awards => Icons.workspace_premium_rounded,
    _HubSection.data => Icons.dataset_rounded,
  };
}

class ProductNbaHubV2Screen extends StatefulWidget {
  const ProductNbaHubV2Screen({super.key});

  @override
  State<ProductNbaHubV2Screen> createState() => _ProductNbaHubV2ScreenState();
}

class _ProductNbaHubV2ScreenState extends State<ProductNbaHubV2Screen> {
  final ProductLocalStore _store = const ProductLocalStore();
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final TextEditingController _search = TextEditingController();
  _HubSection _section = _HubSection.overview;
  Set<String> _favoriteTeams = {};
  Set<String> _watchlist = {};
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final teams = await _store.loadStringSet(ProductLocalStore.favoriteTeamsKey);
    final players = await _store.loadStringSet(ProductLocalStore.playerWatchlistKey);
    if (!mounted) return;
    setState(() {
      _favoriteTeams = teams;
      _watchlist = players;
      _prefsLoaded = true;
    });
  }

  Future<void> _toggleTeam(String id) async {
    if (!_favoriteTeams.add(id)) _favoriteTeams.remove(id);
    await _store.saveStringSet(ProductLocalStore.favoriteTeamsKey, _favoriteTeams);
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayer(String id) async {
    if (!_watchlist.add(id)) _watchlist.remove(id);
    await _store.saveStringSet(ProductLocalStore.playerWatchlistKey, _watchlist);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || !_prefsLoaded) {
          return const _HubPanel(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _HubPanel(child: Text('NBA Hub unavailable: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HubHero(data: data, favoriteTeams: _favoriteTeams.length, watchlist: _watchlist.length),
            const SizedBox(height: 12),
            _SectionNav(selected: _section, onSelected: (value) => setState(() => _section = value)),
            const SizedBox(height: 12),
            if (_section != _HubSection.awards)
              _HubSearch(
                controller: _search,
                hint: _section == _HubSection.games ? 'Search date, matchup, game ID or team…' : 'Search NBA Hub…',
                onChanged: (_) => setState(() {}),
              ),
            if (_section != _HubSection.awards) const SizedBox(height: 12),
            switch (_section) {
              _HubSection.overview => _Overview(data: data, engine: _engine, favoriteTeams: _favoriteTeams, watchlist: _watchlist),
              _HubSection.players => _Players(data: data, engine: _engine, query: _search.text, watchlist: _watchlist, onWatch: _togglePlayer),
              _HubSection.teams => _Teams(data: data, query: _search.text, favorites: _favoriteTeams, onFavorite: _toggleTeam),
              _HubSection.standings => _Standings(data: data, query: _search.text),
              _HubSection.games => _Games(data: data, query: _search.text),
              _HubSection.leaders => _Leaders(data: data, engine: _engine, query: _search.text),
              _HubSection.awards => const ProductNbaAwardsScreen(),
              _HubSection.data => _LeagueData(data: data),
            },
          ],
        );
      },
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({required this.data, required this.favoriteTeams, required this.watchlist});
  final NbaTerminalSeedSnapshot data;
  final int favoriteTeams;
  final int watchlist;
  @override
  Widget build(BuildContext context) => _HubPanel(
        child: LayoutBuilder(builder: (context, constraints) {
          final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NBA / LEAGUE HUB', style: TextStyle(color: _hubBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 5),
            const Text('The NBA in one place.', style: TextStyle(color: _hubText, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('Players, teams, standings, schedule/results, league leaders, awards and voting, plus the canonical data underneath every page.', style: TextStyle(color: _hubMuted, height: 1.4)),
          ]);
          final metrics = Wrap(spacing: 7, runSpacing: 7, children: [
            _HubTag('${data.teams.length} TEAMS', _hubBlue),
            _HubTag('${data.playerSeasonTotals.length} PLAYER ROWS', _hubGreen),
            _HubTag('${data.games.length} GAMES', _hubAmber),
            _HubTag('$favoriteTeams FAVORITES', _hubBlue),
            _HubTag('$watchlist WATCHLIST', _hubGreen),
          ]);
          if (constraints.maxWidth < 820) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 12), metrics]);
          return Row(children: [Expanded(child: copy), const SizedBox(width: 20), Flexible(child: metrics)]);
        }),
      );
}

class _SectionNav extends StatelessWidget {
  const _SectionNav({required this.selected, required this.onSelected});
  final _HubSection selected;
  final ValueChanged<_HubSection> onSelected;
  @override
  Widget build(BuildContext context) => _HubPanel(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final section in _HubSection.values)
            ChoiceChip(
              avatar: Icon(section.icon, size: 15),
              label: Text(section.label),
              selected: selected == section,
              onSelected: (_) => onSelected(section),
            ),
        ]),
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data, required this.engine, required this.favoriteTeams, required this.watchlist});
  final NbaTerminalSeedSnapshot data;
  final NbaStatsWorkstationEngine engine;
  final Set<String> favoriteTeams;
  final Set<String> watchlist;

  @override
  Widget build(BuildContext context) {
    final players = engine.buildRows(data)..sort((a, b) => (b.value('pts') ?? 0).compareTo(a.value('pts') ?? 0));
    final standings = [...data.teamRecords]..sort((a, b) => _number(b['wins']).compareTo(_number(a['wins'])));
    final games = data.games.reversed.take(10).toList();
    return Column(children: [
      _MetricGrid(items: [
        _Metric('Active scope', data.supportedSeason, data.isHistorical ? 'historical canonical' : 'current release'),
        _Metric('Validation', data.validationStatus.toUpperCase(), 'source-aware data status'),
        _Metric('PBP events', _compact(data.playByPlayEvents), 'normalized play-by-play'),
        _Metric('Saved NBA identity', '${favoriteTeams.length + watchlist.length}', 'favorite teams + watched players'),
      ]),
      const SizedBox(height: 12),
      _TwoColumn(
        left: _HubPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _PanelTitle('Scoring leaders', 'Click a player for the complete player page.'),
            for (final row in players.take(10)) _PlayerLinkRow(row: row),
          ]),
        ),
        right: _HubPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _PanelTitle('League table snapshot', 'Click a team for roster, stats and results.'),
            for (var i = 0; i < standings.take(10).length; i++) _TeamStandingRow(rank: i + 1, row: standings[i]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _HubPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _PanelTitle('Recent games', 'Recent loaded schedule and results in the active data scope.'),
          for (final game in games) _GameRow(row: game),
        ]),
      ),
    ]);
  }
}

class _Players extends StatelessWidget {
  const _Players({required this.data, required this.engine, required this.query, required this.watchlist, required this.onWatch});
  final NbaTerminalSeedSnapshot data;
  final NbaStatsWorkstationEngine engine;
  final String query;
  final Set<String> watchlist;
  final ValueChanged<String> onWatch;
  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final rows = engine.buildRows(data).where((row) => q.isEmpty || '${row.player} ${row.team} ${row.position}'.toLowerCase().contains(q)).toList()
      ..sort((a, b) => a.player.compareTo(b.player));
    return _HubPanel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        _ListHeader(title: 'Players', count: rows.length, detail: 'All player rows in the active scope'),
        for (final row in rows)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hubLine, width: .5))),
            child: Row(children: [
              IconButton(tooltip: 'Watch player', onPressed: () => onWatch(row.playerId), icon: Icon(watchlist.contains(row.playerId) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: watchlist.contains(row.playerId) ? _hubAmber : _hubMuted, size: 18)),
              Expanded(flex: 4, child: InkWell(onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player), child: Text(row.player, style: const TextStyle(color: _hubBlue, fontWeight: FontWeight.w900)))),
              SizedBox(width: 58, child: Text(row.position, style: const TextStyle(color: _hubMuted))),
              Expanded(flex: 2, child: _LinkedTeams(value: row.team)),
              for (final item in [('PTS', 'pts'), ('REB', 'reb'), ('AST', 'ast')])
                SizedBox(width: 78, child: Text('${item.$1} ${(row.value(item.$2) ?? 0).toStringAsFixed(1)}', textAlign: TextAlign.right, style: const TextStyle(color: _hubText, fontSize: 10))),
              IconButton(onPressed: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player), icon: const Icon(Icons.chevron_right_rounded, color: _hubMuted)),
            ]),
          ),
      ]),
    );
  }
}

class _Teams extends StatelessWidget {
  const _Teams({required this.data, required this.query, required this.favorites, required this.onFavorite});
  final NbaTerminalSeedSnapshot data;
  final String query;
  final Set<String> favorites;
  final ValueChanged<String> onFavorite;
  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final rows = data.teamRecords.where((row) {
      final id = _teamId(row);
      return q.isEmpty || '$id ${row['team_name'] ?? ''}'.toLowerCase().contains(q);
    }).toList()..sort((a, b) => _teamId(a).compareTo(_teamId(b)));
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1200 ? 4 : constraints.maxWidth >= 800 ? 3 : constraints.maxWidth >= 520 ? 2 : 1;
      final gap = 10.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final row in rows)
          SizedBox(width: width, child: _TeamCard(row: row, favorite: favorites.contains(_teamId(row)), onFavorite: () => onFavorite(_teamId(row)))),
      ]);
    });
  }
}

class _Standings extends StatelessWidget {
  const _Standings({required this.data, required this.query});
  final NbaTerminalSeedSnapshot data;
  final String query;
  @override
  Widget build(BuildContext context) {
    final source = data.standings.isNotEmpty ? data.standings : data.teamRecords;
    final q = query.trim().toLowerCase();
    final rows = source.where((row) => q.isEmpty || '${_teamId(row)} ${row['team_name'] ?? ''}'.toLowerCase().contains(q)).toList()
      ..sort((a, b) {
        final winPct = _number(b['win_pct'] ?? b['win_percentage']);
        final other = _number(a['win_pct'] ?? a['win_percentage']);
        if (winPct != other) return winPct.compareTo(other);
        return _number(b['wins']).compareTo(_number(a['wins']));
      });
    return _HubPanel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        _ListHeader(title: 'Standings', count: rows.length, detail: data.standings.isNotEmpty ? 'Packaged standings feed' : 'Derived from team records'),
        for (var i = 0; i < rows.length; i++) _TeamStandingRow(rank: i + 1, row: rows[i], detailed: true),
      ]),
    );
  }
}

class _Games extends StatelessWidget {
  const _Games({required this.data, required this.query});
  final NbaTerminalSeedSnapshot data;
  final String query;
  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final rows = data.games.where((row) => q.isEmpty || '${row['game_id']} ${row['game_date']} ${row['away_team_id']} ${row['home_team_id']}'.toLowerCase().contains(q)).toList()
      ..sort((a, b) => '${b['game_date']}'.compareTo('${a['game_date']}'));
    return _HubPanel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        _ListHeader(title: 'Schedule & Results', count: rows.length, detail: 'Loaded games in active data scope'),
        for (final row in rows.take(300)) _GameRow(row: row, detailed: true),
        if (rows.length > 300) Padding(padding: const EdgeInsets.all(12), child: Text('${rows.length - 300} additional games available through search and historical game intelligence.', style: const TextStyle(color: _hubMuted))),
      ]),
    );
  }
}

class _Leaders extends StatelessWidget {
  const _Leaders({required this.data, required this.engine, required this.query});
  final NbaTerminalSeedSnapshot data;
  final NbaStatsWorkstationEngine engine;
  final String query;
  @override
  Widget build(BuildContext context) {
    final all = engine.buildRows(data);
    const categories = [('Scoring', 'pts'), ('Rebounding', 'reb'), ('Assists', 'ast'), ('Steals', 'stl'), ('Blocks', 'blk'), ('True Shooting', 'ts_pct')];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth >= 1050 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final category in categories)
          SizedBox(
            width: width,
            child: _HubPanel(
              child: _Leaderboard(title: category.$1, keyName: category.$2, rows: [...all]..sort((a, b) => (b.value(category.$2) ?? -999).compareTo(a.value(category.$2) ?? -999)), engine: engine),
            ),
          ),
      ]);
    });
  }
}

class _LeagueData extends StatelessWidget {
  const _LeagueData({required this.data});
  final NbaTerminalSeedSnapshot data;
  @override
  Widget build(BuildContext context) => Column(children: [
        _MetricGrid(items: [
          _Metric('Teams', '${data.teams.length}', 'identity records'),
          _Metric('Players', '${data.players.length}', 'identity records'),
          _Metric('Season totals', '${data.playerSeasonTotals.length}', 'player summaries'),
          _Metric('Games', '${data.games.length}', 'game records'),
          _Metric('Team game logs', '${data.teamGameLogs.length}', 'team-game facts'),
          _Metric('Player game logs', '${data.playerGameLogsTop.length}', 'packaged player-game facts'),
          _Metric('Search objects', '${data.searchIndex.length}', 'search index'),
          _Metric('PBP events', _compact(data.playByPlayEvents), 'warehouse normalized'),
        ]),
        const SizedBox(height: 12),
        _HubPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _PanelTitle('Data lineage', 'This is the user-facing league data surface, not an admin-only pipeline view.'),
            _KeyValue('Dataset status', data.datasetStatus),
            _KeyValue('Validation', data.validationStatus),
            _KeyValue('Asset path', data.assetPath),
            _KeyValue('Warehouse generated', data.warehouseGeneratedAt),
            _KeyValue('Historical scope', '${data.isHistorical}'),
            _KeyValue('Fallback seed', '${data.usedFallback}'),
          ]),
        ),
      ]);
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.title, required this.keyName, required this.rows, required this.engine});
  final String title;
  final String keyName;
  final List<NbaStatsRow> rows;
  final NbaStatsWorkstationEngine engine;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PanelTitle(title, engine.metric(keyName).label),
        for (var i = 0; i < rows.take(10).length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hubLine, width: .5))),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(color: _hubMuted))),
              Expanded(child: InkWell(onTap: () => openNbaPlayerPage(context, playerId: rows[i].playerId, playerName: rows[i].player), child: Text(rows[i].player, style: const TextStyle(color: _hubBlue, fontWeight: FontWeight.w800)))),
              Text(engine.formatValue(keyName, rows[i].value(keyName)), style: const TextStyle(color: _hubText, fontWeight: FontWeight.w900)),
            ]),
          ),
      ]);
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.row, required this.favorite, required this.onFavorite});
  final Map<String, dynamic> row;
  final bool favorite;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) {
    final id = _teamId(row);
    return _HubPanel(
      child: InkWell(
        onTap: () => openNbaTeamPage(context, teamId: id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: _hubPanel2, border: Border.all(color: _hubLine), borderRadius: BorderRadius.circular(9)), child: Text(id, style: const TextStyle(color: _hubBlue, fontWeight: FontWeight.w900))),
            const Spacer(),
            IconButton(onPressed: onFavorite, icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded, color: favorite ? _hubAmber : _hubMuted)),
          ]),
          const SizedBox(height: 8),
          Text(_text(row['team_name'] ?? row['name'] ?? id), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _hubText, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${_text(row['wins'])}-${_text(row['losses'])} · ${_one(row['points_per_game'])} PPG · ${_signed(row['average_margin'])} margin', style: const TextStyle(color: _hubMuted, fontSize: 10)),
          const SizedBox(height: 7),
          const Row(children: [Text('OPEN TEAM PAGE', style: TextStyle(color: _hubBlue, fontSize: 8, fontWeight: FontWeight.w900)), Spacer(), Icon(Icons.arrow_forward_rounded, color: _hubBlue, size: 14)]),
        ]),
      ),
    );
  }
}

class _PlayerLinkRow extends StatelessWidget {
  const _PlayerLinkRow({required this.row});
  final NbaStatsRow row;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hubLine, width: .5))),
        child: Row(children: [
          Expanded(child: InkWell(onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player), child: Text(row.player, style: const TextStyle(color: _hubBlue, fontWeight: FontWeight.w800)))),
          _LinkedTeams(value: row.team),
          const SizedBox(width: 10),
          Text('${(row.value('pts') ?? 0).toStringAsFixed(1)} PPG', style: const TextStyle(color: _hubText, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _LinkedTeams extends StatelessWidget {
  const _LinkedTeams({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final teams = value.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—').toList();
    return Wrap(spacing: 3, children: [for (final team in teams.take(2)) InkWell(onTap: () => openNbaTeamPage(context, teamId: team), child: Padding(padding: const EdgeInsets.all(3), child: Text(team, style: const TextStyle(color: _hubBlue, fontSize: 9, fontWeight: FontWeight.w900))))]);
  }
}

class _TeamStandingRow extends StatelessWidget {
  const _TeamStandingRow({required this.rank, required this.row, this.detailed = false});
  final int rank;
  final Map<String, dynamic> row;
  final bool detailed;
  @override
  Widget build(BuildContext context) {
    final id = _teamId(row);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hubLine, width: .5))),
      child: Row(children: [
        SizedBox(width: 34, child: Text('$rank', style: const TextStyle(color: _hubMuted))),
        Expanded(child: InkWell(onTap: () => openNbaTeamPage(context, teamId: id), child: Text(id, style: const TextStyle(color: _hubBlue, fontWeight: FontWeight.w900)))),
        SizedBox(width: 80, child: Text('${_text(row['wins'])}-${_text(row['losses'])}', textAlign: TextAlign.right, style: const TextStyle(color: _hubText, fontWeight: FontWeight.w800))),
        if (detailed) ...[
          SizedBox(width: 90, child: Text('${_one(row['points_per_game'])} PPG', textAlign: TextAlign.right, style: const TextStyle(color: _hubMuted, fontSize: 10))),
          SizedBox(width: 90, child: Text('${_signed(row['average_margin'])} DIFF', textAlign: TextAlign.right, style: const TextStyle(color: _hubMuted, fontSize: 10))),
        ],
      ]),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.row, this.detailed = false});
  final Map<String, dynamic> row;
  final bool detailed;
  @override
  Widget build(BuildContext context) {
    final away = _text(row['away_team_id']);
    final home = _text(row['home_team_id']);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hubLine, width: .5))),
      child: Row(children: [
        SizedBox(width: 96, child: Text(_text(row['game_date']), style: const TextStyle(color: _hubMuted, fontSize: 10))),
        Expanded(child: Row(children: [
          InkWell(onTap: away == '—' ? null : () => openNbaTeamPage(context, teamId: away), child: Text(away, style: const TextStyle(color: _hubBlue, fontWeight: FontWeight.w900))),
          Text(' ${_score(row['away_score'])}  @  ', style: const TextStyle(color: _hubText)),
          InkWell(onTap: home == '—' ? null : () => openNbaTeamPage(context, teamId: home), child: Text(home, style: const TextStyle(color: _hubBlue, fontWeight: FontWeight.w900))),
          Text(' ${_score(row['home_score'])}', style: const TextStyle(color: _hubText)),
        ])),
        if (detailed) SizedBox(width: 150, child: Text(_text(row['game_id']), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _hubMuted, fontSize: 9))),
      ]),
    );
  }
}

class _HubSearch extends StatelessWidget {
  const _HubSearch({required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => _HubPanel(
        padding: const EdgeInsets.all(9),
        child: TextField(controller: controller, onChanged: onChanged, decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search_rounded), hintText: hint, border: const OutlineInputBorder())),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 600 ? 2 : 1;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final item in items) SizedBox(width: width, child: _HubPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(color: _hubMuted, fontSize: 9, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _hubText, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(item.detail, style: const TextStyle(color: _hubBlue, fontSize: 9))])))]);
      });
}

class _Metric { const _Metric(this.label, this.value, this.detail); final String label; final String value; final String detail; }

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) => constraints.maxWidth < 900 ? Column(children: [left, const SizedBox(height: 12), right]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]));
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.title, required this.count, required this.detail});
  final String title;
  final int count;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: _hubPanel2, border: Border(bottom: BorderSide(color: _hubLine))), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _hubText, fontSize: 18, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: _hubMuted, fontSize: 10))])), _HubTag('$count', _hubBlue)]));
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _hubText, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _hubMuted, fontSize: 10))]));
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 7), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _hubLine, width: .5))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 180, child: Text(label, style: const TextStyle(color: _hubMuted, fontSize: 10))), Expanded(child: SelectableText(value, style: const TextStyle(color: _hubText, fontSize: 10, fontWeight: FontWeight.w700)))]));
}

class _HubTag extends StatelessWidget {
  const _HubTag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .4)));
}

class _HubPanel extends StatelessWidget {
  const _HubPanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _hubPanel, border: Border.all(color: _hubLine), borderRadius: BorderRadius.circular(9)), child: child);
}

String _teamId(Map<String, dynamic> row) {
  for (final key in const ['team_id', 'abbreviation', 'team_abbreviation', 'id']) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '—';
}
String _text(Object? value) { final text = value?.toString().trim() ?? ''; return text.isEmpty ? '—' : text; }
double _number(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
String _one(Object? value) => _number(value).toStringAsFixed(1);
String _signed(Object? value) { final n = _number(value); return '${n >= 0 ? '+' : ''}${n.toStringAsFixed(1)}'; }
String _score(Object? value) { final n = _number(value); return n == 0 && value == null ? '—' : n.round().toString(); }
String _compact(int value) => value >= 1000000 ? '${(value / 1000000).toStringAsFixed(1)}M' : value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : '$value';
