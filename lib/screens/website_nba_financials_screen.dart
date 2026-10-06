import 'package:flutter/material.dart';

import '../services/nba_team_financial_reference_2026.dart';

class WebsiteNbaFinancialsScreen extends StatelessWidget {
  const WebsiteNbaFinancialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = NbaTeamFinancialReference202627.teams.values.toList()
      ..sort((a, b) => a.team.compareTo(b.team));
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'NBA Financials',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '2026-27 team cap, tax, apron, hard-cap, exception and traded-player-exception reference.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _ThresholdChip(label: 'CAP', value: '\$164.961M'),
            _ThresholdChip(label: 'TAX', value: '\$200.428M'),
            _ThresholdChip(label: '1ST APRON', value: '\$209.015M'),
            _ThresholdChip(label: '2ND APRON', value: '\$221.686M'),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 48,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(label: Text('TEAM')),
                DataColumn(label: Text('ROSTER')),
                DataColumn(label: Text('CAP SPACE')),
                DataColumn(label: Text('TAX SPACE')),
                DataColumn(label: Text('1ST APRON SPACE')),
                DataColumn(label: Text('2ND APRON SPACE')),
                DataColumn(label: Text('HARD CAP')),
                DataColumn(label: Text('AVAILABLE EXCEPTIONS')),
                DataColumn(label: Text('LARGEST TPE')),
              ],
              rows: [
                for (final item in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(
                        item.team == 'BRK' ? 'BKN' : item.team,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      )),
                      DataCell(Text(
                        '${item.standardRoster} standard · ${item.twoWayRoster} two-way',
                      )),
                      DataCell(_SignedMoney(value: item.capSpace)),
                      DataCell(_SignedMoney(value: item.taxSpace)),
                      DataCell(_SignedMoney(value: item.firstApronSpace)),
                      DataCell(_SignedMoney(value: item.secondApronSpace)),
                      DataCell(Text(item.hardCapLabel)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            item.exceptionSummary,
                            softWrap: true,
                          ),
                        ),
                      ),
                      DataCell(Text(
                        item.largestTpe == null
                            ? '—'
                            : '${_money(item.largestTpe!)} · ${item.largestTpeExpires ?? ''}',
                      )),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Current team-summary values are transcribed from the supplied 2026-27 references. Multi-year cap/cash, tax-detail and signing-exception views can extend this route without changing the Trade Machine source model.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  const _ThresholdChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
        label: Text('$label  $value'),
      );
}

class _SignedMoney extends StatelessWidget {
  const _SignedMoney({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = positive
        ? const Color(0xFF4CAF7A)
        : const Color(0xFFD85B67);
    return Text(
      '${positive ? '+' : '-'}${_money(value.abs())}',
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }
}

String _money(double value) {
  if (value.abs() >= 1000000) {
    return '\$' + (value / 1000000).toStringAsFixed(2) + 'M';
  }
  if (value.abs() >= 1000) {
    return '\$' + (value / 1000).toStringAsFixed(0) + 'K';
  }
  return '\$' + value.toStringAsFixed(0);
}
