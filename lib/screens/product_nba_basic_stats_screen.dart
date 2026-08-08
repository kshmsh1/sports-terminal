import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'product_nba_entity_pages_v2.dart';

const _bsPanel = Color(0xFF0F151C);
const _bsPanel2 = Color(0xFF141C25);
const _bsLine = Color(0xFF263342);
const _bsText = Color(0xFFE8EDF3);
const _bsMuted = Color(0xFF8895A5);
const _bsBlue = Color(0xFF63A9FF);
const _bsGreen = Color(0xFF69C99A);

class ProductNbaBasicStatsScreen extends StatefulWidget {
  const ProductNbaBasicStatsScreen({super.key});

  @override
  State<ProductNbaBasicStatsScreen> createState() => _ProductNbaBasicStatsScreenState();
}

class _ProductNbaBasicStatsScreenState extends State<ProductNbaBasicStatsScreen> {
  final NbaStatsWorkstationEngine _engine = const NbaStatsWorkstationEngine();
  final TextEditingController _search = TextEditingController();
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  NbaStatsBasis _basis = NbaStatsBasis.perGame;
  String _team = 'All';
  String _position = 'All';
  String _sort = 'pts';
  bool _descending = true;
  int _limit = 100;

  static const _metrics = <String>[
    'gp', 'min', 'pts', 'reb', 'ast', 'stl', 'blk', 'tov', 'fg_pct', 'three_pct', 'ft_pct',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BasicPanel(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _BasicPanel(child: Text('Basic stats unavailable: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        final data = snapshot.data!;
        var rows = _engine.buildRows(data, basis: _basis, seasonType: _seasonType);
        final teams = <String>{'All'};
        for (final row in rows) {
          teams.addAll(row.team.split(RegExp(r'[,/ ]+')).where((value) => value.isNotEmpty && value != '—'));
        }
        final query = _search.text.trim().toLowerCase();
        rows = rows.where((row) {
          if (query.isNotEmpty && !'${row.player} ${row.team} ${row.position}'.toLowerCase().contains(query)) return false;
          if (_team != 'All' && !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) return false;
          if (_position != 'All' && row.position != _position) return false;
          return true;
        }).toList();
        _engine.sortRows(rows, _sort, descending: _descending);
        final visible = rows.take(_limit).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsHero(data: data, count: rows.length),
            const SizedBox(height: 12),
            _FilterBar(
              seasonType: _seasonType,
              basis: _basis,
              team: _team,
              teams: teams.toList()..sort(),
              position: _position,
              search: _search,
              onSeason: (value) => setState(() => _seasonType = value),
              onBasis: (value) => setState(() => _basis = value),
              onTeam: (value) => setState(() => _team = value),
              onPosition: (value) => setState(() => _position = value),
              onSearch: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _BasicStatsTable(
              rows: visible,
              engine: _engine,
              metrics: _metrics,
              sort: _sort,
              descending: _descending,
              onSort: (key) => setState(() {
                if (_sort == key) {
                  _descending = !_descending;
                } else {
                  _sort = key;
                  _descending = true;
                }
              }),
            ),
            if (rows.length > visible.length) ...[
              const SizedBox(height: 10),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _limit += 100),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Show ${rows.length - visible.length > 100 ? 100 : rows.length - visible.length} more players'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const _BasicPanel(
              child: Row(
                children: [
                  Icon(Icons.analytics_outlined, color: _bsBlue, size: 18),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'This page intentionally stays basic. Defensive tracking, playmaking, rebounding context, efficiency, impact, aggregate models, movement, clutch, shot profile, play type, gravity, physical, discipline and availability metrics live in Advanced Stats.',
                      style: TextStyle(color: _bsMuted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatsHero extends StatelessWidget {
  const _StatsHero({required this.data, required this.count});
  final NbaTerminalSeedSnapshot data;
  final int count;

  @override
  Widget build(BuildContext context) => _BasicPanel(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NBA / BASIC STATISTICS', style: TextStyle(color: _bsBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
                const SizedBox(height: 5),
                const Text('Player Stats', style: TextStyle(color: _bsText, fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('${data.supportedSeason} · $count players in active filters · click any player or team to open its full page', style: const TextStyle(color: _bsMuted, fontSize: 11)),
              ],
            );
            final status = Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Status(data.isHistorical ? 'CANONICAL HISTORY' : 'CURRENT RELEASE', _bsGreen),
                const _Status('BASIC ONLY', _bsBlue),
                const _Status('FULL-PAGE SCROLL', _bsMuted),
              ],
            );
            return compact
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), status])
                : Row(children: [Expanded(child: title), status]);
          },
        ),
      );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.seasonType,
    required this.basis,
    required this.team,
    required this.teams,
    required this.position,
    required this.search,
    required this.onSeason,
    required this.onBasis,
    required this.onTeam,
    required this.onPosition,
    required this.onSearch,
  });
  final NbaStatsSeasonType seasonType;
  final NbaStatsBasis basis;
  final String team;
  final List<String> teams;
  final String position;
  final TextEditingController search;
  final ValueChanged<NbaStatsSeasonType> onSeason;
  final ValueChanged<NbaStatsBasis> onBasis;
  final ValueChanged<String> onTeam;
  final ValueChanged<String> onPosition;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => _BasicPanel(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _Drop<NbaStatsSeasonType>(
              label: 'SEGMENT', value: seasonType, width: 155,
              items: const [
                DropdownMenuItem(value: NbaStatsSeasonType.regular, child: Text('Regular Season')),
                DropdownMenuItem(value: NbaStatsSeasonType.playoffs, child: Text('Playoffs')),
              ], onChanged: onSeason,
            ),
            _Drop<NbaStatsBasis>(
              label: 'BASIS', value: basis, width: 145,
              items: [for (final item in NbaStatsBasis.values) DropdownMenuItem(value: item, child: Text(item.label))], onChanged: onBasis,
            ),
            _Drop<String>(
              label: 'TEAM', value: teams.contains(team) ? team : 'All', width: 110,
              items: [for (final item in teams) DropdownMenuItem(value: item, child: Text(item))], onChanged: onTeam,
            ),
            _Drop<String>(
              label: 'POSITION', value: position, width: 105,
              items: [for (final item in const ['All', 'PG', 'SG', 'SF', 'PF', 'C', 'G', 'F']) DropdownMenuItem(value: item, child: Text(item))], onChanged: onPosition,
            ),
            SizedBox(
              width: 230,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PLAYER SEARCH', style: TextStyle(color: _bsMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .6)),
                const SizedBox(height: 4),
                TextField(
                  controller: search,
                  onChanged: (_) => onSearch(),
                  decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search_rounded, size: 17), border: OutlineInputBorder(), hintText: 'Search player or team…'),
                ),
              ]),
            ),
          ],
        ),
      );
}

