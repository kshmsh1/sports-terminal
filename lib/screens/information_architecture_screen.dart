import 'package:flutter/material.dart';

import '../data/information_architecture_items.dart';
import '../widgets/terminal_primitives.dart';

class InformationArchitectureScreen extends StatelessWidget {
  const InformationArchitectureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p0 = informationArchitectureItems.where((item) => item.priority == 'P0').length;
    final connected = informationArchitectureItems.where((item) => item.status.contains('Connected')).length;
    final planned = informationArchitectureItems.where((item) => item.status == 'Planned').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Information Architecture',
          subtitle: 'The comprehensive map of what Sports Terminal needs to organize beyond simple box-score statistics.',
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
                _ArchitectureMetric(label: 'Information Areas', value: '${informationArchitectureItems.length}', detail: 'Current map'),
                _ArchitectureMetric(label: 'P0 Areas', value: '$p0', detail: 'Foundation'),
                _ArchitectureMetric(label: 'Connected', value: '$connected', detail: 'Available now'),
                _ArchitectureMetric(label: 'Planned', value: '$planned', detail: 'Build queue'),
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
                  'Coverage Map',
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
                    DataColumn(label: Text('Scope')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Examples')),
                    DataColumn(label: Text('Notes')),
                  ],
                  rows: [
                    for (final item in informationArchitectureItems)
                      DataRow(
                        cells: [
                          DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                          DataCell(SizedBox(width: 210, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(SizedBox(width: 260, child: Text(item.scope))),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 430, child: Text(item.examples))),
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

class _ArchitectureMetric extends StatelessWidget {
  const _ArchitectureMetric({required this.label, required this.value, required this.detail});

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
