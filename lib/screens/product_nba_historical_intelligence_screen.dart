import 'package:flutter/material.dart';

import '../services/historical_nba_repository.dart';
import '../services/historical_nba_research_repository.dart';
import '../services/nba_research_context_store.dart';

const _hiBg = Color(0xFF09111C);
const _hiPanel = Color(0xFF121D2B);
const _hiPanel2 = Color(0xFF192638);
const _hiLine = Color(0xFF314158);
const _hiText = Color(0xFFF3F7FC);
const _hiMuted = Color(0xFF9AA8BA);
const _hiBlue = Color(0xFF65B5FF);
const _hiGold = Color(0xFFFFCB45);
const _hiGreen = Color(0xFF65E3A5);
const _hiOrange = Color(0xFFFF9A5A);
const _hiRed = Color(0xFFFF7B7B);

enum _HistoricalIntelTab { records, compare, franchises, games }

extension on _HistoricalIntelTab {
  String get label => switch (this) {
        _HistoricalIntelTab.records => 'All-Time Records',
        _HistoricalIntelTab.compare => 'Cross-Era Compare',
        _HistoricalIntelTab.franchises => 'Franchise Lineage',
        _HistoricalIntelTab.games => 'Games & PBP',
      };

  IconData get icon => switch (this) {
        _HistoricalIntelTab.records => Icons.emoji_events_rounded,
        _HistoricalIntelTab.compare => Icons.compare_arrows_rounded,
        _HistoricalIntelTab.franchises => Icons.account_tree_rounded,
        _HistoricalIntelTab.games => Icons.sports_basketball_rounded,
      };
}

class ProductNbaHistoricalIntelligenceScreen extends StatefulWidget {
  const ProductNbaHistoricalIntelligenceScreen({
    super.key,
    this.onOpenStats,
    this.onOpenAnalytics,
  });

  final VoidCallback? onOpenStats;
  final VoidCallback? onOpenAnalytics;

  @override
  State<ProductNbaHistoricalIntelligenceScreen> createState() =>
      _ProductNbaHistoricalIntelligenceScreenState();
}

