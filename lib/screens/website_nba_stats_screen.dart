import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../widgets/website_nba_data_gate.dart';
import 'product_nba_public_pages_screen.dart' show openNbaPlayerPage, openNbaTeamPage;

class WebsiteNbaStatsScreen extends StatefulWidget {
  const WebsiteNbaStatsScreen({super.key});

  @override
  State<WebsiteNbaStatsScreen> createState() => _WebsiteNbaStatsScreenState();
}

class _WebsiteNbaStatsScreenState extends State<WebsiteNbaStatsScreen> {
  final _engine = const NbaStatsWorkstationEngine();
  final _search = TextEditingController();
  NbaStatsSeasonType _seasonType = NbaStatsSeasonType.regular;
  String _team = 'All';
  String _position = 'All';
  String _sortKey = 'pts';
  bool _descending = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebsiteNbaDataGate(
      builder: (context, data) => _buildStats(context, data),
    );
  }

  Widget _buildStats(BuildContext context, NbaTerminalSeedSnapshot data) {
    final colors = Theme.of(context).colorScheme;
    final rows = _engine.buildRows(
      data,
      basis: NbaStatsBasis.perGame,
      seasonType: _seasonType,
    );
    final teams = <String>{'All'};
    for (final row in rows) {
      teams.addAll(
        row.team
            .split(RegExp(r'[,/ ]+'))
            .where((value) => value.isNotEmpty && value != '—'),
      );
    }
    final orderedTeams = teams.toList()..sort();
    final query = _search.text.trim().toLowerCase();
    final visible = rows.where((row) {
      if (query.isNotEmpty &&
          !'${row.player} ${row.team} ${row.position}'
              .toLowerCase()
              .contains(query)) {
        return false;
      }
      if (_team != 'All' &&
          !row.team.split(RegExp(r'[,/ ]+')).contains(_team)) {
        return false;
      }
      if (_position != 'All' && row.position != _position) return false;
      return true;
    }).toList();
    _engine.sortRows(visible, _sortKey, descending: _descending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NBA Stats',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Player box-score statistics with simple filters, familiar columns and direct player/team links.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<NbaStatsSeasonType>(
                      segments: const [
                        ButtonSegment(
                          value: NbaStatsSeasonType.regular,
                          label: Text('Regular Season'),
                        ),
                        ButtonSegment(
                          value: NbaStatsSeasonType.playoffs,
                          label: Text('Playoffs'),
                        ),
                      ],
                      selected: {_seasonType},
                      onSelectionChanged: (value) {
                        setState(() => _seasonType = value.first);
                      },
                    ),
                    SizedBox(
                      width: constraints.maxWidth < 620
                          ? constraints.maxWidth
                          : 280,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search players',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    _FilterDropdown(
                      value: _team,
                      values: orderedTeams,
                      label: 'Team',
                      onChanged: (value) => setState(() => _team = value),
                    ),
                    _FilterDropdown(
                      value: _position,
                      values: const ['All', 'PG', 'SG', 'SF', 'PF', 'C'],
                      label: 'Position',
                      onChanged: (value) =>
                          setState(() => _position = value),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                '${visible.length} players',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              _seasonType == NbaStatsSeasonType.playoffs
                  ? 'Playoffs'
                  : 'Regular Season',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 48,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 52,
              sortAscending: !_descending,
              sortColumnIndex: _sortColumnIndex(_sortKey),
              columns: [
                const DataColumn(label: Text('Player')),
                const DataColumn(label: Text('Team')),
                const DataColumn(label: Text('Pos')),
                ..._metrics.map(
                  (metric) => DataColumn(
                    numeric: true,
                    label: Text(metric.label),
                    onSort: (_, ascending) {
                      setState(() {
                        _sortKey = metric.key;
                        _descending = !ascending;
                      });
                    },
                  ),
                ),
              ],
              rows: [
                for (final row in visible.take(500))
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          row.player,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => openNbaPlayerPage(
                          context,
                          row.playerId,
                          row.player,
                        ),
                      ),
                      DataCell(
                        Text(
                          row.team,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () {
                          final team = _primaryTeam(row.team);
                          if (team.isNotEmpty) {
                            openNbaTeamPage(context, team, team);
                          }
                        },
                      ),
                      DataCell(Text(row.position)),
                      for (final metric in _metrics)
                        DataCell(
                          Text(_format(row.value(metric.key), metric.percent)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (visible.length > 500) ...[
          const SizedBox(height: 12),
          Text(
            'Showing the first 500 matching players. Narrow the filters to refine the table.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: DropdownButtonFormField<String>(
          initialValue: values.contains(value) ? value : values.first,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final item in values)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

const _metrics = <_TableMetric>[
  _TableMetric('gp', 'GP', integer: true),
  _TableMetric('min', 'MPG'),
  _TableMetric('pts', 'PPG'),
  _TableMetric('reb', 'RPG'),
  _TableMetric('ast', 'APG'),
  _TableMetric('stl', 'SPG'),
  _TableMetric('blk', 'BPG'),
  _TableMetric('tov', 'TOV'),
  _TableMetric('fg_pct', 'FG%', percent: true),
  _TableMetric('three_pct', '3P%', percent: true),
  _TableMetric('ft_pct', 'FT%', percent: true),
];

class _TableMetric {
  const _TableMetric(
    this.key,
    this.label, {
    this.percent = false,
    this.integer = false,
  });

  final String key;
  final String label;
  final bool percent;
  final bool integer;
}

int? _sortColumnIndex(String key) {
  final index = _metrics.indexWhere((metric) => metric.key == key);
  return index < 0 ? null : index + 3;
}

String _format(double? value, bool percent) {
  if (value == null) return '—';
  if (percent) return '${(value * 100).toStringAsFixed(1)}%';
  return value.toStringAsFixed(1);
}

String _primaryTeam(String value) {
  final teams = value
      .split(RegExp(r'[,/ ]+'))
      .where((item) => item.isNotEmpty && item != '—')
      .toList();
  return teams.isEmpty ? '' : teams.first;
}
