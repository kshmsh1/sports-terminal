import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';

const _navy = Color(0xFF102A56);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF6F8FC);

class ProductNbaEntityHubScreen extends StatefulWidget {
  const ProductNbaEntityHubScreen({super.key});

  @override
  State<ProductNbaEntityHubScreen> createState() => _ProductNbaEntityHubScreenState();
}

class _ProductNbaEntityHubScreenState extends State<ProductNbaEntityHubScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  String mode = 'Players';
  String query = '';
  String? selectedPlayerId;
  String? selectedTeamId;
  String? selectedGameId;
  Set<String> favorites = {'OKC', 'BOS'};
  Set<String> watchlist = {};
  bool loadedPreferences = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final storedFavorites = await localStore.loadStringSet(ProductLocalStore.favoriteTeamsKey, fallback: {'OKC', 'BOS'});
    final storedWatchlist = await localStore.loadStringSet(ProductLocalStore.playerWatchlistKey);
    final storedMode = await localStore.loadString(ProductLocalStore.nbaModeKey, fallback: 'Players');
    final storedPlayer = await localStore.loadString(ProductLocalStore.nbaSelectedPlayerKey);
    final storedTeam = await localStore.loadString(ProductLocalStore.nbaSelectedTeamKey);
    final storedGame = await localStore.loadString(ProductLocalStore.nbaSelectedGameKey);
    if (!mounted) return;
    setState(() {
      favorites = storedFavorites;
      watchlist = storedWatchlist;
      mode = {'Players', 'Teams', 'Games'}.contains(storedMode) ? storedMode : 'Players';
      selectedPlayerId = storedPlayer.isEmpty ? null : storedPlayer;
      selectedTeamId = storedTeam.isEmpty ? null : storedTeam;
      selectedGameId = storedGame.isEmpty ? null : storedGame;
      loadedPreferences = true;
    });
  }

  Future<void> _setMode(String value) async {
    setState(() => mode = value);
    await localStore.saveString(ProductLocalStore.nbaModeKey, value);
  }

  Future<void> _selectPlayer(String id) async {
    setState(() => selectedPlayerId = id);
    await localStore.saveString(ProductLocalStore.nbaSelectedPlayerKey, id);
  }

  Future<void> _selectTeam(String id) async {
    setState(() => selectedTeamId = id);
    await localStore.saveString(ProductLocalStore.nbaSelectedTeamKey, id);
  }

  Future<void> _selectGame(String id) async {
    setState(() => selectedGameId = id);
    await localStore.saveString(ProductLocalStore.nbaSelectedGameKey, id);
  }

  Future<void> _toggleWatchlist(String id) async {
    setState(() => watchlist.contains(id) ? watchlist.remove(id) : watchlist.add(id));
    await localStore.saveStringSet(ProductLocalStore.playerWatchlistKey, watchlist);
  }

  Future<void> _toggleFavorite(String id) async {
    setState(() => favorites.contains(id) ? favorites.remove(id) : favorites.add(id));
    await localStore.saveStringSet(ProductLocalStore.favoriteTeamsKey, favorites);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || !loadedPreferences) {
          return const _Surface(child: Text('Loading NBA hub...', style: TextStyle(color: _muted)));
        }
        if (snapshot.hasError) {
          return _Surface(child: Text('NBA data unavailable: ${snapshot.error}', style: const TextStyle(color: _muted)));
        }
        final data = snapshot.data!;
        final playerRows = _playerRows(data, query);
        final teamRows = _teamRows(data, query);
        final gameRows = _gameRows(data, query);
        selectedPlayerId ??= playerRows.isEmpty ? null : _txt(playerRows.first['player_id']);
        selectedTeamId ??= favorites.isNotEmpty ? favorites.first : (teamRows.isEmpty ? null : _txt(teamRows.first['team_id']));
        selectedGameId ??= gameRows.isEmpty ? null : _txt(gameRows.first['game_id']);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Hero(
            title: 'NBA Hub',
            body: 'A friendly league experience with persisted player watchlists, favorite teams, and last-opened NBA pages. The raw terminal tools now feed these pages instead of taking over the navigation.',
            chips: ['${data.teams.length} teams', '${data.playerSeasonTotals.length} player summaries', '${data.games.length} games', '${_compact(data.playByPlayEvents)} PBP events'],
          ),
          const SizedBox(height: 18),
          _PersonalizationBar(favoriteTeams: favorites, watchlistCount: watchlist.length, selectedMode: mode),
          const SizedBox(height: 14),
          _ModeTabs(mode: mode, onChanged: _setMode),
          const SizedBox(height: 14),
          _Search(value: query, hint: 'Search players, teams, dates, or game IDs...', onChanged: (value) => setState(() => query = value)),
          const SizedBox(height: 18),
          if (mode == 'Players')
            _PlayersView(
              rows: playerRows,
              selectedId: selectedPlayerId,
              watchlist: watchlist,
              onSelected: _selectPlayer,
              onWatch: _toggleWatchlist,
            )
          else if (mode == 'Teams')
            _TeamsView(
              teams: teamRows,
              players: data.playerSeasonTotals,
              games: data.teamGameLogs,
              favorites: favorites,
              selectedId: selectedTeamId,
              onSelected: _selectTeam,
              onFavorite: _toggleFavorite,
            )
          else
            _GamesView(
              rows: gameRows,
              teamLogs: data.teamGameLogs,
              playerLogs: data.playerGameLogsTop,
              selectedId: selectedGameId,
              onSelected: _selectGame,
            ),
        ]);
      },
    );
  }
}

