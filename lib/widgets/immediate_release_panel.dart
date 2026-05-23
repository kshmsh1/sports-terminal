import 'package:flutter/material.dart';

import '../data/immediate_release_items.dart';
import '../models/registry_item.dart';
import 'terminal_primitives.dart';

class ImmediateReleasePanel extends StatelessWidget {
  const ImmediateReleasePanel({
    super.key,
    this.target,
    this.title,
    this.subtitle,
    this.maxRows,
  });

  final String? target;
  final String? title;
  final String? subtitle;
  final int? maxRows;

  @override
  Widget build(BuildContext context) {
    final normalizedTarget = target?.toLowerCase();
    final filtered = immediateReleaseItems.where((item) {
      if (normalizedTarget == null || normalizedTarget.isEmpty) return true;
      return item.category.toLowerCase() == normalizedTarget || item.title.toLowerCase().contains(normalizedTarget);
    }).toList();
    final rows = maxRows == null ? filtered : filtered.take(maxRows!).toList();
    final p0 = rows.where((item) => item.priority == 'P0').length;
    final p1 = rows.where((item) => item.priority == 'P1').length;

    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? 'Immediate Workflow Payloads',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    InfoPill(label: '${rows.length} routes'),
                    const SizedBox(width: 8),
                    InfoPill(label: '$p0 P0 / $p1 P1'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle ?? 'Visible first-release payloads for Teams, Seasons, Source Registry, Import Jobs, Data Coverage, QA, Workspace, Compare, Reports, Saved Views, Export, Alerts, Dashboard, Search, and Action Center.',
                  style: const TextStyle(color: terminalTextSoft, height: 1.4),
                ),
              ],
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
                DataColumn(label: Text('Payload')),
                DataColumn(label: Text('Target')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Inputs')),
                DataColumn(label: Text('Route Output')),
              ],
              rows: [for (final item in rows) _row(item)],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(RegistryItem item) {
    return DataRow(cells: [
      DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
      DataCell(SizedBox(width: 290, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
      DataCell(SizedBox(width: 160, child: Text(item.category))),
      DataCell(InfoPill(label: item.status)),
      DataCell(SizedBox(width: 440, child: Text(item.inputs))),
      DataCell(SizedBox(width: 620, child: Text(item.nextStep))),
    ]);
  }
}
