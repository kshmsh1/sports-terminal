import 'package:flutter/material.dart';

import '../data/nba_data_roadmap.dart';
import '../widgets/source_backed_data_wave_panel.dart';
import '../widgets/terminal_primitives.dart';

class DataRoadmapScreen extends StatelessWidget {
  const DataRoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connected = nbaDataRoadmap.where((item) => item.status == 'Connected').length;
    final planned = nbaDataRoadmap.where((item) => item.status == 'Planned').length;
    final needsSource = nbaDataRoadmap.where((item) => item.status == 'Source needed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'NBA Data Roadmap',
          subtitle: 'A source-aware map of the information Sports Terminal needs before it becomes a full historical NBA terminal.',
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
                _RoadmapMetric(label: 'Total Data Areas', value: '${nbaDataRoadmap.length}', detail: 'NBA scope map'),
                _RoadmapMetric(label: 'Connected', value: '$connected', detail: 'Available now'),
                _RoadmapMetric(label: 'Planned', value: '$planned', detail: 'Needs ingestion'),
                _RoadmapMetric(label: 'Source Needed', value: '$needsSource', detail: 'Needs provider decision'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        const SourceBackedDataWavePanel(maxRows: 14),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Data Coverage Plan',
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
                    DataColumn(label: Text('Data Area')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in nbaDataRoadmap)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w800))),
                          DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                          DataCell(Text(item.category)),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 520, child: Text(item.description))),
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

class _RoadmapMetric extends StatelessWidget {
  const _RoadmapMetric({required this.label, required this.value, required this.detail});

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