class _PlayersView extends StatelessWidget {
  const _PlayersView({required this.rows, required this.selectedId, required this.watchlist, required this.onSelected, required this.onWatch});
  final List<Map<String, dynamic>> rows;
  final String? selectedId;
  final Set<String> watchlist;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onWatch;

  @override
  Widget build(BuildContext context) {
    final selected = rows.firstWhere((row) => _txt(row['player_id']) == selectedId, orElse: () => rows.isEmpty ? <String, dynamic>{} : rows.first);
    final selectedIsWatched = watchlist.contains(_txt(selected['player_id']));
    return _TwoColumn(
      left: _ListPanel(
        title: 'Players',
        subtitle: 'Search, open, and persist player watchlist state.',
        children: [
          for (final row in rows.take(60))
            _ListRow(
              title: _txt(row['player_label']),
              subtitle: '${_txt(row['team_ids'])} • ${_decimal(row['points_per_game'])} PPG • ${_decimal(row['avg_bpm'])} BPM',
              selected: _txt(row['player_id']) == _txt(selected['player_id']),
              trailing: watchlist.contains(_txt(row['player_id'])) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              onTap: () => onSelected(_txt(row['player_id'])),
              onTrailing: () => onWatch(_txt(row['player_id'])),
            ),
        ],
      ),
      right: _Surface(
        child: selected.isEmpty
            ? const Text('No player selected.', style: TextStyle(color: _muted))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _EntityHeader(
                  icon: Icons.person_rounded,
                  title: _txt(selected['player_label']),
                  subtitle: selectedIsWatched ? 'Watched player • ${_txt(selected['team_ids'])}' : 'Player page • ${_txt(selected['team_ids'])}',
                ),
                const SizedBox(height: 16),
                _MetricGrid(items: [
                  _Metric('Games', _txt(selected['games']), 'played'),
                  _Metric('PPG', _decimal(selected['points_per_game']), 'points'),
                  _Metric('MPG', _decimal(selected['minutes_per_game']), 'minutes'),
                  _Metric('BPM', _decimal(selected['avg_bpm']), 'impact proxy'),
                ]),
                const SizedBox(height: 18),
                _Table(title: 'Player profile summary', columns: const ['Stat', 'Value'], rows: [
                  ['Teams', _txt(selected['team_ids'])],
                  ['Total points', _decimal(selected['points'])],
                  ['Total rebounds', _decimal(selected['rebounds'])],
                  ['Total assists', _decimal(selected['assists'])],
                  ['Steals', _decimal(selected['steals'])],
                  ['Blocks', _decimal(selected['blocks'])],
                  ['True shooting proxy', _decimal(selected['avg_ts_pct'])],
                ]),
                const SizedBox(height: 12),
                _Note(selectedIsWatched ? 'Saved locally: this player will stay on the watchlist after refresh. Next step is backend-backed watchlists, alerts, notes, and routed player URLs.' : 'Next: add routed player URLs, bio/headshot fields, full game logs, articles, discussion, fantasy watchlists, and comparison workbooks.'),
              ]),
      ),
    );
  }
}

