import 'package:flutter/material.dart';

import '../data/source_policy_items.dart';
import '../widgets/terminal_primitives.dart';

class SourcePolicyScreen extends StatelessWidget {
  const SourcePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Source Policy',
          subtitle: 'Internal guardrails for how Sports Terminal handles official, public, licensed, manual, and modeled data.',
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Core Rule',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'Sports Terminal can be built before every data feed is solved, but product-facing screens must never present fake values as real statistics. Missing data displays as blank. Estimated data must be labeled. Source metadata must travel with every dataset.',
                style: TextStyle(color: terminalTextSoft, fontSize: 15, height: 1.45),
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
                  'Policy Matrix',
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
                    DataColumn(label: Text('Area')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Policy')),
                    DataColumn(label: Text('Notes')),
                  ],
                  rows: [
                    for (final item in sourcePolicyItems)
                      DataRow(
                        cells: [
                          DataCell(SizedBox(width: 220, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 440, child: Text(item.policy))),
                          DataCell(SizedBox(width: 520, child: Text(item.notes))),
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
