import 'package:flutter/material.dart';

import '../data/era_plan_items.dart';
import '../widgets/terminal_primitives.dart';

class EraContextScreen extends StatelessWidget {
  const EraContextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planned = eraPlanItems.where((item) => item.status == 'Planned').length;
    final future = eraPlanItems.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Era Context',
          subtitle: 'A future historical context layer for rule changes, league structure shifts, play style changes, and business-era differences.',
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
                _EraMetric(label: 'Era Concepts', value: '${eraPlanItems.length}', detail: 'Initial map'),
                _EraMetric(label: 'Planned', value: '$planned', detail: 'Historical context'),
                _EraMetric(label: 'Future', value: '$future', detail: 'Business context'),
                const _EraMetric(label: 'Purpose', value: 'Context', detail: 'Avoid flat comparisons'),
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
                'Historical NBA data is not directly comparable across time without context. Rules, pace, league size, three-point usage, playoff structure, roster construction, salary rules, and player development pipelines all change. This page tracks the era layer that will eventually sit above raw stats.',
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
                  'Era Context Map',
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
                    DataColumn(label: Text('Era')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Modeling Use')),
                  ],
                  rows: [
                    for (final item in eraPlanItems)
                      DataRow(
                        cells: [
                          DataCell(SizedBox(width: 240, child: Text(item.era, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(Text(item.category)),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 560, child: Text(item.description))),
                          DataCell(SizedBox(width: 520, child: Text(item.modelingUse))),
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

class _EraMetric extends StatelessWidget {
  const _EraMetric({required this.label, required this.value, required this.detail});

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