class _TeamsView extends StatelessWidget {
  const _TeamsView({required this.teams, required this.players, required this.games, required this.favorites, required this.selectedId, required this.onSelected, required this.onFavorite});
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> games;
  final Set<String> favorites;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    final selected = teams.firstWhere((row) => _txt(row['team_id']) == selectedId, orElse: () => teams.isEmpty ? <String, dynamic>{} : teams.first);
    final id = _txt(selected['team_id']);
    final roster = players.where((row) => _txt(row['team_ids']).contains(id)).toList()
      ..sort((a, b) => _num(b['points_per_game']).compareTo(_num(a['points_per_game'])));
    final teamGames = games.where((row) => _txt(row['team_id']) == id).toList().reversed.take(12).toList();
    return _TwoColumn(
      left: _ListPanel(
        title: 'Teams',
        subtitle: 'Open team pages and persist favorite teams.',
        children: [
          for (final row in teams)
            _ListRow(
              title: _txt(row['team_id']),
              subtitle: '${_txt(row['wins'])}-${_txt(row['losses'])} • ${_decimal(row['points_per_game'])} PPG • ${_decimal(row['average_margin'])} margin',
              selected: _txt(row['team_id']) == id,
              trailing: favorites.contains(_txt(row['team_id'])) ? Icons.star_rounded : Icons.star_border_rounded,
              onTap: () => onSelected(_txt(row['team_id'])),
              onTrailing: () => onFavorite(_txt(row['team_id'])),
            ),
        ],
      ),
      right: _Surface(
        child: selected.isEmpty
            ? const Text('No team selected.', style: TextStyle(color: _muted))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _EntityHeader(icon: Icons.groups_rounded, title: id, subtitle: favorites.contains(id) ? 'Favorited team page • saved locally' : 'Team page'),
                const SizedBox(height: 16),
                _MetricGrid(items: [
                  _Metric('Record', '${_txt(selected['wins'])}-${_txt(selected['losses'])}', 'loaded games'),
                  _Metric('PPG', _decimal(selected['points_per_game']), 'scoring'),
                  _Metric('Opp PPG', _decimal(selected['opponent_points_per_game']), 'allowed'),
                  _Metric('Margin', _decimal(selected['average_margin']), 'average'),
                ]),
                const SizedBox(height: 18),
                _Table(title: 'Top player snapshot', columns: const ['Player', 'PPG', 'MPG', 'BPM'], rows: [
                  for (final row in roster.take(8)) [_txt(row['player_label']), _decimal(row['points_per_game']), _decimal(row['minutes_per_game']), _decimal(row['avg_bpm'])],
                ]),
                const SizedBox(height: 12),
                _Table(title: 'Recent team games', columns: const ['Date', 'Opponent', 'Result', 'PTS', 'Margin'], rows: [
                  for (final row in teamGames) [_txt(row['game_date']), _txt(row['opponent_team_id']), _txt(row['result']), _decimal(row['points']), _decimal(row['margin'])],
                ]),
              ]),
      ),
    );
  }
}

