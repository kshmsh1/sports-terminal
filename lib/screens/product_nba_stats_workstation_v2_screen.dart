import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';

const _ink = Color(0xFF090D12);
const _surface = Color(0xFF0F151C);
const _surface2 = Color(0xFF141C25);
const _surface3 = Color(0xFF1A2430);
const _stroke = Color(0xFF263342);
const _strokeSoft = Color(0xFF1B2632);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _faint = Color(0xFF566273);
const _blue = Color(0xFF63A9FF);
const _blueSoft = Color(0x1A63A9FF);
const _amber = Color(0xFFE2B866);
const _green = Color(0xFF69C99A);
const _red = Color(0xFFE57D7D);

class ProductNbaStatsWorkstationScreen extends StatefulWidget {
  const ProductNbaStatsWorkstationScreen({super.key});

  @override
  State<ProductNbaStatsWorkstationScreen> createState() =>
      _ProductNbaStatsWorkstationScreenState();
}

class _ProductNbaStatsWorkstationScreenState
    extends State<ProductNbaStatsWorkstationScreen> {
  static const _favoritesKey = 'sports_terminal.stats_workstation.favorites.v2';

  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final NbaTerminalMetricResolver _resolver = const NbaTerminalMetricResolver();
  final ProductLocalStore _store = const ProductLocalStore();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _minGames = TextEditingController(text: '1');
  final ScrollController _pageController = ScrollController();
  final GlobalKey _glossaryKey = GlobalKey();
  late final Future<NbaTerminalSeedSnapshot> _seedFuture;

  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _familyId = 'basic';
  String _team = 'All';
  String _position = 'All';
  String _sortKey = 'ppg';
  bool _descending = true;
  int _page = 0;
  int _pageSize = 50;
  final Set<String> _expanded = <String>{};
  final Set<String> _favorites = <String>{};
  final Set<String> _compareIds = <String>{};

  @override
  void initState() {
    super.initState();
    _seedFuture = const NbaTerminalSeedRepository().load();
    _restoreFavorites();
  }

  @override
  void dispose() {
    _search.dispose();
    _minGames.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _restoreFavorites() async {
    final raw = await _store.loadString(_favoritesKey);
    if (!mounted || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        setState(() {
          _favorites.addAll(decoded.map((value) => value.toString()));
        });
      }
    } catch (_) {}
  }

  Future<void> _persistFavorites() =>
      _store.saveString(_favoritesKey, jsonEncode(_favorites.toList()..sort()));

  NbaTerminalStatFamily get _family => nbaTerminalFamily(_familyId);

  List<String> get _visibleMetricKeys =>
      nbaVisibleMetricKeys(_family, _expanded);

  void _changeFamily(String value) {
    final family = nbaTerminalFamily(value);
    setState(() {
      _familyId = value;
      _expanded.clear();
      _sortKey = family.metrics.first;
      _descending = true;
      _page = 0;
    });
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (!_expanded.add(key)) _expanded.remove(key);
      _page = 0;
    });
  }

  void _toggleFavorite(NbaStatsRow row) {
    setState(() {
      if (!_favorites.add(row.playerId)) _favorites.remove(row.playerId);
    });
    _persistFavorites();
  }

  void _toggleCompare(NbaStatsRow row) {
    setState(() {
      if (!_compareIds.add(row.playerId)) _compareIds.remove(row.playerId);
      if (_compareIds.length > 6) _compareIds.remove(_compareIds.first);
    });
  }

  void _sortRows(List<NbaStatsRow> rows) {
    rows.sort((left, right) {
      final l = _resolver.value(left, _sortKey);
      final r = _resolver.value(right, _sortKey);
      if (l == null && r == null) return left.player.compareTo(right.player);
      if (l == null) return 1;
      if (r == null) return -1;
      final compared = l.compareTo(r);
      return _descending ? -compared : compared;
    });
  }

  Future<void> _copyRows(List<NbaStatsRow> rows) async {
    final keys = _visibleMetricKeys;
    final header = ['Player', 'Team', 'Pos', for (final key in keys) _metric(key).shortLabel];
    final lines = <String>[header.join('\t')];
    for (final row in rows) {
      lines.add([
        row.player,
        row.team,
        row.position,
        for (final key in keys) _resolver.format(row, key),
      ].join('\t'));
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${rows.length} rows copied as TSV.')),
    );
  }

  Future<void> _openCompare(List<NbaStatsRow> allRows) async {
    final selected = allRows.where((row) => _compareIds.contains(row.playerId)).toList();
    if (selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least two players to compare.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _CompareDialog(
        rows: selected,
        metricKeys: _visibleMetricKeys,
        resolver: _resolver,
      ),
    );
  }

  void _jumpToGlossary() {
    final target = _glossaryKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: _seedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: _ink,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return ColoredBox(
            color: _ink,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Stats workstation unavailable: ${snapshot.error}',
                  style: const TextStyle(color: _red),
                ),
              ),
            ),
          );
        }

        final seed = snapshot.data!;
        var rows = _engine.buildRows(
          seed,
          basis: _basis,
          seasonType: _seasonType,
        );
        final query = _search.text.trim().toLowerCase();
        final minGames = double.tryParse(_minGames.text) ?? 0;
        rows = rows.where((row) {
          if (query.isNotEmpty &&
              !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) {
            return false;
          }
          if (_team != 'All' &&
              !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) {
            return false;
          }
          if (_position != 'All' && row.position != _position) return false;
          if ((row.value('gp') ?? 0) < minGames) return false;
          return true;
        }).toList();
        _sortRows(rows);

        final teams = <String>{'All'};
        for (final row in rows) {
          teams.addAll(
            row.team
                .split(RegExp(r'[,/ ]+'))
                .where((value) => value.isNotEmpty && value != '—'),
          );
        }
        final totalPages = math.max(1, (rows.length / _pageSize).ceil());
        final page = math.min(_page, totalPages - 1);
        final start = page * _pageSize;
        final end = math.min(rows.length, start + _pageSize);
        final pageRows = start < rows.length ? rows.sublist(start, end) : <NbaStatsRow>[];

        return ColoredBox(
          color: _ink,
          child: Scrollbar(
            controller: _pageController,
            thumbVisibility: true,
            child: ListView(
              controller: _pageController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              children: [
                _Header(
                  seed: seed,
                  seasonType: _seasonType,
                  onSeason: (value) => setState(() {
                    _seasonType = value;
                    _page = 0;
                  }),
                ),
                const SizedBox(height: 10),
                _ControlDeck(
                  family: _family,
                  familyId: _familyId,
                  basis: _basis,
                  team: _team,
                  teams: teams.toList()..sort(),
                  position: _position,
                  search: _search,
                  minGames: _minGames,
                  compareCount: _compareIds.length,
                  onFamily: _changeFamily,
                  onBasis: (value) => setState(() {
                    _basis = value;
                    _page = 0;
                  }),
                  onTeam: (value) => setState(() {
                    _team = value;
                    _page = 0;
                  }),
                  onPosition: (value) => setState(() {
                    _position = value;
                    _page = 0;
                  }),
                  onSearch: () => setState(() => _page = 0),
                  onCompare: () => _openCompare(rows),
                  onCopy: () => _copyRows(rows),
                  onGlossary: _jumpToGlossary,
                ),
                const SizedBox(height: 10),
                _FamilyBrief(
                  family: _family,
                  visibleKeys: _visibleMetricKeys,
                  rows: rows,
                  resolver: _resolver,
                ),
                const SizedBox(height: 8),
                _StatsTable(
                  rows: pageRows,
                  metricKeys: _visibleMetricKeys,
                  sortKey: _sortKey,
                  descending: _descending,
                  expanded: _expanded,
                  favorites: _favorites,
                  compareIds: _compareIds,
                  basis: _basis,
                  resolver: _resolver,
                  onSort: (key) => setState(() {
                    if (_sortKey == key) {
                      _descending = !_descending;
                    } else {
                      _sortKey = key;
                      _descending = true;
                    }
                  }),
                  onExpand: _toggleExpanded,
                  onFavorite: _toggleFavorite,
                  onCompare: _toggleCompare,
                ),
                const SizedBox(height: 8),
                _Pager(
                  start: rows.isEmpty ? 0 : start + 1,
                  end: end,
                  total: rows.length,
                  page: page,
                  totalPages: totalPages,
                  pageSize: _pageSize,
                  onPageSize: (value) => setState(() {
                    _pageSize = value;
                    _page = 0;
                  }),
                  onPrevious: page > 0 ? () => setState(() => _page = page - 1) : null,
                  onNext: page + 1 < totalPages ? () => setState(() => _page = page + 1) : null,
                ),
                const SizedBox(height: 28),
                _Glossary(
                  key: _glossaryKey,
                  activeFamily: _family,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.seed,
    required this.seasonType,
    required this.onSeason,
  });

  final NbaTerminalSeedSnapshot seed;
  final NbaStatsSeasonType seasonType;
  final ValueChanged<NbaStatsSeasonType> onSeason;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(
          top: BorderSide(color: _stroke),
          left: BorderSide(color: _stroke),
          right: BorderSide(color: _stroke),
          bottom: BorderSide(color: _stroke),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 3, height: 44, color: _blue),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLAYER STATISTICS / SEASON INDEX',
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${seed.supportedSeason} · ${seed.isHistorical ? 'HISTORICAL CANONICAL' : 'CURRENT RELEASE'} · source-aware metric registry',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .35,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusTag(
                  text: seed.usedFallback ? 'FALLBACK SEED' : seed.datasetStatus.toUpperCase(),
                  tone: seed.usedFallback ? _amber : _green,
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: _surface2,
              border: Border(top: BorderSide(color: _strokeSoft)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'SEASON SEGMENT',
                  style: TextStyle(
                    color: _faint,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(width: 12),
                _SeasonTab(
                  label: 'REGULAR SEASON',
                  selected: seasonType == NbaStatsSeasonType.regular,
                  onTap: () => onSeason(NbaStatsSeasonType.regular),
                ),
                const SizedBox(width: 4),
                _SeasonTab(
                  label: 'PLAYOFFS',
                  selected: seasonType == NbaStatsSeasonType.playoffs,
                  onTap: () => onSeason(NbaStatsSeasonType.playoffs),
                ),
                const Spacer(),
                const Text(
                  'Regular season is the default · postseason is never blended into regular-season results',
                  style: TextStyle(color: _faint, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonTab extends StatelessWidget {
  const _SeasonTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _blueSoft : Colors.transparent,
        border: Border.all(color: selected ? _blue : _stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _blue : _muted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    ),
  );
}

class _ControlDeck extends StatelessWidget {
  const _ControlDeck({
    required this.family,
    required this.familyId,
    required this.basis,
    required this.team,
    required this.teams,
    required this.position,
    required this.search,
    required this.minGames,
    required this.compareCount,
    required this.onFamily,
    required this.onBasis,
    required this.onTeam,
    required this.onPosition,
    required this.onSearch,
    required this.onCompare,
    required this.onCopy,
    required this.onGlossary,
  });

  final NbaTerminalStatFamily family;
  final String familyId;
  final NbaStatsBasis basis;
  final String team;
  final List<String> teams;
  final String position;
  final TextEditingController search;
  final TextEditingController minGames;
  final int compareCount;
  final ValueChanged<String> onFamily;
  final ValueChanged<NbaStatsBasis> onBasis;
  final ValueChanged<String> onTeam;
  final ValueChanged<String> onPosition;
  final VoidCallback onSearch;
  final VoidCallback onCompare;
  final VoidCallback onCopy;
  final VoidCallback onGlossary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 980;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: _stroke),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _LabeledDrop<String>(
              label: 'STAT FAMILY',
              value: familyId,
              width: compact ? 230 : 260,
              items: [
                for (final item in nbaTerminalStatFamilies)
                  DropdownMenuItem(value: item.id, child: Text(item.label)),
              ],
              onChanged: onFamily,
            ),
            _LabeledDrop<NbaStatsBasis>(
              label: 'RATE BASIS',
              value: basis,
              width: 150,
              items: [
                for (final item in NbaStatsBasis.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: onBasis,
            ),
            _LabeledDrop<String>(
              label: 'TEAM',
              value: teams.contains(team) ? team : 'All',
              width: 120,
              items: [for (final item in teams) DropdownMenuItem(value: item, child: Text(item))],
              onChanged: onTeam,
            ),
            _LabeledDrop<String>(
              label: 'POSITION',
              value: position,
              width: 105,
              items: [
                for (final item in const ['All', 'PG', 'SG', 'SF', 'PF', 'C'])
                  DropdownMenuItem(value: item, child: Text(item == 'All' ? 'All' : item)),
              ],
              onChanged: onPosition,
            ),
            _InputBox(
              label: 'MIN GP',
              width: 82,
              controller: minGames,
              keyboardType: TextInputType.number,
              onChanged: (_) => onSearch(),
            ),
            _InputBox(
              label: 'PLAYER SEARCH',
              width: compact ? 190 : 230,
              controller: search,
              onChanged: (_) => onSearch(),
              prefix: Icons.search_rounded,
            ),
            _CommandButton(
              icon: Icons.compare_arrows_rounded,
              label: compareCount == 0 ? 'COMPARE' : 'COMPARE $compareCount',
              onTap: onCompare,
            ),
            _CommandButton(icon: Icons.copy_rounded, label: 'COPY TSV', onTap: onCopy),
            _CommandButton(icon: Icons.menu_book_outlined, label: 'GLOSSARY ↓', onTap: onGlossary),
          ],
        ),
      );
    },
  );
}

class _FamilyBrief extends StatelessWidget {
  const _FamilyBrief({
    required this.family,
    required this.visibleKeys,
    required this.rows,
    required this.resolver,
  });

  final NbaTerminalStatFamily family;
  final List<String> visibleKeys;
  final List<NbaStatsRow> rows;
  final NbaTerminalMetricResolver resolver;

  @override
  Widget build(BuildContext context) {
    var available = 0;
    for (final key in visibleKeys) {
      if (rows.any((row) => resolver.isAvailable(row, key))) available++;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: _surface2,
        border: Border(
          left: BorderSide(color: _stroke),
          right: BorderSide(color: _stroke),
          top: BorderSide(color: _stroke),
          bottom: BorderSide(color: _stroke),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.label.toUpperCase(),
                  style: const TextStyle(
                    color: _blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(family.description, style: const TextStyle(color: _muted, fontSize: 10)),
              ],
            ),
          ),
          _StatusTag(text: '$available/${visibleKeys.length} COLUMNS POPULATED', tone: available == visibleKeys.length ? _green : _amber),
          const SizedBox(width: 8),
          const _StatusTag(text: '— = SOURCE NOT AVAILABLE', tone: _faint),
        ],
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({
    required this.rows,
    required this.metricKeys,
    required this.sortKey,
    required this.descending,
    required this.expanded,
    required this.favorites,
    required this.compareIds,
    required this.basis,
    required this.resolver,
    required this.onSort,
    required this.onExpand,
    required this.onFavorite,
    required this.onCompare,
  });

  final List<NbaStatsRow> rows;
  final List<String> metricKeys;
  final String sortKey;
  final bool descending;
  final Set<String> expanded;
  final Set<String> favorites;
  final Set<String> compareIds;
  final NbaStatsBasis basis;
  final NbaTerminalMetricResolver resolver;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onExpand;
  final ValueChanged<NbaStatsRow> onFavorite;
  final ValueChanged<NbaStatsRow> onCompare;

  @override
  Widget build(BuildContext context) {
    const playerWidth = 238.0;
    const teamWidth = 74.0;
    const posWidth = 52.0;
    const metricWidth = 92.0;
    final width = playerWidth + teamWidth + posWidth + metricWidth * metricKeys.length;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _stroke),
      ),
      child: rows.isEmpty
          ? const SizedBox(
              height: 180,
              child: Center(
                child: Text('No players match the current segment and filters.', style: TextStyle(color: _muted)),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TableHeader(
                      metricKeys: metricKeys,
                      sortKey: sortKey,
                      descending: descending,
                      expanded: expanded,
                      basis: basis,
                      onSort: onSort,
                      onExpand: onExpand,
                    ),
                    for (var index = 0; index < rows.length; index++)
                      _TableRow(
                        row: rows[index],
                        index: index,
                        metricKeys: metricKeys,
                        resolver: resolver,
                        favorite: favorites.contains(rows[index].playerId),
                        comparing: compareIds.contains(rows[index].playerId),
                        onFavorite: () => onFavorite(rows[index]),
                        onCompare: () => onCompare(rows[index]),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.metricKeys,
    required this.sortKey,
    required this.descending,
    required this.expanded,
    required this.basis,
    required this.onSort,
    required this.onExpand,
  });

  final List<String> metricKeys;
  final String sortKey;
  final bool descending;
  final Set<String> expanded;
  final NbaStatsBasis basis;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    decoration: const BoxDecoration(
      color: _surface3,
      border: Border(bottom: BorderSide(color: _stroke)),
    ),
    child: Row(
      children: [
        const _StaticHeader(width: 238, label: 'PLAYER'),
        const _StaticHeader(width: 74, label: 'TEAM'),
        const _StaticHeader(width: 52, label: 'POS'),
        for (final key in metricKeys)
          _MetricHeader(
            keyValue: key,
            metric: _metric(key),
            basis: basis,
            selected: sortKey == key,
            descending: descending,
            expanded: expanded.contains(key),
            onSort: () => onSort(key),
            onExpand: _metric(key).children.isEmpty ? null : () => onExpand(key),
          ),
      ],
    ),
  );
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.row,
    required this.index,
    required this.metricKeys,
    required this.resolver,
    required this.favorite,
    required this.comparing,
    required this.onFavorite,
    required this.onCompare,
  });

  final NbaStatsRow row;
  final int index;
  final List<String> metricKeys;
  final NbaTerminalMetricResolver resolver;
  final bool favorite;
  final bool comparing;
  final VoidCallback onFavorite;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final background = index.isEven ? _surface : const Color(0xFF0D131A);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: background,
        border: const Border(bottom: BorderSide(color: _strokeSoft)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 238,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: onCompare,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: comparing ? _blueSoft : Colors.transparent,
                        border: Border.all(color: comparing ? _blue : _faint),
                      ),
                      child: comparing ? const Icon(Icons.check, color: _blue, size: 11) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.player,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  InkWell(
                    onTap: onFavorite,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        favorite ? Icons.star_rounded : Icons.star_border_rounded,
                        color: favorite ? _amber : _faint,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _TextCell(width: 74, text: row.team),
          _TextCell(width: 52, text: row.position),
          for (final key in metricKeys)
            _MetricCell(
              value: resolver.format(row, key),
              available: resolver.isAvailable(row, key),
            ),
        ],
      ),
    );
  }
}

