import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import 'product_nba_entity_pages_v2.dart';

const _tbPanel = Color(0xFF0F151C);
const _tbPanel2 = Color(0xFF141C25);
const _tbLine = Color(0xFF263342);
const _tbText = Color(0xFFE8EDF3);
const _tbMuted = Color(0xFF8895A5);
const _tbBlue = Color(0xFF63A9FF);
const _tbAmber = Color(0xFFE2B866);
const _tbGreen = Color(0xFF69C99A);

enum _BlogDesk { home, coverage, roster, schedule, stats, community }

extension on _BlogDesk {
  String get label => switch (this) {
    _BlogDesk.home => 'Home',
    _BlogDesk.coverage => 'Coverage',
    _BlogDesk.roster => 'Roster',
    _BlogDesk.schedule => 'Schedule',
    _BlogDesk.stats => 'Stats',
    _BlogDesk.community => 'Fan Room',
  };
}

class ProductTeamBlogsScreen extends StatefulWidget {
  const ProductTeamBlogsScreen({super.key});

  @override
  State<ProductTeamBlogsScreen> createState() => _ProductTeamBlogsScreenState();
}

class _ProductTeamBlogsScreenState extends State<ProductTeamBlogsScreen> {
  final ProductLocalStore _store = const ProductLocalStore();
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final TextEditingController _search = TextEditingController();
  String _team = '';
  _BlogDesk _desk = _BlogDesk.home;
  Set<String> _followed = {};
  bool _loaded = false;

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
    final followed = await _store.loadStringSet(ProductLocalStore.favoriteTeamsKey);
    if (!mounted) return;
    setState(() {
      _followed = followed;
      _loaded = true;
    });
  }

  Future<void> _toggleFollow(String team) async {
    if (!_followed.add(team)) _followed.remove(team);
    await _store.saveStringSet(ProductLocalStore.favoriteTeamsKey, _followed);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _BlogPanel(child: Center(child: CircularProgressIndicator()));
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BlogPanel(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _BlogPanel(child: Text('Team Blogs unavailable: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        final data = snapshot.data!;
        final teams = data.teamRecords.map(_teamId).where((value) => value != '—').toSet().toList()..sort();
        if (_team.isEmpty && teams.isNotEmpty) _team = _firstOrNull(_followed.where(teams.contains)) ?? teams.first;
        final query = _search.text.trim().toLowerCase();
        final visibleTeams = teams.where((team) => query.isEmpty || team.toLowerCase().contains(query) || _teamName(data, team).toLowerCase().contains(query)).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Hero(team: _team, data: data, followed: _followed.contains(_team), onFollow: () => _toggleFollow(_team)),
          const SizedBox(height: 12),
          _TeamNetwork(
            teams: visibleTeams,
            data: data,
            selected: _team,
            followed: _followed,
            search: _search,
            onSearch: (_) => setState(() {}),
            onTeam: (value) => setState(() {
              _team = value;
              _desk = _BlogDesk.home;
            }),
            onFollow: _toggleFollow,
          ),
          const SizedBox(height: 12),
          _DeskNav(selected: _desk, onSelected: (value) => setState(() => _desk = value)),
          const SizedBox(height: 12),
          if (_team.isNotEmpty)
            switch (_desk) {
              _BlogDesk.home => _BlogHome(team: _team, data: data, engine: _engine),
              _BlogDesk.coverage => _Coverage(team: _team, data: data),
              _BlogDesk.roster => _Roster(team: _team, data: data, engine: _engine),
              _BlogDesk.schedule => _Schedule(team: _team, data: data),
              _BlogDesk.stats => _TeamStats(team: _team, data: data, engine: _engine),
              _BlogDesk.community => _FanRoom(team: _team),
            },
        ]);
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.team, required this.data, required this.followed, required this.onFollow});
  final String team;
  final NbaTerminalSeedSnapshot data;
  final bool followed;
  final VoidCallback onFollow;
  @override
  Widget build(BuildContext context) {
    final name = _teamName(data, team);
    final record = data.teamRecords.firstWhere((row) => _teamId(row) == team, orElse: () => const {});
    return _BlogPanel(
      child: LayoutBuilder(builder: (context, constraints) {
        final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CONTENT / NBA TEAM NETWORK', style: TextStyle(color: _tbBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
          const SizedBox(height: 6),
          Text(team.isEmpty ? 'Team Blogs' : '$name Blog', style: const TextStyle(color: _tbText, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(team.isEmpty ? 'A dedicated publication and fan home for every NBA team.' : '${_text(record['wins'])}-${_text(record['losses'])} · news, analysis, roster context, results, stats and fan discussion connected to the $team team page.', style: const TextStyle(color: _tbMuted, height: 1.4)),
        ]);
        final actions = Wrap(spacing: 8, runSpacing: 8, children: [
          if (team.isNotEmpty) FilledButton.icon(onPressed: onFollow, icon: Icon(followed ? Icons.star_rounded : Icons.star_border_rounded), label: Text(followed ? 'Following' : 'Follow team')),
          if (team.isNotEmpty) OutlinedButton.icon(onPressed: () => openNbaTeamPage(context, teamId: team), icon: const Icon(Icons.groups_rounded), label: const Text('Open team page')),
        ]);
        if (constraints.maxWidth < 850) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 12), actions]);
        return Row(children: [Expanded(child: copy), const SizedBox(width: 20), actions]);
      }),
    );
  }
}

