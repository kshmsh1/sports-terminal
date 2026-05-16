import 'package:flutter/material.dart';

import '../data/terminal_module_items.dart';
import '../widgets/terminal_primitives.dart';

class ModuleInventoryScreen extends StatelessWidget {
  const ModuleInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final started = terminalModuleItems.where((item) => item.status.contains('Started') || item.status.contains('ready')).length;
    final planned = terminalModuleItems.where((item) => item.status == 'Planned').length;
    final future = terminalModuleItems.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Terminal Module Inventory',
          subtitle: 'The working product map for Sports Terminal. Individual tabs are not meant to be comprehensive yet; this inventory tracks the larger terminal we are building toward.',
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
                _ModuleMetric(label: 'Modules', value: '${terminalModuleItems.length}', detail: 'Current product map'),
                _ModuleMetric(label: 'Started', value: '$started', detail: 'Shell/schema underway'),
                _ModuleMetric(label: 'Planned', value: '$planned', detail: 'Core backlog'),
                _ModuleMetric(label: 'Future', value: '$future', detail: 'Longer-horizon layers'),
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
                  'Module Coverage',
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
                    DataColumn(label: Text('Module')),
                    DataColumn(label: Text('Domain')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in terminalModuleItems)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 230, child: Text(item.module, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(Text(item.domain)),
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

class _ModuleMetric extends StatelessWidget {
  const _ModuleMetric({required this.label, required this.value, required this.detail});

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
