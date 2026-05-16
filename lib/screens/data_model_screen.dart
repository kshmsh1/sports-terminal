import 'package:flutter/material.dart';

import '../data/data_model_domains.dart';
import '../widgets/terminal_primitives.dart';

class DataModelScreen extends StatelessWidget {
  const DataModelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final schemaReady = dataModelDomains.where((item) => item.status.contains('Schema')).length;
    final connected = dataModelDomains.where((item) => item.status.contains('Connected')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Data Model',
          subtitle: 'The internal object map that lets Sports Terminal organize teams, seasons, players, rosters, games, awards, drafts, and transactions before every source is connected.',
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
                _ModelMetric(label: 'Domains', value: '${dataModelDomains.length}', detail: 'Current object map'),
                _ModelMetric(label: 'Schema Ready', value: '$schemaReady', detail: 'No data required yet'),
                _ModelMetric(label: 'Connected', value: '$connected', detail: 'Reference data live'),
                const _ModelMetric(label: 'Rule', value: 'Null', detail: 'Blank until sourced'),
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
                  'Domain Model Map',
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
                    DataColumn(label: Text('Domain')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Models')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in dataModelDomains)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 220, child: Text(item.domain, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 260, child: Text(item.models))),
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

class _ModelMetric extends StatelessWidget {
  const _ModelMetric({required this.label, required this.value, required this.detail});

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
