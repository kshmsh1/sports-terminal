import 'package:flutter/material.dart';

import '../data/era_band_items.dart';
import '../data/era_plan_items.dart';
import '../widgets/terminal_primitives.dart';

class EraContextScreen extends StatefulWidget {
  const EraContextScreen({super.key});

  @override
  State<EraContextScreen> createState() => _EraContextScreenState();
}

class _EraContextScreenState extends State<EraContextScreen> {
  String query = '';
  String selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    final planned = eraPlanItems.where((item) => item.status == 'Planned').length;
    final future = eraPlanItems.where((item) => item.status == 'Future').length;
    final filteredBands = eraBandItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
      final matchesQuery = normalized.isEmpty ||
          item.name.toLowerCase().contains(normalized) ||
          item.startSeasonId.toLowerCase().contains(normalized) ||
          item.endSeasonId.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized) ||
          item.primaryContext.toLowerCase().contains(normalized);
      return matchesStatus && matchesQuery;
    }).toList();

    final statuses = ['All', ...eraBandItems.map((item) => item.status).toSet().toList()..sort()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Era Context',
          subtitle: 'Historical context layer for rule changes, league structure shifts, play style changes, business-era differences, and cross-era comparisons.',
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
                _EraMetric(label: 'Era Bands', value: '${eraBandItems.length}', detail: 'Season ranges'),
                _EraMetric(label: 'Era Concepts', value: '${eraPlanItems.length}', detail: 'Context map'),
                _EraMetric(label: 'Planned', value: '$planned', detail: 'Historical context'),
                _EraMetric(label: 'Future', value: '$future', detail: 'Business context'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search era, season, context...'))),
            _FilterDropdown(label: 'Band Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why this matters', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 10),
              Text('Historical NBA data is not directly comparable across time without context. Rules, pace, league size, three-point usage, playoff structure, roster construction, salary rules, and player development pipelines all change. This page tracks the era layer that will eventually sit above raw stats.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Era Bands', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filteredBands.length} bands', style: const TextStyle(color: terminalTextMuted))])),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 30,
                columns: const [DataColumn(label: Text('Era Band')), DataColumn(label: Text('Start')), DataColumn(label: Text('End')), DataColumn(label: Text('Status')), DataColumn(label: Text('Primary Context')), DataColumn(label: Text('Description'))],
                rows: [for (final item in filteredBands) DataRow(cells: [DataCell(SizedBox(width: 230, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.startSeasonId)), DataCell(Text(item.endSeasonId)), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 360, child: Text(item.primaryContext))), DataCell(SizedBox(width: 560, child: Text(item.description)))])],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.all(18), child: Text('Era Context Map', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 30,
                columns: const [DataColumn(label: Text('Era')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Modeling Use'))],
                rows: [for (final item in eraPlanItems) DataRow(cells: [DataCell(SizedBox(width: 240, child: Text(item.era, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.category)), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 520, child: Text(item.modelingUse)))])],
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

class _EraMetric extends StatelessWidget {
  const _EraMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