class _ProductNbaHistoricalIntelligenceScreenState
    extends State<ProductNbaHistoricalIntelligenceScreen> {
  final HistoricalNbaRepository _history = const HistoricalNbaRepository();
  final HistoricalNbaResearchRepository _research =
      const HistoricalNbaResearchRepository();
  final NbaResearchContextStore _contexts = const NbaResearchContextStore();

  _HistoricalIntelTab _tab = _HistoricalIntelTab.records;
  late Future<NbaResearchContext> _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _contexts.load();
  }

  void _refreshContext() {
    if (!mounted) return;
    setState(() => _contextFuture = _contexts.load());
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _hiBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          final height = constraints.hasBoundedHeight ? constraints.maxHeight : 940.0;
          return SizedBox(
            height: height,
            child: Column(
              children: [
                _header(compact),
                _contextStrip(),
                _tabBar(compact),
                Expanded(
                  child: switch (_tab) {
                    _HistoricalIntelTab.records => _AllTimeRecordsPane(
                        research: _research,
                        contexts: _contexts,
                        onContextChanged: _refreshContext,
                        onOpenStats: widget.onOpenStats,
                      ),
                    _HistoricalIntelTab.compare => _CrossEraComparePane(
                        history: _history,
                        research: _research,
                        contexts: _contexts,
                        onContextChanged: _refreshContext,
                        onOpenStats: widget.onOpenStats,
                      ),
                    _HistoricalIntelTab.franchises => _FranchiseLineagePane(
                        research: _research,
                        contexts: _contexts,
                        onContextChanged: _refreshContext,
                        onOpenStats: widget.onOpenStats,
                        onOpenAnalytics: widget.onOpenAnalytics,
                      ),
                    _HistoricalIntelTab.games => _HistoricalGamesPane(
                        history: _history,
                        research: _research,
                        contexts: _contexts,
                        onContextChanged: _refreshContext,
                      ),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(bool compact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
      decoration: const BoxDecoration(
        color: _hiPanel,
        border: Border(bottom: BorderSide(color: _hiLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_hiGold, _hiOrange]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.history_edu_rounded, color: Color(0xFF211506)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NBA HISTORICAL INTELLIGENCE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _hiText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .9,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Records · cross-era comparison · franchise lineage · games · box scores · play-by-play',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _hiMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (!compact) const _IntelPill('CANONICAL HISTORY', _hiGold),
        ],
      ),
    );
  }

  Widget _contextStrip() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0D1725),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: FutureBuilder<NbaResearchContext>(
        future: _contextFuture,
        builder: (context, snapshot) {
          final active = snapshot.data;
          return Row(
            children: [
              const Icon(Icons.hub_rounded, color: _hiBlue, size: 15),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  active == null
                      ? 'Loading shared NBA context…'
                      : 'ACTIVE · ${active.scopeLabel}${active.entityLabel.isEmpty ? '' : ' · ${active.entityLabel}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active?.historical == true ? _hiGold : _hiGreen,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .35,
                  ),
                ),
              ),
              const Text(
                'Selections here can become terminal-wide context',
                style: TextStyle(color: _hiMuted, fontSize: 9),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabBar(bool compact) {
    return Container(
      width: double.infinity,
      color: _hiPanel,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in _HistoricalIntelTab.values)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  selected: _tab == tab,
                  avatar: Icon(tab.icon, size: 17),
                  label: Text(tab.label),
                  onSelected: (_) => setState(() => _tab = tab),
                ),
              ),
            if (!compact)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'NBA · ABA · BAA',
                  style: TextStyle(
                    color: _hiMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AllTimeRecordsPane extends StatefulWidget {
  const _AllTimeRecordsPane({
    required this.research,
    required this.contexts,
    required this.onContextChanged,
    this.onOpenStats,
  });

  final HistoricalNbaResearchRepository research;
  final NbaResearchContextStore contexts;
  final VoidCallback onContextChanged;
  final VoidCallback? onOpenStats;

  @override
  State<_AllTimeRecordsPane> createState() => _AllTimeRecordsPaneState();
}

class _AllTimeRecordsPaneState extends State<_AllTimeRecordsPane> {
  String _metric = 'pts';
  String _basis = 'totals';
  String _mode = 'career';
  String _league = 'NBA';
  String _seasonType = 'regular';
  int _bestN = 5;
  int _minSeasons = 1;
  double _minGames = 0;
  bool _loading = true;
  String _error = '';
  Map<String, dynamic> _payload = const {};

  static const _metrics = <String, String>{
    'pts': 'Points',
    'reb': 'Rebounds',
    'ast': 'Assists',
    'stl': 'Steals',
    'blk': 'Blocks',
    'tov': 'Turnovers',
    'fg_pct': 'FG%',
    'three_pct': '3P%',
    'ft_pct': 'FT%',
    'ts_pct': 'TS%',
    'efg_pct': 'eFG%',
    'per': 'PER',
    'ws': 'Win Shares',
    'ws48': 'WS/48',
    'bpm': 'BPM',
    'vorp': 'VORP',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final payload = await widget.research.allTime(
        metric: _metric,
        basis: _basis,
        mode: _mode,
        bestN: _bestN,
        league: _league,
        seasonType: _seasonType,
        minSeasons: _minSeasons,
        minGames: _minGames,
        limit: 250,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
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

  Future<void> _activate(Map<String, dynamic> row, {bool openStats = false}) async {
    final season = row['peak_season']?.toString() ?? '';
    final playerKey = row['player_key']?.toString() ?? '';
    if (season.isEmpty) return;
    await widget.contexts.activateHistorical(
      season: season,
      league: _league,
      seasonType: _seasonType == 'combined' ? 'regular' : _seasonType,
      playerKey: playerKey,
      playerName: row['player_name']?.toString() ?? '',
    );
    widget.onContextChanged();
    if (openStats) widget.onOpenStats?.call();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _mapList(_payload['rows']);
    return Column(
      children: [
        _ControlBand(
          children: [
            _IntelDrop(
              label: 'League',
              value: _league,
              values: const ['NBA', 'ABA', 'BAA'],
              onChanged: (value) {
                setState(() => _league = value);
                _load();
              },
            ),
            _IntelDrop(
              label: 'Metric',
              value: _metric,
              values: _metrics.keys.toList(),
              labels: _metrics,
              onChanged: (value) {
                setState(() => _metric = value);
                _load();
              },
            ),
            _IntelDrop(
              label: 'Basis',
              value: _basis,
              values: const [
                'totals',
                'per_game',
                'per36',
                'per48',
                'per75',
                'per100',
              ],
              labels: const {
                'totals': 'Totals',
                'per_game': 'Per Game',
                'per36': 'Per 36',
                'per48': 'Per 48',
                'per75': 'Per 75 Poss',
                'per100': 'Per 100 Poss',
              },
              onChanged: (value) {
                setState(() => _basis = value);
                _load();
              },
            ),
            _IntelDrop(
              label: 'Career Mode',
              value: _mode,
              values: const ['career', 'peak', 'best_n'],
              labels: const {
                'career': 'Career',
                'peak': 'Peak Season',
                'best_n': 'Best N Seasons',
              },
              onChanged: (value) {
                setState(() => _mode = value);
                _load();
              },
            ),
            if (_mode == 'best_n')
              _IntelDrop(
                label: 'Best N',
                value: '$_bestN',
                values: const ['3', '5', '7', '10'],
                onChanged: (value) {
                  setState(() => _bestN = int.parse(value));
                  _load();
                },
              ),
            _IntelDrop(
              label: 'Segment',
              value: _seasonType,
              values: const ['regular', 'playoffs', 'combined'],
              labels: const {
                'regular': 'Regular',
                'playoffs': 'Playoffs',
                'combined': 'Combined',
              },
              onChanged: (value) {
                setState(() => _seasonType = value);
                _load();
              },
            ),
            _IntelDrop(
              label: 'Min Seasons',
              value: '$_minSeasons',
              values: const ['1', '3', '5', '8', '10'],
              onChanged: (value) {
                setState(() => _minSeasons = int.parse(value));
                _load();
              },
            ),
            _IntelDrop(
              label: 'Min Games',
              value: _minGames.toInt().toString(),
              values: const ['0', '82', '164', '410', '820'],
              onChanged: (value) {
                setState(() => _minGames = double.parse(value));
                _load();
              },
            ),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _hiGold))
              : _error.isNotEmpty
                  ? _IntelEmpty(
                      icon: Icons.warning_amber_rounded,
                      title: 'All-time query unavailable',
                      body: _error,
                    )
                  : _AllTimeTable(
                      rows: rows,
                      metricLabel: _metrics[_metric] ?? _metric,
                      basis: _basis,
                      mode: _mode,
                      onActivate: _activate,
                    ),
        ),
      ],
    );
  }
}

class _AllTimeTable extends StatelessWidget {
  const _AllTimeTable({
    required this.rows,
    required this.metricLabel,
    required this.basis,
    required this.mode,
    required this.onActivate,
  });

  final List<Map<String, dynamic>> rows;
  final String metricLabel;
  final String basis;
  final String mode;
  final Future<void> Function(Map<String, dynamic> row, {bool openStats}) onActivate;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _IntelEmpty(
        icon: Icons.emoji_events_outlined,
        title: 'No eligible historical records',
        body: 'Relax the eligibility filters or choose another metric/basis.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final rank = row['rank'] ?? index + 1;
        final value = _format(row['metric_value']);
        final peakValue = _format(row['peak_metric_value']);
        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _hiPanel,
            border: Border.all(color: _hiLine),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: _hiGold,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['player_name']?.toString() ?? 'Historical player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _hiText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${row['first_season'] ?? '—'}–${row['last_season'] ?? '—'} · ${row['seasons'] ?? 0} seasons · ${_format(row['career_games'])} games',
                      style: const TextStyle(color: _hiMuted, fontSize: 9),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: _hiText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$metricLabel · ${_basisLabel(basis)}',
                      style: const TextStyle(color: _hiMuted, fontSize: 8),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peak ${row['peak_season'] ?? '—'} · ${row['peak_team'] ?? '—'}',
                      style: const TextStyle(
                        color: _hiBlue,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      peakValue,
                      style: const TextStyle(color: _hiMuted, fontSize: 9),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Use record context',
                onSelected: (value) => onActivate(
                  row,
                  openStats: value == 'stats',
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'context',
                    child: Text('Set peak season/player context'),
                  ),
                  PopupMenuItem(
                    value: 'stats',
                    child: Text('Set context + open Stats'),
                  ),
                ],
                icon: const Icon(Icons.bolt_rounded, color: _hiBlue),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CrossEraComparePane extends StatefulWidget {
  const _CrossEraComparePane({
    required this.history,
    required this.research,
    required this.contexts,
    required this.onContextChanged,
    this.onOpenStats,
  });

  final HistoricalNbaRepository history;
  final HistoricalNbaResearchRepository research;
  final NbaResearchContextStore contexts;
  final VoidCallback onContextChanged;
  final VoidCallback? onOpenStats;

  @override
  State<_CrossEraComparePane> createState() => _CrossEraComparePaneState();
}

class _CrossEraComparePaneState extends State<_CrossEraComparePane> {
  final TextEditingController _search = TextEditingController();
  final List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _searchResults = const [];
  String _metric = 'pts';
  String _basis = 'per_game';
  String _league = 'NBA';
  String _seasonType = 'regular';
  bool _searching = false;
  bool _loading = false;
  String _error = '';
  Map<String, dynamic> _comparison = const {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = '';
    });
    try {
      final rows = await widget.history.searchPlayers(
        query,
        league: _league,
        limit: 40,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = rows;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = error.toString();
      });
    }
  }

  void _toggle(Map<String, dynamic> player) {
    final key = player['player_key']?.toString() ?? '';
    if (key.isEmpty) return;
    setState(() {
      final existing = _players.indexWhere(
        (item) => item['player_key']?.toString() == key,
      );
      if (existing >= 0) {
        _players.removeAt(existing);
      } else if (_players.length < 6) {
        _players.add(player);
      }
      _comparison = const {};
    });
  }

  Future<void> _compare() async {
    if (_players.length < 2) {
      setState(() => _error = 'Choose at least two canonical players.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final payload = await widget.research.compare(
        playerKeys: [
          for (final player in _players) player['player_key'].toString(),
        ],
        metric: _metric,
        basis: _basis,
        league: _league,
        seasonType: _seasonType,
      );
      if (!mounted) return;
      setState(() {
        _comparison = payload;
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

  Future<void> _activatePeak(Map<String, dynamic> player) async {
    final identity = _stringMap(player['identity']);
    final peak = _stringMap(player['peak_season']);
    final season = peak['season_id']?.toString() ?? '';
    if (season.isEmpty) return;
    await widget.contexts.activateHistorical(
      season: season,
      league: _league,
      seasonType: _seasonType,
      playerKey: identity['player_key']?.toString() ?? '',
      playerName: identity['canonical_name']?.toString() ?? '',
    );
    widget.onContextChanged();
  }

  @override
  Widget build(BuildContext context) {
    final compared = _mapList(_comparison['players']);
    return Column(
      children: [
        _ControlBand(
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _find(),
                style: const TextStyle(color: _hiText, fontSize: 11),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search historical players…',
                  hintStyle: const TextStyle(color: _hiMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: IconButton(
                    onPressed: _find,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                  filled: true,
                  fillColor: _hiPanel2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: _hiLine),
                  ),
                ),
              ),
            ),
            _IntelDrop(
              label: 'League',
              value: _league,
              values: const ['NBA', 'ABA', 'BAA'],
              onChanged: (value) => setState(() {
                _league = value;
                _comparison = const {};
              }),
            ),
            _IntelDrop(
              label: 'Metric',
              value: _metric,
              values: const ['pts', 'reb', 'ast', 'stl', 'blk', 'ts_pct', 'per', 'ws', 'bpm', 'vorp'],
              onChanged: (value) => setState(() {
                _metric = value;
                _comparison = const {};
              }),
            ),
            _IntelDrop(
              label: 'Basis',
              value: _basis,
              values: const ['per_game', 'totals', 'per36', 'per75', 'per100'],
              labels: const {
                'per_game': 'Per Game',
                'totals': 'Totals',
                'per36': 'Per 36',
                'per75': 'Per 75',
                'per100': 'Per 100',
              },
              onChanged: (value) => setState(() {
                _basis = value;
                _comparison = const {};
              }),
            ),
            _IntelDrop(
              label: 'Segment',
              value: _seasonType,
              values: const ['regular', 'playoffs', 'combined'],
              onChanged: (value) => setState(() {
                _seasonType = value;
                _comparison = const {};
              }),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _compare,
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text('Compare ${_players.length}'),
            ),
          ],
        ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_error, style: const TextStyle(color: _hiRed)),
            ),
          ),
        if (_players.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final player in _players)
                  InputChip(
                    label: Text(player['canonical_name']?.toString() ?? 'Player'),
                    avatar: const Icon(Icons.person_rounded, size: 16),
                    onDeleted: () => _toggle(player),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _hiGold))
              : compared.isNotEmpty
                  ? _CompareResults(
                      players: compared,
                      metric: _metric,
                      basis: _basis,
                      onActivatePeak: _activatePeak,
                      onOpenStats: widget.onOpenStats,
                    )
                  : _searching
                      ? const Center(child: CircularProgressIndicator(color: _hiBlue))
                      : _searchResults.isNotEmpty
                          ? ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final player = _searchResults[index];
                                final selected = _players.any(
                                  (item) => item['player_key'] == player['player_key'],
                                );
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: (_) => _toggle(player),
                                  dense: true,
                                  title: Text(
                                    player['canonical_name']?.toString() ?? 'Player',
                                    style: const TextStyle(
                                      color: _hiText,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${player['first_stat_season'] ?? '—'}–${player['last_stat_season'] ?? '—'} · ${player['seasons'] ?? 0} seasons',
                                    style: const TextStyle(color: _hiMuted),
                                  ),
                                );
                              },
                            )
                          : const _IntelEmpty(
                              icon: Icons.compare_arrows_rounded,
                              title: 'Build a cross-era comparison set',
                              body:
                                  'Search canonical players, select 2–6, then compare career production, peak season and era-relative peak on a common metric/basis.',
                            ),
        ),
      ],
    );
  }
}

