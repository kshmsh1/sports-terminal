import 'package:flutter/material.dart';

import '../data/franchise_history_plan_items.dart';
import '../widgets/terminal_primitives.dart';

class FranchiseHistoryScreen extends StatelessWidget {
  const FranchiseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planned = franchiseHistoryPlanItems.where((item) => item.status == 'Planned').length;
    final future = franchiseHistoryPlanItems.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Franchise History',
          subtitle: 'The future franchise-history layer for relocations, renames, predecessor clubs, expansion context, arenas, leadership eras, and G League affiliates.',
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 2.0 : 1.5,
              children: [
                _FranchiseMetric(label: 'Coverage Areas', value: '${franchiseHistoryPlanItems.length}', detail: 'Franchise layer'),
                const _FranchiseMetric(label: 'Current Identity', value: 'Live', detail: 'NBA teams connected'),
                _FranchiseMetric(label: 'Planned', value: '$planned', detail: 'Historical mapping'),
                _FranchiseMetric(label: 'Future', value: '$future', detail: 'Deeper context'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Why this matters',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'A serious sports terminal cannot treat teams as static names. Historical NBA analysis needs franchise continuity, city moves, name changes, league expansion, arena history, leadership eras, and affiliate relationships. This layer will eventually make old player, team, draft, and game records resolve cleanly even when franchise identity changed over time.',
                style: TextStyle(color: terminalTextSoft, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Franchise History Build Plan',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const Divider(height: 1, color: terminalBorder),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                  headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                  dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                  columnSpacing: 30,
                  columns: const [
                    DataColumn(label: Text('Priority')),
                    DataColumn(label: Text('Area')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Examples')),
                  ],
                  rows: [
                    for (final item in franchiseHistoryPlanItems)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 240, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 560, child: Text(item.description))),
                          DataCell(SizedBox(width: 480, child: Text(item.examples))),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FranchiseMetric extends StatelessWidget {
  const _FranchiseMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
        ],
      ),
    );
  }
}