class _MetricHeader extends StatelessWidget {
  const _MetricHeader({
    required this.keyValue,
    required this.metric,
    required this.basis,
    required this.selected,
    required this.descending,
    required this.expanded,
    required this.onSort,
    required this.onExpand,
  });

  final String keyValue;
  final NbaTerminalMetric metric;
  final NbaStatsBasis basis;
  final bool selected;
  final bool descending;
  final bool expanded;
  final VoidCallback onSort;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: _strokeSoft))),
    child: InkWell(
      onTap: onSort,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              metric.group.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _faint, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: .45),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onExpand != null)
                  InkWell(
                    onTap: onExpand,
                    child: Icon(
                      expanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded,
                      color: _amber,
                      size: 16,
                    ),
                  ),
                Flexible(
                  child: Text(
                    _basisLabel(metric, basis),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _blue : _text,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (selected)
                  Icon(descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: _blue, size: 10),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StaticHeader extends StatelessWidget {
  const _StaticHeader({required this.width, required this.label});
  final double width;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .6),
      ),
    ),
  );
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.value, required this.available});
  final String value;
  final bool available;

  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    height: double.infinity,
    alignment: Alignment.center,
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: _strokeSoft))),
    child: Text(
      value,
      style: TextStyle(
        color: available ? _text : _faint,
        fontSize: 10,
        fontWeight: available ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
  );
}