class _GamesView extends StatelessWidget {
  const _GamesView({required this.rows, required this.teamLogs, required this.playerLogs, required this.selectedId, required this.onSelected});
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> teamLogs;
  final List<Map<String, dynamic>> playerLogs;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = rows.firstWhere((row) => _txt(row['game_id']) == selectedId, orElse: () => rows.isEmpty ? <String, dynamic>{} : rows.first);
    final id = _txt(selected['game_id']);
    final attachedTeams = teamLogs.where((row) => _txt(row['game_id']) == id).toList();
    final attachedPlayers = playerLogs.where((row) => _txt(row['game_id']) == id).toList()
      ..sort((a, b) => _num(b['pts']).compareTo(_num(a['pts'])));
    final margin = (_num(selected['home_score']) - _num(selected['away_score'])).abs();
    return _TwoColumn(
      left: _ListPanel(
        title: 'Games',
        subtitle: 'Open game pages from schedule/results. Last opened game persists locally.',
        children: [
          for (final row in rows.take(80))
            _ListRow(
              title: _txt(row['game_id']),
              subtitle: '${_txt(row['away_team_id'])} ${_decimal(row['away_score'], decimals: 0)} @ ${_txt(row['home_team_id'])} ${_decimal(row['home_score'], decimals: 0)} • ${_txt(row['game_date'])}',
              selected: _txt(row['game_id']) == id,
              onTap: () => onSelected(_txt(row['game_id'])),
            ),
        ],
      ),
      right: _Surface(
        child: selected.isEmpty
            ? const Text('No game selected.', style: TextStyle(color: _muted))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _EntityHeader(icon: Icons.scoreboard_rounded, title: id, subtitle: '${_txt(selected['away_team_id'])} at ${_txt(selected['home_team_id'])} • ${_txt(selected['game_date'])}'),
                const SizedBox(height: 16),
                _MetricGrid(items: [
                  _Metric('Winner', _txt(selected['winner_team_id']), 'result'),
                  _Metric('Total', _decimal(_num(selected['home_score']) + _num(selected['away_score'])), 'points'),
                  _Metric('Margin', _decimal(margin), 'points'),
                  _Metric('Player rows', '${attachedPlayers.length}', 'available'),
                ]),
                const SizedBox(height: 18),
                _Table(title: 'Team box snapshot', columns: const ['Team', 'Opp', 'Result', 'PTS', 'Margin'], rows: [
                  for (final row in attachedTeams) [_txt(row['team_id']), _txt(row['opponent_team_id']), _txt(row['result']), _decimal(row['points']), _decimal(row['margin'])],
                ]),
                const SizedBox(height: 12),
                _Table(title: 'Top player rows', columns: const ['Player', 'Team', 'PTS', 'REB', 'AST', '+/-'], rows: [
                  for (final row in attachedPlayers.take(10)) [_txt(row['player_label']), _txt(row['team_id']), _decimal(row['pts']), _decimal(row['trb']), _decimal(row['ast']), _decimal(row['plus_minus'])],
                ]),
              ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.body, required this.chips});
  final String title;
  final String body;
  final List<String> chips;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_navy, _blue, _orange]), borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 22, offset: Offset(0, 10))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NBA', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 12)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 38, height: 1.05, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: Text(body, style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 16, height: 1.5))),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [for (final chip in chips) _Pill(chip)]),
        ]),
      );
}

class _PersonalizationBar extends StatelessWidget {
  const _PersonalizationBar({required this.favoriteTeams, required this.watchlistCount, required this.selectedMode});
  final Set<String> favoriteTeams;
  final int watchlistCount;
  final String selectedMode;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _StatusChip(Icons.star_rounded, 'Favorite teams', favoriteTeams.isEmpty ? 'None yet' : favoriteTeams.take(5).join(', ')),
          _StatusChip(Icons.bookmark_rounded, 'Player watchlist', '$watchlistCount saved'),
          _StatusChip(Icons.history_rounded, 'Last section', selectedMode),
          const _StatusChip(Icons.save_rounded, 'Storage', 'Saved on this device'),
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _blue, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: 12)),
          Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12)),
        ]),
      );
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});
  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final item in const [('Players', Icons.person_rounded), ('Teams', Icons.groups_rounded), ('Games', Icons.scoreboard_rounded)])
            ChoiceChip(
              avatar: Icon(item.$2, size: 18, color: mode == item.$1 ? Colors.white : _muted),
              label: Text(item.$1),
              selected: mode == item.$1,
              selectedColor: _navy,
              labelStyle: TextStyle(color: mode == item.$1 ? Colors.white : _ink, fontWeight: FontWeight.w900),
              onSelected: (_) => onChanged(item.$1),
            ),
        ]),
      );
}

