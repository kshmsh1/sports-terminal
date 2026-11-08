import 'package:flutter/material.dart';

import '../services/website_nba_api_service.dart';

/// Date-first, source-backed NBA archive. Games are browsed on the left;
/// choosing a game reveals its box score and player drill-down on the right.
class WebsiteNbaBoxScoresScreen extends StatefulWidget {
  const WebsiteNbaBoxScoresScreen({super.key});
  @override
  State<WebsiteNbaBoxScoresScreen> createState() => _WebsiteNbaBoxScoresScreenState();
}

class _WebsiteNbaBoxScoresScreenState extends State<WebsiteNbaBoxScoresScreen> {
  final _api = const WebsiteNbaApiService();
  late final Future<_BoxScoreArchive> _archive = _load();
  String _season = 'All';
  String _segment = 'All';
  DateTime? _date;
  String? _selectedGameKey;
  Future<Map<String, dynamic>>? _gameFuture;
  Map<String, dynamic>? _selectedPlayer;
  String? _teamFilter;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_BoxScoreArchive> _load() async {
    final data = await Future.wait<dynamic>([_api.seasons(), _api.games()]);
    final games = data[1] as List<Map<String, dynamic>>;
    games.sort((a, b) => _text(b['game_date']).compareTo(_text(a['game_date'])));
    return _BoxScoreArchive(
      seasons: data[0] as List<WebsiteNbaSeason>, games: games);
  }

