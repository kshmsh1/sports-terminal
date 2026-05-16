import 'package:flutter/material.dart';

import '../data/screen_depth_plan_items.dart';
import '../widgets/terminal_primitives.dart';

class ScreenDepthPlanScreen extends StatelessWidget {
  const ScreenDepthPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final started = screenDepthPlanItems.where((item) => item.status.contains('Started') || item.status.contains('ready')).length;
    final planned = screenDepthPlanItems.where((item) => item.status == 'Planned').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Screen Depth Plan',
          subtitle: 'A reminder that every tab is only an early surface. This map tracks how each screen should become much deeper over time.',
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
                _DepthMetric(label: 'Screens Tracked', value: '${screenDepthPlanItems.length}', detail: 'Current UX map'),
                _DepthMetric(label: 'Started', value: '$started', detail: 'Initial shells'),
                _DepthMetric(label: 'Planned', value: '$planned', detail: 'Future expansion'),
                const _DepthMetric(label: 'Rule', value: 'Depth', detail: 'Every tab expands'),
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
                'Design Principle',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'The current terminal tabs are not meant to be comprehensive. They are durable starting points. Each one should eventually become a dense professional workspace with tables, filters, source metadata, drill-down profiles, saved views, and cross-links to related entities.',
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
                  'Screen Expansion Map',
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
                    DataColumn(label: Text('Screen')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Current Role')),
                    DataColumn(label: Text('Future Depth')),
                  ],
                  rows: [
                    for (final item in screenDepthPlanItems)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 210, child: Text(item.screen, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 400, child: Text(item.currentRole))),
                          DataCell(SizedBox(width: 720, child: Text(item.futureDepth))),
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

class _DepthMetric extends StatelessWidget {
  const _DepthMetric({required this.label, required this.value, required this.detail});

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