class _TextCell extends StatelessWidget {
  const _TextCell({required this.width, required this.text});
  final double width;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: double.infinity,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: _strokeSoft))),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.start,
    required this.end,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.pageSize,
    required this.onPageSize,
    required this.onPrevious,
    required this.onNext,
  });

  final int start;
  final int end;
  final int total;
  final int page;
  final int totalPages;
  final int pageSize;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: _surface2, border: Border.all(color: _stroke)),
    child: Row(
      children: [
        Text('$start–$end OF $total', style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w800)),
        const Spacer(),
        _MiniDrop<int>(
          value: pageSize,
          width: 72,
          items: const [25, 50, 100, 250],
          label: (value) => '$value',
          onChanged: onPageSize,
        ),
        const SizedBox(width: 8),
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left_rounded, color: _text, size: 18)),
        Text('${page + 1}/$totalPages', style: const TextStyle(color: _text, fontSize: 9, fontWeight: FontWeight.w800)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded, color: _text, size: 18)),
      ],
    ),
  );
}

class _Glossary extends StatelessWidget {
  const _Glossary({super.key, required this.activeFamily});
  final NbaTerminalStatFamily activeFamily;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<NbaTerminalMetric>>{};
    for (final metric in nbaTerminalMetrics) {
      groups.putIfAbsent(metric.group, () => []).add(metric);
    }
    return Container(
      decoration: BoxDecoration(color: _surface, border: Border.all(color: _stroke)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: const BoxDecoration(
              color: _surface3,
              border: Border(bottom: BorderSide(color: _stroke)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STAT GLOSSARY', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .5)),
                SizedBox(height: 3),
                Text(
                  'Every metric registered in the workstation. Source-gated tracking and model metrics remain visible but display — until an authorized source populates them.',
                  style: TextStyle(color: _muted, fontSize: 9, height: 1.35),
                ),
              ],
            ),
          ),
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
              child: Row(
                children: [
                  Container(width: 2, height: 14, color: entry.key == activeFamily.label ? _blue : _faint),
                  const SizedBox(width: 7),
                  Text(entry.key.toUpperCase(), style: const TextStyle(color: _amber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1200 ? 3 : constraints.maxWidth >= 720 ? 2 : 1;
                final width = (constraints.maxWidth - 28 - (columns - 1) * 8) / columns;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final metric in entry.value)
                        SizedBox(
                          width: width,
                          child: _GlossaryCard(metric: metric),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard({required this.metric});
  final NbaTerminalMetric metric;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 78),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _surface2,
      border: Border.all(color: _strokeSoft),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(metric.shortLabel, style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            if (metric.providerNative)
              const Text('SOURCE', style: TextStyle(color: _faint, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .4)),
          ],
        ),
        const SizedBox(height: 5),
        Text(metric.description, style: const TextStyle(color: _muted, fontSize: 9, height: 1.35)),
      ],
    ),
  );
}