  void _selectGame(Map<String, dynamic> game) {
    final key = _text(game['game_key']);
    if (key.isEmpty) return;
    setState(() {
      _selectedGameKey = key;
      _selectedPlayer = null;
      _teamFilter = null;
      _gameFuture = _api.gameDetail(key);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_BoxScoreArchive>(
    future: _archive,
    builder: (context, result) {
      if (!result.hasData) {
        return SizedBox(height: 430, child: Center(child: result.hasError
            ? Text('Game archive unavailable: ${result.error}')
            : const CircularProgressIndicator()));
      }
      return _buildArchive(context, result.data!);
    },
  );

  Widget _buildArchive(BuildContext context, _BoxScoreArchive archive) {
    final colors = Theme.of(context).colorScheme;
    final seasonGames = archive.games.where((game) {
      if (_season != 'All' && _text(game['season_id']) != _season) return false;
      if (_segment == 'Regular Season' && _isPlayoffs(game)) return false;
      if (_segment == 'Playoffs' && !_isPlayoffs(game)) return false;
      return true;
    }).toList();
    final date = _date ?? (seasonGames.isEmpty
        ? null : DateTime.tryParse(_text(seasonGames.first['game_date']).substring(0, 10)));
    final dateString = date == null ? '' : _dateKey(date);
    final query = _search.text.trim().toLowerCase();
    final visible = seasonGames.where((game) {
      if (dateString.isNotEmpty &&
          !_text(game['game_date']).startsWith(dateString)) return false;
      if (query.isEmpty) return true;
      return [
        game['away_team_name'], game['home_team_name'],
        game['away_team_abbreviation'], game['home_team_abbreviation'],
        game['game_key'],
      ].any((value) => _text(value).toLowerCase().contains(query));
    }).toList();

    final filters = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Wrap(spacing: 10, runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 152, child: DropdownButtonFormField<String>(
            key: ValueKey('box-season-$_season'),
            initialValue: _season,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Season', isDense: true),
            items: [
              const DropdownMenuItem(value: 'All', child: Text('All seasons')),
              for (final item in archive.seasons)
                DropdownMenuItem(value: item.id, child: Text(item.id)),
            ],
            onChanged: (next) {
              if (next == null) return;
              setState(() {
                _season = next;
                _date = null;
                _selectedGameKey = null;
                _gameFuture = null;
                _selectedPlayer = null;
              });
            },
          )),
          SizedBox(width: 167, child: DropdownButtonFormField<String>(
            key: ValueKey('box-segment-$_segment'),
            initialValue: _segment,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Segment', isDense: true),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All games')),
              DropdownMenuItem(value: 'Regular Season', child: Text('Regular Season')),
              DropdownMenuItem(value: 'Playoffs', child: Text('Playoffs')),
            ],
            onChanged: (next) => setState(() {
              _segment = next ?? 'All';
              _date = null;
              _selectedGameKey = null;
              _gameFuture = null;
              _selectedPlayer = null;
            }),
          )),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text(date == null ? 'Choose date' : _niceDate(date)),
            onPressed: () async {
              final pick = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime(2025, 1, 1),
                firstDate: DateTime(1946),
                lastDate: DateTime(2027, 12, 31),
                helpText: 'Select a game date',
              );
              if (pick == null || !mounted) return;
              setState(() {
                _date = pick;
                _selectedGameKey = null;
                _gameFuture = null;
                _selectedPlayer = null;
              });
            },
          ),
          IconButton(
            tooltip: 'Previous day',
            onPressed: date == null ? null : () => setState(() {
              _date = date.subtract(const Duration(days: 1));
              _selectedGameKey = null; _gameFuture = null; _selectedPlayer = null;
            }),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: date == null ? null : () => setState(() {
              _date = date.add(const Duration(days: 1));
              _selectedGameKey = null; _gameFuture = null; _selectedPlayer = null;
            }),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          SizedBox(width: 180, child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              isDense: true, hintText: 'Search teams',
              prefixIcon: Icon(Icons.search_rounded)),
          )),
          Chip(label: Text('${visible.length} game${visible.length == 1 ? '' : 's'}')),
        ]),
      ),
    );

    final gameGrid = visible.isEmpty
      ? Card(child: Padding(padding: const EdgeInsets.all(26),
          child: Text('No games found for ${date == null ? 'this season' : _niceDate(date)}. Choose another date.')))
      : LayoutBuilder(builder: (context, bounds) {
        final width = (bounds.maxWidth - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final game in visible)
            SizedBox(width: width, child: _GameTile(
              game: game,
              selected: _selectedGameKey == _text(game['game_key']),
              onTap: () => _selectGame(game),
            )),
        ]);
      });

    Widget detailPanel() {
      if (_gameFuture == null || _selectedGameKey == null) return const SizedBox.shrink();
      Map<String, dynamic>? selectedGame;
      for (final game in archive.games) {
        if (_text(game['game_key']) == _selectedGameKey) {
          selectedGame = game; break;
        }
      }
      if (selectedGame == null) return const SizedBox.shrink();
      final selected = selectedGame;
      return FutureBuilder<Map<String, dynamic>>(
        future: _gameFuture,
        builder: (context, result) => _GameInspector(
          game: selected,
          detail: result.data,
          loading: result.connectionState != ConnectionState.done,
          error: result.error,
          selectedPlayer: _selectedPlayer,
          selectedTeam: _teamFilter,
          onTeam: (team) => setState(() {
            _teamFilter = team;
            _selectedPlayer = null;
          }),
          onPlayer: (player) => setState(() => _selectedPlayer = player),
          onClose: () => setState(() {
            _selectedGameKey = null; _gameFuture = null;
            _selectedPlayer = null;
          }),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Box Scores', style: Theme.of(context).textTheme.displaySmall
          ?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text('Choose a season and date to browse final scores. Select a game for team and player box scores.',
          style: TextStyle(color: colors.onSurfaceVariant)),
      const SizedBox(height: 16),
      filters,
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, bounds) {
        final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(date == null ? 'Select a date' : _niceDate(date),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900))),
            Text('${visible.length} final scores', style: TextStyle(
                fontSize: 12, color: colors.onSurfaceVariant)),
          ]),
          const SizedBox(height: 11),
          gameGrid,
        ]);
        if (bounds.maxWidth < 1100) return Column(children: [
          left, if (_gameFuture != null) ...[
            const SizedBox(height: 16), detailPanel(),
          ],
        ]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          SizedBox(width: 670, child: detailPanel()),
        ]);
      }),
      const SizedBox(height: 14),
      Text('ARCSIDE · Historical static archive · Missing player statistics are not inferred.',
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
    ]);
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.selected, required this.onTap});
  final Map<String, dynamic> game;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final away = _team(game, away: true);
    final home = _team(game, away: false);
    final awayScore = _num(game['away_score']);
    final homeScore = _num(game['home_score']);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: selected ? colors.primary :
            colors.outlineVariant, width: selected ? 2 : .7),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text('FINAL', style: TextStyle(fontSize: 10,
                  letterSpacing: 1, color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w900)),
              const Spacer(),
              if (_isPlayoffs(game))
                Text('PLAYOFFS', style: TextStyle(fontSize: 10,
                    color: colors.primary, fontWeight: FontWeight.w900)),
              const SizedBox(width: 5),
              Icon(game['box_score_available'] == true
                  ? Icons.table_chart_rounded : Icons.table_chart_outlined,
                  size: 15, color: colors.onSurfaceVariant),
            ]),
            const SizedBox(height: 10),
            _teamScoreRow(away, awayScore, awayScore != null &&
                homeScore != null && awayScore > homeScore),
            const SizedBox(height: 6),
            _teamScoreRow(home, homeScore, awayScore != null &&
                homeScore != null && homeScore > awayScore),
          ]),
        ),
      ),
    );
  }

  Widget _teamScoreRow(String team, double? score, bool winner) =>
      Row(children: [
        Expanded(child: Text(team, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight:
                winner ? FontWeight.w900 : FontWeight.w600))),
        const SizedBox(width: 7),
        Text(score == null ? '—' : score.round().toString(),
            style: TextStyle(fontSize: 21, fontWeight: winner
                ? FontWeight.w900 : FontWeight.w600)),
      ]);
}

