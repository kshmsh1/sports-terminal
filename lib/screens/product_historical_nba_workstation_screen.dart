import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/historical_nba_repository.dart';

const _historyBg = Color(0xFF151C29);
const _historyPanel = Color(0xFF1D2636);
const _historyPanel2 = Color(0xFF232D3F);
const _historyLine = Color(0xFF354155);
const _historyText = Color(0xFFF3F6FB);
const _historyMuted = Color(0xFF9DA8BA);
const _historyYellow = Color(0xFFFFCB45);
const _historyCyan = Color(0xFF65D5FF);
const _historyGreen = Color(0xFF63E6A6);
const _historyRed = Color(0xFFFF7B7B);

class ProductHistoricalNbaWorkstationScreen extends StatefulWidget {
  const ProductHistoricalNbaWorkstationScreen({super.key});

  @override
  State<ProductHistoricalNbaWorkstationScreen> createState() =>
      _ProductHistoricalNbaWorkstationScreenState();
}

class _ProductHistoricalNbaWorkstationScreenState
    extends State<ProductHistoricalNbaWorkstationScreen> {
  final HistoricalNbaRepository _repository = const HistoricalNbaRepository();
  final TextEditingController _search = TextEditingController();
  final Set<String> _compare = {};

  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _seasons = const [];
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _coverage = const [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _career;
  Map<String, dynamic>? _era;
  String _league = 'NBA';
  String _season = '';
  String _seasonType = 'regular';
  String _basis = 'per_game';
  String _metric = 'pts';
  double _minGames = 1;
  bool _loading = true;
  bool _loadingRows = false;
  String _error = '';
  int _requestGeneration = 0;

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
    'per_game': 'Per Game',
    'per36': 'Per 36',
    'per48': 'Per 48',
    'per75': 'Per 75 Poss',
    'per100': 'Per 100 Poss',
    'totals': 'Totals',
  };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final status = await _repository.status();
      if (status['canonical_ready'] != true) {
        throw HistoricalNbaException(
          status['canonical'] == null
              ? 'Historical sources are installed, but the canonical historical build has not been generated yet.'
              : 'Canonical historical NBA data is not ready.',
        );
      }
      final seasons = await _repository.seasons(league: _league);
      if (seasons.isEmpty) {
        throw const HistoricalNbaException(
          'No canonical player-season coverage is available for this league.',
        );
      }
      final selected = seasons.last['season_id']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _status = status;
        _seasons = seasons;
        _season = selected;
        _loading = false;
      });
      await _loadRows();
    } on HistoricalNbaException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _changeLeague(String league) async {
    if (_league == league) return;
    setState(() {
      _league = league;
      _season = '';
      _rows = const [];
      _selected = null;
      _career = null;
      _era = null;
      _compare.clear();
      _loadingRows = true;
    });
    try {
      final seasons = await _repository.seasons(league: league);
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        _season = seasons.isEmpty
            ? ''
            : seasons.last['season_id']?.toString() ?? '';
      });
      await _loadRows();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRows = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadRows() async {
    if (_season.isEmpty) return;
    final generation = ++_requestGeneration;
    setState(() {
      _loadingRows = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        _repository.leaderboard(
          season: _season,
          metric: _metric,
          basis: _basis,
          league: _league,
          seasonType: _seasonType,
          minGames: _minGames,
        ),
        _repository.coverage(season: _season, league: _league),
      ]);
      if (!mounted || generation != _requestGeneration) return;
      final payload = results[0];
      final rows = payload['rows'];
      final coverage = results[1]['rows'];
      setState(() {
        _rows = rows is List
            ? [
                for (final item in rows)
                  if (item is Map)
                    item.map((key, value) => MapEntry(key.toString(), value)),
              ]
            : const [];
        _coverage = coverage is List
            ? [
                for (final item in coverage)
                  if (item is Map)
                    item.map((key, value) => MapEntry(key.toString(), value)),
              ]
            : const [];
        _loadingRows = false;
        if (_selected != null &&
            !_rows.any((row) => row['player_key'] == _selected!['player_key'])) {
          _selected = null;
          _career = null;
          _era = null;
        }
      });
    } on HistoricalNbaException catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loadingRows = false;
        _error = error.message;
      });
    }
  }

  Future<void> _selectPlayer(Map<String, dynamic> row) async {
    final playerKey = row['player_key']?.toString() ?? '';
    if (playerKey.isEmpty) return;
    setState(() {
      _selected = row;
      _career = null;
      _era = null;
    });
    try {
      final results = await Future.wait([
        _repository.career(
          playerKey,
          league: _league,
          seasonType: _seasonType,
        ),
        _repository.eraAdjusted(
          playerKey,
          metric: _metric,
          basis: _basis,
          league: _league,
          seasonType: _seasonType,
          minGames: _minGames,
        ),
      ]);
      if (!mounted || _selected?['player_key'] != playerKey) return;
      setState(() {
        _career = results[0];
        _era = results[1];
      });
    } catch (_) {
      // The selected season row remains useful even if an optional inspector query fails.
    }
  }

  void _toggleCompare(Map<String, dynamic> row) {
    final key = row['player_key']?.toString() ?? '';
    if (key.isEmpty) return;
    setState(() {
      if (!_compare.add(key)) _compare.remove(key);
      while (_compare.length > 6) {
        _compare.remove(_compare.first);
      }
    });
  }

  Future<void> _openCompare() async {
    final rows = _rows
        .where((row) => _compare.contains(row['player_key']?.toString()))
        .toList();
    if (rows.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least two historical players.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _HistoricalCompareDialog(
        rows: rows,
        season: _season,
        basis: _bases[_basis] ?? _basis,
      ),
    );
  }

  Future<void> _openProvenance() async {
    final selected = _selected;
    if (selected == null) return;
    final factKey = selected['fact_key']?.toString() ?? '';
    if (factKey.isEmpty) return;
    try {
      final results = await Future.wait([
        _repository.provenance('player_season', factKey),
        _repository.conflicts(entityType: 'player_season', entityKey: factKey),
      ]);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _ProvenanceDialog(
          player: selected['player_name']?.toString() ?? 'Player',
          season: _season,
          provenance: results[0],
          conflicts: results[1],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Provenance unavailable: $error')),
      );
    }
  }

  List<Map<String, dynamic>> get _visibleRows {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _rows;
    return _rows.where((row) {
      final text = '${row['player_name']} ${row['team_abbreviation']} ${row['team_name']}'
          .toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: _historyBg,
        child: Center(
          child: CircularProgressIndicator(color: _historyYellow),
        ),
      );
    }
    if (_error.isNotEmpty && _status == null) {
      return ColoredBox(
        color: _historyBg,
        child: Center(
          child: _HistoryPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_rounded, color: _historyRed, size: 36),
                const SizedBox(height: 12),
                const Text(
                  'Historical NBA warehouse unavailable',
                  style: TextStyle(
                    color: _historyText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _historyMuted),
                ),
                const SizedBox(height: 14),
                FilledButton(onPressed: _bootstrap, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final visible = _visibleRows;
    return ColoredBox(
      color: _historyBg,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 8),
            _controls(),
            const SizedBox(height: 8),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error, style: const TextStyle(color: _historyRed)),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1150;
                  if (!wide) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 620, child: _table(visible)),
                          const SizedBox(height: 8),
                          _inspector(),
                        ],
                      ),
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _table(visible)),
                      const SizedBox(width: 8),
                      SizedBox(width: 330, child: _inspector()),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _footer(visible.length),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final raw = _status?['raw'];
    final canonical = _status?['canonical'];
    final rawRows = raw is Map ? raw['rows'] : null;
    final counts = canonical is Map ? canonical['canonical_counts'] : null;
    final players = counts is Map ? counts['players'] : null;
    return _HistoryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.timeline_rounded, color: _historyYellow, size: 20),
          const SizedBox(width: 8),
          const Text(
            'HISTORICAL NBA WORKSTATION',
            style: TextStyle(
              color: _historyYellow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'BAA · NBA · ABA',
            style: TextStyle(color: _historyMuted, fontSize: 10),
          ),
          const Spacer(),
          if (rawRows != null)
            _Pill('${_compactInt(rawRows)} RAW ROWS', _historyCyan),
          const SizedBox(width: 6),
          if (players != null)
            _Pill('${_compactInt(players)} PLAYERS', _historyGreen),
          const SizedBox(width: 6),
          const _Pill('FIELD PROVENANCE', _historyYellow),
        ],
      ),
    );
  }

  Widget _controls() => _HistoryPanel(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Drop<String>(
              value: _league,
              values: const ['NBA', 'ABA', 'BAA'],
              width: 85,
              label: (value) => value,
              onChanged: _changeLeague,
            ),
            _Drop<String>(
              value: _season,
              values: [
                for (final season in _seasons)
                  season['season_id']?.toString() ?? '',
              ].where((value) => value.isNotEmpty).toList(),
              width: 120,
              label: (value) => value,
              onChanged: (value) {
                setState(() {
                  _season = value;
                  _selected = null;
                  _compare.clear();
                });
                _loadRows();
              },
            ),
            _Drop<String>(
              value: _seasonType,
              values: const ['regular', 'playoffs', 'combined'],
              width: 112,
              label: (value) => switch (value) {
                'regular' => 'Regular',
                'playoffs' => 'Playoffs',
                _ => 'Combined',
              },
              onChanged: (value) {
                setState(() => _seasonType = value);
                _loadRows();
              },
            ),
            _Drop<String>(
              value: _basis,
              values: _bases.keys.toList(),
              width: 130,
              label: (value) => _bases[value] ?? value,
              onChanged: (value) {
                setState(() => _basis = value);
                _loadRows();
              },
            ),
            _Drop<String>(
              value: _metric,
              values: _metrics.keys.toList(),
              width: 105,
              label: (value) => _metrics[value] ?? value,
              onChanged: (value) {
                setState(() => _metric = value);
                _loadRows();
                if (_selected != null) _selectPlayer(_selected!);
              },
            ),
            SizedBox(
              width: 190,
              height: 38,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: _historyText, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search season players…',
                  hintStyle: const TextStyle(color: _historyMuted),
                  prefixIcon: const Icon(Icons.search, size: 17, color: _historyMuted),
                  filled: true,
                  fillColor: _historyBg,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _MiniButton(
              icon: Icons.compare_arrows_rounded,
              label: 'Compare ${_compare.length}',
              onTap: _openCompare,
              active: _compare.length >= 2,
            ),
            _MiniButton(
              icon: Icons.source_outlined,
              label: 'Provenance',
              onTap: _selected == null ? null : _openProvenance,
            ),
            _MiniButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              onTap: _loadRows,
            ),
          ],
        ),
      );

  Widget _table(List<Map<String, dynamic>> rows) {
    if (_loadingRows) {
      return const _HistoryPanel(
        child: Center(
          child: CircularProgressIndicator(color: _historyYellow),
        ),
      );
    }
    if (rows.isEmpty) {
      return const _HistoryPanel(
        child: Center(
          child: Text(
            'No canonical player-season rows match these historical filters.',
            style: TextStyle(color: _historyMuted),
          ),
        ),
      );
    }
    return _HistoryPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: _historyPanel2,
              border: Border(bottom: BorderSide(color: _historyLine)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 36),
                Expanded(flex: 4, child: _HeaderText('PLAYER')),
                Expanded(flex: 2, child: _HeaderText('TEAM')),
                Expanded(child: _HeaderText('GP')),
                Expanded(child: _HeaderText('MIN')),
                Expanded(child: _HeaderText('PTS')),
                Expanded(child: _HeaderText('REB')),
                Expanded(child: _HeaderText('AST')),
                Expanded(child: _HeaderText('BPM')),
                Expanded(flex: 2, child: _HeaderText('ACTIVE METRIC')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final key = row['player_key']?.toString() ?? '';
                final selected = _selected?['player_key'] == key;
                final comparing = _compare.contains(key);
                return InkWell(
                  onTap: () => _selectPlayer(row),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2B3549) : _historyPanel,
                      border: const Border(
                        bottom: BorderSide(color: _historyLine, width: .5),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Checkbox(
                            value: comparing,
                            onChanged: (_) => _toggleCompare(row),
                            activeColor: _historyYellow,
                            checkColor: _historyBg,
                            side: const BorderSide(color: _historyMuted),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            row['player_name']?.toString() ?? '—',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _historyText,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            row['team_abbreviation']?.toString() ?? '—',
                            style: const TextStyle(color: _historyMuted, fontSize: 11),
                          ),
                        ),
                        Expanded(child: _StatText(_format(row['games'], 0))),
                        Expanded(child: _StatText(_perGame(row, 'minutes'))),
                        Expanded(child: _StatText(_perGame(row, 'pts'))),
                        Expanded(child: _StatText(_perGame(row, 'reb'))),
                        Expanded(child: _StatText(_perGame(row, 'ast'))),
                        Expanded(child: _StatText(_format(row['bpm'], 1))),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '#${row['rank'] ?? index + 1}',
                                style: const TextStyle(color: _historyMuted, fontSize: 9),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatMetric(row['metric_value']),
                                style: const TextStyle(
                                  color: _historyYellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
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

  Widget _inspector() {
    final row = _selected;
    if (row == null) {
      return const _HistoryPanel(
        child: Center(
          child: Text(
            'Select a player to inspect career history, era-relative performance, identities, and source evidence.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _historyMuted, height: 1.4),
          ),
        ),
      );
    }
    final careerRows = _career?['rows'];
    final eraRows = _era?['rows'];
    final career = careerRows is List ? careerRows : const [];
    final era = eraRows is List ? eraRows : const [];
    final eraCurrent = era.cast<Object?>().whereType<Map>().firstWhere(
          (item) => item['season']?.toString() == _season,
          orElse: () => const {},
        );
    return _HistoryPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: const BoxDecoration(
              color: _historyPanel2,
              border: Border(bottom: BorderSide(color: _historyLine)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['player_name']?.toString() ?? 'Player',
                  style: const TextStyle(
                    color: _historyText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${row['team_abbreviation'] ?? '—'} · $_season · $_league · ${_bases[_basis]}',
                  style: const TextStyle(color: _historyMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (eraCurrent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: _InspectorTile(
                      label: 'ERA Z-SCORE',
                      value: _signed(eraCurrent['z_score']),
                      accent: _historyCyan,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _InspectorTile(
                      label: 'PERCENTILE',
                      value: _percent(eraCurrent['percentile']),
                      accent: _historyGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _InspectorTile(
                      label: 'PEERS',
                      value: eraCurrent['peer_count']?.toString() ?? '—',
                      accent: _historyYellow,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('SELECTED SEASON'),
                  _keyValue('Active metric', _formatMetric(row['metric_value'])),
                  _keyValue('Games', _format(row['games'], 0)),
                  _keyValue('Minutes/game', _perGame(row, 'minutes')),
                  _keyValue('Points/game', _perGame(row, 'pts')),
                  _keyValue('Rebounds/game', _perGame(row, 'reb')),
                  _keyValue('Assists/game', _perGame(row, 'ast')),
                  _keyValue('TS%', _percent(row['ts_pct'])),
                  _keyValue('BPM', _signed(row['bpm'])),
                  _keyValue('Primary source', row['primary_source']?.toString() ?? '—'),
                  _keyValue('Sources', row['source_count']?.toString() ?? '—'),
                  const SizedBox(height: 8),
                  const _SectionLabel('CAREER'),
                  if (career.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Loading career…', style: TextStyle(color: _historyMuted)),
                    )
                  else
                    for (final item in career.reversed.take(12))
                      _careerRow(item is Map ? item : const {}),
                  if (career.length > 12)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '+ ${career.length - 12} earlier team-season rows',
                        style: const TextStyle(color: _historyMuted, fontSize: 9),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const _SectionLabel('ERA-ADJUSTED TREND'),
                  if (era.isEmpty)
                    const Text('Loading era-relative series…', style: TextStyle(color: _historyMuted, fontSize: 10))
                  else
                    _EraBars(rows: era, selectedSeason: _season),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(int visibleCount) {
    final rowCount = _coverage.fold<int>(
      0,
      (sum, row) => sum + ((row['row_count'] as num?)?.toInt() ?? 0),
    );
    final sources = <String>{};
    for (final row in _coverage) {
      final values = row['sources'];
      if (values is List) sources.addAll(values.map((value) => value.toString()));
    }
    return _HistoryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          const SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(color: _historyGreen, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$visibleCount PLAYERS · ${_compactInt(rowCount)} CANONICAL ROWS IN $_season COVERAGE',
            style: const TextStyle(
              color: _historyMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            sources.isEmpty ? 'CANONICAL SOURCE POLICY ACTIVE' : sources.join(' · ').toUpperCase(),
            style: const TextStyle(color: _historyYellow, fontSize: 8, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _keyValue(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _historyBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _historyLine),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: _historyMuted, fontSize: 9))),
            Text(value, style: const TextStyle(color: _historyText, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _careerRow(Map item) {
    final games = _number(item['games']);
    final pts = _number(item['pts']);
    final ppg = games != null && games > 0 && pts != null ? pts / games : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: item['season_id']?.toString() == _season
            ? const Color(0x2220C7E8)
            : _historyBg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(item['season_id']?.toString() ?? '—', style: const TextStyle(color: _historyText, fontSize: 9)),
          ),
          SizedBox(
            width: 42,
            child: Text(item['team_abbreviation']?.toString() ?? '—', style: const TextStyle(color: _historyMuted, fontSize: 9)),
          ),
          const Spacer(),
          Text('${ppg?.toStringAsFixed(1) ?? '—'} PPG', style: const TextStyle(color: _historyYellow, fontSize: 9, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _perGame(Map<String, dynamic> row, String key) {
    final games = _number(row['games']);
    final value = _number(row[key]);
    if (games == null || games <= 0 || value == null) return '—';
    return (value / games).toStringAsFixed(1);
  }

  String _formatMetric(Object? value) {
    if (_metric.endsWith('_pct') || _metric == 'ts_pct' || _metric == 'efg_pct' || _metric == 'usg_pct') {
      return _percent(value);
    }
    return _format(value, _basis == 'totals' ? 0 : 1);
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _historyPanel,
          border: Border.all(color: _historyLine),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
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
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: _historyBg, borderRadius: BorderRadius.circular(7), border: Border.all(color: _historyLine)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: values.contains(value) ? value : (values.isEmpty ? null : values.first),
            isExpanded: true,
            dropdownColor: _historyPanel2,
            iconEnabledColor: _historyMuted,
            style: const TextStyle(color: _historyText, fontSize: 10, fontWeight: FontWeight.w700),
            items: [for (final item in values) DropdownMenuItem<T>(value: item, child: Text(label(item), overflow: TextOverflow.ellipsis))],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: active ? _historyYellow : _historyText,
          side: BorderSide(color: active ? _historyYellow : _historyLine),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
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
        decoration: BoxDecoration(color: color.withValues(alpha: .08), border: Border.all(color: color.withValues(alpha: .5)), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      );
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(value, textAlign: TextAlign.right, style: const TextStyle(color: _historyMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .5));
}

class _StatText extends StatelessWidget {
  const _StatText(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(value, textAlign: TextAlign.right, style: const TextStyle(color: _historyText, fontSize: 10, fontWeight: FontWeight.w700));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 5),
        child: Text(label, style: const TextStyle(color: _historyYellow, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
      );
}

class _InspectorTile extends StatelessWidget {
  const _InspectorTile({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        decoration: BoxDecoration(color: _historyBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _historyLine)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _historyMuted, fontSize: 7, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _EraBars extends StatelessWidget {
  const _EraBars({required this.rows, required this.selectedSeason});
  final List rows;
  final String selectedSeason;

  @override
  Widget build(BuildContext context) {
    final visible = rows.cast<Object?>().whereType<Map>().toList();
    return Column(
      children: [
        for (final row in visible.reversed.take(14).toList().reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(width: 58, child: Text(row['season']?.toString() ?? '—', style: TextStyle(color: row['season']?.toString() == selectedSeason ? _historyYellow : _historyMuted, fontSize: 8))),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final z = _number(row['z_score']) ?? 0;
                      final normalized = ((z.clamp(-3.0, 3.0) + 3) / 6).toDouble();
                      return Stack(
                        children: [
                          Container(height: 8, decoration: BoxDecoration(color: _historyBg, borderRadius: BorderRadius.circular(4))),
                          Container(width: constraints.maxWidth * normalized, height: 8, decoration: BoxDecoration(color: z >= 0 ? _historyGreen : _historyCyan, borderRadius: BorderRadius.circular(4))),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(width: 40, child: Text(_signed(row['z_score']), textAlign: TextAlign.right, style: const TextStyle(color: _historyText, fontSize: 8))),
              ],
            ),
          ),
      ],
    );
  }
}

class _HistoricalCompareDialog extends StatelessWidget {
  const _HistoricalCompareDialog({required this.rows, required this.season, required this.basis});
  final List<Map<String, dynamic>> rows;
  final String season;
  final String basis;

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: _historyPanel,
        title: Text('Historical comparison · $season · $basis', style: const TextStyle(color: _historyText)),
        content: SizedBox(
          width: 900,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(color: _historyYellow, fontWeight: FontWeight.w900),
              dataTextStyle: const TextStyle(color: _historyText, fontSize: 11),
              columns: const [
                DataColumn(label: Text('Player')),
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('GP')),
                DataColumn(label: Text('PPG')),
                DataColumn(label: Text('RPG')),
                DataColumn(label: Text('APG')),
                DataColumn(label: Text('TS%')),
                DataColumn(label: Text('BPM')),
                DataColumn(label: Text('Source')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(cells: [
                    DataCell(Text(row['player_name']?.toString() ?? '—')),
                    DataCell(Text(row['team_abbreviation']?.toString() ?? '—')),
                    DataCell(Text(_format(row['games'], 0))),
                    DataCell(Text(_perGameStatic(row, 'pts'))),
                    DataCell(Text(_perGameStatic(row, 'reb'))),
                    DataCell(Text(_perGameStatic(row, 'ast'))),
                    DataCell(Text(_percent(row['ts_pct']))),
                    DataCell(Text(_signed(row['bpm']))),
                    DataCell(Text(row['primary_source']?.toString() ?? '—')),
                  ]),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      );
}

class _ProvenanceDialog extends StatelessWidget {
  const _ProvenanceDialog({required this.player, required this.season, required this.provenance, required this.conflicts});
  final String player;
  final String season;
  final Map<String, dynamic> provenance;
  final Map<String, dynamic> conflicts;

  @override
  Widget build(BuildContext context) {
    final evidence = provenance['evidence'] is List ? provenance['evidence'] as List : const [];
    final conflictRows = conflicts['rows'] is List ? conflicts['rows'] as List : const [];
    return AlertDialog(
      backgroundColor: _historyPanel,
      title: Text('$player · $season · source evidence', style: const TextStyle(color: _historyText)),
      content: SizedBox(
        width: 820,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${evidence.length} selected field evidence records · ${conflictRows.length} material source conflicts', style: const TextStyle(color: _historyMuted)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  const _SectionLabel('SELECTED FIELD PROVENANCE'),
                  for (final item in evidence.whereType<Map>())
                    _dialogRow('${item['field_name']}', '${item['source_key']} · ${item['source_value'] ?? '—'}'),
                  const _SectionLabel('MATERIAL SOURCE CONFLICTS'),
                  if (conflictRows.isEmpty)
                    const Padding(padding: EdgeInsets.all(8), child: Text('No material conflicts recorded for this fact.', style: TextStyle(color: _historyGreen)))
                  else
                    for (final item in conflictRows.whereType<Map>())
                      _dialogRow('${item['field_name']}', '${item['selected_source']}: ${item['selected_value']}  ←  ${item['alternate_source']}: ${item['alternate_value']}'),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }

  Widget _dialogRow(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _historyBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: _historyLine)),
        child: Row(children: [SizedBox(width: 150, child: Text(label, style: const TextStyle(color: _historyYellow, fontSize: 9, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: _historyText, fontSize: 9)))]),
      );
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _format(Object? value, int decimals) {
  final resolved = _number(value);
  return resolved == null ? '—' : resolved.toStringAsFixed(decimals);
}

String _signed(Object? value) {
  final resolved = _number(value);
  if (resolved == null) return '—';
  return '${resolved >= 0 ? '+' : ''}${resolved.toStringAsFixed(2)}';
}

String _percent(Object? value) {
  final resolved = _number(value);
  if (resolved == null) return '—';
  final percentage = resolved.abs() <= 1.5 ? resolved * 100 : resolved;
  return '${percentage.toStringAsFixed(1)}%';
}

String _perGameStatic(Map<String, dynamic> row, String key) {
  final games = _number(row['games']);
  final value = _number(row[key]);
  if (games == null || games <= 0 || value == null) return '—';
  return (value / games).toStringAsFixed(1);
}

String _compactInt(Object? value) {
  final number = _number(value);
  if (number == null) return '—';
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(number >= 10000000 ? 1 : 2)}M';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(number >= 100000 ? 0 : 1)}K';
  return number.round().toString();
}