class _BasicStatsTable extends StatelessWidget {
  const _BasicStatsTable({required this.rows, required this.engine, required this.metrics, required this.sort, required this.descending, required this.onSort});
  final List<NbaStatsRow> rows;
  final NbaStatsWorkstationEngine engine;
  final List<String> metrics;
  final String sort;
  final bool descending;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) => _BasicPanel(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  for (final row in rows) _CompactPlayerRow(row: row, engine: engine),
                ],
              );
            }
            return Table(
              columnWidths: {
                0: const FlexColumnWidth(2.8),
                1: const FlexColumnWidth(.95),
                for (var index = 0; index < metrics.length; index++) index + 2: const FlexColumnWidth(.72),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: _bsPanel2),
                  children: [
                    const _HeaderCell('PLAYER'),
                    const _HeaderCell('TEAM'),
                    for (final key in metrics)
                      _SortHeaderCell(
                        label: engine.metric(key).shortLabel,
                        selected: sort == key,
                        descending: descending,
                        onTap: () => onSort(key),
                      ),
                  ],
                ),
                for (var index = 0; index < rows.length; index++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: index.isEven ? _bsPanel : const Color(0xFF0D131A),
                      border: const Border(bottom: BorderSide(color: _bsLine, width: .5)),
                    ),
                    children: [
                      _LinkCell(
                        label: rows[index].player,
                        onTap: () => openNbaPlayerPage(context, playerId: rows[index].playerId, playerName: rows[index].player),
                      ),
                      _TeamCell(team: rows[index].team),
                      for (final key in metrics) _ValueCell(engine.formatValue(key, rows[index].value(key))),
                    ],
                  ),
              ],
            );
          },
        ),
      );
}

