import 'package:flutter/material.dart';

import '../data/navigation_strategy_items.dart';
import '../widgets/terminal_primitives.dart';

class NavigationStrategyScreen extends StatelessWidget {
  const NavigationStrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final temporary = navigationStrategyItems.where((item) => item.status == 'Temporary').length;
    final planned = navigationStrategyItems.where((item) => item.status == 'Planned').length;
    final future = navigationStrategyItems.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Navigation Strategy',
          subtitle: 'A UI plan for moving from today’s architecture-heavy sidebar to a cleaner terminal layout once the product foundation is clearer.',
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
                _NavMetric(label: 'Navigation Areas', value: '${navigationStrategyItems.length}', detail: 'UX map'),
                _NavMetric(label: 'Temporary', value: '$temporary', detail: 'Current sidebar'),
                _NavMetric(label: 'Planned', value: '$planned', detail: 'Near-term cleanup'),
                _NavMetric(label: 'Future', value: '$future', detail: 'Later UX layers'),
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
                'Current Sidebar Is Temporary',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'The sidebar is intentionally overexposed while the product architecture is being designed. Once the major modules are defined, the normal user sidebar should become smaller, and architecture pages should move into a Build Lab / Admin area. This keeps the product powerful without making the main interface feel cluttered.',
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
                  'Navigation Evolution Plan',
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
                    DataColumn(label: Text('Current State')),
                    DataColumn(label: Text('Future State')),
                  ],
                  rows: [
                    for (final item in navigationStrategyItems)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 240, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 520, child: Text(item.currentState))),
                          DataCell(SizedBox(width: 620, child: Text(item.futureState))),
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

class _NavMetric extends StatelessWidget {
  const _NavMetric({required this.label, required this.value, required this.detail});

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
