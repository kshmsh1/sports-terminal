import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import 'product_nba_entity_pages_v2.dart';

const _asPanel = Color(0xFF0F151C);
const _asPanel2 = Color(0xFF141C25);
const _asPanel3 = Color(0xFF1A2430);
const _asLine = Color(0xFF263342);
const _asSoftLine = Color(0xFF1B2632);
const _asText = Color(0xFFE8EDF3);
const _asMuted = Color(0xFF8895A5);
const _asFaint = Color(0xFF566273);
const _asBlue = Color(0xFF63A9FF);
const _asAmber = Color(0xFFE2B866);
const _asGreen = Color(0xFF69C99A);

class ProductNbaAdvancedStatsDocumentScreen extends StatefulWidget {
  const ProductNbaAdvancedStatsDocumentScreen({super.key});

  @override
  State<ProductNbaAdvancedStatsDocumentScreen> createState() =>
      _ProductNbaAdvancedStatsDocumentScreenState();
}

class _ProductNbaAdvancedStatsDocumentScreenState
    extends State<ProductNbaAdvancedStatsDocumentScreen> {
  static const _favoritesKey = 'sports_terminal.advanced_stats.favorites.v1';
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final NbaTerminalMetricResolver _resolver = const NbaTerminalMetricResolver();
  final ProductLocalStore _store = const ProductLocalStore();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _minGames = TextEditingController(text: '1');

  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _familyId = 'defense_hustle';
  String _team = 'All';
  String _position = 'All';
  String _sortKey = 'spg';
  bool _descending = true;
  int _limit = 100;
  final Set<String> _expanded = {};
  final Set<String> _favorites = {};
  final Set<String> _compareIds = {};

  @override
  void initState() {
    super.initState();
    _restoreFavorites();
  }

  @override
  void dispose() {
    _search.dispose();
    _minGames.dispose();
    super.dispose();
  }

  Future<void> _restoreFavorites() async {
    final raw = await _store.loadString(_favoritesKey);
    if (!mounted || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        setState(() => _favorites.addAll(decoded.map((value) => value.toString())));
      }
    } catch (_) {}
  }

  Future<void> _persistFavorites() =>
      _store.saveString(_favoritesKey, jsonEncode(_favorites.toList()..sort()));

  NbaTerminalStatFamily get _family => nbaTerminalFamily(_familyId);
  List<String> get _metricKeys => nbaVisibleMetricKeys(_family, _expanded);

  void _changeFamily(String value) {
    final family = nbaTerminalFamily(value);
    setState(() {
      _familyId = value;
      _expanded.clear();
      _sortKey = family.metrics.first;
      _descending = true;
      _limit = 100;
    });
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (!_expanded.add(key)) _expanded.remove(key);
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
      while (_compareIds.length > 6) {
        _compareIds.remove(_compareIds.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AdvancedPanel(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _AdvancedPanel(child: Text('Advanced Stats unavailable: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        final data = snapshot.data!;
        var rows = _engine.buildRows(data, basis: _basis, seasonType: _seasonType);
        final teams = <String>{'All'};
        for (final row in rows) {
          teams.addAll(row.team.split(RegExp(r'[,/ ]+')).where((value) => value.isNotEmpty && value != '—'));
        }
        final query = _search.text.trim().toLowerCase();
        final minGames = double.tryParse(_minGames.text) ?? 0;
        rows = rows.where((row) {
          if (query.isNotEmpty && !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) return false;
          if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
          if (_position != 'All' && row.position != _position) return false;
          if ((row.value('gp') ?? 0) < minGames) return false;
          return true;
        }).toList();
        rows.sort((a, b) {
          final left = _resolver.value(a, _sortKey);
          final right = _resolver.value(b, _sortKey);
          if (left == null && right == null) return a.player.compareTo(b.player);
          if (left == null) return 1;
          if (right == null) return -1;
          return _descending ? right.compareTo(left) : left.compareTo(right);
        });
        final visible = rows.take(_limit).toList();
        final compared = rows.where((row) => _compareIds.contains(row.playerId)).toList();
        var populated = 0;
        for (final key in _metricKeys) {
          if (rows.any((row) => _resolver.isAvailable(row, key))) populated++;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdvancedHero(data: data, rowCount: rows.length),
            const SizedBox(height: 12),
            _FamilyStrip(selected: _familyId, onSelected: _changeFamily),
            const SizedBox(height: 12),
            _Controls(
              familyId: _familyId,
              basis: _basis,
              seasonType: _seasonType,
              team: _team,
              teams: teams.toList()..sort(),
              position: _position,
              search: _search,
              minGames: _minGames,
              favoriteOnly: false,
              compareCount: _compareIds.length,
              onFamily: _changeFamily,
              onBasis: (value) => setState(() => _basis = value),
              onSeason: (value) => setState(() => _seasonType = value),
              onTeam: (value) => setState(() => _team = value),
              onPosition: (value) => setState(() => _position = value),
              onChanged: () => setState(() => _limit = 100),
              onClearCompare: () => setState(_compareIds.clear),
            ),
            const SizedBox(height: 12),
            _FamilySummary(family: _family, populated: populated, total: _metricKeys.length),
            const SizedBox(height: 12),
            _AdvancedTable(
              rows: visible,
              metricKeys: _metricKeys,
              resolver: _resolver,
              sortKey: _sortKey,
              descending: _descending,
              expanded: _expanded,
              favorites: _favorites,
              compareIds: _compareIds,
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
            if (rows.length > visible.length) ...[
              const SizedBox(height: 10),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _limit += 100),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Show more · ${visible.length}/${rows.length}'),
                ),
              ),
            ],
            if (compared.length >= 2) ...[
              const SizedBox(height: 14),
              _InlineCompare(rows: compared, keys: _metricKeys, resolver: _resolver),
            ],
            const SizedBox(height: 14),
            _Glossary(activeFamily: _family),
          ],
        );
      },
    );
  }
}