class _CompareResults extends StatelessWidget {
  const _CompareResults({
    required this.players,
    required this.metric,
    required this.basis,
    required this.onActivatePeak,
    this.onOpenStats,
  });

  final List<Map<String, dynamic>> players;
  final String metric;
  final String basis;
  final Future<void> Function(Map<String, dynamic>) onActivatePeak;
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final player in players)
              _CompareCard(
                player: player,
                metric: metric,
                basis: basis,
                onActivate: () async {
                  await onActivatePeak(player);
                },
                onOpenStats: () async {
                  await onActivatePeak(player);
                  onOpenStats?.call();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.player,
    required this.metric,
    required this.basis,
    required this.onActivate,
    required this.onOpenStats,
  });

  final Map<String, dynamic> player;
  final String metric;
  final String basis;
  final VoidCallback onActivate;
  final VoidCallback onOpenStats;

  @override
  Widget build(BuildContext context) {
    final identity = _stringMap(player['identity']);
    final peak = _stringMap(player['peak_season']);
    final peakEra = _stringMap(player['peak_era']);
    final aggregate = _stringMap(player['career_aggregate']);
    final z = _num(peakEra['z_score']);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _hiPanel,
        border: Border.all(color: _hiLine),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            identity['canonical_name']?.toString() ?? 'Historical player',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _hiText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _MetricPair(
            label: 'Career $metric · ${_basisLabel(basis)}',
            value: _format(player['career_metric_value']),
          ),
          _MetricPair(
            label: 'Peak season',
            value: '${peak['season_id'] ?? '—'} · ${peak['team_abbreviation'] ?? '—'}',
          ),
          _MetricPair(
            label: 'Peak era signal',
            value: z == null ? '—' : '${z >= 0 ? '+' : ''}${z.toStringAsFixed(2)}σ',
          ),
          _MetricPair(
            label: 'Career games',
            value: _format(aggregate['games']),
          ),
          _MetricPair(label: 'PTS', value: _format(aggregate['pts'])),
          _MetricPair(label: 'REB', value: _format(aggregate['reb'])),
          _MetricPair(label: 'AST', value: _format(aggregate['ast'])),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              OutlinedButton(
                onPressed: onActivate,
                child: const Text('Use peak context'),
              ),
              FilledButton.tonal(
                onPressed: onOpenStats,
                child: const Text('Open Stats'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FranchiseLineagePane extends StatefulWidget {
  const _FranchiseLineagePane({
    required this.research,
    required this.contexts,
    required this.onContextChanged,
    this.onOpenStats,
    this.onOpenAnalytics,
  });

  final HistoricalNbaResearchRepository research;
  final NbaResearchContextStore contexts;
  final VoidCallback onContextChanged;
  final VoidCallback? onOpenStats;
  final VoidCallback? onOpenAnalytics;

  @override
  State<_FranchiseLineagePane> createState() => _FranchiseLineagePaneState();
}

class _FranchiseLineagePaneState extends State<_FranchiseLineagePane> {
  final TextEditingController _query = TextEditingController();
  String _league = '';
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _franchises = const [];
  Map<String, dynamic>? _selected;
  Future<Map<String, dynamic>>? _detailFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final payload = await widget.research.franchises(
        query: _query.text.trim(),
        league: _league,
        limit: 300,
      );
      if (!mounted) return;
      setState(() {
        _franchises = _mapList(payload['rows']);
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

  void _select(Map<String, dynamic> row) {
    setState(() {
      _selected = row;
      _detailFuture = widget.research.franchise(
        row['franchise_key']?.toString() ?? '',
      );
    });
  }

  Future<void> _activate(
    Map<String, dynamic> seasonRow, {
    String destination = 'context',
  }) async {
    final season = seasonRow['season_id']?.toString() ?? '';
    if (season.isEmpty) return;
    await widget.contexts.activateHistorical(
      season: season,
      league: seasonRow['league_id']?.toString() ?? 'NBA',
      seasonType: seasonRow['season_type']?.toString() ?? 'regular',
      teamKey: seasonRow['team_key']?.toString() ?? '',
      teamName: seasonRow['team_identity_name']?.toString() ??
          seasonRow['team_abbreviation']?.toString() ??
          '',
    );
    widget.onContextChanged();
    if (destination == 'stats') widget.onOpenStats?.call();
    if (destination == 'analytics') widget.onOpenAnalytics?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        final list = _franchiseList();
        final detail = _franchiseDetail();
        if (!wide) {
          return ListView(
            children: [
              _franchiseControls(),
              SizedBox(height: 360, child: list),
              const Divider(height: 1, color: _hiLine),
              SizedBox(height: 620, child: detail),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: 380,
              child: Column(
                children: [
                  _franchiseControls(),
                  Expanded(child: list),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: _hiLine),
            Expanded(child: detail),
          ],
        );
      },
    );
  }

  Widget _franchiseControls() {
    return _ControlBand(
      children: [
        SizedBox(
          width: 230,
          child: TextField(
            controller: _query,
            onSubmitted: (_) => _load(),
            style: const TextStyle(color: _hiText),
            decoration: InputDecoration(
              hintText: 'Search franchises…',
              hintStyle: const TextStyle(color: _hiMuted),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: _hiPanel2,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _hiLine),
              ),
            ),
          ),
        ),
        _IntelDrop(
          label: 'League',
          value: _league.isEmpty ? 'ALL' : _league,
          values: const ['ALL', 'NBA', 'ABA', 'BAA'],
          onChanged: (value) {
            setState(() => _league = value == 'ALL' ? '' : value);
            _load();
          },
        ),
      ],
    );
  }

  Widget _franchiseList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _hiGold));
    }
    if (_error.isNotEmpty) {
      return _IntelEmpty(
        icon: Icons.warning_amber_rounded,
        title: 'Franchise index unavailable',
        body: _error,
      );
    }
    if (_franchises.isEmpty) {
      return const _IntelEmpty(
        icon: Icons.account_tree_outlined,
        title: 'No matching franchise lineage',
        body: 'Try a broader name or league filter.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _franchises.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final row = _franchises[index];
        final selected = row['franchise_key'] == _selected?['franchise_key'];
        return ListTile(
          selected: selected,
          selectedTileColor: const Color(0xFF203B5A),
          tileColor: _hiPanel2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: BorderSide(color: selected ? _hiBlue : _hiLine),
          ),
          leading: const Icon(Icons.account_tree_rounded, color: _hiGold),
          title: Text(
            row['canonical_name']?.toString() ?? 'Franchise',
            style: const TextStyle(color: _hiText, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${row['first_season'] ?? '—'}–${row['last_season'] ?? '—'} · ${row['seasons'] ?? 0} seasons · ${row['team_identities'] ?? 0} team identities',
            style: const TextStyle(color: _hiMuted, fontSize: 9),
          ),
          onTap: () => _select(row),
        );
      },
    );
  }

  Widget _franchiseDetail() {
    final future = _detailFuture;
    if (future == null) {
      return const _IntelEmpty(
        icon: Icons.account_tree_rounded,
        title: 'Open a franchise lineage',
        body:
            'Inspect relocations, team identities, historical abbreviations and every canonical franchise season without flattening distinct team eras.',
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _hiGold));
        }
        if (snapshot.hasError) {
          return _IntelEmpty(
            icon: Icons.warning_amber_rounded,
            title: 'Franchise detail unavailable',
            body: snapshot.error.toString(),
          );
        }
        final detail = snapshot.data ?? const <String, dynamic>{};
        final franchise = _stringMap(detail['franchise']);
        final teams = _mapList(detail['teams']);
        final seasons = _mapList(detail['seasons']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              franchise['canonical_name']?.toString() ?? 'Franchise',
              style: const TextStyle(
                color: _hiText,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Current abbreviation ${franchise['current_abbreviation'] ?? '—'} · ${franchise['source_count'] ?? 0} sources',
              style: const TextStyle(color: _hiMuted),
            ),
            const SizedBox(height: 14),
            const _IntelHeading(
              'Team identities',
              'Distinct canonical identities are retained across moves, renames and league eras.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final team in teams)
                  _MiniEntityCard(
                    title: team['canonical_name']?.toString() ?? 'Team',
                    subtitle:
                        '${team['abbreviation'] ?? '—'} · ${team['league_id'] ?? '—'} · ${team['active_from'] ?? '—'}–${team['active_to'] ?? '—'}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _IntelHeading(
              'Season history',
              'Activate any season/team identity as shared terminal context.',
            ),
            const SizedBox(height: 8),
            for (final season in seasons.reversed.take(100))
              _FranchiseSeasonRow(
                row: season,
                onSelected: (destination) =>
                    _activate(season, destination: destination),
              ),
          ],
        );
      },
    );
  }
}