class _GameInspector extends StatelessWidget {
  const _GameInspector({required this.game, required this.detail,
    required this.loading, required this.error, required this.selectedPlayer,
    required this.selectedTeam, required this.onPlayer, required this.onTeam,
    required this.onClose});
  final Map<String, dynamic> game;
  final Map<String, dynamic>? detail;
  final bool loading;
  final Object? error;
  final Map<String, dynamic>? selectedPlayer;
  final String? selectedTeam;
  final ValueChanged<Map<String, dynamic>> onPlayer;
  final ValueChanged<String> onTeam;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = _maps(detail?['player_box_scores']);
    final teamTotals = _maps(detail?['team_box_scores']);
    final away = _text(game['away_team_abbreviation']);
    final home = _text(game['home_team_abbreviation']);
    final team = selectedTeam == home ? home : selectedTeam == away ? away : away;
    final players = rows.where((r) => _text(r['team_abbreviation']) == team).toList()
      ..sort((a, b) => (_num(b['pts']) ?? -1).compareTo(_num(a['pts']) ?? -1));

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('GAME CENTER', style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2)),
            const Spacer(),
            IconButton(tooltip: 'Close game', onPressed: onClose,
                icon: const Icon(Icons.close_rounded)),
          ]),
          Text('${_team(game, away: true)} @ ${_team(game, away: false)}',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          Text('${_text(game['game_date']).split(' ').first}  ·  ${_text(game['season_id'])}  ·  ${_isPlayoffs(game) ? 'Playoffs' : 'Regular Season'}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 10),
          _ScoreStrip(game: game),
          const SizedBox(height: 14),
          if (loading) const Padding(
            padding: EdgeInsets.all(38),
            child: Center(child: CircularProgressIndicator()))
          else if (error != null || rows.isEmpty) Padding(
            padding: const EdgeInsets.all(22),
            child: Text('Individual box scores are not available for this game in the local static archive.${error == null ? '' : ' $error'}',
                style: TextStyle(color: colors.onSurfaceVariant)))
          else ...[
            if (selectedPlayer != null) ...[
              _PlayerSpotlight(row: selectedPlayer!),
              const SizedBox(height: 14),
            ],
            const Text('TEAM BOX SCORES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                    letterSpacing: 1.1)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(label: Text(away), selected: team == away,
                  onSelected: (_) => onTeam(away)),
              ChoiceChip(label: Text(home), selected: team == home,
                  onSelected: (_) => onTeam(home)),
            ]),
            const SizedBox(height: 9),
            if (teamTotals.isNotEmpty)
              for (final total in teamTotals.where((t) =>
                  _text(t['team_abbreviation']) == team))
                Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Team  ·  ${_stat(total, 'pts')} PTS  ·  ${_stat(total, 'reb')} REB  ·  ${_stat(total, 'ast')} AST')),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                horizontalMargin: 8,
                columnSpacing: 15,
                headingRowHeight: 35,
                dataRowMinHeight: 37,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('Player')),
                  DataColumn(label: Text('MIN')),
                  DataColumn(label: Text('PTS')),
                  DataColumn(label: Text('REB')),
                  DataColumn(label: Text('AST')),
                  DataColumn(label: Text('STL')),
                  DataColumn(label: Text('BLK')),
                  DataColumn(label: Text('TO')),
                  DataColumn(label: Text('FG')),
                  DataColumn(label: Text('3P')),
                  DataColumn(label: Text('FT')),
                ],
                rows: [
                  for (final player in players)
                    DataRow(
                      selected: identical(player, selectedPlayer),
                      onSelectChanged: (_) => onPlayer(player),
                      cells: [
                        DataCell(Text(_text(player['player_name'], 'Player'),
                            style: const TextStyle(fontWeight: FontWeight.w800))),
                        for (final stat in ['minutes', 'pts', 'reb', 'ast', 'stl', 'blk', 'tov'])
                          DataCell(Text(_stat(player, stat))),
                        DataCell(Text('${_stat(player, 'fgm')}/${_stat(player, 'fga')}')),
                        DataCell(Text('${_stat(player, 'three_pm')}/${_stat(player, 'three_pa')}')),
                        DataCell(Text('${_stat(player, 'ftm')}/${_stat(player, 'fta')}')),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Select any player to inspect their full game stat line.',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Text('ARCSIDE · SOURCE-BACKED BOX SCORE',
              style: TextStyle(fontSize: 10,
                  color: colors.onSurfaceVariant, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.game});
  final Map<String, dynamic> game;
  @override
  Widget build(BuildContext context) {
    final awayScore = _num(game['away_score']);
    final homeScore = _num(game['home_score']);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .23),
        borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Text(_team(game, away: true), textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(width: 9),
        Text(awayScore == null ? '—' : awayScore.round().toString(),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('–')),
        Text(homeScore == null ? '—' : homeScore.round().toString(),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(width: 9),
        Expanded(child: Text(_team(game, away: false),
            style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

class _PlayerSpotlight extends StatelessWidget {
  const _PlayerSpotlight({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = [
      ('MIN', 'minutes'), ('PTS', 'pts'), ('REB', 'reb'),
      ('AST', 'ast'), ('STL', 'stl'), ('BLK', 'blk'),
      ('TO', 'tov'), ('+/−', 'plus_minus'),
      ('FG', 'fgm'), ('FGA', 'fga'), ('3PM', 'three_pm'),
      ('3PA', 'three_pa'), ('FTM', 'ftm'), ('FTA', 'fta'),
    ];
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .20),
        border: Border.all(color: colors.primary.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_text(row['player_name'], 'Player'), style:
            Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        Text('${_text(row['team_abbreviation'])} · Individual game',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
        const SizedBox(height: 13),
        Row(children: [
          for (final key in ['pts','reb','ast'])
            Expanded(child: Column(children: [
              Text(_stat(row, key), style:
                  const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              Text(key.toUpperCase(), style:
                  TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
            ])),
        ]),
        const Divider(height: 24),
        Wrap(spacing: 17, runSpacing: 13, children: [
          for (final item in items)
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_stat(row, item.$2),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(item.$1, style: TextStyle(color: colors.onSurfaceVariant,
                  fontSize: 10)),
            ]),
        ]),
      ]),
    );
  }
}

class _BoxScoreArchive {
  const _BoxScoreArchive({required this.seasons, required this.games});
  final List<WebsiteNbaSeason> seasons;
  final List<Map<String, dynamic>> games;
}

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _niceDate(DateTime date) => '${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][date.month - 1]} ${date.day}, ${date.year}';
bool _isPlayoffs(Map<String, dynamic> game) =>
    _text(game['season_type']).toLowerCase().contains('play');
String _team(Map<String, dynamic> game, {required bool away}) {
  final key = away ? 'away' : 'home';
  return _text(game['${key}_team_name'], _text(game['${key}_team_abbreviation'], 'Team'));
}
String _text(Object? value, [String fallback = '']) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty || result == 'null' ? fallback : result;
}
double? _num(Object? value) => value is num
    ? value.toDouble() : double.tryParse(value?.toString() ?? '');
String _stat(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return '—';
  if (value is num && value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}
List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}
