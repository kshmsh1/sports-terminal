import 'package:flutter/material.dart';

import '../data/ingestion_pipeline_steps.dart';
import '../widgets/terminal_primitives.dart';

class IngestionPipelineScreen extends StatelessWidget {
  const IngestionPipelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Ingestion Pipeline',
          subtitle: 'The planned path for moving from official or licensed sources into normalized Sports Terminal data without coupling the UI to any single provider.',
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Pipeline Architecture',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'Source → raw file → normalized model → validation → app-ready JSON → Flutter data service → UI. Later, the app-ready JSON layer can be replaced by an internal API without rewriting the screens.',
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
                  'Pipeline Steps',
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
                    DataColumn(label: Text('Step')),
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('Owner')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in ingestionPipelineSteps)
                      DataRow(
                        cells: [
                          DataCell(Text('${item.step}', style: const TextStyle(fontWeight: FontWeight.w800))),
                          DataCell(SizedBox(width: 220, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(Text(item.owner)),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 620, child: Text(item.description))),
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