class _AdvancedHero extends StatelessWidget {
  const _AdvancedHero({required this.data, required this.rowCount});
  final NbaTerminalSeedSnapshot data;
  final int rowCount;
  @override
  Widget build(BuildContext context) => _AdvancedPanel(
        child: LayoutBuilder(builder: (context, constraints) {
          final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NBA / ADVANCED STATISTICS', style: TextStyle(color: _asBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 5),
            const Text('Advanced Stats Workstation', style: TextStyle(color: _asText, fontSize: 29, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text('${data.supportedSeason} · $rowCount player rows · ${nbaTerminalMetrics.length} registered metrics · source-aware availability', style: const TextStyle(color: _asMuted, fontSize: 10)),
            const SizedBox(height: 7),
            const Text('All non-basic statistical infrastructure lives here: defense/hustle, playmaking, rebounding, efficiency, impact, aggregate models, movement, clutch, shot profile, play type, gravity/creation, physical profile, discipline and availability.', style: TextStyle(color: _asMuted, height: 1.4)),
          ]);
          final tags = Wrap(spacing: 7, runSpacing: 7, children: [
            _Tag('${nbaTerminalStatFamilies.length} FAMILIES', _asBlue),
            _Tag('${nbaTerminalMetrics.length} METRICS', _asGreen),
            const _Tag('— = NOT AVAILABLE', _asFaint),
            const _Tag('OUTER PAGE SCROLL', _asAmber),
          ]);
          if (constraints.maxWidth < 850) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 12), tags]);
          return Row(children: [Expanded(child: copy), const SizedBox(width: 20), Flexible(child: tags)]);
        }),
      );
}

