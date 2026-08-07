import 'dart:async';
import 'dart:collection';

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
  final LinkedHashSet<String> _compare = LinkedHashSet<String>();

  Timer? _searchTimer;
  int _desk = 0;
  bool _loading = true;
  bool _busy = false;
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

  String _allTimeMode = 'career';
  String _allTimeBasis = 'totals';
  int _bestN = 5;
  int _minSeasons = 1;
  Map<String, dynamic> _allTime = const {};

  Map<String, dynamic> _games = const {};
  Map<String, dynamic>? _game;
  Map<String, dynamic> _playByPlay = const {};

  List<Map<String, dynamic>> _franchises = const [];
  Map<String, dynamic>? _franchise;

  static const _desks = <(String, IconData)>[
    ('Career', Icons.person_search_rounded),
    ('All-Time', Icons.emoji_events_outlined),
    ('Games + PBP', Icons.sports_basketball_outlined),
    ('Franchises', Icons.account_tree_outlined),
    ('Coverage', Icons.fact_check_outlined),
  ];

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
      final seasons = await _history.seasons(league: _league);
      final season = seasons.isEmpty
          ? ''
          : seasons.last['season_id']?.toString() ?? '';
      final results = await Future.wait<Map<String, dynamic>>([
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
        if (season.isNotEmpty)
          _research.games(
            season: season,
            league: _league,
            seasonType: _seasonType,
          )
        else
          Future.value(<String, dynamic>{'rows': const []}),
      ]);
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        _season = season;
        _summary = results[0];
        _allTime = results[1];
        _franchises = _rows(results[2]['rows']);
        _games = results[3];
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

  Future<void> _refresh({bool reloadSeasons = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (reloadSeasons) {
        final seasons = await _history.seasons(league: _league);
        _seasons = seasons;
        _season = seasons.isEmpty
            ? ''
            : seasons.last['season_id']?.toString() ?? '';
      }
      switch (_desk) {
        case 0:
          if (_player != null) {
            await _loadPlayer(_player!['player_key']?.toString() ?? '');
          }
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
          _playByPlay = const {};
          break;
        case 3:
          final result = await _research.franchises(
            query: _franchiseSearch.text.trim(),
            league: _league,
          );
          _franchises = _rows(result['rows']);
          break;
        case 4:
          _summary = await _research.summary();
          break;
      }
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _changeLeague(String league) async {
    if (_league == league) return;
    setState(() {
      _league = league;
      _player = null;
      _career = const {};
      _era = const {};
      _playerGames = const {};
      _compare.clear();
      _game = null;
      _playByPlay = const {};
      _franchise = null;
    });
    await _refresh(reloadSeasons: true);
  }

  void _queueSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), () async {
      final query = value.trim();
      if (query.length < 2) {
        if (mounted) setState(() => _playerResults = const []);
        return;
      }
      try {
        final results = await _history.searchPlayers(
          query,
          league: _league,
          limit: 50,
        );
        if (!mounted || _playerSearch.text.trim() != query) return;
        setState(() => _playerResults = results);
      } catch (_) {
        // Search is incremental and should not replace the current research file.
      }
    });
  }

  Future<void> _loadPlayer(String playerKey) async {
    if (playerKey.isEmpty) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
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
          seasonType: _seasonType,
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
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  void _toggleCompare(String playerKey) {
    if (playerKey.isEmpty) return;
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
        builder: (context) => _CompareDialog(payload: result),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cross-era comparison unavailable: $error')),
      );
    }
  }

  Future<void> _loadGame(String gameKey) async {
    if (gameKey.isEmpty) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        _research.game(gameKey),
        _research.playByPlay(gameKey, limit: 1500),
      ]);
      if (!mounted) return;
      setState(() {
        _game = results[0];
        _playByPlay = results[1];
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadFranchise(String franchiseKey) async {
    if (franchiseKey.isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await _research.franchise(franchiseKey);
      if (!mounted) return;
      setState(() {
        _franchise = result;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
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
            _deskNav(),
            const SizedBox(height: 8),
            _controls(),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error,
                  style: const TextStyle(color: _red, fontSize: 10),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _deskBody()),
                  if (_busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x55121925),
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
    return _Panel(
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
            _Pill('${_compact(counts['players'])} PLAYERS', _cyan),
            const SizedBox(width: 5),
            _Pill('${_compact(counts['games'])} GAMES', _green),
            const SizedBox(width: 5),
            _Pill('${_compact(counts['material_conflicts'])} CONFLICTS', _yellow),
          ],
        ],
      ),
    );
  }

  Widget _deskNav() => _Panel(
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
                    _refresh();
                  },
                ),
              ),
            ],
          ],
        ),
      );

  Widget _controls() => _Panel(
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
              width: 108,
              label: (value) => switch (value) {
                'regular' => 'Regular',
                'playoffs' => 'Playoffs',
                _ => 'Combined',
              },
              onChanged: (value) {
                setState(() => _seasonType = value);
                _refresh();
              },
            ),
            _Drop<String>(
              value: _metric,
              values: _metrics.keys.toList(),
              width: 100,
              label: (value) => _metrics[value] ?? value,
              onChanged: (value) {
                setState(() => _metric = value);
                _refresh();
              },
            ),
            _Drop<String>(
              value: _basis,
              values: _bases.keys.toList(),
              width: 116,
              label: (value) => _bases[value] ?? value,
              onChanged: (value) {
                setState(() => _basis = value);
                if (_desk == 0) _refresh();
              },
            ),
            _Drop<double>(
              value: _minGames,
              values: const [0, 1, 5, 10, 20, 41, 58],
              width: 100,
              label: (value) => value == 0 ? 'No GP min' : '${value.toInt()}+ GP',
              onChanged: (value) {
                setState(() => _minGames = value);
                if (_desk <= 1) _refresh();
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
                  _refresh();
                },
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _text,
                side: const BorderSide(color: _line),
                textStyle: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
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
          final searchPanel = _careerSearchPanel();
          final detailPanel = _careerDetailPanel();
          if (constraints.maxWidth < 1080) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 340, child: searchPanel),
                  const SizedBox(height: 8),
                  SizedBox(height: 920, child: detailPanel),
                ],
              ),
            );
          }
          return Row(
            children: [
              SizedBox(width: 315, child: searchPanel),
              const SizedBox(width: 8),
              Expanded(child: detailPanel),
            ],
          );
        },
      );

  Widget _careerSearchPanel() => _Panel(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SectionLabel('PLAYER SEARCH'),
                const Spacer(),
                if (_compare.isNotEmpty)
                  Text(
                    '${_compare.length}/6 COMPARE',
                    style: const TextStyle(
                      color: _yellow,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 38,
              child: TextField(
                controller: _playerSearch,
                onChanged: _queueSearch,
                style: const TextStyle(color: _text, fontSize: 11),
                decoration: _inputDecoration('Search 1946–present players…'),
              ),
            ),
            const SizedBox(height: 7),
            if (_compare.length >= 2)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openCompare,
                  icon: const Icon(Icons.compare_arrows_rounded, size: 15),
                  label: const Text('Cross-era compare'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _yellow,
                    foregroundColor: _bg,
                    textStyle: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 5),
            Expanded(
              child: _playerResults.isEmpty
                  ? const Center(
                      child: Text(
                        'Search by player name or historical ID.\nCompare up to six players across eras.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _playerResults.length,
                      itemBuilder: (context, index) {
                        final row = _playerResults[index];
                        final key = row['player_key']?.toString() ?? '';
                        return InkWell(
                          onTap: () => _loadPlayer(key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 7,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: _line, width: .5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row['canonical_name']?.toString() ?? '—',
                                        style: const TextStyle(
                                          color: _text,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${row['first_stat_season'] ?? '—'} → ${row['last_stat_season'] ?? '—'} · ${row['seasons'] ?? 0} seasons',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Add to compare',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _toggleCompare(key),
                                  icon: Icon(
                                    _compare.contains(key)
                                        ? Icons.check_box
                                        : Icons.add_box_outlined,
                                    size: 16,
                                    color: _compare.contains(key)
                                        ? _yellow
                                        : _muted,
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
      return const _Panel(
        child: Center(
          child: Text(
            'Select a player to open the historical research file.',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }
    final careerRows = _rows(_career['rows']);
    final eraRows = _rows(_era['rows']);
    final gameRows = _rows(_playerGames['rows']);
    final awards = _rows(player['awards']);
    final allStar = _rows(player['all_star']);
    final draft = _rows(player['draft']);
    final playerKey = player['player_key']?.toString() ?? '';
    return _Panel(
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
                        style: const TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${player['primary_position'] ?? '—'} · ${player['active_from'] ?? '—'} → ${player['active_to'] ?? '—'} · NBA ID ${player['nba_id'] ?? '—'} · BRef ${player['bref_id'] ?? '—'}',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add to compare',
                  onPressed: () => _toggleCompare(playerKey),
                  icon: Icon(
                    _compare.contains(playerKey)
                        ? Icons.library_add_check
                        : Icons.library_add_outlined,
                    color: _yellow,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(9),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _careerTable(careerRows)),
                      const SizedBox(width: 8),
                      SizedBox(width: 300, child: _eraPanel(eraRows)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _honorsPanel(awards, allStar, draft),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _playerGamePanel(gameRows)),
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

  Widget _careerTable(List<Map<String, dynamic>> items) => _SubPanel(
        title: 'CAREER / PLAYOFF SEASON FILE',
        child: SizedBox(
          height: 365,
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No season rows for this segment.',
                    style: TextStyle(color: _muted),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final row = items[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: _line, width: .5),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 62,
                            child: _Cell(
                              row['season_id']?.toString() ?? '—',
                              strong: true,
                            ),
                          ),
                          SizedBox(
                            width: 42,
                            child: _Cell(
                              row['team_abbreviation']?.toString() ?? '—',
                            ),
                          ),
                          SizedBox(
                            width: 35,
                            child: _Cell(
                              _fmt(row['games'], 0),
                              right: true,
                            ),
                          ),
                          Expanded(
                            child: _Cell(
                              '${_perGame(row, 'pts')} PTS',
                              right: true,
                            ),
                          ),
                          Expanded(
                            child: _Cell(
                              '${_perGame(row, 'reb')} REB',
                              right: true,
                            ),
                          ),
                          Expanded(
                            child: _Cell(
                              '${_perGame(row, 'ast')} AST',
                              right: true,
                            ),
                          ),
                          SizedBox(
                            width: 55,
                            child: _Cell(
                              _signed(row['bpm']),
                              right: true,
                              accent: _cyan,
                            ),
                          ),
                          SizedBox(
                            width: 55,
                            child: _Cell(
                              _pct(row['ts_pct']),
                              right: true,
                              accent: _green,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      );

  Widget _eraPanel(List<Map<String, dynamic>> items) => _SubPanel(
        title: 'ERA-RELATIVE SERIES · ${_metrics[_metric]}',
        child: SizedBox(
          height: 365,
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No qualified era series.',
                    style: TextStyle(color: _muted),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final row = items[index];
                    final z = _num(row['z_score']) ?? 0;
                    final value = ((z.clamp(-3, 3) + 3) / 6).toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 58,
                            child: _Cell(row['season']?.toString() ?? '—'),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 7,
                              backgroundColor: _bg,
                              color: z >= 0 ? _green : _cyan,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 42,
                            child: _Cell(
                              _signed(z),
                              right: true,
                              accent: z >= 0 ? _green : _cyan,
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: _Cell(
                              _pct(row['percentile']),
                              right: true,
                            ),
                          ),
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
      _SubPanel(
        title: 'HONORS / DRAFT / ALL-STAR',
        child: SizedBox(
          height: 235,
          child: ListView(
            children: [
              for (final item in draft)
                _eventRow(
                  'DRAFT',
                  '${item['draft_year'] ?? '—'} · R${item['round_text'] ?? '—'} · Pick ${_fmt(item['pick_number'], 0)} · ${item['drafting_team_text'] ?? '—'}',
                  _cyan,
                ),
              for (final item in awards)
                _eventRow(
                  'AWARD',
                  '${item['season_id'] ?? '—'} · ${item['award'] ?? '—'}${item['winner'] == 1 ? ' · WINNER' : ''}',
                  _yellow,
                ),
              for (final item in allStar)
                _eventRow(
                  'ALL-STAR',
                  '${item['season_id'] ?? '—'} · ${item['team_text'] ?? 'Selection'}',
                  _green,
                ),
              if (draft.isEmpty && awards.isEmpty && allStar.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'No honors records in canonical coverage.',
                    style: TextStyle(color: _muted),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _playerGamePanel(List<Map<String, dynamic>> items) => _SubPanel(
        title: 'GAME-LEVEL COVERAGE · LATEST 50',
        child: SizedBox(
          height: 235,
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No canonical player-game rows for this player/era.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final row = items[index];
                    return _simpleRow(
                      '${row['game_date'] ?? '—'} · ${row['team_abbreviation'] ?? '—'} vs ${row['opponent_abbreviation'] ?? '—'}',
                      '${_fmt(row['pts'], 0)} PTS · ${_fmt(row['reb'], 0)} REB · ${_fmt(row['ast'], 0)} AST',
                    );
                  },
                ),
        ),
      );

  Widget _eventRow(String label, String value, Color accent) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: _text, fontSize: 9),
              ),
            ),
          ],
        ),
      );

  Widget _allTimeDesk() {
    final items = _rows(_allTime['rows']);
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: _panel2,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Drop<String>(
                  value: _allTimeMode,
                  values: const ['career', 'peak', 'best_n'],
                  width: 118,
                  label: (value) => switch (value) {
                    'career' => 'Career',
                    'peak' => 'Peak Season',
                    _ => 'Best N Seasons',
                  },
                  onChanged: (value) {
                    setState(() => _allTimeMode = value);
                    _refresh();
                  },
                ),
                _Drop<String>(
                  value: _allTimeBasis,
                  values: _bases.keys.toList(),
                  width: 115,
                  label: (value) => _bases[value] ?? value,
                  onChanged: (value) {
                    setState(() => _allTimeBasis = value);
                    _refresh();
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
                      _refresh();
                    },
                  ),
                _Drop<int>(
                  value: _minSeasons,
                  values: const [1, 2, 3, 5, 7, 10],
                  width: 105,
                  label: (value) => '$value+ seasons',
                  onChanged: (value) {
                    setState(() => _minSeasons = value);
                    _refresh();
                  },
                ),
                Text(
                  '${_allTime['matched_rows'] ?? items.length} QUALIFIED',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'No all-time rows for these filters.',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final row = items[index];
                      return InkWell(
                        onTap: () {
                          setState(() => _desk = 0);
                          _loadPlayer(row['player_key']?.toString() ?? '');
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _line, width: .5),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 42,
                                child: _Cell(
                                  '#${row['rank'] ?? index + 1}',
                                  accent: _yellow,
                                  strong: true,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: _Cell(
                                  row['player_name']?.toString() ?? '—',
                                  strong: true,
                                ),
                              ),
                              Expanded(
                                child: _Cell('${row['seasons'] ?? 0} seasons'),
                              ),
                              Expanded(
                                child: _Cell(
                                  '${_fmt(row['career_games'], 0)} GP',
                                ),
                              ),
                              Expanded(
                                child: _Cell(
                                  '${row['first_season'] ?? '—'} → ${row['last_season'] ?? '—'}',
                                ),
                              ),
                              Expanded(
                                child: _Cell(
                                  'Peak ${row['peak_season'] ?? '—'}',
                                ),
                              ),
                              SizedBox(
                                width: 105,
                                child: _Cell(
                                  _metricValue(
                                    row['metric_value'],
                                    _metric,
                                    _allTimeBasis,
                                  ),
                                  right: true,
                                  accent: _yellow,
                                  strong: true,
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
  }

  Widget _gamesDesk() {
    final items = _rows(_games['rows']);
    final list = _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: const BoxDecoration(
              color: _panel2,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                const _SectionLabel('HISTORICAL GAMES'),
                const Spacer(),
                Text(
                  '${items.length} LOADED',
                  style: const TextStyle(color: _muted, fontSize: 8),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'No games for this season/segment.',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final row = items[index];
                      final key = row['game_key']?.toString() ?? '';
                      final selected = _game?['game_key'] == key;
                      return InkWell(
                        onTap: () => _loadGame(key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          color: selected
                              ? const Color(0x182AC6E8)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 82,
                                child: _Cell(
                                  row['game_date']?.toString() ?? '—',
                                ),
                              ),
                              Expanded(
                                child: _Cell(
                                  '${row['away_team_abbreviation'] ?? '—'} @ ${row['home_team_abbreviation'] ?? '—'}',
                                  strong: true,
                                ),
                              ),
                              SizedBox(
                                width: 95,
                                child: _Cell(
                                  '${_fmt(row['away_score'], 0)} – ${_fmt(row['home_score'], 0)}',
                                  right: true,
                                  accent: _yellow,
                                  strong: true,
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
    final detail = _gameDetail();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1120) {
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 480, child: list),
                const SizedBox(height: 8),
                SizedBox(height: 780, child: detail),
              ],
            ),
          );
        }
        return Row(
          children: [
            SizedBox(width: 400, child: list),
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
      return const _Panel(
        child: Center(
          child: Text(
            'Select a game to inspect canonical box rows and play-by-play.',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }
    final teams = _rows(game['teams']);
    final players = _rows(game['players']);
    final events = _rows(_playByPlay['rows']);
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: _panel2,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Text(
                  game['game_date']?.toString() ?? '—',
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_fmt(game['away_score'], 0)} – ${_fmt(game['home_score'], 0)} · ${game['season_id'] ?? '—'} · ${game['season_type'] ?? '—'}',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _Pill('${_playByPlay['matched_rows'] ?? 0} PBP', _cyan),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _SubPanel(
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
                        _SubPanel(
                          title: 'PLAYER GAME FACTS',
                          child: SizedBox(
                            height: 350,
                            child: players.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No player-game materialization for this source/era.',
                                      style: TextStyle(color: _muted),
                                    ),
                                  )
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: _SectionLabel('PLAY-BY-PLAY'),
                      ),
                      Expanded(
                        child: events.isEmpty
                            ? const Center(
                                child: Text(
                                  'No canonical PBP for this game.',
                                  style: TextStyle(color: _muted),
                                ),
                              )
                            : ListView.builder(
                                itemCount: events.length,
                                itemBuilder: (context, index) {
                                  final row = events[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: _line,
                                          width: .4,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: _Cell('Q${row['period'] ?? '—'}'),
                                        ),
                                        SizedBox(
                                          width: 48,
                                          child: _Cell(
                                            row['clock']?.toString() ?? '—',
                                          ),
                                        ),
                                        Expanded(
                                          child: _Cell(
                                            row['description']?.toString() ?? '—',
                                          ),
                                        ),
                                        SizedBox(
                                          width: 56,
                                          child: _Cell(
                                            row['score']?.toString() ?? '',
                                            right: true,
                                            accent: _yellow,
                                          ),
                                        ),
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

  Widget _franchiseDesk() {
    final list = _Panel(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: TextField(
              controller: _franchiseSearch,
              onSubmitted: (_) => _refresh(),
              style: const TextStyle(color: _text, fontSize: 11),
              decoration: _inputDecoration('Search franchise lineage…'),
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: ListView.builder(
              itemCount: _franchises.length,
              itemBuilder: (context, index) {
                final row = _franchises[index];
                return InkWell(
                  onTap: () => _loadFranchise(
                    row['franchise_key']?.toString() ?? '',
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: _line, width: .5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['canonical_name']?.toString() ?? '—',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${row['abbreviations'] ?? '—'} · ${row['first_season'] ?? '—'} → ${row['last_season'] ?? '—'} · ${row['seasons'] ?? 0} seasons',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 8,
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
    final detail = _franchiseDetail();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 400, child: list),
                const SizedBox(height: 8),
                SizedBox(height: 680, child: detail),
              ],
            ),
          );
        }
        return Row(
          children: [
            SizedBox(width: 325, child: list),
            const SizedBox(width: 8),
            Expanded(child: detail),
          ],
        );
      },
    );
  }

  Widget _franchiseDetail() {
    final payload = _franchise;
    if (payload == null) {
      return const _Panel(
        child: Center(
          child: Text(
            'Select a franchise to inspect lineage and team-season history.',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }
    final franchise = payload['franchise'];
    final teams = _rows(payload['teams']);
    final seasons = _rows(payload['seasons']);
    final name = franchise is Map
        ? franchise['canonical_name']?.toString() ?? 'Franchise'
        : 'Franchise';
    return _Panel(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final team in teams)
                _Pill(
                  '${team['abbreviation'] ?? '—'} · ${team['canonical_name'] ?? '—'}',
                  _cyan,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const _SectionLabel('TEAM-SEASON HISTORY'),
          const SizedBox(height: 5),
          Expanded(
            child: seasons.isEmpty
                ? const Center(
                    child: Text(
                      'No canonical team-season rows.',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: seasons.length,
                    itemBuilder: (context, index) {
                      final row = seasons[index];
                      return Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: _line, width: .5),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 65,
                              child: _Cell(
                                row['season_id']?.toString() ?? '—',
                                strong: true,
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: _Cell(
                                row['team_abbreviation']?.toString() ?? '—',
                              ),
                            ),
                            Expanded(
                              child: _Cell(
                                row['team_identity_name']?.toString() ??
                                    row['team_name']?.toString() ??
                                    '—',
                              ),
                            ),
                            SizedBox(
                              width: 78,
                              child: _Cell(
                                '${_fmt(row['wins'], 0)}–${_fmt(row['losses'], 0)}',
                                right: true,
                              ),
                            ),
                            SizedBox(
                              width: 68,
                              child: _Cell(
                                '${_fmt(row['srs'], 1)} SRS',
                                right: true,
                                accent: _yellow,
                              ),
                            ),
                            SizedBox(
                              width: 78,
                              child: _Cell(
                                '${_fmt(row['ortg'], 1)} ORtg',
                                right: true,
                              ),
                            ),
                            SizedBox(
                              width: 78,
                              child: _Cell(
                                '${_fmt(row['drtg'], 1)} DRtg',
                                right: true,
                              ),
                            ),
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
    final sources = _rows(_summary['sources']);
    final coverage = _rows(_summary['coverage']);
    final conflicts = _rows(_summary['top_conflict_fields']);
    final counts = _summary['counts'];
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  'FIELD PROVENANCE',
                  counts is Map ? counts['field_provenance'] : null,
                  _cyan,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MetricTile(
                  'MATERIAL CONFLICTS',
                  counts is Map ? counts['material_conflicts'] : null,
                  _yellow,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MetricTile(
                  'CANONICAL PLAYERS',
                  counts is Map ? counts['players'] : null,
                  _green,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MetricTile(
                  'CANONICAL GAMES',
                  counts is Map ? counts['games'] : null,
                  _cyan,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MetricTile(
                  'PLAYER-GAME ROWS',
                  counts is Map ? counts['player_games'] : null,
                  _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SubPanel(
                  title: 'SOURCE REGISTRY / RIGHTS',
                  child: Column(
                    children: [
                      for (final row in sources)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row['label']?.toString() ??
                                    row['source_key']?.toString() ??
                                    'Source',
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_compact(row['row_count'])} rows · ${row['table_count'] ?? 0} tables · ${row['coverage'] ?? 'source-native'}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                row['license']?.toString() ??
                                    'License not recorded',
                                style: const TextStyle(
                                  color: _yellow,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SubPanel(
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
                child: _SubPanel(
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
                          child: Text(
                            'No material conflicts in this canonical build.',
                            style: TextStyle(color: _green),
                          ),
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
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line, width: .5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _text,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(color: _muted, fontSize: 8),
              ),
            ),
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
    if (metric.endsWith('_pct') ||
        {'ts_pct', 'efg_pct', 'usg_pct'}.contains(metric)) {
      return _pct(value);
    }
    return _fmt(value, basis == 'totals' ? 0 : 2);
  }
}

class _CompareDialog extends StatelessWidget {
  const _CompareDialog({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final players = _rows(payload['players']);
    return AlertDialog(
      backgroundColor: _panel,
      title: Text(
        'Cross-era compare · ${payload['metric'] ?? 'metric'} · ${payload['basis'] ?? 'basis'}',
        style: const TextStyle(color: _text),
      ),
      content: SizedBox(
        width: 1040,
        height: 610,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = players[index];
            final identity = item['identity'] is Map
                ? item['identity'] as Map
                : const <String, dynamic>{};
            final peak = item['peak_season'] is Map
                ? item['peak_season'] as Map
                : const <String, dynamic>{};
            final era = item['peak_era'] is Map
                ? item['peak_era'] as Map
                : const <String, dynamic>{};
            final seasons = _rows(item['season_rows']);
            return Container(
              width: 245,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity['canonical_name']?.toString() ?? 'Player',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${identity['active_from'] ?? '—'} → ${identity['active_to'] ?? '—'}',
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                  const SizedBox(height: 10),
                  _DialogMetric(
                    label: 'CAREER',
                    value: _fmt(item['career_metric_value'], 2),
                    color: _yellow,
                  ),
                  _DialogMetric(
                    label: 'PEAK SEASON',
                    value: peak['season_id']?.toString() ?? '—',
                    color: _cyan,
                  ),
                  _DialogMetric(
                    label: 'PEAK Z',
                    value: _signed(era['z_score']),
                    color: _green,
                  ),
                  _DialogMetric(
                    label: 'PEAK PCTL',
                    value: _pct(era['percentile']),
                    color: _green,
                  ),
                  const SizedBox(height: 10),
                  const _SectionLabel('SEASON SERIES'),
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
                              SizedBox(
                                width: 58,
                                child: _Cell(
                                  row['season_id']?.toString() ?? '—',
                                ),
                              ),
                              const Spacer(),
                              _Cell(
                                '${_fmt(row['games'], 0)} GP',
                                right: true,
                              ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DialogMetric extends StatelessWidget {
  const _DialogMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _panel2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: _muted, fontSize: 8),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(10)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _line),
        ),
        child: child,
      );
}

class _SubPanel extends StatelessWidget {
  const _SubPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _panel2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(title),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );
}

class _DeskButton extends StatelessWidget {
  const _DeskButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

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
              Icon(
                icon,
                size: 14,
                color: selected ? _yellow : _muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _yellow : _text,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

class _Drop<T> extends StatelessWidget {
  const _Drop({
    required this.value,
    required this.values,
    required this.width,
    required this.label,
    required this.onChanged,
  });

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
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _line),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: values.contains(value)
                ? value
                : (values.isEmpty ? null : values.first),
            isExpanded: true,
            dropdownColor: _panel2,
            iconEnabledColor: _muted,
            style: const TextStyle(
              color: _text,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
            items: [
              for (final item in values)
                DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    label(item),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Text(
        value,
        style: const TextStyle(
          color: _yellow,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.value, {
    this.right = false,
    this.strong = false,
    this.accent,
  });

  final String value;
  final bool right;
  final bool strong;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Text(
        value,
        overflow: TextOverflow.ellipsis,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: accent ?? _muted,
          fontSize: 9,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 7,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.label, this.value, this.color);

  final String label;
  final Object? value;
  final Color color;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 7,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _compact(value),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 9),
      prefixIcon: const Icon(Icons.search, size: 16, color: _muted),
      filled: true,
      fillColor: _bg,
      contentPadding: EdgeInsets.zero,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _yellow),
      ),
    );

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
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
  if (number.abs() >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(number.abs() >= 10000000 ? 1 : 2)}M';
  }
  if (number.abs() >= 1000) {
    return '${(number / 1000).toStringAsFixed(number.abs() >= 100000 ? 0 : 1)}K';
  }
  return number.toStringAsFixed(0);
}