class _TeamNetwork extends StatelessWidget {
  const _TeamNetwork({required this.teams, required this.data, required this.selected, required this.followed, required this.search, required this.onSearch, required this.onTeam, required this.onFollow});
  final List<String> teams;
  final NbaTerminalSeedSnapshot data;
  final String selected;
  final Set<String> followed;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onTeam;
  final ValueChanged<String> onFollow;
  @override
  Widget build(BuildContext context) => _BlogPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('30-TEAM BLOG NETWORK', style: TextStyle(color: _tbBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8))),
            SizedBox(width: 250, child: TextField(controller: search, onChanged: onSearch, decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search_rounded, size: 17), hintText: 'Find team publication…', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final team in teams)
              InputChip(
                avatar: CircleAvatar(backgroundColor: followed.contains(team) ? const Color(0x22E2B866) : const Color(0x2263A9FF), child: Text(team, style: TextStyle(color: followed.contains(team) ? _tbAmber : _tbBlue, fontSize: 7, fontWeight: FontWeight.w900))),
                label: Text(_teamName(data, team)),
                selected: selected == team,
                onPressed: () => onTeam(team),
                onDeleted: () => onFollow(team),
                deleteIcon: Icon(followed.contains(team) ? Icons.star_rounded : Icons.star_border_rounded, size: 16, color: followed.contains(team) ? _tbAmber : _tbMuted),
              ),
          ]),
        ]),
      );
}

class _DeskNav extends StatelessWidget {
  const _DeskNav({required this.selected, required this.onSelected});
  final _BlogDesk selected;
  final ValueChanged<_BlogDesk> onSelected;
  @override
  Widget build(BuildContext context) => _BlogPanel(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 6, runSpacing: 6, children: [for (final desk in _BlogDesk.values) ChoiceChip(label: Text(desk.label), selected: selected == desk, onSelected: (_) => onSelected(desk))]),
      );
}

class _BlogHome extends StatelessWidget {
  const _BlogHome({required this.team, required this.data, required this.engine});
  final String team;
  final NbaTerminalSeedSnapshot data;
  final NbaStatsWorkstationEngine engine;
  @override
  Widget build(BuildContext context) {
    final games = data.teamGameLogs.where((row) => _teamId(row) == team).toList()..sort((a, b) => _text(b['game_date']).compareTo(_text(a['game_date'])));
    final players = engine.buildRows(data).where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(team)).toList()..sort((a, b) => (b.value('pts') ?? 0).compareTo(a.value('pts') ?? 0));
    return Column(children: [
      _FeatureStory(team: team, game: _firstOrNull(games)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final left = _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('Latest coverage', 'Team-native stories connected to loaded games and roster context.'),
          for (final game in games.take(6)) _GeneratedStory(team: team, game: game),
          if (games.isEmpty) const Text('No game-linked coverage is available in the current data scope.', style: TextStyle(color: _tbMuted)),
        ]));
        final right = _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('Team leaders', 'Click a player to open the full player page.'),
          for (final row in players.take(8)) _PlayerRow(row: row),
        ]));
        return compact ? Column(children: [left, const SizedBox(height: 12), right]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: left), const SizedBox(width: 12), Expanded(flex: 2, child: right)]);
      }),
      const SizedBox(height: 12),
      const _BlogPanel(child: _EditorialModules()),
    ]);
  }
}

