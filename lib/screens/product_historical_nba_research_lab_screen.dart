import 'dart:async';

import 'package:flutter/material.dart';

import '../services/historical_nba_repository.dart';
import '../services/historical_nba_research_repository.dart';

const _bg = Color(0xFF121925);
const _panel = Color(0xFF1A2332);
const _panel2 = Color(0xFF222D3E);
const _line = Color(0xFF344154);
const _text = Color(0xFFF3F6FA);
const _muted = Color(0xFF9CA8BA);
const _yellow = Color(0xFFFFCB45);
const _cyan = Color(0xFF62D6FF);
const _green = Color(0xFF62E6A5);
const _red = Color(0xFFFF7B7B);

class ProductHistoricalNbaResearchLabScreen extends StatefulWidget {
  const ProductHistoricalNbaResearchLabScreen({super.key});

  @override
  State<ProductHistoricalNbaResearchLabScreen> createState() =>
      _ProductHistoricalNbaResearchLabScreenState();
}

class _ProductHistoricalNbaResearchLabScreenState
    extends State<ProductHistoricalNbaResearchLabScreen> {
  final HistoricalNbaRepository _history = const HistoricalNbaRepository();
  final HistoricalNbaResearchRepository _research =
      const HistoricalNbaResearchRepository();
  final TextEditingController _playerSearch = TextEditingController();
  final TextEditingController _franchiseSearch = TextEditingController();
  Timer? _searchTimer;

  int _desk = 0;
  bool _loading = true;
  bool _deskBusy = false;
  String _error = '';
  String _league = 'NBA';
  String _seasonType = 'regular';
  String _metric = 'pts';
  String _basis = 'per_game';
  double _minGames = 10;
  String _season = '';
  List<Map<String, dynamic>> _seasons = const [];
  Map<String, dynamic> _summary = const {};

  List<Map<String, dynamic>> _playerResults = const [];
  Map<String, dynamic>? _player;
  Map<String, dynamic> _career = const {};
  Map<String, dynamic> _era = const {};
  Map<String, dynamic> _playerGames = const {};
  final LinkedHashSet<String> _compare = LinkedHashSet<String>();

  String _allTimeMode = 'career';
  String _allTimeBasis = 'totals';
  int _bestN = 5;
  int _minSeasons = 1;
  Map<String, dynamic> _allTime = const {};

  Map<String, dynamic> _games = const {};
  Map<String, dynamic>? _game;
  Map<String, dynamic> _pbp = const {};

  List<Map<String, dynamic>> _franchises = const [];
  Map<String, dynamic>? _franchise;

  static const _metrics = <String, String>{
    'pts': 'PTS',
    'ast': 'AST',
    'reb': 'REB',
    'stl': 'STL',
    'blk': 'BLK',
    'tov': 'TOV',
    'fg_pct': 'FG%',
    'three_pct': '3P%',
    'ft_pct': 'FT%',
    'ts_pct': 'TS%',
    'efg_pct': 'eFG%',
    'per': 'PER',
    'ws': 'WS',
    'ws48': 'WS/48',
    'bpm': 'BPM',
    'vorp': 'VORP',
    'usg_pct': 'USG%',
    'ortg': 'ORtg',
    'drtg': 'DRtg',
  };

  static const _bases = <String, String>{
    'totals': 'Totals',
    'per_game': 'Per Game',
    'per36': 'Per 36',
    'per48': 'Per 48',
    'per75': 'Per 75 Poss',
    'per100': 'Per 100 Poss',
  };

  static const _desks = <(String, IconData)>[
    ('Career', Icons.person_search_rounded),
    ('All-Time', Icons.emoji_events_outlined),
    ('Games + PBP', Icons.sports_basketball_outlined),
    ('Franchises', Icons.account_tree_outlined),
    ('Coverage', Icons.fact_check_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _playerSearch.dispose();
    _franchiseSearch.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        _history.seasons(league: _league),
        _research.summary(),
        _research.allTime(
          metric: _metric,
          basis: _allTimeBasis,
          mode: _allTimeMode,
          league: _league,
          seasonType: _seasonType,
          minGames: _minGames,
        ),
        _research.franchises(league: _league),
      ]);
      final seasons = results[0] as List<Map<String, dynamic>>;
      final season = seasons.isEmpty
          ? ''
          : seasons.last['season_id']?.toString() ?? '';
      final games = season.isEmpty
          ? <String, dynamic>{'rows': const []}
          : await _research.games(
              season: season,
              league: _league,
              seasonType: _seasonType,
            );
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        _season = season;
        _summary = results[1] as Map<String, dynamic>;
        _allTime = results[2] as Map<String, dynamic>;
        _franchises = _mapRows((results[3] as Map<String, dynamic>)['rows']);
        _games = games;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _changeLeague(String value) async {
    if (_league == value) return;
    setState(() {
      _league = value;
      _season = '';
      _player = null;
      _career = const {};
      _era = const {};
      _playerGames = const {};
      _compare.clear();
      _game = null;
      _pbp = const {};
      _franchise = null;
    });
    await _refreshDesk(forceSeasons: true);
  }

  Future<void> _refreshDesk({bool forceSeasons = false}) async {
    setState(() {
      _deskBusy = true;
      _error = '';
    });
    try {
      if (forceSeasons) {
        final seasons = await _history.seasons(league: _league);
        _seasons = seasons;
        _season = seasons.isEmpty
            ? ''
            : seasons.last['season_id']?.toString() ?? '';
      }
      switch (_desk) {
        case 0:
          if (_player != null) await _selectPlayer(_player!['player_key'].toString());
          break;
        case 1:
          _allTime = await _research.allTime(
            metric: _metric,
            basis: _allTimeBasis,
            mode: _allTimeMode,
            bestN: _bestN,
            league: _league,
            seasonType: _seasonType,
            minSeasons: _minSeasons,
            minGames: _minGames,
          );
          break;
        case 2:
          _games = _season.isEmpty
              ? <String, dynamic>{'rows': const []}
              : await _research.games(
                  season: _season,
                  league: _league,
                  seasonType: _seasonType,
                );
          _game = null;
          _pbp = const {};
          break;
        case 3:
          final result = await _research.franchises(
            query: _franchiseSearch.text.trim(),
            league: _league,
          );
          _franchises = _mapRows(result['rows']);
          break;
        case 4:
          _summary = await _research.summary();
          break;
      }
      if (!mounted) return;
      setState(() => _deskBusy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deskBusy = false;
        _error = error.toString();
      });
    }
  }

  void _queuePlayerSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), () async {
      if (value.trim().length < 2) {
        if (mounted) setState(() => _playerResults = const []);
        return;
      }
      try {
        final rows = await _history.searchPlayers(
          value,
          league: _league,
          limit: 50,
        );
        if (!mounted || _playerSearch.text != value) return;
        setState(() => _playerResults = rows);
      } catch (_) {}
    });
  }

  Future<void> _selectPlayer(String playerKey) async {
    setState(() => _deskBusy = true);
    try {
      final results = await Future.wait([
        _history.player(playerKey),
        _history.career(
          playerKey,
          league: _league,
          seasonType: _seasonType,
        ),
        _history.eraAdjusted(
          playerKey,
          metric: _metric,
          basis: _basis,
          league: _league,
          seasonType: _seasonType,
          minGames: _minGames,
        ),
        _research.playerGames(
          playerKey,
          seasonType: _seasonType == 'combined' ? 'combined' : _seasonType,
          limit: 50,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _player = results[0];
        _career = results[1];
        _era = results[2];
        _playerGames = results[3];
        _playerResults = const [];
        _playerSearch.clear();
        _deskBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deskBusy = false;
        _error = error.toString();
      });
    }
  }

  void _toggleCompare(String playerKey) {
    setState(() {
      if (!_compare.add(playerKey)) _compare.remove(playerKey);
      while (_compare.length > 6) {
        _compare.remove(_compare.first);
      }
    });
  }

  Future<void> _openCompare() async {
    if (_compare.length < 2) return;
    try {
      final result = await _research.compare(
        playerKeys: _compare.toList(),
        metric: _metric,
        basis: _basis,
        league: _league,
        seasonType: _seasonType,
        minGames: _minGames,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _CrossEraDialog(payload: result),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cross-era comparison unavailable: $error')),
      );
    }
  }

  Future<void> _selectGame(String gameKey) async {
    setState(() => _deskBusy = true);
    try {
      final results = await Future.wait([
        _research.game(gameKey),
        _research.playByPlay(gameKey, limit: 1500),
      ]);
      if (!mounted) return;
      setState(() {
        _game = results[0];
        _pbp = results[1];
        _deskBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deskBusy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _selectFranchise(String franchiseKey) async {
    setState(() => _deskBusy = true);
    try {
      final result = await _research.franchise(franchiseKey);
      if (!mounted) return;
      setState(() {
        _franchise = result;
        _deskBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deskBusy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: _bg,
        child: Center(child: CircularProgressIndicator(color: _yellow)),
      );
    }
    return ColoredBox(
      color: _bg,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 8),
            _deskBar(),
            const SizedBox(height: 8),
            _globalControls(),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error, style: const TextStyle(color: _red, fontSize: 10)),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _deskBody()),
                  if (_deskBusy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x44121925),
                        child: Center(
                          child: CircularProgressIndicator(color: _yellow),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final counts = _summary['counts'];
    final manifest = _summary['manifest'];
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: _yellow, size: 19),
          const SizedBox(width: 8),
          const Text(
            'HISTORICAL NBA RESEARCH LAB',
            style: TextStyle(
              color: _yellow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            manifest is Map
                ? '${manifest['schema_version'] ?? 'CANON'} · ${manifest['built_at'] ?? ''}'
                : 'CANONICAL MULTI-SOURCE HISTORY',
            style: const TextStyle(color: _muted, fontSize: 8),
          ),
          const Spacer(),
          if (counts is Map) ...[
            _Chip('${_compact(counts['players'])} PLAYERS', _cyan),
            const SizedBox(width: 5),
            _Chip('${_compact(counts['games'])} GAMES', _green),
            const SizedBox(width: 5),
            _Chip('${_compact(counts['material_conflicts'])} CONFLICTS', _yellow),
          ],
        ],
      ),
    );
  }

  Widget _deskBar() => _Card(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            for (var index = 0; index < _desks.length; index++) ...[
              if (index > 0) const SizedBox(width: 4),
              Expanded(
                child: _DeskButton(
                  label: _desks[index].$1,
                  icon: _desks[index].$2,
                  selected: _desk == index,
                  onTap: () {
                    if (_desk == index) return;
                    setState(() => _desk = index);
                    _refreshDesk();
                  },
                ),
              ),
            ],
          ],
        ),
      );

  Widget _globalControls() => _Card(
        padding: const EdgeInsets.all(7),
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Drop<String>(
              value: _league,
              values: const ['NBA', 'ABA', 'BAA'],
              width: 82,
              label: (value) => value,
              onChanged: _changeLeague,
            ),
            _Drop<String>(
              value: _seasonType,
              values: const ['regular', 'playoffs', 'combined'],
              width: 105,
              label: (value) => switch (value) {
                'regular' => 'Regular',
                'playoffs' => 'Playoffs',
                _ => 'Combined',
              },
              onChanged: (value) {
                setState(() => _seasonType = value);
                _refreshDesk();
              },
            ),
            _Drop<String>(
              value: _metric,
              values: _metrics.keys.toList(),
              width: 100,
              label: (value) => _metrics[value] ?? value,
              onChanged: (value) {
                setState(() => _metric = value);
                _refreshDesk();
              },
            ),
            _Drop<String>(
              value: _basis,
              values: _bases.keys.toList(),
              width: 115,
              label: (value) => _bases[value] ?? value,
              onChanged: (value) {
                setState(() => _basis = value);
                if (_desk == 0) _refreshDesk();
              },
            ),
            _Drop<double>(
              value: _minGames,
              values: const [0, 1, 5, 10, 20, 41, 58],
              width: 100,
              label: (value) => value == 0 ? 'No GP min' : '${value.toInt()}+ GP',
              onChanged: (value) {
                setState(() => _minGames = value);
                if (_desk <= 1) _refreshDesk();
              },
            ),
            if (_desk == 2)
              _Drop<String>(
                value: _season,
                values: [
                  for (final item in _seasons)
                    if ((item['season_id']?.toString() ?? '').isNotEmpty)
                      item['season_id'].toString(),
                ],
                width: 112,
                label: (value) => value,
                onChanged: (value) {
                  setState(() => _season = value);
                  _refreshDesk();
                },
              ),
            OutlinedButton.icon(
              onPressed: _deskBusy ? null : _refreshDesk,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _text,
                side: const BorderSide(color: _line),
                textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

  Widget _deskBody() => switch (_desk) {
        0 => _careerDesk(),
        1 => _allTimeDesk(),
        2 => _gamesDesk(),
        3 => _franchiseDesk(),
        _ => _coverageDesk(),
      };

  Widget _careerDesk() => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          final search = _careerSearchPanel();
          final detail = _careerDetailPanel();
          if (!wide) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 350, child: search),
                  const SizedBox(height: 8),
                  SizedBox(height: 850, child: detail),
                ],
              ),
            );
          }
          return Row(
            children: [
              SizedBox(width: 320, child: search),
              const SizedBox(width: 8),
              Expanded(child: detail),
            ],
          );
        },
      );

  Widget _careerSearchPanel() => _Card(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Label('PLAYER SEARCH'),
                const Spacer(),
                if (_compare.isNotEmpty)
                  Text(
                    '${_compare.length}/6 COMPARE',
                    style: const TextStyle(color: _yellow, fontSize: 8, fontWeight: FontWeight.w900),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 38,
              child: TextField(
                controller: _playerSearch,
                onChanged: _queuePlayerSearch,
                style: const TextStyle(color: _text, fontSize: 11),
                decoration: _input('Search 1946–present players…'),
              ),
            ),
            const SizedBox(height: 7),
            if (_compare.length >= 2)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openCompare,
                  icon: const Icon(Icons.compare_arrows_rounded, size: 15),
                  label: const Text('Open cross-era compare'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _yellow,
                    foregroundColor: _bg,
                    textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: _playerResults.isEmpty
                  ? const Center(
                      child: Text(
                        'Search by player name or historical ID.\nSelections can span any era.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _playerResults.length,
                      itemBuilder: (context, index) {
                        final row = _playerResults[index];
                        final key = row['player_key']?.toString() ?? '';
                        return InkWell(
                          onTap: () => _selectPlayer(key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: _line, width: .5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row['canonical_name']?.toString() ?? '—',
                                        style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w800),
                                      ),
                                      Text(
                                        '${row['first_stat_season'] ?? '—'} → ${row['last_stat_season'] ?? '—'} · ${row['seasons'] ?? 0} seasons',
                                        style: const TextStyle(color: _muted, fontSize: 8),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Compare',
                                  onPressed: () => _toggleCompare(key),
                                  icon: Icon(
                                    _compare.contains(key) ? Icons.check_box : Icons.add_box_outlined,
                                    size: 16,
                                    color: _compare.contains(key) ? _yellow : _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );

  Widget _careerDetailPanel() {
    final player = _player;
    if (player == null) {
      return const _Card(
        child: Center(
          child: Text(
            'Select a player to open the full historical research file.',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }
    final careerRows = _mapRows(_career['rows']);
    final eraRows = _mapRows(_era['rows']);
    final games = _mapRows(_playerGames['rows']);
    final awards = _mapRows(player['awards']);
    final allStar = _mapRows(player['all_star']);
    final draft = _mapRows(player['draft']);
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: _panel2,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player['canonical_name']?.toString() ?? 'Player',
                        style: const TextStyle(color: _text, fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${player['primary_position'] ?? '—'} · ${player['active_from'] ?? '—'} → ${player['active_to'] ?? '—'} · NBA ID ${player['nba_id'] ?? '—'} · BRef ${player['bref_id'] ?? '—'}',
                        style: const TextStyle(color: _muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add to cross-era compare',
                  onPressed: () => _toggleCompare(player['player_key'].toString()),
                  icon: Icon(
                    _compare.contains(player['player_key']) ? Icons.library_add_check : Icons.library_add_outlined,
                    color: _yellow,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _careerTable(careerRows)),
                      const SizedBox(width: 8),
                      SizedBox(width: 285, child: _eraPanel(eraRows)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _honorsPanel(awards, allStar, draft)),
                      const SizedBox(width: 8),
                      Expanded(child: _gameLogPanel(games)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _careerTable(List<Map<String, dynamic>> rows) => _SubCard(
        title: 'CAREER / PLAYOFF SEASON FILE',
        child: SizedBox(
          height: 370,
          child: rows.isEmpty
              ? const Center(child: Text('No season rows for this segment.', style: TextStyle(color: _muted)))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final games = _num(row['games']);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line, width: .5))),
                      child: Row(
                        children: [
                          SizedBox(width: 64, child: _Cell(row['season_id']?.toString() ?? '—', strong: true)),
                          SizedBox(width: 44, child: _Cell(row['team_abbreviation']?.toString() ?? '—')),
                          SizedBox(width: 38, child: _Cell(_fmt(games, 0), right: true)),
                          Expanded(child: _Cell('${_perGame(row, 'pts')} PTS', right: true)),
                          Expanded(child: _Cell('${_perGame(row, 'reb')} REB', right: true)),
                          Expanded(child: _Cell('${_perGame(row, 'ast')} AST', right: true)),
                          SizedBox(width: 55, child: _Cell(_signed(row['bpm']), right: true, accent: _cyan)),
                          SizedBox(width: 55, child: _Cell(_pct(row['ts_pct']), right: true, accent: _green)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      );

  Widget _eraPanel(List<Map<String, dynamic>> rows) => _SubCard(
        title: 'ERA-RELATIVE SERIES · ${_metrics[_metric]}',
        child: SizedBox(
          height: 370,
          child: rows.isEmpty
              ? const Center(child: Text('No qualified era series.', style: TextStyle(color: _muted)))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final z = _num(row['z_score']) ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 58, child: _Cell(row['season']?.toString() ?? '—')),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: ((z.clamp(-3, 3) + 3) / 6).toDouble(),
                              minHeight: 7,
                              backgroundColor: _bg,
                              color: z >= 0 ? _green : _cyan,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(width: 42, child: _Cell(_signed(z), right: true, accent: z >= 0 ? _green : _cyan)),
                          SizedBox(width: 46, child: _Cell(_pct(row['percentile']), right: true)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      );

  Widget _honorsPanel(
    List<Map<String, dynamic>> awards,
    List<Map<String, dynamic>> allStar,
    List<Map<String, dynamic>> draft,
  ) =>
      _SubCard(
        title: 'HONORS / DRAFT / ALL-STAR',
        child: SizedBox(
          height: 250,
          child: ListView(
            children: [
              for (final item in draft)
                _eventRow('DRAFT', '${item['draft_year'] ?? '—'} · R${item['round_text'] ?? '—'} · Pick ${_fmt(item['pick_number'], 0)} · ${item['drafting_team_text'] ?? '—'}', _cyan),
              for (final item in awards)
                _eventRow('AWARD', '${item['season_id'] ?? '—'} · ${item['award'] ?? '—'}${item['winner'] == 1 ? ' · WINNER' : ''}', _yellow),
              for (final item in allStar)
                _eventRow('ALL-STAR', '${item['season_id'] ?? '—'} · ${item['team_text'] ?? 'Selection'}', _green),
              if (draft.isEmpty && awards.isEmpty && allStar.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('No honors records in canonical coverage.', style: TextStyle(color: _muted)),
                ),
            ],
          ),
        ),
      );

  Widget _gameLogPanel(List<Map<String, dynamic>> rows) => _SubCard(
        title: 'GAME-LEVEL COVERAGE · LATEST 50',
        child: SizedBox(
          height: 250,
          child: rows.isEmpty
              ? const Center(
                  child: Text(
                    'No canonical player-game rows for this player/era.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line, width: .5))),
                      child: Row(
                        children: [
                          SizedBox(width: 78, child: _Cell(row['game_date']?.toString() ?? '—')),
                          SizedBox(width: 76, child: _Cell('${row['team_abbreviation'] ?? '—'} vs ${row['opponent_abbreviation'] ?? '—'}')),
                          Expanded(child: _Cell('${_fmt(row['pts'], 0)} PTS · ${_fmt(row['reb'], 0)} REB · ${_fmt(row['ast'], 0)} AST', right: true, accent: _text)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      );

  Widget _eventRow(String label, String value, Color accent) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 62, child: Text(label, style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.w900))),
            Expanded(child: Text(value, style: const TextStyle(color: _text, fontSize: 9))),
          ],
        ),
      );

  Widget _allTimeDesk() {
    final rows = _mapRows(_allTime['rows']);
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: _panel2, border: Border(bottom: BorderSide(color: _line))),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Drop<String>(
                  value: _allTimeMode,
                  values: const ['career', 'peak', 'best_n'],
                  width: 115,
                  label: (value) => switch (value) {
                    'career' => 'Career',
                    'peak' => 'Peak Season',
                    _ => 'Best N Seasons',
                  },
                  onChanged: (value) {
                    setState(() => _allTimeMode = value);
                    _refreshDesk();
                  },
                ),
                _Drop<String>(
                  value: _allTimeBasis,
                  values: _bases.keys.toList(),
                  width: 115,
                  label: (value) => _bases[value] ?? value,
                  onChanged: (value) {
                    setState(() => _allTimeBasis = value);
                    _refreshDesk();
                  },
                ),
                if (_allTimeMode == 'best_n')
                  _Drop<int>(
                    value: _bestN,
                    values: const [1, 3, 5, 7, 10, 15],
                    width: 95,
                    label: (value) => 'Best $value',
                    onChanged: (value) {
                      setState(() => _bestN = value);
                      _refreshDesk();
                    },
                  ),
                _Drop<int>(
                  value: _minSeasons,
                  values: const [1, 2, 3, 5, 7, 10],
                  width: 105,
                  label: (value) => '$value+ seasons',
                  onChanged: (value) {
                    setState(() => _minSeasons = value);
                    _refreshDesk();
                  },
                ),
                Text(
                  '${_allTime['matched_rows'] ?? rows.length} QUALIFIED PLAYERS',
                  style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No all-time rows for these filters.', style: TextStyle(color: _muted)))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return InkWell(
                        onTap: () {
                          setState(() => _desk = 0);
                          _selectPlayer(row['player_key'].toString());
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line, width: .5))),
                          child: Row(
                            children: [
                              SizedBox(width: 42, child: _Cell('#${row['rank'] ?? index + 1}', accent: _yellow, strong: true)),
                              Expanded(flex: 3, child: _Cell(row['player_name']?.toString() ?? '—', strong: true)),
                              Expanded(child: _Cell('${row['seasons'] ?? 0} seasons')),
                              Expanded(child: _Cell('${_fmt(row['career_games'], 0)} GP')),
                              Expanded(child: _Cell('${row['first_season'] ?? '—'} → ${row['last_season'] ?? '—'}')),
                              Expanded(child: _Cell('Peak ${row['peak_season'] ?? '—'}')),
                              SizedBox(width: 105, child: _Cell(_metricValue(row['metric_value'], _metric, _allTimeBasis), right: true, accent: _yellow, strong: true)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _gamesDesk() {
    final rows = _mapRows(_games['rows']);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1150;
        final list = _Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: const BoxDecoration(color: _panel2, border: Border(bottom: BorderSide(color: _line))),
                child: Row(
                  children: [
                    const _Label('HISTORICAL GAMES'),
                    const Spacer(),
                    Text('${rows.length} LOADED', style: const TextStyle(color: _muted, fontSize: 8)),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('No games for this season/segment.', style: TextStyle(color: _muted)))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final gameKey = row['game_key']?.toString() ?? '';
                          final selected = _game?['game_key'] == gameKey;
                          return InkWell(
                            onTap: () => _selectGame(gameKey),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                              color: selected ? const Color(0x182AC6E8) : Colors.transparent,
                              child: Row(
                                children: [
                                  SizedBox(width: 82, child: _Cell(row['game_date']?.toString() ?? '—')),
                                  Expanded(child: _Cell('${row['away_team_abbreviation'] ?? '—'} @ ${row['home_team_abbreviation'] ?? '—'}', strong: true)),
                                  SizedBox(width: 100, child: _Cell('${_fmt(row['away_score'], 0)} – ${_fmt(row['home_score'], 0)}', right: true, accent: _yellow, strong: true)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
        final detail = _gameDetail();
        if (!wide) {
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 500, child: list),
                const SizedBox(height: 8),
                SizedBox(height: 800, child: detail),
              ],
            ),
          );
        }
        return Row(
          children: [
            SizedBox(width: 410, child: list),
            const SizedBox(width: 8),
            Expanded(child: detail),
          ],
        );
      },
    );
  }

  Widget _gameDetail() {
    final game = _game;
    if (game == null) {
      return const _Card(
        child: Center(child: Text('Select a game to inspect canonical box rows and play-by-play.', style: TextStyle(color: _muted))),
      );
    }
    final teams = _mapRows(game['teams']);
    final players = _mapRows(game['players']);
    final events = _mapRows(_pbp['rows']);
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: const BoxDecoration(color: _panel2, border: Border(bottom: BorderSide(color: _line))),
            child: Row(
              children: [
                Text(game['game_date']?.toString() ?? '—', style: const TextStyle(color: _muted, fontSize: 9)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${game['away_team_key'] ?? 'Away'} ${_fmt(game['away_score'], 0)}  —  ${_fmt(game['home_score'], 0)} ${game['home_team_key'] ?? 'Home'}',
                    style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                _Chip('${_pbp['matched_rows'] ?? 0} PBP', _cyan),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _SubCard(
                          title: 'TEAM GAME FACTS',
                          child: Column(
                            children: [
                              for (final row in teams)
                                _simpleRow(
                                  row['team_key']?.toString() ?? 'Team',
                                  '${row['result'] ?? '—'} · ${_fmt(row['points'], 0)} PTS · ${_fmt(row['reb'], 0)} REB · ${_fmt(row['ast'], 0)} AST',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SubCard(
                          title: 'PLAYER GAME FACTS',
                          child: SizedBox(
                            height: 360,
                            child: players.isEmpty
                                ? const Center(child: Text('No player-game materialization for this source/era.', style: TextStyle(color: _muted)))
                                : ListView.builder(
                                    itemCount: players.length,
                                    itemBuilder: (context, index) {
                                      final row = players[index];
                                      return _simpleRow(
                                        '${row['player_name'] ?? '—'} · ${row['team_abbreviation'] ?? '—'}',
                                        '${_fmt(row['pts'], 0)} PTS · ${_fmt(row['reb'], 0)} REB · ${_fmt(row['ast'], 0)} AST · ${_signed(row['bpm'])} BPM',
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: _line),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Align(alignment: Alignment.centerLeft, child: _Label('PLAY-BY-PLAY')), 
                      ),
                      Expanded(
                        child: events.isEmpty
                            ? const Center(child: Text('No canonical PBP for this game.', style: TextStyle(color: _muted)))
                            : ListView.builder(
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final row = events[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line, width: .4))),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(width: 28, child: _Cell('Q${row['period'] ?? '—'}')),
                                        SizedBox(width: 48, child: _Cell(row['clock']?.toString() ?? '—')),
                                        Expanded(child: _Cell(row['description']?.toString() ?? '—')),
                                        SizedBox(width: 56, child: _Cell(row['score']?.toString() ?? '', right: true, accent: _yellow)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _franchiseDesk() => LayoutBuilder(
        builder: (context, constraints) {
          final list = _Card(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _franchiseSearch,
                    onSubmitted: (_) => _refreshDesk(),
                    style: const TextStyle(color: _text, fontSize: 11),
                    decoration: _input('Search franchise lineage…'),
                  ),
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: ListView.builder(
                    itemCount: _franchises.length,
                    itemBuilder: (context, index) {
                      final row = _franchises[index];
                      return InkWell(
                        onTap: () => _selectFranchise(row['franchise_key'].toString()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line, width: .5))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['canonical_name']?.toString() ?? '—', style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text('${row['abbreviations'] ?? '—'} · ${row['first_season'] ?? '—'} → ${row['last_season'] ?? '—'} · ${row['seasons'] ?? 0} seasons', style: const TextStyle(color: _muted, fontSize: 8)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
          final detail = _franchiseDetail();
          if (constraints.maxWidth < 1000) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 420, child: list),
                  const SizedBox(height: 8),
                  SizedBox(height: 700, child: detail),
                ],
              ),
            );
          }
          return Row(
            children: [
              SizedBox(width: 330, child: list),
              const SizedBox(width: 8),
              Expanded(child: detail),
            ],
          );
        },
      );

  Widget _franchiseDetail() {
    final payload = _franchise;
    if (payload == null) {
      return const _Card(
        child: Center(child: Text('Select a franchise to inspect lineage and team-season history.', style: TextStyle(color: _muted))),
      );
    }
    final franchise = payload['franchise'];
    final teams = _mapRows(payload['teams']);
    final seasons = _mapRows(payload['seasons']);
    return _Card(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            franchise is Map ? franchise['canonical_name']?.toString() ?? 'Franchise' : 'Franchise',
            style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final team in teams)
                _Chip('${team['abbreviation'] ?? '—'} · ${team['canonical_name'] ?? '—'}', _cyan),
            ],
          ),
          const SizedBox(height: 10),
          const _Label('TEAM-SEASON HISTORY'),
          const SizedBox(height: 5),
          Expanded(
            child: seasons.isEmpty
                ? const Center(child: Text('No canonical team-season rows.', style: TextStyle(color: _muted)))
                : ListView.builder(
                    itemCount: seasons.length,
                    itemBuilder: (context, index) {
                      final row = seasons[index];
                      final wins = _num(row['wins']);
                      final losses = _num(row['losses']);
                      return Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line, width: .5))),
                        child: Row(
                          children: [
                            SizedBox(width: 65, child: _Cell(row['season_id']?.toString() ?? '—', strong: true)),
                            SizedBox(width: 50, child: _Cell(row['team_abbreviation']?.toString() ?? '—')),
                            Expanded(child: _Cell(row['team_identity_name']?.toString() ?? row['team_name']?.toString() ?? '—')),
                            SizedBox(width: 80, child: _Cell(wins == null && losses == null ? '—' : '${_fmt(wins, 0)}–${_fmt(losses, 0)}', right: true)),
                            SizedBox(width: 70, child: _Cell('${_fmt(row['srs'], 1)} SRS', right: true, accent: _yellow)),
                            SizedBox(width: 80, child: _Cell('${_fmt(row['ortg'], 1)} ORtg', right: true)),
                            SizedBox(width: 80, child: _Cell('${_fmt(row['drtg'], 1)} DRtg', right: true)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _coverageDesk() {
    final sources = _mapRows(_summary['sources']);
    final coverage = _mapRows(_summary['coverage']);
    final conflicts = _mapRows(_summary['top_conflict_fields']);
    final counts = _summary['counts'];
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _MetricCard('FIELD PROVENANCE', counts is Map ? counts['field_provenance'] : null, _cyan)),
              const SizedBox(width: 7),
              Expanded(child: _MetricCard('MATERIAL CONFLICTS', counts is Map ? counts['material_conflicts'] : null, _yellow)),
              const SizedBox(width: 7),
              Expanded(child: _MetricCard('CANONICAL PLAYERS', counts is Map ? counts['players'] : null, _green)),
              const SizedBox(width: 7),
              Expanded(child: _MetricCard('CANONICAL GAMES', counts is Map ? counts['games'] : null, _cyan)),
              const SizedBox(width: 7),
              Expanded(child: _MetricCard('PLAYER-GAME ROWS', counts is Map ? counts['player_games'] : null, _green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SubCard(
                  title: 'SOURCE REGISTRY / RIGHTS',
                  child: Column(
                    children: [
                      for (final row in sources)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _line)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['label']?.toString() ?? row['source_key']?.toString() ?? 'Source', style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text('${_compact(row['row_count'])} rows · ${row['table_count'] ?? 0} tables · ${row['coverage'] ?? 'source-native'}', style: const TextStyle(color: _muted, fontSize: 8)),
                              const SizedBox(height: 2),
                              Text(row['license']?.toString() ?? 'License not recorded', style: const TextStyle(color: _yellow, fontSize: 8)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SubCard(
                  title: 'CANONICAL COVERAGE MATRIX',
                  child: Column(
                    children: [
                      for (final row in coverage)
                        _simpleRow(
                          '${row['domain'] ?? '—'} · ${row['league_id'] ?? '—'}',
                          '${row['first_season'] ?? '—'} → ${row['last_season'] ?? '—'} · ${row['seasons'] ?? 0} seasons · ${_compact(row['rows'])} rows',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SubCard(
                  title: 'TOP SOURCE CONFLICT FIELDS',
                  child: Column(
                    children: [
                      for (final row in conflicts)
                        _simpleRow(
                          '${row['entity_type'] ?? '—'} · ${row['field_name'] ?? '—'}',
                          '${_compact(row['conflicts'])} retained conflicts',
                        ),
                      if (conflicts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('No material conflicts in the current canonical build.', style: TextStyle(color: _green)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _simpleRow(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line, width: .5))),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: _text, fontSize: 9, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(color: _muted, fontSize: 8)),
          ],
        ),
      );

  String _perGame(Map<String, dynamic> row, String field) {
    final games = _num(row['games']);
    final value = _num(row[field]);
    if (games == null || games <= 0 || value == null) return '—';
    return (value / games).toStringAsFixed(1);
  }

  String _metricValue(Object? value, String metric, String basis) {
    if (metric.endsWith('_pct') || {'ts_pct', 'efg_pct', 'usg_pct'}.contains(metric)) {
      return _pct(value);
    }
    return _fmt(value, basis == 'totals' ? 0 : 2);
  }
}

class LinkedHashSet<E> extends SetBase<E> {
  final List<E> _values = <E>[];

  @override
  bool add(E value) {
    if (_values.contains(value)) return false;
    _values.add(value);
    return true;
  }

  @override
  bool contains(Object? element) => _values.contains(element);

  @override
  Iterator<E> get iterator => _values.iterator;

  @override
  int get length => _values.length;

  @override
  E? lookup(Object? element) {
    for (final value in _values) {
      if (value == element) return value;
    }
    return null;
  }

  @override
  bool remove(Object? value) => _values.remove(value);

  @override
  E get first => _values.first;

  @override
  void clear() => _values.clear();
}

abstract class SetBase<E> implements Set<E> {
  @override
  Set<R> cast<R>() => Set<R>.from(this);
  @override
  bool containsAll(Iterable<Object?> other) => other.every(contains);
  @override
  Set<E> difference(Set<Object?> other) => Set<E>.from(where((value) => !other.contains(value)));
  @override
  bool get isEmpty => length == 0;
  @override
  bool get isNotEmpty => length != 0;
  @override
  String join([String separator = '']) => iterator.join(separator);
  @override
  Set<E> intersection(Set<Object?> other) => Set<E>.from(where(other.contains));
  @override
  E get last => _valuesLast();
  E _valuesLast() => iterator.reduce((_, value) => value);
  @override
  void removeAll(Iterable<Object?> elements) {
    for (final value in elements) remove(value);
  }
  @override
  void retainAll(Iterable<Object?> elements) {
    final keep = elements.toSet();
    removeWhere((value) => !keep.contains(value));
  }
  @override
  void removeWhere(bool Function(E element) test) {
    for (final value in toList()) if (test(value)) remove(value);
  }
  @override
  void retainWhere(bool Function(E element) test) {
    for (final value in toList()) if (!test(value)) remove(value);
  }
  @override
  Set<E> union(Set<E> other) => Set<E>.from(this)..addAll(other);
  @override
  void addAll(Iterable<E> elements) {
    for (final value in elements) add(value);
  }
  @override
  List<E> toList({bool growable = true}) => iterator.toList(growable: growable);
  @override
  Set<E> toSet() => Set<E>.from(this);
  @override
  Iterable<T> map<T>(T Function(E e) toElement) => iterator.map(toElement);
  @override
  Iterable<E> where(bool Function(E element) test) => iterator.where(test);
  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) => iterator.fold(initialValue, combine);
  @override
  void forEach(void Function(E element) action) => iterator.forEach(action);
  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) => iterator.firstWhere(test, orElse: orElse);
  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) => iterator.lastWhere(test, orElse: orElse);
  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) => iterator.singleWhere(test, orElse: orElse);
  @override
  E elementAt(int index) => iterator.elementAt(index);
  @override
  bool every(bool Function(E element) test) => iterator.every(test);
  @override
  bool any(bool Function(E element) test) => iterator.any(test);
  @override
  E get single => iterator.single;
  @override
  Iterable<E> take(int count) => iterator.take(count);
  @override
  Iterable<E> takeWhile(bool Function(E value) test) => iterator.takeWhile(test);
  @override
  Iterable<E> skip(int count) => iterator.skip(count);
  @override
  Iterable<E> skipWhile(bool Function(E value) test) => iterator.skipWhile(test);
  @override
  Iterable<E> followedBy(Iterable<E> other) => iterator.followedBy(other);
  @override
  String toString() => toSet().toString();
}

class _CrossEraDialog extends StatelessWidget {
  const _CrossEraDialog({required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final players = _mapRows(payload['players']);
    return AlertDialog(
      backgroundColor: _panel,
      title: Text(
        'Cross-era compare · ${payload['metric'] ?? 'metric'} · ${payload['basis'] ?? 'basis'}',
        style: const TextStyle(color: _text),
      ),
      content: SizedBox(
        width: 1050,
        height: 620,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = players[index];
            final identity = item['identity'] is Map ? item['identity'] as Map : const {};
            final peak = item['peak_season'] is Map ? item['peak_season'] as Map : const {};
            final era = item['peak_era'] is Map ? item['peak_era'] as Map : const {};
            final seasons = _mapRows(item['season_rows']);
            return Container(
              width: 250,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(identity['canonical_name']?.toString() ?? 'Player', style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w900)),
                  Text('${identity['active_from'] ?? '—'} → ${identity['active_to'] ?? '—'}', style: const TextStyle(color: _muted, fontSize: 8)),
                  const SizedBox(height: 10),
                  _dialogMetric('CAREER', _fmt(item['career_metric_value'], 2), _yellow),
                  _dialogMetric('PEAK SEASON', peak['season_id']?.toString() ?? '—', _cyan),
                  _dialogMetric('PEAK Z', _signed(era['z_score']), _green),
                  _dialogMetric('PEAK PCTL', _pct(era['percentile']), _green),
                  const SizedBox(height: 10),
                  const _Label('SEASON SERIES'),
                  const SizedBox(height: 5),
                  Expanded(
                    child: ListView.builder(
                      itemCount: seasons.length,
                      itemBuilder: (context, seasonIndex) {
                        final row = seasons[seasonIndex];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(width: 58, child: _Cell(row['season_id']?.toString() ?? '—')),
                              const Spacer(),
                              _Cell('${_fmt(row['games'], 0)} GP', right: true),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }

  Widget _dialogMetric(String label, String value, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 8))),
            Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(10)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: _line)),
        child: child,
      );
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(7), border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label(title),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
}

class _DeskButton extends StatelessWidget {
  const _DeskButton({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: selected ? const Color(0x22FFCB45) : _bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? _yellow : _line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? _yellow : _muted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: selected ? _yellow : _text, fontSize: 9, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _Drop<T> extends StatelessWidget {
  const _Drop({required this.value, required this.values, required this.width, required this.label, required this.onChanged});
  final T value;
  final List<T> values;
  final double width;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _line)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: values.contains(value) ? value : (values.isEmpty ? null : values.first),
            isExpanded: true,
            dropdownColor: _panel2,
            iconEnabledColor: _muted,
            style: const TextStyle(color: _text, fontSize: 9, fontWeight: FontWeight.w700),
            items: [for (final item in values) DropdownMenuItem<T>(value: item, child: Text(label(item), overflow: TextOverflow.ellipsis))],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(value, style: const TextStyle(color: _yellow, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .6));
}

class _Cell extends StatelessWidget {
  const _Cell(this.value, {this.right = false, this.strong = false, this.accent});
  final String value;
  final bool right;
  final bool strong;
  final Color? accent;
  @override
  Widget build(BuildContext context) => Text(
        value,
        overflow: TextOverflow.ellipsis,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: accent ?? _muted, fontSize: 9, fontWeight: strong ? FontWeight.w900 : FontWeight.w500),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: .45))),
        child: Text(label, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900)),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.color);
  final String label;
  final Object? value;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 7, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_compact(value), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

InputDecoration _input(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 9),
      prefixIcon: const Icon(Icons.search, size: 16, color: _muted),
      filled: true,
      fillColor: _bg,
      contentPadding: EdgeInsets.zero,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _yellow)),
    );

List<Map<String, dynamic>> _mapRows(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _fmt(Object? value, int decimals) {
  final number = _num(value);
  return number == null ? '—' : number.toStringAsFixed(decimals);
}

String _signed(Object? value) {
  final number = _num(value);
  if (number == null) return '—';
  return '${number >= 0 ? '+' : ''}${number.toStringAsFixed(2)}';
}

String _pct(Object? value) {
  final number = _num(value);
  if (number == null) return '—';
  final scaled = number.abs() <= 1.5 ? number * 100 : number;
  return '${scaled.toStringAsFixed(1)}%';
}

String _compact(Object? value) {
  final number = _num(value);
  if (number == null) return '—';
  if (number.abs() >= 1000000) return '${(number / 1000000).toStringAsFixed(number.abs() >= 10000000 ? 1 : 2)}M';
  if (number.abs() >= 1000) return '${(number / 1000).toStringAsFixed(number.abs() >= 100000 ? 0 : 1)}K';
  return number.toStringAsFixed(0);
}
