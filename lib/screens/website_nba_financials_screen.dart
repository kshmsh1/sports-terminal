import 'package:flutter/material.dart';

import '../services/nba_league_environment_2026.dart';
import '../services/nba_team_financial_reference_2026.dart';

/// Static 2026–27 financial reference. Never presents cap/apron headroom as
/// transaction legality; the CBA and Trade Machine determine the latter.
class WebsiteNbaFinancialsScreen extends StatefulWidget {
  const WebsiteNbaFinancialsScreen({super.key});

  @override
  State<WebsiteNbaFinancialsScreen> createState() =>
      _WebsiteNbaFinancialsScreenState();
}

enum _FinancialView { all, capRoom, aboveTax, aboveFirstApron, aboveSecondApron }
enum _FinancialSort { team, cap, tax, firstApron, secondApron }

class _WebsiteNbaFinancialsScreenState extends State<WebsiteNbaFinancialsScreen> {
  final _search = TextEditingController();
  final _horizontal = ScrollController();
  _FinancialView _view = _FinancialView.all;
  _FinancialSort _sort = _FinancialSort.team;
  bool _ascending = true;

  @override
  void dispose() {
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = NbaTeamFinancialReference202627.teams.values.toList();
    final query = _search.text.trim().toLowerCase();
    final rows = all.where((item) {
      if (query.isNotEmpty && !item.team.toLowerCase().contains(query) &&
          !(item.team == 'BRK' && 'bkn'.contains(query))) return false;
      return switch (_view) {
        _FinancialView.all => true,
        _FinancialView.capRoom => item.capSpace > 0,
        _FinancialView.aboveTax => item.taxSpace < 0,
        _FinancialView.aboveFirstApron => item.firstApronSpace < 0,
        _FinancialView.aboveSecondApron => item.secondApronSpace < 0,
      };
    }).toList();

    double metric(NbaTeamFinancialSnapshot item) => switch (_sort) {
      _FinancialSort.team => 0,
      _FinancialSort.cap => item.capSpace,
      _FinancialSort.tax => item.taxSpace,
      _FinancialSort.firstApron => item.firstApronSpace,
      _FinancialSort.secondApron => item.secondApronSpace,
    };
    rows.sort((a, b) {
      final compare = _sort == _FinancialSort.team
          ? a.team.compareTo(b.team)
          : metric(a).compareTo(metric(b));
      return _ascending ? compare : -compare;
    });

    final overTax = all.where((team) => team.taxSpace < 0).length;
    final overFirst = all.where((team) => team.firstApronSpace < 0).length;
    final overSecond = all.where((team) => team.secondApronSpace < 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NBA Financials',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('2026–27 team headroom, tax and apron positions, signing exceptions and trade exceptions.',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: const [
          _ThresholdChip(label: 'SALARY CAP', amount: NbaLeagueEnvironment202627.salaryCap),
          _ThresholdChip(label: 'LUXURY TAX', amount: NbaLeagueEnvironment202627.luxuryTax),
          _ThresholdChip(label: 'FIRST APRON', amount: NbaLeagueEnvironment202627.firstApron),
          _ThresholdChip(label: 'SECOND APRON', amount: NbaLeagueEnvironment202627.secondApron),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _SummaryStat(label: 'Teams over tax', number: overTax, onTap: () =>
              setState(() => _view = _FinancialView.aboveTax)),
          _SummaryStat(label: 'Above first apron', number: overFirst, onTap: () =>
              setState(() => _view = _FinancialView.aboveFirstApron)),
          _SummaryStat(label: 'Above second apron', number: overSecond, onTap: () =>
              setState(() => _view = _FinancialView.aboveSecondApron)),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12, runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: 210,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Find a team',
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 195,
                  child: DropdownButtonFormField<_FinancialView>(
                    key: ValueKey(_view),
                    initialValue: _view,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Show', isDense: true),
                    items: const [
                      DropdownMenuItem(value: _FinancialView.all, child: Text('All 30 teams')),
                      DropdownMenuItem(value: _FinancialView.capRoom, child: Text('Under salary cap')),
                      DropdownMenuItem(value: _FinancialView.aboveTax, child: Text('Above luxury tax')),
                      DropdownMenuItem(value: _FinancialView.aboveFirstApron, child: Text('Above first apron')),
                      DropdownMenuItem(value: _FinancialView.aboveSecondApron, child: Text('Above second apron')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _view = v); },
                  ),
                ),
                SizedBox(width: 195,
                  child: DropdownButtonFormField<_FinancialSort>(
                    key: ValueKey(_sort),
                    initialValue: _sort, isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sort by', isDense: true),
                    items: const [
                      DropdownMenuItem(value: _FinancialSort.team, child: Text('Team')),
                      DropdownMenuItem(value: _FinancialSort.cap, child: Text('Cap headroom')),
                      DropdownMenuItem(value: _FinancialSort.tax, child: Text('Tax headroom')),
                      DropdownMenuItem(value: _FinancialSort.firstApron, child: Text('First apron')),
                      DropdownMenuItem(value: _FinancialSort.secondApron, child: Text('Second apron')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _sort = v); },
                  ),
                ),
                IconButton(
                  tooltip: _ascending ? 'Sort descending' : 'Sort ascending',
                  onPressed: () => setState(() => _ascending = !_ascending),
                  icon: Icon(_ascending ? Icons.arrow_upward_rounded :
                      Icons.arrow_downward_rounded),
                ),
                Text('${rows.length} of ${all.length} teams',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                TextButton(
                  onPressed: () => setState(() {
                    _view = _FinancialView.all;
                    _sort = _FinancialSort.team;
                    _ascending = true;
                    _search.clear();
                  }),
                  child: const Text('Reset filters'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            const Icon(Icons.swipe_rounded, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Select a team for exceptions and trade-exception details. Scroll the table horizontally to see every threshold.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
          ]),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: rows.isEmpty
              ? const Padding(padding: EdgeInsets.all(30),
                  child: Text('No teams match the selected filters.'))
              : Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 50,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 65,
                      columns: const [
                        DataColumn(label: Text('TEAM')),
                        DataColumn(label: Text('ROSTER REFERENCE')),
                        DataColumn(label: Text('CAP HEADROOM')),
                        DataColumn(label: Text('TAX HEADROOM')),
                        DataColumn(label: Text('1ST APRON')),
                        DataColumn(label: Text('2ND APRON')),
                        DataColumn(label: Text('HARD CAP')),
                        DataColumn(label: Text('EXCEPTIONS / TPE')),
                      ],
                      rows: [
                        for (final item in rows)
                          DataRow(cells: [
                            DataCell(Text(_displayTeam(item.team),
                                style: const TextStyle(fontWeight: FontWeight.w900)),
                                onTap: () => _showTeamDetails(context, item)),
                            DataCell(Text('${item.standardRoster} listed · ${item.twoWayRoster} two-way'),
                                onTap: () => _showTeamDetails(context, item)),
                            DataCell(_SignedMoney(value: item.capSpace),
                                onTap: () => _showTeamDetails(context, item)),
                            DataCell(_SignedMoney(value: item.taxSpace),
                                onTap: () => _showTeamDetails(context, item)),
                            DataCell(_SignedMoney(value: item.firstApronSpace),
                                onTap: () => _showTeamDetails(context, item)),
                            DataCell(_SignedMoney(value: item.secondApronSpace),
                                onTap: () => _showTeamDetails(context, item)),
                            DataCell(Text(item.hardCapLabel),
                                onTap: () => _showTeamDetails(context, item)),
                            DataCell(OutlinedButton.icon(
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text('View details'),
                              onPressed: () => _showTeamDetails(context, item),
                            )),
                          ]),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          'Methodology: headroom is the supplied threshold minus the associated team allocation. '
          'A negative value indicates an allocation above that threshold, not necessarily an illegal roster or transaction. '
          'Hard-cap status is distinct from current apron position. '
          'The listed roster and exception figures are reference snapshots, not verified live transactions; '
          'consult the Trade Machine and applicable CBA rules before drawing a transaction conclusion.',
          style: TextStyle(fontSize: 12, height: 1.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  void _showTeamDetails(BuildContext context, NbaTeamFinancialSnapshot team) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(child: FractionallySizedBox(
          heightFactor: .72,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${_displayTeam(team.team)} · 2026–27',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900))),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 6),
              Text('${team.standardRoster} listed standard roster entries · ${team.twoWayRoster} two-way',
                style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 18),
              _DetailMetric(label: 'Salary cap headroom', value: team.capSpace),
              _DetailMetric(label: 'Luxury tax headroom', value: team.taxSpace),
              _DetailMetric(label: 'First apron headroom', value: team.firstApronSpace),
              _DetailMetric(label: 'Second apron headroom', value: team.secondApronSpace),
              const Divider(height: 32),
              Text('Hard-cap restriction', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(team.hardCapLabel == 'None'
                ? 'No hard-cap restriction recorded in this reference.'
                : 'Reported hard cap: ${team.hardCapLabel}.'),
              const SizedBox(height: 18),
              Text('Available signing exceptions',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(team.exceptionSummary),
              const SizedBox(height: 18),
              Text('Largest recorded traded-player exception',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(team.largestTpe == null
                ? 'Not listed in this reference'
                : '${_money(team.largestTpe!)}  ·  Expires ${team.largestTpeExpires ?? 'date unavailable'}'),
              const SizedBox(height: 20),
              Text('Source: 2026–27 team financial reference in Sports Terminal. '
                   'Balances and availability can change after transactions.',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
            ]),
          ),
        ));
      },
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  const _ThresholdChip({required this.label, required this.amount});
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
    label: Text('$label  ${_money(amount)}'),
  );
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.number, required this.onTap});
  final String label;
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$number', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    ),
  );
}

class _SignedMoney extends StatelessWidget {
  const _SignedMoney({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    return Text('${positive ? '+' : '−'}${_money(value.abs())}',
      style: TextStyle(
        color: positive ? const Color(0xFF4CAF7A) : const Color(0xFFD85B67),
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(child: Text(label)),
      _SignedMoney(value: value),
    ]),
  );
}

String _displayTeam(String code) => code == 'BRK' ? 'BKN' : code;

String _money(double value) {
  if (value.abs() >= 1000000) {
    return '\$' + (value / 1000000).toStringAsFixed(2) + 'M';
  }
  if (value.abs() >= 1000) {
    return '\$' + (value / 1000).toStringAsFixed(0) + 'K';
  }
  return '\$' + value.toStringAsFixed(0);
}