class _FamilyStrip extends StatelessWidget {
  const _FamilyStrip({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => _AdvancedPanel(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final family in nbaTerminalStatFamilies.where((family) => family.id != 'basic'))
            ChoiceChip(
              label: Text(family.label),
              selected: selected == family.id,
              onSelected: (_) => onSelected(family.id),
            ),
        ]),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.familyId,
    required this.basis,
    required this.seasonType,
    required this.team,
    required this.teams,
    required this.position,
    required this.search,
    required this.minGames,
    required this.favoriteOnly,
    required this.compareCount,
    required this.onFamily,
    required this.onBasis,
    required this.onSeason,
    required this.onTeam,
    required this.onPosition,
    required this.onChanged,
    required this.onClearCompare,
  });
  final String familyId;
  final NbaStatsBasis basis;
  final NbaStatsSeasonType seasonType;
  final String team;
  final List<String> teams;
  final String position;
  final TextEditingController search;
  final TextEditingController minGames;
  final bool favoriteOnly;
  final int compareCount;
  final ValueChanged<String> onFamily;
  final ValueChanged<NbaStatsBasis> onBasis;
  final ValueChanged<NbaStatsSeasonType> onSeason;
  final ValueChanged<String> onTeam;
  final ValueChanged<String> onPosition;
  final VoidCallback onChanged;
  final VoidCallback onClearCompare;

  @override
  Widget build(BuildContext context) => _AdvancedPanel(
        padding: const EdgeInsets.all(10),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
          _Drop<String>(
            label: 'STAT FAMILY', value: familyId, width: 230,
            items: [for (final item in nbaTerminalStatFamilies) DropdownMenuItem(value: item.id, child: Text(item.label))],
            onChanged: onFamily,
          ),
          _Drop<NbaStatsSeasonType>(
            label: 'SEGMENT', value: seasonType, width: 150,
            items: const [DropdownMenuItem(value: NbaStatsSeasonType.regular, child: Text('Regular Season')), DropdownMenuItem(value: NbaStatsSeasonType.playoffs, child: Text('Playoffs'))],
            onChanged: onSeason,
          ),
          _Drop<NbaStatsBasis>(
            label: 'RATE BASIS', value: basis, width: 140,
            items: [for (final item in NbaStatsBasis.values) DropdownMenuItem(value: item, child: Text(item.label))],
            onChanged: onBasis,
          ),
          _Drop<String>(
            label: 'TEAM', value: teams.contains(team) ? team : 'All', width: 105,
            items: [for (final item in teams) DropdownMenuItem(value: item, child: Text(item))], onChanged: onTeam,
          ),
          _Drop<String>(
            label: 'POSITION', value: position, width: 100,
            items: [for (final item in const ['All', 'PG', 'SG', 'SF', 'PF', 'C', 'G', 'F']) DropdownMenuItem(value: item, child: Text(item))], onChanged: onPosition,
          ),
          _Input(label: 'MIN GP', width: 75, controller: minGames, onChanged: (_) => onChanged()),
          _Input(label: 'PLAYER SEARCH', width: 210, controller: search, onChanged: (_) => onChanged(), icon: Icons.search_rounded),
          if (compareCount > 0)
            OutlinedButton.icon(onPressed: onClearCompare, icon: const Icon(Icons.clear_all_rounded), label: Text('Clear compare ($compareCount)')),
        ]),
      );
}

class _FamilySummary extends StatelessWidget {
  const _FamilySummary({required this.family, required this.populated, required this.total});
  final NbaTerminalStatFamily family;
  final int populated;
  final int total;
  @override
  Widget build(BuildContext context) => _AdvancedPanel(
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(family.label.toUpperCase(), style: const TextStyle(color: _asBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(family.description, style: const TextStyle(color: _asMuted, fontSize: 10)),
          ])),
          _Tag('$populated/$total POPULATED', populated == total ? _asGreen : _asAmber),
        ]),
      );
}

class _AdvancedTable extends StatelessWidget {
  const _AdvancedTable({
    required this.rows,
    required this.metricKeys,
    required this.resolver,
    required this.sortKey,
    required this.descending,
    required this.expanded,
    required this.favorites,
    required this.compareIds,
    required this.onSort,
    required this.onExpand,
    required this.onFavorite,
    required this.onCompare,
  });
  final List<NbaStatsRow> rows;
  final List<String> metricKeys;
  final NbaTerminalMetricResolver resolver;
  final String sortKey;
  final bool descending;
  final Set<String> expanded;
  final Set<String> favorites;
  final Set<String> compareIds;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onExpand;
  final ValueChanged<NbaStatsRow> onFavorite;
  final ValueChanged<NbaStatsRow> onCompare;

  @override
  Widget build(BuildContext context) => _AdvancedPanel(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 1000 || metricKeys.length > 13) {
            return Column(children: [
              for (final row in rows)
                _AdvancedPlayerCard(
                  row: row,
                  metricKeys: metricKeys,
                  resolver: resolver,
                  favorite: favorites.contains(row.playerId),
                  comparing: compareIds.contains(row.playerId),
                  onFavorite: () => onFavorite(row),
                  onCompare: () => onCompare(row),
                ),
            ]);
          }
          return Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const FlexColumnWidth(2.6),
              1: const FlexColumnWidth(.8),
              for (var i = 0; i < metricKeys.length; i++) i + 2: const FlexColumnWidth(.74),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: _asPanel3),
                children: [
                  const _Header('PLAYER'),
                  const _Header('TEAM'),
                  for (final key in metricKeys)
                    _MetricHeader(
                      keyName: key,
                      selected: key == sortKey,
                      descending: descending,
                      expanded: expanded.contains(key),
                      onSort: () => onSort(key),
                      onExpand: (nbaTerminalMetricByKey[key]?.children.isNotEmpty ?? false) ? () => onExpand(key) : null,
                    ),
                ],
              ),
              for (var index = 0; index < rows.length; index++)
                TableRow(
                  decoration: BoxDecoration(color: index.isEven ? _asPanel : const Color(0xFF0D131A), border: const Border(bottom: BorderSide(color: _asSoftLine, width: .5))),
                  children: [
                    _PlayerCell(
                      row: rows[index], favorite: favorites.contains(rows[index].playerId), comparing: compareIds.contains(rows[index].playerId),
                      onFavorite: () => onFavorite(rows[index]), onCompare: () => onCompare(rows[index]),
                    ),
                    _TeamCell(rows[index].team),
                    for (final key in metricKeys) _Value(resolver.format(rows[index], key), available: resolver.isAvailable(rows[index], key)),
                  ],
                ),
            ],
          );
        }),
      );
}