class _CompareDialog extends StatelessWidget {
  const _CompareDialog({required this.rows, required this.metricKeys, required this.resolver});
  final List<NbaStatsRow> rows;
  final List<String> metricKeys;
  final NbaTerminalMetricResolver resolver;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _surface,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: _surface3, border: Border(bottom: BorderSide(color: _stroke))),
            child: Row(
              children: [
                const Expanded(child: Text('PLAYER COMPARISON', style: TextStyle(color: _text, fontWeight: FontWeight.w900, letterSpacing: .5))),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: _muted)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Table(
                border: TableBorder.all(color: _strokeSoft),
                columnWidths: const {0: FixedColumnWidth(160)},
                children: [
                  TableRow(children: [
                    const _CompareCell(text: 'METRIC', header: true),
                    for (final row in rows) _CompareCell(text: row.player, header: true),
                  ]),
                  for (final key in metricKeys)
                    TableRow(children: [
                      _CompareCell(text: _metric(key).shortLabel),
                      for (final row in rows) _CompareCell(text: resolver.format(row, key)),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompareCell extends StatelessWidget {
  const _CompareCell({required this.text, this.header = false});
  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(9),
    child: Text(
      text,
      textAlign: header ? TextAlign.left : TextAlign.center,
      style: TextStyle(color: header ? _blue : _text, fontSize: 9, fontWeight: header ? FontWeight.w900 : FontWeight.w600),
    ),
  );
}

class _LabeledDrop<T> extends StatelessWidget {
  const _LabeledDrop({
    required this.label,
    required this.value,
    required this.width,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final double width;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: DropdownButtonFormField<T>(
            value: value,
            isExpanded: true,
            dropdownColor: _surface3,
            icon: const Icon(Icons.unfold_more_rounded, color: _muted, size: 14),
            style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w700),
            decoration: _inputDecoration(),
            items: items,
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ],
    ),
  );
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.label,
    required this.width,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.prefix,
  });

  final String label;
  final double width;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final IconData? prefix;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(color: _text, fontSize: 10, fontWeight: FontWeight.w700),
            decoration: _inputDecoration(prefix: prefix),
          ),
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: _faint, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .7),
  );
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 11),
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _surface2, border: Border.all(color: _stroke)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _muted),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: _text, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .35)),
          ],
        ),
      ),
    ),
  );
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text, required this.tone});
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(border: Border.all(color: tone.withValues(alpha: .6))),
    child: Text(text, style: TextStyle(color: tone, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .45)),
  );
}