class _Coverage extends StatelessWidget {
  const _Coverage({required this.team, required this.data});
  final String team;
  final NbaTerminalSeedSnapshot data;
  @override
  Widget build(BuildContext context) {
    final games = data.teamGameLogs.where((row) => _teamId(row) == team).toList()..sort((a, b) => _text(b['game_date']).compareTo(_text(a['game_date'])));
    return _BlogPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('Coverage archive', 'Recaps, previews, transactions, film/stat notes and long-form team analysis share one archive.'),
        for (var i = 0; i < games.take(30).length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _tbLine, width: .5))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 68, height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: _tbPanel2, borderRadius: BorderRadius.circular(7), border: Border.all(color: _tbLine)), child: Text(team, style: const TextStyle(color: _tbBlue, fontWeight: FontWeight.w900))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_storyHeadline(team, games[i], i), style: const TextStyle(color: _tbText, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${_text(games[i]['game_date'])} · Team Desk · ${_resultLabel(games[i])}', style: const TextStyle(color: _tbMuted, fontSize: 9)),
              ])),
              const Icon(Icons.arrow_forward_rounded, color: _tbBlue, size: 16),
            ]),
          ),
        if (games.isEmpty) const Text('No game-linked archive rows are packaged for this team yet.', style: TextStyle(color: _tbMuted)),
      ]),
    );
  }
}

class _Roster extends StatelessWidget {
  const _Roster({required this.team, required this.data, required this.engine});
  final String team;
  final NbaTerminalSeedSnapshot data;
  final NbaStatsWorkstationEngine engine;
  @override
  Widget build(BuildContext context) {
    final rows = engine.buildRows(data).where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(team)).toList()..sort((a, b) => (b.value('min') ?? 0).compareTo(a.value('min') ?? 0));
    return _BlogPanel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(14), child: _SectionTitle('Roster', 'The team publication links directly into the player intelligence graph.')),
        for (final row in rows)
          InkWell(
            onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: const BoxDecoration(border: Border(top: BorderSide(color: _tbLine, width: .5))), child: Row(children: [
              Expanded(flex: 4, child: Text(row.player, style: const TextStyle(color: _tbBlue, fontWeight: FontWeight.w900))),
              SizedBox(width: 52, child: Text(row.position, style: const TextStyle(color: _tbMuted))),
              for (final stat in [('PTS', 'pts'), ('REB', 'reb'), ('AST', 'ast')]) SizedBox(width: 72, child: Text('${stat.$1} ${(row.value(stat.$2) ?? 0).toStringAsFixed(1)}', textAlign: TextAlign.right, style: const TextStyle(color: _tbText, fontSize: 10))),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _tbMuted),
            ])),
          ),
      ]),
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({required this.team, required this.data});
  final String team;
  final NbaTerminalSeedSnapshot data;
  @override
  Widget build(BuildContext context) {
    final rows = data.teamGameLogs.where((row) => _teamId(row) == team).toList()..sort((a, b) => _text(b['game_date']).compareTo(_text(a['game_date'])));
    return _BlogPanel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(14), child: _SectionTitle('Schedule & results', 'Every game can become a recap, preview, live thread or postgame discussion anchor.')),
        for (final row in rows)
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: const BoxDecoration(border: Border(top: BorderSide(color: _tbLine, width: .5))), child: Row(children: [
            SizedBox(width: 100, child: Text(_text(row['game_date']), style: const TextStyle(color: _tbMuted, fontSize: 10))),
            Expanded(child: Text('vs ${_text(row['opponent_team_id'])}', style: const TextStyle(color: _tbText, fontWeight: FontWeight.w800))),
            SizedBox(width: 55, child: Text(_text(row['result']), textAlign: TextAlign.right, style: TextStyle(color: _text(row['result']).startsWith('W') ? _tbGreen : _tbAmber, fontWeight: FontWeight.w900))),
            SizedBox(width: 80, child: Text('${_text(row['points'])} PTS', textAlign: TextAlign.right, style: const TextStyle(color: _tbMuted))),
          ]),
      ]),
    );
  }
}

