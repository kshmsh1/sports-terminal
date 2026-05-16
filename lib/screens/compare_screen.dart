import 'package:flutter/material.dart';

import '../data/comparison_template_items.dart';
import '../widgets/terminal_primitives.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String query = '';
  String type = 'All';
  String status = 'All';

  @override
  Widget build(BuildContext context) {
    final types = ['All', ...comparisonTemplateItems.map((item) => item.comparisonType).toSet().toList()..sort()];
    final statuses = ['All', ...comparisonTemplateItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = comparisonTemplateItems.where((item) {
      final q = query.trim().toLowerCase();
      return (type == 'All' || item.comparisonType == type) &&
          (status == 'All' || item.status == status) &&
          (q.isEmpty || item.name.toLowerCase().contains(q) || item.primaryEntities.toLowerCase().contains(q) || item.requiredDatasets.toLowerCase().contains(q) || item.output.toLowerCase().contains(q) || item.notes.toLowerCase().contains(q));
    }).toList();

    final schemaReady = comparisonTemplateItems.where((item) => item.status == 'Schema ready').length;
    final planned = comparisonTemplateItems.where((item) => item.status == 'Planned').length;
    final future = comparisonTemplateItems.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Compare', subtitle: 'Comparison engine blueprint for players, teams, seasons, franchises, drafts, transactions, and G League development paths.'),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: isWide ? 2.0 : 1.5,
            children: [
              _Metric(label: 'Templates', value: '${comparisonTemplateItems.length}', detail: 'Comparison workflows'),
              _Metric(label: 'Schema Ready', value: '$schemaReady', detail: 'Join keys defined'),
              _Metric(label: 'Planned', value: '$planned', detail: 'Data pending'),
              _Metric(label: 'Future', value: '$future', detail: 'Later workflows'),
            ],
          );
        }),
        const SizedBox(height: 22),
        TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search comparison, entity, dataset...'))),
          _FilterDropdown(label: 'Type', value: type, values: types, onChanged: (value) => setState(() => type = value)),
          _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
        ])),
        const SizedBox(height: 22),
        const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Comparison Rule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 10),
          Text('A comparison should be a controlled workflow with declared entities, required datasets, source coverage, output structure, and null handling. The terminal should never compare fake values or unreviewed data.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
        ])),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Comparison Templates', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} templates', style: const TextStyle(color: terminalTextMuted))])),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 30,
                columns: const [
                  DataColumn(label: Text('Template')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Primary Entities')),
                  DataColumn(label: Text('Required Datasets')),
                  DataColumn(label: Text('Output')),
                  DataColumn(label: Text('Notes')),
                ],
                rows: [for (final item in filtered) DataRow(cells: [
                  DataCell(SizedBox(width: 290, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                  DataCell(Text(item.comparisonType)),
                  DataCell(InfoPill(label: item.status)),
                  DataCell(SizedBox(width: 380, child: Text(item.primaryEntities))),
                  DataCell(SizedBox(width: 430, child: Text(item.requiredDatasets))),
                  DataCell(SizedBox(width: 620, child: Text(item.output))),
                  DataCell(SizedBox(width: 520, child: Text(item.notes))),
                ])],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(width: 230, child: DropdownButtonFormField<String>(value: value, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