class _FranchiseSeasonRow extends StatelessWidget {
  const _FranchiseSeasonRow({
    required this.row,
    required this.onSelected,
  });

  final Map<String, dynamic> row;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _hiPanel2,
        border: Border.all(color: _hiLine),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              row['season_id']?.toString() ?? '—',
              style: const TextStyle(
                color: _hiGold,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${row['team_identity_name'] ?? row['team_abbreviation'] ?? 'Team'} · ${row['league_id'] ?? 'NBA'} · ${_format(row['wins'])}–${_format(row['losses'])}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _hiText, fontSize: 10),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: onSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'context', child: Text('Set active context')),
              PopupMenuItem(value: 'stats', child: Text('Set context + Stats')),
              PopupMenuItem(
                value: 'analytics',
                child: Text('Set context + Analytics'),
              ),
            ],
            icon: const Icon(Icons.bolt_rounded, color: _hiBlue, size: 18),
          ),
        ],
      ),
    );
  }
}

class _HistoricalGamesPane extends StatefulWidget {
  const _HistoricalGamesPane({
    required this.history,
    required this.research,
    required this.contexts,
    required this.onContextChanged,
  });

  final HistoricalNbaRepository history;
  final HistoricalNbaResearchRepository research;
  final NbaResearchContextStore contexts;
  final VoidCallback onContextChanged;