class _MiniDrop<T> extends StatelessWidget {
  const _MiniDrop({required this.value, required this.width, required this.items, required this.label, required this.onChanged});
  final T value;
  final double width;
  final List<T> items;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 28,
    child: DropdownButtonFormField<T>(
      value: value,
      dropdownColor: _surface3,
      style: const TextStyle(color: _text, fontSize: 9),
      decoration: _inputDecoration(),
      items: [for (final item in items) DropdownMenuItem(value: item, child: Text(label(item)))],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

InputDecoration _inputDecoration({IconData? prefix}) => InputDecoration(
  filled: true,
  fillColor: _surface2,
  prefixIcon: prefix == null ? null : Icon(prefix, color: _faint, size: 14),
  prefixIconConstraints: const BoxConstraints(minWidth: 30),
  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
  enabledBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: _stroke),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: _blue),
  ),
  border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
);

NbaTerminalMetric _metric(String key) =>
    nbaTerminalMetricByKey[key] ??
    NbaTerminalMetric(
      key: key,
      label: key,
      shortLabel: key.toUpperCase(),
      group: 'Other',
      description: 'Source-provided metric.',
    );

String _basisLabel(NbaTerminalMetric metric, NbaStatsBasis basis) {
  if (metric.engineKey == null ||
      const ['fg_pct', 'three_pct', 'ft_pct', 'efg_pct', 'ts_pct', 'ft_rate', 'three_rate', 'bpm', 'scoring_load'].contains(metric.engineKey)) {
    return metric.shortLabel;
  }
  if (basis == NbaStatsBasis.perGame) return metric.shortLabel;
  final base = switch (metric.key) {
    'mpg' => 'MIN',
    'ppg' => 'PTS',
    'rpg' => 'REB',
    'apg' => 'AST',
    'spg' => 'STL',
    'bpg' => 'BLK',
    'tpg' => 'TOV',
    _ => metric.shortLabel,
  };
  return switch (basis) {
    NbaStatsBasis.totals => base,
    NbaStatsBasis.per36 => '$base/36',
    NbaStatsBasis.per48 => '$base/48',
    NbaStatsBasis.per75 => '$base/75',
    NbaStatsBasis.per100 => '$base/100',
    NbaStatsBasis.perGame => metric.shortLabel,
  };
}