class _CompactPlayerRow extends StatelessWidget {
  const _CompactPlayerRow({required this.row, required this.engine});
  final NbaStatsRow row;
  final NbaStatsWorkstationEngine engine;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => openNbaPlayerPage(context, playerId: row.playerId, playerName: row.player),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _bsLine))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(row.player, style: const TextStyle(color: _bsBlue, fontSize: 14, fontWeight: FontWeight.w900))),
              _TeamInline(team: row.team),
              const Icon(Icons.chevron_right_rounded, color: _bsMuted),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 6, children: [
              for (final key in const ['gp', 'min', 'pts', 'reb', 'ast', 'stl', 'blk', 'fg_pct', 'three_pct', 'ft_pct'])
                Text('${engine.metric(key).shortLabel} ${engine.formatValue(key, row.value(key))}', style: const TextStyle(color: _bsText, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      );
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11), child: Text(label, style: const TextStyle(color: _bsMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .5)));
}

class _SortHeaderCell extends StatelessWidget {
  const _SortHeaderCell({required this.label, required this.selected, required this.descending, required this.onTap});
  final String label;
  final bool selected;
  final bool descending;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 11),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(label, style: TextStyle(color: selected ? _bsBlue : _bsMuted, fontSize: 8, fontWeight: FontWeight.w900))),
            if (selected) Icon(descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: _bsBlue, size: 9),
          ]),
        ),
      );
}

class _LinkCell extends StatelessWidget {
  const _LinkCell({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _bsBlue, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      );
}

class _TeamCell extends StatelessWidget {
  const _TeamCell({required this.team});
  final String team;
  @override
  Widget build(BuildContext context) {
    final values = team.split(RegExp(r'[,/ ]+')).where((value) => value.isNotEmpty && value != '—').toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        children: [
          for (final value in values.take(2))
            InkWell(
              onTap: () => openNbaTeamPage(context, teamId: value),
              child: Padding(padding: const EdgeInsets.all(4), child: Text(value, style: const TextStyle(color: _bsBlue, fontSize: 9, fontWeight: FontWeight.w900))),
            ),
        ],
      ),
    );
  }
}

class _TeamInline extends StatelessWidget {
  const _TeamInline({required this.team});
  final String team;
  @override
  Widget build(BuildContext context) {
    final value = team.split(RegExp(r'[,/ ]+')).firstWhere((item) => item.isNotEmpty && item != '—', orElse: () => '—');
    return TextButton(onPressed: value == '—' ? null : () => openNbaTeamPage(context, teamId: value), child: Text(value));
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        child: Text(value, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(color: _bsText, fontSize: 9, fontWeight: FontWeight.w700)),
      );
}

class _Drop<T> extends StatelessWidget {
  const _Drop({required this.label, required this.value, required this.width, required this.items, required this.onChanged});
  final String label;
  final T value;
  final double width;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _bsMuted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .6)),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            value: value,
            isExpanded: true,
            dropdownColor: _bsPanel2,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: items,
            onChanged: (next) { if (next != null) onChanged(next); },
          ),
        ]),
      );
}

class _Status extends StatelessWidget {
  const _Status(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .5)),
      );
}

class _BasicPanel extends StatelessWidget {
  const _BasicPanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _bsPanel, border: Border.all(color: _bsLine), borderRadius: BorderRadius.circular(9)),
        child: child,
      );
}
