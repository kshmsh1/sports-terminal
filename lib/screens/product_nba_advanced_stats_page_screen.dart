import 'package:flutter/material.dart';

import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'product_nba_public_pages_screen.dart';

const _aBg = Color(0xFF090D12);
const _aPanel = Color(0xFF0F151C);
const _aPanel2 = Color(0xFF141C25);
const _aLine = Color(0xFF263342);
const _aText = Color(0xFFE8EDF3);
const _aMuted = Color(0xFF8895A5);
const _aBlue = Color(0xFF63A9FF);
const _aAmber = Color(0xFFE2B866);

class ProductNbaAdvancedStatsPageScreen extends StatefulWidget {
  const ProductNbaAdvancedStatsPageScreen({super.key});
  @override
  State<ProductNbaAdvancedStatsPageScreen> createState() => _ProductNbaAdvancedStatsPageScreenState();
}

class _ProductNbaAdvancedStatsPageScreenState extends State<ProductNbaAdvancedStatsPageScreen> {
  final _engine = const NbaStatsWorkstationEngine();
  final _resolver = const NbaTerminalMetricResolver();
  final _search = TextEditingController();
  final _minGames = TextEditingController(text: '1');
  String _familyId = 'basic';
  String _team = 'All';
  String _position = 'All';
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  String _sortKey = 'ppg';
  bool _descending = true;
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _search.dispose();
    _minGames.dispose();
    super.dispose();
  }

  NbaTerminalStatFamily get _family => nbaTerminalFamily(_familyId);
  List<String> get _keys => nbaVisibleMetricKeys(_family, _expanded);

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
    future: const NbaTerminalSeedRepository().load(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const _AdvancedPanel(child: Center(child: CircularProgressIndicator()));
      }
      var rows = _engine.buildRows(snapshot.data!, basis: _basis, seasonType: _seasonType);
      final q = _search.text.trim().toLowerCase();
      final minGames = double.tryParse(_minGames.text) ?? 0;
      final teams = <String>{'All'};
      for (final row in rows) {
        teams.addAll(row.team.split(RegExp(r'[,/ ]+')).where((v) => v.isNotEmpty && v != '—'));
      }
      rows = rows.where((row) {
        if (q.isNotEmpty && !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(q)) return false;
        if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
        if (_position != 'All' && row.position != _position) return false;
        return (row.value('gp') ?? 0) >= minGames;
      }).toList();
      rows.sort((l, r) {
        final lv = _resolver.value(l, _sortKey);
        final rv = _resolver.value(r, _sortKey);
        if (lv == null && rv == null) return l.player.compareTo(r.player);
        if (lv == null) return 1;
        if (rv == null) return -1;
        final value = lv.compareTo(rv);
        return _descending ? -value : value;
      });
      final available = _keys.where((key) => rows.any((row) => _resolver.isAvailable(row, key))).length;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AdvancedPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ADVANCED NBA STATISTICS WORKSTATION', style: TextStyle(color: _aText, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: .5)),
              SizedBox(height: 4),
              Text('Full source-aware metric registry with categorized fields, rate bases, historical scope and linked NBA entities.', style: TextStyle(color: _aMuted, height: 1.4)),
            ])),
            Text('$available/${_keys.length} visible columns populated', style: const TextStyle(color: _aAmber, fontSize: 10, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Select<String>(value: _familyId, values: [for (final item in nbaTerminalStatFamilies) item.id], label: (v) => nbaTerminalFamily(v).label, onChanged: (v) => setState(() { _familyId = v; _expanded.clear(); _sortKey = nbaTerminalFamily(v).metrics.first; })),
            _Select<NbaStatsBasis>(value: _basis, values: NbaStatsBasis.values, label: (v) => v.label, onChanged: (v) => setState(() => _basis = v)),
            _Select<NbaStatsSeasonType>(value: _seasonType, values: const [NbaStatsSeasonType.regular, NbaStatsSeasonType.playoffs], label: (v) => v.label, onChanged: (v) => setState(() => _seasonType = v)),
            _Select<String>(value: teams.contains(_team) ? _team : 'All', values: teams.toList()..sort(), label: (v) => v, onChanged: (v) => setState(() => _team = v)),
            _Select<String>(value: _position, values: const ['All','PG','SG','SF','PF','C'], label: (v) => v, onChanged: (v) => setState(() => _position = v)),
            SizedBox(width: 90, child: TextField(controller: _minGames, onChanged: (_) => setState(() {}), style: const TextStyle(color: _aText), decoration: const InputDecoration(labelText: 'Min GP', isDense: true, border: OutlineInputBorder()))),
            SizedBox(width: 240, child: TextField(controller: _search, onChanged: (_) => setState(() {}), style: const TextStyle(color: _aText), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search players…', isDense: true, border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          Text(_family.description, style: const TextStyle(color: _aMuted, fontSize: 11, height: 1.4)),
        ])),
        const SizedBox(height: 10),
        _AdvancedTable(rows: rows, keys: _keys, resolver: _resolver, sortKey: _sortKey, descending: _descending, expanded: _expanded, onSort: (key) => setState(() { if (_sortKey == key) { _descending = !_descending; } else { _sortKey = key; _descending = true; } }), onExpand: (key) => setState(() { if (!_expanded.add(key)) _expanded.remove(key); })),
        const SizedBox(height: 10),
        _AdvancedGlossary(family: _family),
      ]);
    },
  );
}

