import 'package:flutter/material.dart';

import '../data/stat_definition_items.dart';
import '../widgets/terminal_primitives.dart';

class StatDictionaryScreen extends StatefulWidget {
  const StatDictionaryScreen({super.key});

  @override
  State<StatDictionaryScreen> createState() => _StatDictionaryScreenState();
}

class _StatDictionaryScreenState extends State<StatDictionaryScreen> {
  String query = '';
  String status = 'All';

  @override
  Widget build(BuildContext context) {
    final statuses = ['All', ...statDefinitionItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = statDefinitionItems.where((item) {
      final q = query.trim().toLowerCase();
      final matchesStatus = status == 'All' || item.status == status;
      final matchesQuery = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.abbreviation.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.level.toLowerCase().contains(q) ||
          item.definition.toLowerCase().contains(q) ||
          item.dataNeeds.toLowerCase().contains(q);
      return matchesStatus && matchesQuery;
    }).toList();

    final core = statDefinitionItems.where((item) => item.status == 'Core').length;
    final future = statDefinitionItems.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Stat Dictionary',
          subtitle: 'Definitions, formulas, dependencies, and display rules for core and future basketball statistics.',
        ),
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
              _Metric(label: 'Stats', value: '${statDefinitionItems.length}', detail: 'Definitions'),
              _Metric(label: 'Core', value: '$core', detail: 'Initial stats'),
              _Metric(label: 'Future', value: '$future', detail: 'Advanced stats'),
              _Metric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
            ],
          );
        }),
        const SizedBox(height: 22),
        TerminalCard(
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: 360,
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                style: const TextStyle(color: Colors.white),
                cursorColor: terminalAccent,
                decoration: _inputDecoration('Search stat, category, formula, dependency...'),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: status,
                dropdownColor: terminalPanelDark,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'Status', labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))),
                items: statuses.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => status = value);
                },
              ),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Stat Governance Rule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text('Every displayed number should have an explicit definition, formula, source dependency, display use, and null handling rule before it becomes part of the terminal experience.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Definitions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} stats', style: const TextStyle(color: terminalTextMuted))])),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('Stat')),
                  DataColumn(label: Text('Abbrev.')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Level')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Formula')),
                  DataColumn(label: Text('Data Needs')),
                  DataColumn(label: Text('Use')),
                ],
                rows: [
                  for (final item in filtered)
                    DataRow(cells: [
                      DataCell(SizedBox(width: 240, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Text(item.abbreviation, style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(Text(item.category)),
                      DataCell(Text(item.level)),
                      DataCell(InfoPill(label: item.status)),
                      DataCell(SizedBox(width: 320, child: Text(item.formula))),
                      DataCell(SizedBox(width: 430, child: Text(item.dataNeeds))),
                      DataCell(SizedBox(width: 420, child: Text(item.displayUse))),
                    ]),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: terminalTextMuted),
      prefixIcon: const Icon(Icons.search, color: terminalTextMuted),
      filled: true,
      fillColor: terminalPanelDark,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
    );

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
