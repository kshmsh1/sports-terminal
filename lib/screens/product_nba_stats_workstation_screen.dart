import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';

const _bg = Color(0xFF151C29);
const _panel = Color(0xFF1D2636);
const _panel2 = Color(0xFF232D3F);
const _panel3 = Color(0xFF2B3547);
const _line = Color(0xFF354155);
const _text = Color(0xFFF3F6FB);
const _muted = Color(0xFF9DA8BA);
const _yellow = Color(0xFFFFCB45);
const _cyan = Color(0xFF65D5FF);
const _green = Color(0xFF63E6A6);
const _red = Color(0xFFFF7B7B);

class ProductNbaStatsWorkstationScreen extends StatefulWidget {
  const ProductNbaStatsWorkstationScreen({super.key});

  @override
  State<ProductNbaStatsWorkstationScreen> createState() =>
      _ProductNbaStatsWorkstationScreenState();
}

class _ProductNbaStatsWorkstationScreenState
    extends State<ProductNbaStatsWorkstationScreen> {
  static const _favoritesKey = 'sports_terminal.stats_workstation.favorites.v1';
  static const _customViewsKey =
      'sports_terminal.stats_workstation.custom_views.v1';
  static const _viewKey = 'sports_terminal.stats_workstation.view.v1';

  final ProductLocalStore _store = const ProductLocalStore();
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final Future<NbaTerminalSeedSnapshot> _seedFuture;

  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsFilters _filters = const NbaStatsFilters(minGames: 1);
  String _activeView = 'Overview';
  String _sortKey = 'pts';
  bool _descending = true;
  int _pageSize = 50;
  int _page = 0;
  double _density = 1;
  String _identityMode = 'Initials';
  NbaStatsRow? _selected;
  final Set<String> _compareIds = {};
  final Set<String> _favorites = {};
  final Map<String, List<String>> _customViews = {};

  @override
  void initState() {
    super.initState();
    _seedFuture = const NbaTerminalSeedRepository().load();
    _restoreState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _restoreState() async {
    final favoriteRaw = await _store.loadString(_favoritesKey);
    final customRaw = await _store.loadString(_customViewsKey);
    final savedView = await _store.loadString(_viewKey);
    if (!mounted) return;
    setState(() {
      try {
        final decoded = jsonDecode(favoriteRaw);
        if (decoded is List) {
          _favorites.addAll(decoded.map((item) => item.toString()));
        }
      } catch (_) {}
      try {
        final decoded = jsonDecode(customRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is List) {
              _customViews[entry.key.toString()] = [
                for (final item in entry.value as List) item.toString(),
              ];
            }
          }
        }
      } catch (_) {}
      if (savedView.isNotEmpty &&
          (nbaDefaultViews.containsKey(savedView) ||
              _customViews.containsKey(savedView))) {
        _activeView = savedView;
      }
    });
  }

  Future<void> _persistFavorites() =>
      _store.saveString(_favoritesKey, jsonEncode(_favorites.toList()..sort()));

  Future<void> _persistViews() =>
      _store.saveString(_customViewsKey, jsonEncode(_customViews));

  Future<void> _setView(String value) async {
    setState(() {
      _activeView = value;
      _page = 0;
    });
    await _store.saveString(_viewKey, value);
  }

  List<String> get _metricKeys =>
      _customViews[_activeView] ??
      nbaDefaultViews[_activeView] ??
      nbaDefaultViews['Overview']!;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyF) {
      _openFilters();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyG) {
      _openGlossary();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      if (_compareIds.length >= 2) _openComparison();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC && _selected != null) {
      setState(() {
        if (!_compareIds.add(_selected!.playerId)) {
          _compareIds.remove(_selected!.playerId);
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyW) {
      setState(() => _density = math.max(.75, _density - .1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyE) {
      setState(() => _density = math.min(1.35, _density + .1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _selected = null;
        _compareIds.clear();
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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

  Future<void> _openFilters() async {
    final result = await showDialog<NbaStatsFilters>(
      context: context,
      builder: (context) =>
          _FilterDialog(filters: _filters, metrics: nbaStatMetrics),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters = result.copyWith(search: _searchController.text);
      _page = 0;
    });
  }

  Future<void> _openGlossary() => showDialog<void>(
    context: context,
    builder: (context) => const _GlossaryDialog(),
  );

  Future<void> _openCustomViewEditor() async {
    final existing = _customViews[_activeView] ?? _metricKeys;
    final result = await showDialog<_CustomViewResult>(
      context: context,
      builder: (context) => _CustomViewDialog(
        initialName: _customViews.containsKey(_activeView) ? _activeView : '',
        initialKeys: existing,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _customViews[result.name] = result.keys;
      _activeView = result.name;
    });
    await _persistViews();
    await _store.saveString(_viewKey, result.name);
  }

  Future<void> _openComparison() async {
    if (_compareIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least two players to compare.'),
        ),
      );
      return;
    }
    final snapshot = await _seedFuture;
    final rows = _engine.buildRows(
      snapshot,
      basis: _basis,
      seasonType: _seasonType,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _ComparisonDialog(
        rows: rows.where((row) => _compareIds.contains(row.playerId)).toList(),
        metrics: _metricKeys,
        engine: _engine,
      ),
    );
  }

  Future<void> _openChartStudio(
    List<NbaStatsRow> rows,
    NbaTerminalSeedSnapshot snapshot,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => _ChartStudio(
        rows: rows,
        snapshot: snapshot,
        engine: _engine,
        selected: _selected,
      ),
    );
  }

  Future<void> _copyRows(List<NbaStatsRow> rows) async {
    final headers = [
      'Player',
      'Team',
      'Position',
      ..._metricKeys.map((key) => _engine.metric(key).shortLabel),
    ];
    final output = <String>[headers.join('\t')];
    for (final row in rows) {
      output.add(
        [
          row.player,
          row.team,
          row.position,
          for (final key in _metricKeys)
            _engine.formatValue(key, row.value(key)),
        ].join('\t'),
      );
    }
    await Clipboard.setData(ClipboardData(text: output.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${rows.length} rows copied as TSV.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: FutureBuilder<NbaTerminalSeedSnapshot>(
        future: _seedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _DarkSurface(
              child: Text(
                'Loading Stats Workstation…',
                style: TextStyle(color: _muted),
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _DarkSurface(
              child: Text(
                'Stats unavailable: ${snapshot.error}',
                style: const TextStyle(color: _red),
              ),
            );
          }
          final data = snapshot.data!;
          var rows = _engine.buildRows(
            data,
            basis: _basis,
            seasonType: _seasonType,
          );
          rows = _engine.filterRows(
            rows,
            _filters.copyWith(search: _searchController.text),
            favorites: _favorites,
          );
          _engine.sortRows(rows, _sortKey, descending: _descending);
          final totalPages = math.max(1, (rows.length / _pageSize).ceil());
          final safePage = math.min(_page, totalPages - 1);
          final start = safePage * _pageSize;
          final end = math.min(rows.length, start + _pageSize);
          final pageRows = start < rows.length
              ? rows.sublist(start, end)
              : <NbaStatsRow>[];
          _selected ??= pageRows.isEmpty ? null : pageRows.first;
          final teams = <String>{'All'};
          for (final row in rows) {
            teams.addAll(
              row.team
                  .split(RegExp(r'[,/ ]+'))
                  .where((team) => team.isNotEmpty && team != '—'),
            );
          }

          return Container(
            color: _bg,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrimaryToolbar(
                  seasonType: _seasonType,
                  basis: _basis,
                  team: _filters.team,
                  position: _filters.position,
                  teams: teams.toList()..sort(),
                  onSeason: (value) => setState(() {
                    _seasonType = value;
                    _page = 0;
                  }),
                  onTeam: (value) => setState(() {
                    _filters = _filters.copyWith(team: value);
                    _page = 0;
                  }),
                  onPosition: (value) => setState(() {
                    _filters = _filters.copyWith(position: value);
                    _page = 0;
                  }),
                ),
                const SizedBox(height: 8),
                _ViewTabs(
                  active: _activeView,
                  customViews: _customViews.keys.toList(),
                  onChanged: _setView,
                  onEdit: _openCustomViewEditor,
                ),
                const SizedBox(height: 8),
                _ActionToolbar(
                  basis: _basis,
                  identityMode: _identityMode,
                  controller: _searchController,
                  compareCount: _compareIds.length,
                  favoriteOnly: _filters.favoriteOnly,
                  onBasis: (value) => setState(() {
                    _basis = value;
                    _page = 0;
                  }),
                  onIdentity: (value) => setState(() => _identityMode = value),
                  onSearch: (_) => setState(() => _page = 0),
                  onFilters: _openFilters,
                  onGlossary: _openGlossary,
                  onCompare: _openComparison,
                  onChart: () => _openChartStudio(rows, data),
                  onCopy: () => _copyRows(rows),
                  onFavoriteOnly: () => setState(() {
                    _filters = _filters.copyWith(
                      favoriteOnly: !_filters.favoriteOnly,
                    );
                    _page = 0;
                  }),
                  onDensityDown: () =>
                      setState(() => _density = math.max(.75, _density - .1)),
                  onDensityUp: () =>
                      setState(() => _density = math.min(1.35, _density + .1)),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1180;
                    final table = Expanded(
                      child: _StatsTable(
                        rows: pageRows,
                        metricKeys: _metricKeys,
                        engine: _engine,
                        selected: _selected,
                        compareIds: _compareIds,
                        favorites: _favorites,
                        density: _density,
                        identityMode: _identityMode,
                        sortKey: _sortKey,
                        descending: _descending,
                        onSort: (key) => setState(() {
                          if (_sortKey == key) {
                            _descending = !_descending;
                          } else {
                            _sortKey = key;
                            _descending = true;
                          }
                        }),
                        onSelected: (row) => setState(() => _selected = row),
                        onFavorite: _toggleFavorite,
                        onCompare: _toggleCompare,
                      ),
                    );
                    final inspector = _PlayerInspector(
                      row: _selected,
                      metricKeys: _metricKeys,
                      engine: _engine,
                      inComparison:
                          _selected != null &&
                          _compareIds.contains(_selected!.playerId),
                      favorite:
                          _selected != null &&
                          _favorites.contains(_selected!.playerId),
                      onCompare: _selected == null
                          ? null
                          : () => _toggleCompare(_selected!),
                      onFavorite: _selected == null
                          ? null
                          : () => _toggleFavorite(_selected!),
                    );
                    if (wide) {
                      return SizedBox(
                        height: 720,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            table,
                            const SizedBox(width: 8),
                            SizedBox(width: 286, child: inspector),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(height: 650, child: table),
                        const SizedBox(height: 8),
                        inspector,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                _FooterBar(
                  start: rows.isEmpty ? 0 : start + 1,
                  end: end,
                  total: rows.length,
                  page: safePage,
                  totalPages: totalPages,
                  pageSize: _pageSize,
                  estimatedPossessions: pageRows.any(
                    (row) => row.possessionsEstimated,
                  ),
                  onPageSize: (value) => setState(() {
                    _pageSize = value;
                    _page = 0;
                  }),
                  onPrevious: safePage > 0
                      ? () => setState(() => _page = safePage - 1)
                      : null,
                  onNext: safePage + 1 < totalPages
                      ? () => setState(() => _page = safePage + 1)
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PrimaryToolbar extends StatelessWidget {
  const _PrimaryToolbar({
    required this.seasonType,
    required this.basis,
    required this.team,
    required this.position,
    required this.teams,
    required this.onSeason,
    required this.onTeam,
    required this.onPosition,
  });

  final NbaStatsSeasonType seasonType;
  final NbaStatsBasis basis;
  final String team;
  final String position;
  final List<String> teams;
  final ValueChanged<NbaStatsSeasonType> onSeason;
  final ValueChanged<String> onTeam;
  final ValueChanged<String> onPosition;

  @override
  Widget build(BuildContext context) => _ToolbarSurface(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _YearControl(),
        _Segmented<NbaStatsSeasonType>(
          value: seasonType,
          options: NbaStatsSeasonType.values,
          label: (value) => value.label,
          onChanged: onSeason,
        ),
        _CompactDrop(
          value: team,
          values: teams,
          width: 130,
          hint: 'Select team',
          onChanged: onTeam,
        ),
        for (final item in const ['All', 'PG', 'SG', 'SF', 'PF', 'C'])
          _ToolbarChip(
            label: item == 'All' ? 'ALL POS' : item,
            selected: position == item,
            onTap: () => onPosition(item),
          ),
        const _ToolbarChip(label: '2025–26 DATA', selected: true),
      ],
    ),
  );
}

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({
    required this.active,
    required this.customViews,
    required this.onChanged,
    required this.onEdit,
  });

  final String active;
  final List<String> customViews;
  final ValueChanged<String> onChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _ToolbarSurface(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in [...nbaDefaultViews.keys, ...customViews])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _ToolbarChip(
                label: item,
                selected: active == item,
                onTap: () => onChanged(item),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Create or edit a custom view',
            onPressed: onEdit,
            icon: const Icon(Icons.add_box_outlined, color: _yellow, size: 20),
          ),
        ],
      ),
    ),
  );
}

class _ActionToolbar extends StatelessWidget {
  const _ActionToolbar({
    required this.basis,
    required this.identityMode,
    required this.controller,
    required this.compareCount,
    required this.favoriteOnly,
    required this.onBasis,
    required this.onIdentity,
    required this.onSearch,
    required this.onFilters,
    required this.onGlossary,
    required this.onCompare,
    required this.onChart,
    required this.onCopy,
    required this.onFavoriteOnly,
    required this.onDensityDown,
    required this.onDensityUp,
  });

  final NbaStatsBasis basis;
  final String identityMode;
  final TextEditingController controller;
  final int compareCount;
  final bool favoriteOnly;
  final ValueChanged<NbaStatsBasis> onBasis;
  final ValueChanged<String> onIdentity;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilters;
  final VoidCallback onGlossary;
  final VoidCallback onCompare;
  final VoidCallback onChart;
  final VoidCallback onCopy;
  final VoidCallback onFavoriteOnly;
  final VoidCallback onDensityDown;
  final VoidCallback onDensityUp;

  @override
  Widget build(BuildContext context) => _ToolbarSurface(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'SPORTS TERMINAL',
          style: TextStyle(
            color: _yellow,
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
          ),
        ),
        _Segmented<NbaStatsBasis>(
          value: basis,
          options: NbaStatsBasis.values,
          label: (value) => value.label,
          onChanged: onBasis,
          compact: true,
        ),
        SizedBox(
          width: 190,
          height: 38,
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            style: const TextStyle(color: _text, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search players…',
              hintStyle: const TextStyle(color: _muted),
              prefixIcon: const Icon(Icons.search, color: _muted, size: 18),
              filled: true,
              fillColor: _bg,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        _IconAction(
          icon: Icons.scatter_plot_rounded,
          tooltip: 'Chart studio',
          onTap: onChart,
        ),
        _IconAction(
          icon: Icons.compare_arrows_rounded,
          tooltip: 'Compare selected players ($compareCount)',
          onTap: onCompare,
          badge: compareCount,
        ),
        _IconAction(
          icon: favoriteOnly ? Icons.star_rounded : Icons.star_border_rounded,
          tooltip: 'Favorites only',
          onTap: onFavoriteOnly,
          active: favoriteOnly,
        ),
        _IconAction(
          icon: Icons.filter_alt_outlined,
          tooltip: 'Filters (F)',
          onTap: onFilters,
        ),
        _IconAction(
          icon: Icons.menu_book_outlined,
          tooltip: 'Stats glossary (G)',
          onTap: onGlossary,
        ),
        _IconAction(
          icon: Icons.copy_all_outlined,
          tooltip: 'Copy all filtered rows',
          onTap: onCopy,
        ),
        _CompactDrop(
          value: identityMode,
          values: const ['Initials', 'None'],
          width: 105,
          hint: 'Identity',
          onChanged: onIdentity,
        ),
        _IconAction(
          icon: Icons.text_decrease,
          tooltip: 'Smaller cells (W)',
          onTap: onDensityDown,
        ),
        _IconAction(
          icon: Icons.text_increase,
          tooltip: 'Larger cells (E)',
          onTap: onDensityUp,
        ),
      ],
    ),
  );
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({
    required this.rows,
    required this.metricKeys,
    required this.engine,
    required this.selected,
    required this.compareIds,
    required this.favorites,
    required this.density,
    required this.identityMode,
    required this.sortKey,
    required this.descending,
    required this.onSort,
    required this.onSelected,
    required this.onFavorite,
    required this.onCompare,
  });

  final List<NbaStatsRow> rows;
  final List<String> metricKeys;
  final NbaStatsWorkstationEngine engine;
  final NbaStatsRow? selected;
  final Set<String> compareIds;
  final Set<String> favorites;
  final double density;
  final String identityMode;
  final String sortKey;
  final bool descending;
  final ValueChanged<String> onSort;
  final ValueChanged<NbaStatsRow> onSelected;
  final ValueChanged<NbaStatsRow> onFavorite;
  final ValueChanged<NbaStatsRow> onCompare;

  @override
  Widget build(BuildContext context) {
    final rowHeight = 54.0 * density;
    final metricWidth = 82.0 * density;
    final rightWidth = metricWidth * metricKeys.length;
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(9),
      ),
      clipBehavior: Clip.antiAlias,
      child: rows.isEmpty
          ? const Center(
              child: Text(
                'No players match the current season, position and filters.',
                style: TextStyle(color: _muted),
              ),
            )
          : SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 270,
                    child: Column(
                      children: [
                        _IdentityHeader(height: 64 * density),
                        for (final row in rows)
                          _IdentityCell(
                            row: row,
                            height: rowHeight,
                            selected: selected?.playerId == row.playerId,
                            favorite: favorites.contains(row.playerId),
                            comparing: compareIds.contains(row.playerId),
                            identityMode: identityMode,
                            onTap: () => onSelected(row),
                            onFavorite: () => onFavorite(row),
                            onCompare: () => onCompare(row),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: math.max(rightWidth, 720),
                        child: Column(
                          children: [
                            _MetricsHeader(
                              keys: metricKeys,
                              width: metricWidth,
                              height: 64 * density,
                              engine: engine,
                              sortKey: sortKey,
                              descending: descending,
                              onSort: onSort,
                            ),
                            for (final row in rows)
                              _MetricsRow(
                                row: row,
                                keys: metricKeys,
                                width: metricWidth,
                                height: rowHeight,
                                engine: engine,
                                selected: selected?.playerId == row.playerId,
                                onTap: () => onSelected(row),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(
      color: _panel2,
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: const Row(
      children: [
        SizedBox(width: 28),
        Expanded(
          child: Text(
            'PLAYER',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
        ),
        Text(
          'TEAM · POS',
          style: TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _IdentityCell extends StatelessWidget {
  const _IdentityCell({
    required this.row,
    required this.height,
    required this.selected,
    required this.favorite,
    required this.comparing,
    required this.identityMode,
    required this.onTap,
    required this.onFavorite,
    required this.onCompare,
  });

  final NbaStatsRow row;
  final double height;
  final bool selected;
  final bool favorite;
  final bool comparing;
  final String identityMode;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => onTap(),
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2B3549) : _panel,
          border: const Border(bottom: BorderSide(color: _line, width: .6)),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: onCompare,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: comparing ? _yellow : const Color(0xFF607089),
                  ),
                  color: comparing
                      ? const Color(0x33FFCB45)
                      : Colors.transparent,
                ),
                child: comparing
                    ? const Icon(Icons.check, size: 12, color: _yellow)
                    : null,
              ),
            ),
            const SizedBox(width: 7),
            if (identityMode == 'Initials') ...[
              CircleAvatar(
                radius: math.min(17, height * .3),
                backgroundColor: const Color(0xFF33425B),
                child: Text(
                  _initials(row.player),
                  style: const TextStyle(
                    color: _text,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.player,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${row.team} · ${row.position}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              tooltip: favorite ? 'Remove favorite' : 'Favorite',
              onPressed: onFavorite,
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: favorite ? _yellow : _muted,
                size: 15,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetricsHeader extends StatelessWidget {
  const _MetricsHeader({
    required this.keys,
    required this.width,
    required this.height,
    required this.engine,
    required this.sortKey,
    required this.descending,
    required this.onSort,
  });

  final List<String> keys;
  final double width;
  final double height;
  final NbaStatsWorkstationEngine engine;
  final String sortKey;
  final bool descending;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: const BoxDecoration(
      color: _panel2,
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        for (final key in keys)
          InkWell(
            onTap: () => onSort(key),
            child: Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: _line, width: .5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    engine.metric(key).group.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          engine.metric(key).shortLabel,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sortKey == key ? _yellow : _text,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (sortKey == key)
                        Icon(
                          descending
                              ? Icons.arrow_drop_down
                              : Icons.arrow_drop_up,
                          color: _yellow,
                          size: 14,
                        ),
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

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.row,
    required this.keys,
    required this.width,
    required this.height,
    required this.engine,
    required this.selected,
    required this.onTap,
  });

  final NbaStatsRow row;
  final List<String> keys;
  final double width;
  final double height;
  final NbaStatsWorkstationEngine engine;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: height,
      color: selected ? const Color(0xFF2B3549) : _panel,
      child: Row(
        children: [
          for (final key in keys)
            Container(
              width: width,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: _line, width: .5),
                  bottom: BorderSide(color: _line, width: .6),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    engine.formatValue(key, row.value(key)),
                    style: const TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _PercentileMark(value: row.percentiles[key]),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _PlayerInspector extends StatelessWidget {
  const _PlayerInspector({
    required this.row,
    required this.metricKeys,
    required this.engine,
    required this.inComparison,
    required this.favorite,
    required this.onCompare,
    required this.onFavorite,
  });

  final NbaStatsRow? row;
  final List<String> metricKeys;
  final NbaStatsWorkstationEngine engine;
  final bool inComparison;
  final bool favorite;
  final VoidCallback? onCompare;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    if (row == null) {
      return const _DarkSurface(
        child: Center(
          child: Text(
            'Hover or select a player to inspect every visible metric.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }
    return _DarkSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _panel2,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: const Color(0xFF394965),
                  child: Text(
                    _initials(row!.player),
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row!.player,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${row!.team} · ${row!.position}',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onFavorite,
                  icon: Icon(
                    favorite ? Icons.star : Icons.star_border,
                    color: favorite ? _yellow : _muted,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCompare,
                    icon: Icon(
                      inComparison ? Icons.check : Icons.compare_arrows,
                      size: 16,
                    ),
                    label: Text(inComparison ? 'Selected' : 'Compare'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _yellow,
                      side: const BorderSide(color: _line),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: [
                  for (final key in metricKeys)
                    _InspectorMetric(
                      metric: engine.metric(key),
                      value: engine.formatValue(key, row!.value(key)),
                      percentile: row!.percentiles[key],
                    ),
                  if (row!.possessionsEstimated)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Possession-based fields use the displayed transparent estimate where direct possessions are absent.',
                        style: TextStyle(
                          color: _yellow,
                          fontSize: 9,
                          height: 1.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorMetric extends StatelessWidget {
  const _InspectorMetric({
    required this.metric,
    required this.value,
    required this.percentile,
  });
  final NbaStatMetric metric;
  final String value;
  final double? percentile;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: _line),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            metric.shortLabel,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _text,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 7),
        _PercentilePill(value: percentile),
      ],
    ),
  );
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({
    required this.start,
    required this.end,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.pageSize,
    required this.estimatedPossessions,
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
  final bool estimatedPossessions;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => _ToolbarSurface(
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: _yellow,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$start–$end OF $total RECORDS',
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
        if (estimatedPossessions) ...[
          const SizedBox(width: 12),
          const Flexible(
            child: Text(
              '* possession values may use transparent estimates',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _yellow, fontSize: 9),
            ),
          ),
        ],
        const Spacer(),
        _CompactDrop<int>(
          value: pageSize,
          values: const [25, 50, 100, 250],
          width: 76,
          hint: 'Rows',
          onChanged: onPageSize,
        ),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, color: _text),
        ),
        Text(
          '${page + 1}/$totalPages',
          style: const TextStyle(
            color: _text,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, color: _text),
        ),
      ],
    ),
  );
}

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({required this.filters, required this.metrics});
  final NbaStatsFilters filters;
  final List<NbaStatMetric> metrics;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late final TextEditingController minGames;
  late final TextEditingController minMinutes;
  late final TextEditingController minAge;
  late final TextEditingController maxAge;
  late final TextEditingController metricMin;
  late final TextEditingController metricMax;
  String? metricKey;

  @override
  void initState() {
    super.initState();
    minGames = TextEditingController(
      text: widget.filters.minGames.toStringAsFixed(0),
    );
    minMinutes = TextEditingController(
      text: widget.filters.minMinutes.toStringAsFixed(0),
    );
    minAge = TextEditingController(
      text: widget.filters.minAge?.toString() ?? '',
    );
    maxAge = TextEditingController(
      text: widget.filters.maxAge?.toString() ?? '',
    );
    metricMin = TextEditingController(
      text: widget.filters.metricMinimum?.toString() ?? '',
    );
    metricMax = TextEditingController(
      text: widget.filters.metricMaximum?.toString() ?? '',
    );
    metricKey = widget.filters.metricKey;
  }

  @override
  void dispose() {
    for (final controller in [
      minGames,
      minMinutes,
      minAge,
      maxAge,
      metricMin,
      metricMax,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _panel,
    title: const Text('Inline filters', style: TextStyle(color: _text)),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Minimum games',
                    controller: minGames,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    label: 'Minimum minutes',
                    controller: minMinutes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(label: 'Minimum age', controller: minAge),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(label: 'Maximum age', controller: maxAge),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: metricKey,
              dropdownColor: _panel2,
              style: const TextStyle(color: _text),
              decoration: _darkInput('Metric filter'),
              items: [
                for (final metric in widget.metrics)
                  DropdownMenuItem(
                    value: metric.key,
                    child: Text('${metric.group} · ${metric.label}'),
                  ),
              ],
              onChanged: (value) => setState(() => metricKey = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Metric minimum',
                    controller: metricMin,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    label: 'Metric maximum',
                    controller: metricMax,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () =>
            Navigator.of(context).pop(const NbaStatsFilters(minGames: 1)),
        child: const Text('Reset'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(
          widget.filters.copyWith(
            minGames: double.tryParse(minGames.text) ?? 0,
            minMinutes: double.tryParse(minMinutes.text) ?? 0,
            minAge: double.tryParse(minAge.text),
            maxAge: double.tryParse(maxAge.text),
            clearMinAge: minAge.text.trim().isEmpty,
            clearMaxAge: maxAge.text.trim().isEmpty,
            metricKey: metricKey,
            metricMinimum: double.tryParse(metricMin.text),
            metricMaximum: double.tryParse(metricMax.text),
            clearMetric: metricKey == null,
          ),
        ),
        child: const Text('Apply filters'),
      ),
    ],
  );
}

class _GlossaryDialog extends StatelessWidget {
  const _GlossaryDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _panel,
    title: const Text('Stats glossary', style: TextStyle(color: _text)),
    content: SizedBox(
      width: 720,
      height: 620,
      child: ListView(
        children: [
          for (final group
              in nbaStatMetrics.map((metric) => metric.group).toSet()) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
              child: Text(
                group.toUpperCase(),
                style: const TextStyle(
                  color: _yellow,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            for (final metric in nbaStatMetrics.where(
              (metric) => metric.group == group,
            ))
              ListTile(
                dense: true,
                title: Text(
                  '${metric.shortLabel} · ${metric.label}',
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  [
                    metric.description,
                    metric.sourceNote,
                  ].where((item) => item.isNotEmpty).join(' '),
                  style: const TextStyle(color: _muted),
                ),
              ),
          ],
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}

class _CustomViewResult {
  const _CustomViewResult(this.name, this.keys);
  final String name;
  final List<String> keys;
}

class _CustomViewDialog extends StatefulWidget {
  const _CustomViewDialog({
    required this.initialName,
    required this.initialKeys,
  });
  final String initialName;
  final List<String> initialKeys;

  @override
  State<_CustomViewDialog> createState() => _CustomViewDialogState();
}

class _CustomViewDialogState extends State<_CustomViewDialog> {
  late final TextEditingController name;
  late List<String> selected;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initialName);
    selected = [...widget.initialKeys];
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _panel,
    title: const Text('Custom stat view', style: TextStyle(color: _text)),
    content: SizedBox(
      width: 680,
      height: 650,
      child: Column(
        children: [
          TextField(
            controller: name,
            style: const TextStyle(color: _text),
            decoration: _darkInput('View name'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Select metrics below. Drag selected metrics to reorder columns.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      for (final metric in nbaStatMetrics)
                        CheckboxListTile(
                          dense: true,
                          value: selected.contains(metric.key),
                          activeColor: _yellow,
                          checkColor: _bg,
                          title: Text(
                            '${metric.group} · ${metric.shortLabel}',
                            style: const TextStyle(color: _text, fontSize: 12),
                          ),
                          subtitle: Text(
                            metric.label,
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              if (!selected.contains(metric.key)) {
                                selected.add(metric.key);
                              }
                            } else {
                              selected.remove(metric.key);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(color: _line),
                Expanded(
                  child: ReorderableListView(
                    children: [
                      for (final key in selected)
                        ListTile(
                          key: ValueKey(key),
                          dense: true,
                          leading: const Icon(Icons.drag_handle, color: _muted),
                          title: Text(
                            nbaStatMetrics
                                .firstWhere((metric) => metric.key == key)
                                .shortLabel,
                            style: const TextStyle(color: _text),
                          ),
                        ),
                    ],
                    onReorder: (oldIndex, newIndex) => setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = selected.removeAt(oldIndex);
                      selected.insert(newIndex, item);
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: selected.isEmpty
            ? null
            : () {
                final resolved = name.text.trim().isEmpty
                    ? 'Custom ${DateTime.now().millisecondsSinceEpoch % 1000}'
                    : name.text.trim();
                Navigator.of(
                  context,
                ).pop(_CustomViewResult(resolved, selected));
              },
        child: const Text('Save view'),
      ),
    ],
  );
}

class _ComparisonDialog extends StatelessWidget {
  const _ComparisonDialog({
    required this.rows,
    required this.metrics,
    required this.engine,
  });
  final List<NbaStatsRow> rows;
  final List<String> metrics;
  final NbaStatsWorkstationEngine engine;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _panel,
    title: Text(
      'Side-by-side comparison · ${rows.length} players',
      style: const TextStyle(color: _text),
    ),
    content: SizedBox(
      width: 980,
      height: 650,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 180 + rows.length * 170,
          child: ListView(
            children: [
              Row(
                children: [
                  const SizedBox(width: 180),
                  for (final row in rows)
                    SizedBox(
                      width: 170,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          row.player,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (final key in metrics)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _line)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 180,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            engine.metric(key).label,
                            style: const TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      for (final row in rows)
                        SizedBox(
                          width: 170,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                Text(
                                  engine.formatValue(key, row.value(key)),
                                  style: const TextStyle(
                                    color: _text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                _PercentilePill(value: row.percentiles[key]),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}

class _ChartStudio extends StatefulWidget {
  const _ChartStudio({
    required this.rows,
    required this.snapshot,
    required this.engine,
    required this.selected,
  });
  final List<NbaStatsRow> rows;
  final NbaTerminalSeedSnapshot snapshot;
  final NbaStatsWorkstationEngine engine;
  final NbaStatsRow? selected;

  @override
  State<_ChartStudio> createState() => _ChartStudioState();
}

class _ChartStudioState extends State<_ChartStudio> {
  String mode = 'Scatter';
  String x = 'pts';
  String y = 'ts_pct';
  String trendMetric = 'pts';
  String? playerId;

  @override
  void initState() {
    super.initState();
    playerId =
        widget.selected?.playerId ??
        (widget.rows.isEmpty ? null : widget.rows.first.playerId);
  }

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final row in widget.rows)
        if (row.value(x) != null && row.value(y) != null)
          _ScatterPoint(row.value(x)!, row.value(y)!, row.player),
    ];
    final logs = widget.snapshot.playerGameLogsTop
        .where((row) => _rawText(row, const ['player_id', 'id']) == playerId)
        .toList();
    final trend = <double>[];
    for (final row in logs.reversed) {
      final value = _rawNumber(row, _gameMetricAliases(trendMetric));
      if (value != null) trend.add(value);
    }

    return AlertDialog(
      backgroundColor: _panel,
      title: const Text('Chart Studio', style: TextStyle(color: _text)),
      content: SizedBox(
        width: 980,
        height: 650,
        child: Column(
          children: [
            Row(
              children: [
                _Segmented<String>(
                  value: mode,
                  options: const ['Scatter', 'Game Trend'],
                  label: (value) => value,
                  onChanged: (value) => setState(() => mode = value),
                ),
                const SizedBox(width: 12),
                if (mode == 'Scatter') ...[
                  Expanded(
                    child: _MetricDrop(
                      value: x,
                      label: 'X axis',
                      onChanged: (value) => setState(() => x = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricDrop(
                      value: y,
                      label: 'Y axis',
                      onChanged: (value) => setState(() => y = value),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: playerId,
                      dropdownColor: _panel2,
                      style: const TextStyle(color: _text),
                      decoration: _darkInput('Player'),
                      items: [
                        for (final row in widget.rows.take(100))
                          DropdownMenuItem(
                            value: row.playerId,
                            child: Text(row.player),
                          ),
                      ],
                      onChanged: (value) => setState(() => playerId = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricDrop(
                      value: trendMetric,
                      label: 'Game metric',
                      limited: const [
                        'pts',
                        'reb',
                        'ast',
                        'stl',
                        'blk',
                        'plus_minus',
                      ],
                      onChanged: (value) => setState(() => trendMetric = value),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _line),
                ),
                padding: const EdgeInsets.all(18),
                child: CustomPaint(
                  painter: mode == 'Scatter'
                      ? _ScatterPainter(
                          points: points,
                          xLabel: widget.engine.metric(x).shortLabel,
                          yLabel: widget.engine.metric(y).shortLabel,
                        )
                      : _LinePainter(
                          values: trend,
                          label: widget.engine.metric(trendMetric).shortLabel,
                        ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mode == 'Scatter'
                  ? '${points.length} filtered players · chart responds to all workstation filters.'
                  : '${trend.length} available player-game rows · no missing games are fabricated.',
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ScatterPoint {
  const _ScatterPoint(this.x, this.y, this.label);
  final double x;
  final double y;
  final String label;
}

class _ScatterPainter extends CustomPainter {
  const _ScatterPainter({
    required this.points,
    required this.xLabel,
    required this.yLabel,
  });
  final List<_ScatterPoint> points;
  final String xLabel;
  final String yLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = _line
      ..strokeWidth = 1;
    final dot = Paint()..color = _cyan.withValues(alpha: .75);
    const left = 50.0;
    const bottom = 34.0;
    final plot = Rect.fromLTRB(left, 16, size.width - 12, size.height - bottom);
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axis,
    );
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axis,
    );
    if (points.isEmpty) return;
    final minX = points.map((point) => point.x).reduce(math.min);
    final maxX = points.map((point) => point.x).reduce(math.max);
    final minY = points.map((point) => point.y).reduce(math.min);
    final maxY = points.map((point) => point.y).reduce(math.max);
    for (final point in points) {
      final px =
          plot.left +
          (point.x - minX) / math.max(.000001, maxX - minX) * plot.width;
      final py =
          plot.bottom -
          (point.y - minY) / math.max(.000001, maxY - minY) * plot.height;
      canvas.drawCircle(Offset(px, py), 4, dot);
    }
    _paintLabel(canvas, xLabel, Offset(plot.center.dx - 12, size.height - 18));
    _paintLabel(canvas, yLabel, Offset(6, plot.center.dy));
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.xLabel != xLabel ||
      oldDelegate.yLabel != yLabel;
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.values, required this.label});
  final List<double> values;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = _line
      ..strokeWidth = 1;
    final line = Paint()
      ..color = _yellow
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = _yellow;
    const left = 50.0;
    const bottom = 34.0;
    final plot = Rect.fromLTRB(left, 16, size.width - 12, size.height - bottom);
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axis,
    );
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axis,
    );
    if (values.isEmpty) return;
    final minY = values.reduce(math.min);
    final maxY = values.reduce(math.max);
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final px =
          plot.left +
          (values.length == 1 ? .5 : index / (values.length - 1)) * plot.width;
      final py =
          plot.bottom -
          (values[index] - minY) / math.max(.000001, maxY - minY) * plot.height;
      if (index == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
      canvas.drawCircle(Offset(px, py), 3.2, dot);
    }
    canvas.drawPath(path, line);
    _paintLabel(canvas, label, Offset(6, plot.top));
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.label != label;
}

void _paintLabel(Canvas canvas, String text, Offset offset) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: _muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
}

class _MetricDrop extends StatelessWidget {
  const _MetricDrop({
    required this.value,
    required this.label,
    required this.onChanged,
    this.limited,
  });
  final String value;
  final String label;
  final ValueChanged<String> onChanged;
  final List<String>? limited;

  @override
  Widget build(BuildContext context) {
    final metrics =
        limited ?? nbaStatMetrics.map((metric) => metric.key).toList();
    return DropdownButtonFormField<String>(
      value: metrics.contains(value) ? value : metrics.first,
      dropdownColor: _panel2,
      style: const TextStyle(color: _text),
      decoration: _darkInput(label),
      items: [
        for (final key in metrics)
          DropdownMenuItem(
            value: key,
            child: Text(
              nbaStatMetrics.firstWhere((metric) => metric.key == key).label,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _YearControl extends StatelessWidget {
  const _YearControl();
  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    decoration: BoxDecoration(
      color: _panel3,
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 9),
          child: Icon(Icons.chevron_left, color: _muted, size: 16),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '2025–26',
            style: TextStyle(
              color: _text,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 9),
          child: Icon(Icons.chevron_right, color: _muted, size: 16),
        ),
      ],
    ),
  );
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
    this.compact = false,
  });
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _panel3,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          InkWell(
            onTap: () => onChanged(option),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 7 : 11,
                vertical: compact ? 5 : 7,
              ),
              decoration: BoxDecoration(
                color: value == option
                    ? const Color(0xFF4A4433)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: value == option
                    ? Border.all(color: const Color(0xFF8E7736))
                    : null,
              ),
              child: Text(
                label(option),
                style: TextStyle(
                  color: value == option ? _yellow : _muted,
                  fontSize: compact ? 8 : 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF4A4433) : _panel3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? const Color(0xFF8E7736) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _yellow : _muted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _CompactDrop<T> extends StatelessWidget {
  const _CompactDrop({
    required this.value,
    required this.values,
    required this.width,
    required this.hint,
    required this.onChanged,
  });
  final T value;
  final List<T> values;
  final double width;
  final String hint;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 36,
    child: DropdownButtonFormField<T>(
      value: values.contains(value) ? value : values.first,
      dropdownColor: _panel2,
      style: const TextStyle(
        color: _text,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _panel3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        for (final item in values)
          DropdownMenuItem<T>(
            value: item,
            child: Text('$item', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
    this.active = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;
  final bool active;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4A4433) : _panel3,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? const Color(0xFF8E7736) : _line),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(icon, color: active ? _yellow : _muted, size: 18),
            ),
            if (badge > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _yellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: _bg,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ToolbarSurface extends StatelessWidget {
  const _ToolbarSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: _line),
    ),
    child: child,
  );
}

class _DarkSurface extends StatelessWidget {
  const _DarkSurface({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: _line),
    ),
    child: child,
  );
}

class _PercentileMark extends StatelessWidget {
  const _PercentileMark({required this.value});
  final double? value;
  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox(height: 9);
    final color = value! >= 80
        ? _yellow
        : value! >= 55
        ? _green
        : value! <= 20
        ? _cyan
        : _muted;
    return Text(
      value!.round().toString(),
      style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900),
    );
  }
}

class _PercentilePill extends StatelessWidget {
  const _PercentilePill({required this.value});
  final double? value;
  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox(width: 30);
    final color = value! >= 80
        ? _yellow
        : value! >= 55
        ? _green
        : value! <= 20
        ? _cyan
        : _muted;
    return Container(
      width: 34,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value!.round().toString(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: const TextStyle(color: _text),
    decoration: _darkInput(label),
  );
}

InputDecoration _darkInput(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: _muted),
  filled: true,
  fillColor: _bg,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _line),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _line),
  ),
);

String _initials(String value) {
  final parts = value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'NBA';
  return parts.take(2).map((part) => part[0]).join().toUpperCase();
}

String _rawText(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

double? _rawNumber(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value.toDouble();
    if (value != null) {
      final parsed = double.tryParse(
        value.toString().replaceAll(',', '').replaceAll('%', ''),
      );
      if (parsed != null) return parsed;
    }
  }
  return null;
}

List<String> _gameMetricAliases(String metric) => switch (metric) {
  'pts' => const ['pts', 'points'],
  'reb' => const ['trb', 'reb', 'rebounds'],
  'ast' => const ['ast', 'assists'],
  'stl' => const ['stl', 'steals'],
  'blk' => const ['blk', 'blocks'],
  'plus_minus' => const ['plus_minus', 'plusMinus'],
  _ => [metric],
};