class _TeamStats extends StatelessWidget {
  const _TeamStats({required this.team, required this.data, required this.engine});
  final String team;
  final NbaTerminalSeedSnapshot data;
  final NbaStatsWorkstationEngine engine;
  @override
  Widget build(BuildContext context) {
    final rows = engine.buildRows(data).where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(team)).toList();
    rows.sort((a, b) => (b.value('game_score_proxy') ?? 0).compareTo(a.value('game_score_proxy') ?? 0));
    return _BlogPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle('Team stat notebook', 'A blog writer can jump from narrative coverage into the same player-stat system used throughout Sports Terminal.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final row in rows.take(12))
            SizedBox(width: 230, child: InkWell(onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _tbPanel2, border: Border.all(color: _tbLine), borderRadius: BorderRadius.circular(7)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.player, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _tbBlue, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('${(row.value('pts') ?? 0).toStringAsFixed(1)} PTS · ${(row.value('reb') ?? 0).toStringAsFixed(1)} REB · ${(row.value('ast') ?? 0).toStringAsFixed(1)} AST', style: const TextStyle(color: _tbText, fontSize: 9)),
              const SizedBox(height: 3),
              Text('${engine.formatValue('ts_pct', row.value('ts_pct'))} TS · ${engine.formatValue('bpm', row.value('bpm'))} BPM', style: const TextStyle(color: _tbMuted, fontSize: 9)),
            ])))),
        ]),
      ]),
    );
  }
}

class _FanRoom extends StatelessWidget {
  const _FanRoom({required this.team});
  final String team;
  @override
  Widget build(BuildContext context) => _BlogPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle('$team Fan Room', 'The team blog and community should feel connected, not like separate products.'),
          const SizedBox(height: 8),
          const Text('Team-specific live threads, postgame rooms, polls, trade ideas, Q&As, mailbags and comments route into the authenticated Community service, where reports, blocks, mutes and moderation controls apply.', style: TextStyle(color: _tbMuted, height: 1.45)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.forum_rounded), label: const Text('Open team discussion')), 
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.poll_rounded), label: const Text('Create poll')),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.live_tv_rounded), label: const Text('Game thread')), 
          ]),
          const SizedBox(height: 12),
          const Text('Community handoff buttons are present in the team publication surface; full cross-route deep-linking will use the shared object router as community identifiers are expanded.', style: TextStyle(color: _tbMuted, fontSize: 10)),
        ]),
      );
}

