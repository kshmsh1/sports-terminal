import 'package:flutter/material.dart';

import '../services/nba_team_financial_reference_2026.dart';

class WebsiteNbaFinancialsScreen extends StatefulWidget {
  const WebsiteNbaFinancialsScreen({super.key});
  @override
  State<WebsiteNbaFinancialsScreen> createState() => _WebsiteNbaFinancialsScreenState();
}

class _WebsiteNbaFinancialsScreenState extends State<WebsiteNbaFinancialsScreen> {
  String? _selectedTeam;

  @override
  Widget build(BuildContext context) {
    final rows = NbaTeamFinancialReference202627.teams.values.toList()
      ..sort((a, b) => a.team.compareTo(b.team));
    final colors = Theme.of(context).colorScheme;
    final selected = _selectedTeam == null
        ? null : NbaTeamFinancialReference202627.teams[_selectedTeam];

    final listing = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, bounds) =>
        Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              horizontalMargin: 12,
              columnSpacing: 19,
              headingRowHeight: 45,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 63,
              columns: const [
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Roster')),
                DataColumn(label: Text('Cap Space')),
                DataColumn(label: Text('Tax Space')),
                DataColumn(label: Text('1st Apron')),
                DataColumn(label: Text('2nd Apron')),
                DataColumn(label: Text('Hard Cap')),
              ],
              rows: [
                for (final item in rows)
                  DataRow(
                    selected: _selectedTeam == item.team,
                    onSelectChanged: (_) => setState(() => _selectedTeam = item.team),
                    cells: [
                      DataCell(Text(item.team == 'BRK' ? 'BKN' : item.team,
                          style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(Text('${item.standardRoster} + ${item.twoWayRoster} two-way')),
                      DataCell(_SignedMoney(value: item.capSpace)),
                      DataCell(_SignedMoney(value: item.taxSpace)),
                      DataCell(_SignedMoney(value: item.firstApronSpace)),
                      DataCell(_SignedMoney(value: item.secondApronSpace)),
                      DataCell(Text(item.hardCapLabel)),
                    ],
                  ),
              ],
            ),
          ),
        )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NBA Financials', style: Theme.of(context).textTheme.displaySmall
            ?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('2026–27 salary cap, tax and apron reference · Select a team for details',
            style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 12),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text('Cap  \$164.961M')),
          Chip(label: Text('Tax  \$200.428M')),
          Chip(label: Text('1st Apron  \$209.015M')),
          Chip(label: Text('2nd Apron  \$221.686M')),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, bounds) {
          final side = selected == null ? const SizedBox.shrink() :
              _TeamFinancialInspector(item: selected,
                  onClose: () => setState(() => _selectedTeam = null));
          if (bounds.maxWidth < 1000) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [listing, if (selected != null) ...[
                  const SizedBox(height: 16), side,
                ]]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: listing),
            const SizedBox(width: 16),
            SizedBox(width: 375, child: side),
          ]);
        }),
        const SizedBox(height: 16),
        Text('Source: supplied 2026–27 team financial summaries · Arcside',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
      ],
    );
  }
}

class _TeamFinancialInspector extends StatelessWidget {
  const _TeamFinancialInspector({required this.item, required this.onClose});
  final NbaTeamFinancialSnapshot item;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: colors.onSurfaceVariant))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('TEAM FINANCIALS',
                style: TextStyle(color: colors.primary, fontSize: 11,
                    letterSpacing: 1.2, fontWeight: FontWeight.w900))),
            IconButton(tooltip: 'Close details', onPressed: onClose,
                icon: const Icon(Icons.close_rounded)),
          ]),
          Text(item.team == 'BRK' ? 'Brooklyn Nets' : item.team,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('2026–27 · Financial position'),
          const Divider(height: 30),
          line('Standard roster', '${item.standardRoster}'),
          line('Two-way roster', '${item.twoWayRoster}'),
          line('Cap allocation', _money(item.capAllocation)),
          line('Cap space', _signed(item.capSpace)),
          line('Tax space', _signed(item.taxSpace)),
          line('1st apron room', _signed(item.firstApronSpace)),
          line('2nd apron room', _signed(item.secondApronSpace)),
          line('Hard cap', item.hardCapLabel),
          const Divider(height: 30),
          Text('AVAILABLE EXCEPTIONS', style: TextStyle(
              color: colors.onSurfaceVariant, fontSize: 11,
              fontWeight: FontWeight.w900, letterSpacing: .7)),
          const SizedBox(height: 8),
          Text(item.exceptionSummary),
          const SizedBox(height: 18),
          Text('LARGEST TRADED PLAYER EXCEPTION', style: TextStyle(
              color: colors.onSurfaceVariant, fontSize: 11,
              fontWeight: FontWeight.w900, letterSpacing: .7)),
          const SizedBox(height: 8),
          Text(item.largestTpe == null ? 'Unavailable' :
              '${_money(item.largestTpe!)}  ·  Expires ${item.largestTpeExpires ?? '—'}'),
          const SizedBox(height: 12),
          Text('ARCSIDE · 2026–27', style: TextStyle(fontSize: 10,
              color: colors.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _SignedMoney extends StatelessWidget {
  const _SignedMoney({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => Text(_signed(value),
      style: TextStyle(color: value >= 0 ? const Color(0xFF4CAF7A)
          : const Color(0xFFD85B67), fontWeight: FontWeight.w800));
}

String _signed(double value) => '${value >= 0 ? '+' : '-'}${_money(value.abs())}';
String _money(double value) {
  if (value.abs() >= 1000000) return '\$${(value / 1000000).toStringAsFixed(2)}M';
  if (value.abs() >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}K';
  return '\$${value.toStringAsFixed(0)}';
}