class _AdvancedTable extends StatelessWidget {
  const _AdvancedTable({required this.rows, required this.keys, required this.resolver, required this.sortKey, required this.descending, required this.expanded, required this.onSort, required this.onExpand});
  final List<NbaStatsRow> rows;
  final List<String> keys;
  final NbaTerminalMetricResolver resolver;
  final String sortKey;
  final bool descending;
  final Set<String> expanded;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) {
    const player = 220.0, team = 70.0, pos = 48.0, metric = 86.0;
    return _AdvancedPanel(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: player + team + pos + metric * keys.length,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(height: 55, color: _aPanel2, child: Row(children: [
              const _Header(width: player, text: 'PLAYER'), const _Header(width: team, text: 'TEAM'), const _Header(width: pos, text: 'POS'),
              for (final key in keys) _MetricHeader(keyValue: key, width: metric, selected: sortKey == key, descending: descending, expanded: expanded.contains(key), onSort: () => onSort(key), onExpand: (nbaTerminalMetricByKey[key]?.children.isNotEmpty ?? false) ? () => onExpand(key) : null),
            ])),
            for (final row in rows)
              Container(height: 39, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _aLine, width: .5))), child: Row(children: [
                SizedBox(width: player, child: InkWell(onTap: () => openNbaPlayerPage(context, row.playerId, row.player), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Align(alignment: Alignment.centerLeft, child: Text(row.player, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _aBlue, fontSize: 10.5, fontWeight: FontWeight.w900)))))),
                SizedBox(width: team, child: InkWell(onTap: () { final id = row.team.split(RegExp(r'[,/ ]+')).first; openNbaTeamPage(context, id, id); }, child: Center(child: Text(row.team, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _aBlue, fontSize: 9, fontWeight: FontWeight.w800))))),
                SizedBox(width: pos, child: Center(child: Text(row.position, style: const TextStyle(color: _aMuted, fontSize: 9)))),
                for (final key in keys) SizedBox(width: metric, child: Center(child: Text(resolver.format(row, key), style: TextStyle(color: resolver.isAvailable(row, key) ? _aText : _aMuted, fontSize: 9.5, fontWeight: FontWeight.w700)))),
              ])),
          ]),
        ),
      ),
    );
  }
}

class _MetricHeader extends StatelessWidget {
  const _MetricHeader({required this.keyValue, required this.width, required this.selected, required this.descending, required this.expanded, required this.onSort, this.onExpand});
  final String keyValue; final double width; final bool selected, descending, expanded; final VoidCallback onSort; final VoidCallback? onExpand;
  @override
  Widget build(BuildContext context) {
    final metric = nbaTerminalMetricByKey[keyValue];
    return SizedBox(width: width, child: InkWell(onTap: onSort, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(metric?.group.toUpperCase() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _aMuted, fontSize: 6.5, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3), Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (onExpand != null) InkWell(onTap: onExpand, child: Icon(expanded ? Icons.arrow_drop_down : Icons.arrow_right, color: _aAmber, size: 15)), Flexible(child: Text(metric?.shortLabel ?? keyValue.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? _aBlue : _aText, fontSize: 9, fontWeight: FontWeight.w900))), if (selected) Icon(descending ? Icons.arrow_downward : Icons.arrow_upward, color: _aBlue, size: 9)]),
    ]))));
  }
}

class _AdvancedGlossary extends StatelessWidget {
  const _AdvancedGlossary({required this.family});
  final NbaTerminalStatFamily family;
  @override
  Widget build(BuildContext context) => _AdvancedPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('${family.label.toUpperCase()} GLOSSARY', style: const TextStyle(color: _aText, fontSize: 14, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [for (final key in family.metrics) if (nbaTerminalMetricByKey[key] case final metric?) Container(width: 280, padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _aPanel2, border: Border.all(color: _aLine)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${metric.shortLabel} · ${metric.label}', style: const TextStyle(color: _aBlue, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(metric.description, style: const TextStyle(color: _aMuted, fontSize: 9, height: 1.35))]))]),
  ]));
}

class _AdvancedPanel extends StatelessWidget {
  const _AdvancedPanel({required this.child, this.padding = const EdgeInsets.all(14)}); final Widget child; final EdgeInsetsGeometry padding;
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _aPanel, border: Border.all(color: _aLine)), child: child);
}
class _Header extends StatelessWidget { const _Header({required this.width, required this.text}); final double width; final String text; @override Widget build(BuildContext context) => SizedBox(width: width, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(color: _aMuted, fontSize: 8, fontWeight: FontWeight.w900))))); }
class _Select<T> extends StatelessWidget { const _Select({required this.value, required this.values, required this.label, required this.onChanged}); final T value; final List<T> values; final String Function(T) label; final ValueChanged<T> onChanged; @override Widget build(BuildContext context) => Container(height: 40, constraints: const BoxConstraints(minWidth: 105, maxWidth: 220), padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: _aPanel2, border: Border.all(color: _aLine)), child: DropdownButtonHideUnderline(child: DropdownButton<T>(value: value, dropdownColor: _aPanel2, style: const TextStyle(color: _aText, fontSize: 10), items: [for (final item in values) DropdownMenuItem(value: item, child: Text(label(item)))], onChanged: (v) { if (v != null) onChanged(v); }))); }
