import 'package:flutter/material.dart';

import '../data/nba_player_schema_fields.dart';
import '../widgets/terminal_primitives.dart';

class PlayerSchemaScreen extends StatelessWidget {
  const PlayerSchemaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = nbaPlayerSchemaFields.map((field) => field.group).toSet().toList()
      ..sort();
    final nullableCount = nbaPlayerSchemaFields.where((field) => field.status.contains('Nullable')).length;
    final requiredCount = nbaPlayerSchemaFields.where((field) => field.status.contains('Required')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Player Schema',
          subtitle: 'The internal player identity and statistics model. Fields stay nullable until sourced so the product never invents sports data.',
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
                _SchemaMetric(label: 'Fields', value: '${nbaPlayerSchemaFields.length}', detail: 'Player data model'),
                _SchemaMetric(label: 'Groups', value: '${groups.length}', detail: 'Identity, bio, stats, metadata'),
                _SchemaMetric(label: 'Nullable', value: '$nullableCount', detail: 'Blank until sourced'),
                _SchemaMetric(label: 'Required', value: '$requiredCount', detail: 'Core identifiers'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        for (final group in groups) ...[
          _SchemaGroupTable(
            group: group,
            fields: nbaPlayerSchemaFields.where((field) => field.group == group).toList(),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _SchemaMetric extends StatelessWidget {
  const _SchemaMetric({required this.label, required this.value, required this.detail});

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

class _SchemaGroupTable extends StatelessWidget {
  const _SchemaGroupTable({required this.group, required this.fields});

  final String group;
  final List<PlayerSchemaField> fields;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Text(group, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${fields.length} fields', style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
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
                DataColumn(label: Text('Field')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Description')),
              ],
              rows: [
                for (final field in fields)
                  DataRow(
                    cells: [
                      DataCell(Text(field.field, style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(field.type)),
                      DataCell(InfoPill(label: field.status)),
                      DataCell(SizedBox(width: 620, child: Text(field.description))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