class _AdvancedPlayerCard extends StatelessWidget {
  const _AdvancedPlayerCard({required this.row, required this.metricKeys, required this.resolver, required this.favorite, required this.comparing, required this.onFavorite, required this.onCompare});
  final NbaStatsRow row;
  final List<String> metricKeys;
  final NbaTerminalMetricResolver resolver;
  final bool favorite;
  final bool comparing;
  final VoidCallback onFavorite;
  final VoidCallback onCompare;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _asLine, width: .5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(onPressed: onCompare, icon: Icon(comparing ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: comparing ? _asBlue : _asMuted, size: 18)),
            Expanded(child: InkWell(onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player), child: Text(row.player, style: const TextStyle(color: _asBlue, fontSize: 13, fontWeight: FontWeight.w900)))),
            _LinkedTeams(value: row.team),
            IconButton(onPressed: onFavorite, icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded, color: favorite ? _asAmber : _asMuted, size: 18)),
          ]),
          const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 7, children: [
            for (final key in metricKeys)
              Container(
                width: 96,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: _asPanel2, border: Border.all(color: _asSoftLine)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nbaTerminalMetricByKey[key]?.shortLabel ?? key.toUpperCase(), style: const TextStyle(color: _asMuted, fontSize: 7, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(resolver.format(row, key), style: TextStyle(color: resolver.isAvailable(row, key) ? _asText : _asFaint, fontSize: 12, fontWeight: FontWeight.w900)),
                ]),
              ),
          ]),
        ]),
      );
}

class _InlineCompare extends StatelessWidget {
  const _InlineCompare({required this.rows, required this.keys, required this.resolver});
  final List<NbaStatsRow> rows;
  final List<String> keys;
  final NbaTerminalMetricResolver resolver;
  @override
  Widget build(BuildContext context) => _AdvancedPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PLAYER COMPARISON', style: TextStyle(color: _asAmber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 10),
          for (final key in keys)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _asSoftLine, width: .5))),
              child: Row(children: [
                SizedBox(width: 125, child: Text(nbaTerminalMetricByKey[key]?.shortLabel ?? key.toUpperCase(), style: const TextStyle(color: _asBlue, fontSize: 9, fontWeight: FontWeight.w900))),
                for (final row in rows)
                  Expanded(child: Column(children: [Text(row.player, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _asMuted, fontSize: 8)), const SizedBox(height: 2), Text(resolver.format(row, key), style: const TextStyle(color: _asText, fontSize: 10, fontWeight: FontWeight.w900))])),
              ]),
            ),
        ]),
      );
}

class _Glossary extends StatelessWidget {
  const _Glossary({required this.activeFamily});
  final NbaTerminalStatFamily activeFamily;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<NbaTerminalMetric>>{};
    for (final metric in nbaTerminalMetrics) {
      groups.putIfAbsent(metric.group, () => []).add(metric);
    }
    return _AdvancedPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ADVANCED STAT GLOSSARY', style: TextStyle(color: _asText, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('Every registered metric remains discoverable even when the active source does not populate it. Source-gated fields display — rather than fabricated values.', style: TextStyle(color: _asMuted, height: 1.4)),
        const SizedBox(height: 12),
        for (final entry in groups.entries.where((entry) => entry.key != 'Basic')) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(entry.key.toUpperCase(), style: TextStyle(color: entry.value.any((metric) => activeFamily.metrics.contains(metric.key)) ? _asBlue : _asAmber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .7)),
          ),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
            final gap = 7.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final metric in entry.value)
                SizedBox(width: width, child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _asPanel2, border: Border.all(color: _asSoftLine)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Text(metric.shortLabel, style: const TextStyle(color: _asBlue, fontSize: 9, fontWeight: FontWeight.w900)), const SizedBox(width: 6), Expanded(child: Text(metric.label, style: const TextStyle(color: _asText, fontSize: 9, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)), if (metric.providerNative) const Text('SOURCE', style: TextStyle(color: _asFaint, fontSize: 7, fontWeight: FontWeight.w900))]),
                  const SizedBox(height: 4),
                  Text(metric.description, style: const TextStyle(color: _asMuted, fontSize: 8.5, height: 1.35)),
                ]))),
            ]);
          }),
        ],
      ]),
    );
  }
}