  @override
  State<_HistoricalGamesPane> createState() => _HistoricalGamesPaneState();
}

class _HistoricalGamesPaneState extends State<_HistoricalGamesPane> {
  String _league = 'NBA';
  String _season = '';
  String _seasonType = 'regular';
  List<String> _seasons = const [];
  List<Map<String, dynamic>> _games = const [];
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _selectedGame;
  Future<Map<String, dynamic>>? _gameFuture;
  Future<Map<String, dynamic>>? _pbpFuture;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      var seasons = await widget.history.seasons(
        league: _league,
        domain: 'games',
      );
      if (seasons.isEmpty) {
        seasons = await widget.history.seasons(league: _league);
      }
      final ids = seasons
          .map((row) => row['season_id']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
      final season = ids.isEmpty ? '' : ids.last;
      if (!mounted) return;
      setState(() {
        _seasons = ids;
        _season = season;
      });
      await _loadGames();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadGames() async {
    if (_season.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _selectedGame = null;
      _gameFuture = null;
      _pbpFuture = null;
    });
    try {
      final payload = await widget.research.games(
        season: _season,
        league: _league,
        seasonType: _seasonType,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _games = _mapList(payload['rows']);
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

  Future<void> _changeLeague(String league) async {
    setState(() {
      _league = league;
      _season = '';
      _seasons = const [];
      _games = const [];
    });
    await _bootstrap();
  }

  void _openGame(Map<String, dynamic> game) {
    final key = game['game_key']?.toString() ?? '';
    if (key.isEmpty) return;
    setState(() {
      _selectedGame = game;
      _gameFuture = widget.research.game(key);
      _pbpFuture = widget.research.playByPlay(key, limit: 250);
    });
  }

  Future<void> _activateGame() async {
    final game = _selectedGame;
    if (game == null) return;
    await widget.contexts.activateHistorical(
      season: game['season_id']?.toString() ?? _season,
      league: game['league_id']?.toString() ?? _league,
      seasonType: game['season_type']?.toString() ?? _seasonType,
      gameKey: game['game_key']?.toString() ?? '',
    );
    widget.onContextChanged();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final list = _gamesList();
        final detail = _gameDetail();
        if (!wide) {
          return ListView(
            children: [
              _gameControls(),
              SizedBox(height: 440, child: list),
              const Divider(height: 1, color: _hiLine),
              SizedBox(height: 700, child: detail),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: 450,
              child: Column(
                children: [
                  _gameControls(),
                  Expanded(child: list),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: _hiLine),
            Expanded(child: detail),
          ],
        );
      },
    );
  }

  Widget _gameControls() {
    return _ControlBand(
      children: [
        _IntelDrop(
          label: 'League',
          value: _league,
          values: const ['NBA', 'ABA', 'BAA'],
          onChanged: _changeLeague,
        ),
        if (_seasons.isNotEmpty)
          _IntelDrop(
            label: 'Season',
            value: _season,
            values: _seasons.reversed.toList(),
            onChanged: (value) {
              setState(() => _season = value);
              _loadGames();
            },
          ),
        _IntelDrop(
          label: 'Segment',
          value: _seasonType,
          values: const ['regular', 'playoffs', 'combined'],
          onChanged: (value) {
            setState(() => _seasonType = value);
            _loadGames();
          },
        ),
      ],
    );
  }

  Widget _gamesList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _hiGold));
    }
    if (_error.isNotEmpty) {
      return _IntelEmpty(
        icon: Icons.warning_amber_rounded,
        title: 'Historical games unavailable',
        body: _error,
      );
    }
    if (_games.isEmpty) {
      return const _IntelEmpty(
        icon: Icons.sports_basketball_outlined,
        title: 'No canonical games for this scope',
        body:
            'Game-level historical coverage varies by source and era. Try another season or segment.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _games.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final game = _games[index];
        final selected = game['game_key'] == _selectedGame?['game_key'];
        return Material(
          color: selected ? const Color(0xFF203B5A) : _hiPanel2,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: () => _openGame(game),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? _hiBlue : _hiLine),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      game['game_date']?.toString() ?? '—',
                      style: const TextStyle(color: _hiMuted, fontSize: 9),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${game['away_team_abbreviation'] ?? game['away_team_name'] ?? 'Away'} @ ${game['home_team_abbreviation'] ?? game['home_team_name'] ?? 'Home'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _hiText,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${game['away_score'] ?? '—'} – ${game['home_score'] ?? '—'} · ${game['season_type'] ?? _seasonType}',
                          style: const TextStyle(color: _hiMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: _hiMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _gameDetail() {
    final future = _gameFuture;
    if (future == null) {
      return const _IntelEmpty(
        icon: Icons.scoreboard_rounded,
        title: 'Open a historical game',
        body:
            'Inspect canonical team lines, available player box score rows and source-linked play-by-play. Game-level coverage is shown only where source data exists.',
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _hiGold));
        }
        if (snapshot.hasError) {
          return _IntelEmpty(
            icon: Icons.warning_amber_rounded,
            title: 'Game detail unavailable',
            body: snapshot.error.toString(),
          );
        }
        final game = snapshot.data ?? const <String, dynamic>{};
        final teams = _mapList(game['teams']);
        final players = _mapList(game['players']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${game['away_score'] ?? '—'}  ${game['away_team_key'] ?? 'Away'}   @   ${game['home_team_key'] ?? 'Home'}  ${game['home_score'] ?? '—'}',
                        style: const TextStyle(
                          color: _hiText,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${game['game_date'] ?? '—'} · ${game['season_id'] ?? _season} · ${game['league_id'] ?? _league} · ${game['season_type'] ?? _seasonType}',
                        style: const TextStyle(color: _hiMuted),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _activateGame,
                  icon: const Icon(Icons.hub_rounded),
                  label: const Text('Use game context'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _IntelHeading(
              'Team box score',
              'Canonical team-game facts available for this game.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final team in teams)
                  _MiniEntityCard(
                    title: team['team_abbreviation']?.toString() ?? 'Team',
                    subtitle:
                        '${_format(team['pts'])} PTS · ${_format(team['reb'])} REB · ${_format(team['ast'])} AST',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _IntelHeading(
              'Player box score',
              'Player-game rows are shown only where canonical game-level source coverage exists.',
            ),
            const SizedBox(height: 8),
            if (players.isEmpty)
              const Text(
                'No canonical player-game rows are available for this game.',
                style: TextStyle(color: _hiMuted),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Player')),
                    DataColumn(label: Text('Team')),
                    DataColumn(label: Text('MIN')),
                    DataColumn(label: Text('PTS')),
                    DataColumn(label: Text('REB')),
                    DataColumn(label: Text('AST')),
                    DataColumn(label: Text('STL')),
                    DataColumn(label: Text('BLK')),
                    DataColumn(label: Text('TOV')),
                  ],
                  rows: [
                    for (final player in players.take(80))
                      DataRow(
                        cells: [
                          DataCell(Text(player['player_name']?.toString() ?? '—')),
                          DataCell(Text(player['team_abbreviation']?.toString() ?? '—')),
                          DataCell(Text(_format(player['minutes']))),
                          DataCell(Text(_format(player['pts']))),
                          DataCell(Text(_format(player['reb']))),
                          DataCell(Text(_format(player['ast']))),
                          DataCell(Text(_format(player['stl']))),
                          DataCell(Text(_format(player['blk']))),
                          DataCell(Text(_format(player['tov']))),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const _IntelHeading(
              'Play-by-play',
              'First 250 canonical events from the zero-copy historical PBP view when this game can be linked to event data.',
            ),
            const SizedBox(height: 8),
            _PlayByPlayPreview(future: _pbpFuture),
          ],
        );
      },
    );
  }
}

class _PlayByPlayPreview extends StatelessWidget {
  const _PlayByPlayPreview({required this.future});

  final Future<Map<String, dynamic>>? future;

  @override
  Widget build(BuildContext context) {
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _hiBlue));
        }
        if (snapshot.hasError) {
          return Text(
            'Play-by-play unavailable for this game: ${snapshot.error}',
            style: const TextStyle(color: _hiMuted),
          );
        }
        final payload = snapshot.data ?? const <String, dynamic>{};
        final rows = _mapList(payload['rows']);
        if (rows.isEmpty) {
          return const Text(
            'No linked play-by-play events are available for this canonical game.',
            style: TextStyle(color: _hiMuted),
          );
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 340),
          decoration: BoxDecoration(
            color: _hiPanel,
            border: Border.all(color: _hiLine),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: _hiLine,
            ),
            itemBuilder: (context, index) {
              final event = rows[index];
              final description = event['description'] ??
                  event['event_description'] ??
                  event['text'] ??
                  event['action_description'] ??
                  'Event ${event['event_number'] ?? index + 1}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        'P${event['period'] ?? '—'} · ${event['clock'] ?? event['game_clock'] ?? '—'}',
                        style: const TextStyle(color: _hiGold, fontSize: 9),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        description.toString(),
                        style: const TextStyle(color: _hiText, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ControlBand extends StatelessWidget {
  const _ControlBand({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: _hiPanel,
        border: Border(bottom: BorderSide(color: _hiLine)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: children,
      ),
    );
  }
}

class _IntelDrop extends StatelessWidget {
  const _IntelDrop({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.labels = const {},
  });

  final String label;
  final String value;
  final List<String> values;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safe = values.contains(value) ? value : values.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _hiMuted,
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: _hiPanel2,
            border: Border.all(color: _hiLine),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safe,
              dropdownColor: _hiPanel2,
              style: const TextStyle(
                color: _hiText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
              items: [
                for (final item in values)
                  DropdownMenuItem(
                    value: item,
                    child: Text(labels[item] ?? item),
                  ),
              ],
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _IntelHeading extends StatelessWidget {
  const _IntelHeading(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _hiText,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: _hiMuted, fontSize: 9, height: 1.35),
        ),
      ],
    );
  }
}

class _MiniEntityCard extends StatelessWidget {
  const _MiniEntityCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _hiPanel2,
        border: Border.all(color: _hiLine),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _hiText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _hiMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _MetricPair extends StatelessWidget {
  const _MetricPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _hiMuted, fontSize: 9),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _hiText,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelPill extends StatelessWidget {
  const _IntelPill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        border: Border.all(color: color.withOpacity(.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .45,
        ),
      ),
    );
  }
}

class _IntelEmpty extends StatelessWidget {
  const _IntelEmpty({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _hiBlue, size: 34),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _hiText,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _hiMuted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry(key.toString(), value));
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _format(Object? value) {
  final number = _num(value);
  if (number == null) return value?.toString() ?? '—';
  if (number == number.roundToDouble()) return number.round().toString();
  if (number.abs() >= 1000) return number.toStringAsFixed(0);
  return number.toStringAsFixed(2);
}

String _basisLabel(String basis) => switch (basis) {
      'per_game' => 'Per Game',
      'per36' => 'Per 36',
      'per48' => 'Per 48',
      'per75' => 'Per 75',
      'per100' => 'Per 100',
      _ => 'Totals',
    };
