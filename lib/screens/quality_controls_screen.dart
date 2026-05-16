import 'package:flutter/material.dart';

import '../data/quality_control_items.dart';
import '../widgets/terminal_primitives.dart';

class QualityControlsScreen extends StatelessWidget {
  const QualityControlsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final critical = qualityControlItems.where((item) => item.severity == 'Critical').length;
    final planned = qualityControlItems.where((item) => item.status == 'Planned').length;
    final started = qualityControlItems.where((item) => item.status == 'Started').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Quality Controls',
          subtitle: 'Data quality rules that keep the terminal trustworthy as official, public, manual, and future licensed datasets are introduced.',
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
                _QualityMetric(label: 'Checks', value: '${qualityControlItems.length}', detail: 'Current QC map'),
                _QualityMetric(label: 'Critical', value: '$critical', detail: 'Must-have controls'),
                _QualityMetric(label: 'Started', value: '$started', detail: 'Already reflected'),
                _QualityMetric(label: 'Planned', value: '$planned', detail: 'Build queue'),
              ],
            );
          },
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
                  'Validation and Governance Rules',
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
                    DataColumn(label: Text('Check')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Severity')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in qualityControlItems)
                      DataRow(
                        cells: [
                          DataCell(SizedBox(width: 260, child: Text(item.check, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(Text(item.category)),
                          DataCell(InfoPill(label: item.severity)),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 660, child: Text(item.description))),
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

class _QualityMetric extends StatelessWidget {
  const _QualityMetric({required this.label, required this.value, required this.detail});

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