class _Search extends StatelessWidget {
  const _Search({required this.value, required this.hint, required this.onChanged});
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _Surface(
        child: TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
          onChanged: onChanged,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: hint, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line))),
        ),
      );
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 920) return Column(children: [left, const SizedBox(height: 18), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 390, child: left), const SizedBox(width: 18), Expanded(child: right)]);
      });
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _Surface(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted))])),
          const Divider(height: 1, color: _line),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 620),
            child: SingleChildScrollView(child: Column(children: children.isEmpty ? const [Padding(padding: EdgeInsets.all(18), child: Text('No matches yet.', style: TextStyle(color: _muted)))] : children)),
          ),
        ]),
      );
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.title, required this.subtitle, required this.selected, required this.onTap, this.trailing, this.onTrailing});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? _blue : _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12))])),
              if (trailing != null) IconButton(onPressed: onTrailing, icon: Icon(trailing, color: selected ? _blue : _muted, size: 20)),
            ]),
          ),
        ),
      );
}

class _EntityHeader extends StatelessWidget {
  const _EntityHeader({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(children: [
        CircleAvatar(radius: 28, backgroundColor: const Color(0xFFEFF6FF), child: Icon(icon, color: _blue, size: 30)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))])),
      ]);
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 760;
        return GridView.count(crossAxisCount: wide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: wide ? 1.8 : 1.35, children: [for (final item in items) _MetricTile(item)]);
      });
}

class _Metric {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.item);
  final _Metric item;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(item.label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w800)), Text(item.value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w900)), Text(item.detail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w700))]),
      );
}

class _Table extends StatelessWidget {
  const _Table({required this.title, required this.columns, required this.rows});
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: _line), borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, color: _soft, padding: const EdgeInsets.all(14), child: Text(title, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900))),
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.all(14), child: Text('No rows available yet.', style: TextStyle(color: _muted)))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w900),
                dataTextStyle: const TextStyle(color: _ink),
                columns: [for (final column in columns) DataColumn(label: Text(column))],
                rows: [
                  for (final row in rows)
                    DataRow(cells: [
                      for (final cell in row) DataCell(SizedBox(width: cell.length > 26 ? 210 : 96, child: Text(cell, overflow: TextOverflow.ellipsis))),
                    ]),
                ],
              ),
            ),
        ]),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 8))]), child: child);
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.28))), child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)));
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFD7A8))), child: Text(text, style: const TextStyle(color: Color(0xFF9A3412), height: 1.4, fontWeight: FontWeight.w700)));
}

List<Map<String, dynamic>> _playerRows(NbaTerminalSeedSnapshot data, String query) {
  final q = query.trim().toLowerCase();
  final rows = data.playerSeasonTotals.where((row) => q.isEmpty || '${_txt(row['player_label'])} ${_txt(row['team_ids'])}'.toLowerCase().contains(q)).toList()
    ..sort((a, b) => _num(b['points_per_game']).compareTo(_num(a['points_per_game'])));
  return rows;
}

List<Map<String, dynamic>> _teamRows(NbaTerminalSeedSnapshot data, String query) {
  final q = query.trim().toLowerCase();
  final rows = data.teamRecords.where((row) => q.isEmpty || _txt(row['team_id']).toLowerCase().contains(q)).toList()
    ..sort((a, b) => _num(b['wins']).compareTo(_num(a['wins'])));
  return rows;
}

List<Map<String, dynamic>> _gameRows(NbaTerminalSeedSnapshot data, String query) {
  final q = query.trim().toLowerCase();
  final rows = data.games.where((row) => q.isEmpty || '${_txt(row['game_id'])} ${_txt(row['game_date'])} ${_txt(row['away_team_id'])} ${_txt(row['home_team_id'])} ${_txt(row['winner_team_id'])}'.toLowerCase().contains(q)).toList();
  return rows.reversed.toList();
}

String _txt(Object? value) => value?.toString() ?? '—';

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _decimal(Object? value, {int decimals = 1}) {
  final number = _num(value);
  return decimals == 0 ? number.round().toString() : number.toStringAsFixed(decimals);
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