class _PlayerCell extends StatelessWidget {
  const _PlayerCell({required this.row, required this.favorite, required this.comparing, required this.onFavorite, required this.onCompare});
  final NbaStatsRow row;
  final bool favorite;
  final bool comparing;
  final VoidCallback onFavorite;
  final VoidCallback onCompare;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(children: [
          InkWell(onTap: onCompare, child: Icon(comparing ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: comparing ? _asBlue : _asFaint, size: 15)),
          const SizedBox(width: 5),
          Expanded(child: InkWell(onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player), child: Text(row.player, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _asBlue, fontSize: 10, fontWeight: FontWeight.w800)))),
          InkWell(onTap: onFavorite, child: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded, color: favorite ? _asAmber : _asFaint, size: 15)),
        ]),
      );
}

class _TeamCell extends StatelessWidget {
  const _TeamCell(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => _LinkedTeams(value: value);
}

class _LinkedTeams extends StatelessWidget {
  const _LinkedTeams({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final teams = value.split(RegExp(r'[,/ ]+')).where((item) => item.isNotEmpty && item != '—').toList();
    return Wrap(alignment: WrapAlignment.center, spacing: 2, children: [for (final team in teams.take(2)) InkWell(onTap: () => openNbaTeamPage(context, teamId: team), child: Padding(padding: const EdgeInsets.all(3), child: Text(team, style: const TextStyle(color: _asBlue, fontSize: 8, fontWeight: FontWeight.w900))))]);
  }
}

class _MetricHeader extends StatelessWidget {
  const _MetricHeader({required this.keyName, required this.selected, required this.descending, required this.expanded, required this.onSort, required this.onExpand});
  final String keyName;
  final bool selected;
  final bool descending;
  final bool expanded;
  final VoidCallback onSort;
  final VoidCallback? onExpand;
  @override
  Widget build(BuildContext context) {
    final metric = nbaTerminalMetricByKey[keyName];
    return InkWell(
      onTap: onSort,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (onExpand != null)
            InkWell(onTap: onExpand, child: Icon(expanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, color: _asAmber, size: 13)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(metric?.shortLabel ?? keyName.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? _asBlue : _asMuted, fontSize: 7.5, fontWeight: FontWeight.w900))),
            if (selected) Icon(descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: _asBlue, size: 8),
          ]),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10), child: Text(text, style: const TextStyle(color: _asMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .5)));
}

class _Value extends StatelessWidget {
  const _Value(this.text, {required this.available});
  final String text;
  final bool available;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8), child: Text(text, textAlign: TextAlign.center, maxLines: 1, style: TextStyle(color: available ? _asText : _asFaint, fontSize: 8.5, fontWeight: available ? FontWeight.w800 : FontWeight.w500)));
}

class _Drop<T> extends StatelessWidget {
  const _Drop({required this.label, required this.value, required this.width, required this.items, required this.onChanged});
  final String label;
  final T value;
  final double width;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: _asFaint, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .6)),
    const SizedBox(height: 4),
    DropdownButtonFormField<T>(value: value, isExpanded: true, dropdownColor: _asPanel3, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), items: items, onChanged: (next) { if (next != null) onChanged(next); }),
  ]));
}

class _Input extends StatelessWidget {
  const _Input({required this.label, required this.width, required this.controller, required this.onChanged, this.icon});
  final String label;
  final double width;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: _asFaint, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: .6)),
    const SizedBox(height: 4),
    TextField(controller: controller, onChanged: onChanged, style: const TextStyle(color: _asText, fontSize: 10), decoration: InputDecoration(isDense: true, prefixIcon: icon == null ? null : Icon(icon, size: 15), border: const OutlineInputBorder())),
  ]));
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: .4)));
}

class _AdvancedPanel extends StatelessWidget {
  const _AdvancedPanel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _asPanel, border: Border.all(color: _asLine), borderRadius: BorderRadius.circular(8)), child: child);
}