class _FeatureStory extends StatelessWidget {
  const _FeatureStory({required this.team, required this.game});
  final String team;
  final Map<String, dynamic>? game;
  @override
  Widget build(BuildContext context) => _BlogPanel(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _tbPanel2, borderRadius: BorderRadius.circular(9), border: Border.all(color: _tbLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FEATURED', style: TextStyle(color: _tbAmber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 7),
            Text(game == null ? '$team season notebook: what matters next' : _storyHeadline(team, game!, 0), style: const TextStyle(color: _tbText, fontSize: 25, fontWeight: FontWeight.w900, height: 1.1)),
            const SizedBox(height: 8),
            Text(game == null ? 'Follow roster, schedule, advanced statistics, transactions and fan discussion from one team-native publication.' : 'A data-linked team story anchored to the loaded ${_text(game!['game_date'])} result. The publication layer can attach player cards, game context and deeper Sports Terminal research.', style: const TextStyle(color: _tbMuted, height: 1.45)),
            const SizedBox(height: 10),
            const Text('TEAM DESK · ANALYSIS', style: TextStyle(color: _tbBlue, fontSize: 9, fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}

class _GeneratedStory extends StatelessWidget {
  const _GeneratedStory({required this.team, required this.game});
  final String team;
  final Map<String, dynamic> game;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _tbLine, width: .5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 86, child: Text(_text(game['game_date']), style: const TextStyle(color: _tbMuted, fontSize: 9))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_storyHeadline(team, game, 0), style: const TextStyle(color: _tbText, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('${_resultLabel(game)} · Team Desk', style: const TextStyle(color: _tbBlue, fontSize: 9)),
          ])),
        ]),
      );
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.row});
  final NbaStatsRow row;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _tbLine, width: .5))), child: Row(children: [
          Expanded(child: Text(row.player, style: const TextStyle(color: _tbBlue, fontWeight: FontWeight.w900))),
          Text('${(row.value('pts') ?? 0).toStringAsFixed(1)} PPG', style: const TextStyle(color: _tbText, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: _tbMuted, size: 16),
        ])),
      );
}

class _EditorialModules extends StatelessWidget {
  const _EditorialModules();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        _SectionTitle('Publication modules', 'The full team site architecture is active as a reusable surface.'),
        SizedBox(height: 9),
        _ModuleLine(Icons.article_outlined, 'News & analysis', 'Features, notebooks, recaps, previews, film/stat analysis, rumors with sourcing labels and explainers.'),
        _ModuleLine(Icons.groups_rounded, 'Roster intelligence', 'Every player links to the shared player page, watchlist and advanced-stat graph.'),
        _ModuleLine(Icons.calendar_month_rounded, 'Game coverage', 'Schedule/results, preview anchors, live-thread hooks, postgame recaps and game-level data.'),
        _ModuleLine(Icons.swap_horiz_rounded, 'Transactions', 'Trade-machine scenarios, contract context, draft assets and transaction notes can be attached to coverage.'),
        _ModuleLine(Icons.forum_rounded, 'Fan Room', 'Comments, polls, game threads and team communities share Sports Terminal moderation and identity.'),
        _ModuleLine(Icons.person_rounded, 'Writers', 'Author pages, follows, beats, disclosure labels, corrections and archives fit into the platform profile/content graph.'),
      ]);
}

class _ModuleLine extends StatelessWidget {
  const _ModuleLine(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: _tbBlue, size: 18), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _tbText, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(body, style: const TextStyle(color: _tbMuted, fontSize: 10, height: 1.35))]))]));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _tbText, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _tbMuted, fontSize: 10, height: 1.35))]);
}

class _BlogPanel extends StatelessWidget {
  const _BlogPanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _tbPanel, border: Border.all(color: _tbLine), borderRadius: BorderRadius.circular(9)), child: child);
}

String _teamId(Map<String, dynamic> row) {
  for (final key in const ['team_id', 'team', 'abbreviation', 'team_abbreviation', 'id']) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '—';
}
String _teamName(NbaTerminalSeedSnapshot data, String team) {
  final row = data.teamRecords.firstWhere((item) => _teamId(item) == team, orElse: () => data.teams.firstWhere((item) => _teamId(item) == team, orElse: () => const {}));
  final value = row['team_name'] ?? row['name'] ?? row['full_name'];
  return _text(value) == '—' ? team : _text(value);
}
String _text(Object? value) { final text = value?.toString().trim() ?? ''; return text.isEmpty ? '—' : text; }
String _resultLabel(Map<String, dynamic> game) => '${_text(game['result'])} · ${_text(game['points'])} pts · ${_text(game['margin'])} margin';
String _storyHeadline(String team, Map<String, dynamic> game, int index) {
  final opponent = _text(game['opponent_team_id']);
  final result = _text(game['result']);
  if (result.startsWith('W')) return '$team takeaways: what changed in the win over $opponent';
  if (result.startsWith('L')) return '$team film + numbers: what went wrong against $opponent';
  return '$team vs. $opponent: game notebook and statistical context';
}

T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}
