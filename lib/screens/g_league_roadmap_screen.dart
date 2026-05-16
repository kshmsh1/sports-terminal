import 'package:flutter/material.dart';

import '../data/g_league_roadmap_items.dart';
import '../widgets/terminal_primitives.dart';

class GLeagueRoadmapScreen extends StatelessWidget {
  const GLeagueRoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sourceNeeded = gLeagueRoadmapItems.where((item) => item.status == 'Source needed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'G League Roadmap',
          subtitle: 'NBA remains the priority. This page preserves the future development-league strategy so G League data can be added without reshaping the core app.',
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expansion Principle',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Build NBA first. Keep G League schema-aware. Add G League data after NBA team, season, player identity, roster, and historical stats foundations are stronger. Current source-needed items: $sourceNeeded.',
                style: const TextStyle(color: terminalTextSoft, fontSize: 15, height: 1.45),
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
                  'G League Integration Map',
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
                    DataColumn(label: Text('NBA Connection')),
                  ],
                  rows: [
                    for (final item in gLeagueRoadmapItems)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 220, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 520, child: Text(item.description))),
                          DataCell(SizedBox(width: 520, child: Text(item.nbaConnection))),
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
