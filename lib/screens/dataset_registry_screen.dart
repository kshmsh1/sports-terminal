import 'package:flutter/material.dart';

import '../data/dataset_registry_items.dart';
import '../widgets/terminal_primitives.dart';

class DatasetRegistryScreen extends StatelessWidget {
  const DatasetRegistryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connected = datasetRegistryItems.where((item) => item.status == 'Connected').length;
    final next = datasetRegistryItems.where((item) => item.status == 'Next').length;
    final planned = datasetRegistryItems.where((item) => item.status == 'Planned').length;
    final sourceNeeded = datasetRegistryItems.where((item) => item.status == 'Source needed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Dataset Registry',
          subtitle: 'The operational map of every dataset Sports Terminal needs, where it should live, how it should refresh, and what source posture it requires.',
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 5 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 2.0 : 1.5,
              children: [
                _DatasetMetric(label: 'Datasets', value: '${datasetRegistryItems.length}', detail: 'Registry items'),
                _DatasetMetric(label: 'Connected', value: '$connected', detail: 'Available now'),
                _DatasetMetric(label: 'Next', value: '$next', detail: 'Near-term target'),
                _DatasetMetric(label: 'Planned', value: '$planned', detail: 'Historical build'),
                _DatasetMetric(label: 'Source Needed', value: '$sourceNeeded', detail: 'Provider decision'),
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
                  'Dataset Registry',
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
                    DataColumn(label: Text('Dataset')),
                    DataColumn(label: Text('Domain')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Refresh Mode')),
                    DataColumn(label: Text('Storage Target')),
                    DataColumn(label: Text('Source Preference')),
                    DataColumn(label: Text('Notes')),
                  ],
                  rows: [
                    for (final item in datasetRegistryItems)
                      DataRow(
                        cells: [
                          DataCell(SizedBox(width: 260, child: Text(item.dataset, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(Text(item.domain)),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 220, child: Text(item.refreshMode))),
                          DataCell(SizedBox(width: 420, child: Text(item.storageTarget))),
                          DataCell(SizedBox(width: 420, child: Text(item.sourcePreference))),
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

class _DatasetMetric extends StatelessWidget {
  const _DatasetMetric({required this.label, required this.value, required this.detail});

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
