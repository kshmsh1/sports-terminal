import 'package:flutter/material.dart';

import '../data/research_source_items.dart';
import '../widgets/terminal_primitives.dart';

class ResearchSourceScreen extends StatefulWidget {
  const ResearchSourceScreen({super.key});

  @override
  State<ResearchSourceScreen> createState() => _ResearchSourceScreenState();
}

class _ResearchSourceScreenState extends State<ResearchSourceScreen> {
  String query = '';
  String domain = 'All';
  String status = 'All';

  @override
  Widget build(BuildContext context) {
    final domains = ['All', ...researchSourceItems.map((item) => item.domain).toSet().toList()..sort()];
    final statuses = ['All', ...researchSourceItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = researchSourceItems.where((item) {
      final q = query.trim().toLowerCase();
      return (domain == 'All' || item.domain == domain) &&
          (status == 'All' || item.status == status) &&
          (q.isEmpty || item.title.toLowerCase().contains(q) || item.sourceType.toLowerCase().contains(q) || item.domain.toLowerCase().contains(q) || item.useCase.toLowerCase().contains(q) || item.linkPolicy.toLowerCase().contains(q));
    }).toList();

    final preferred = researchSourceItems.where((item) => item.status.contains('Preferred')).length;
    final candidates = researchSourceItems.where((item) => item.status == 'Candidate').length;
    final future = researchSourceItems.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Research Sources', subtitle: 'Research and source registry for official statistics, team pages, reference sites, media guides, CBA documents, licensed feeds, and internal notes.'),
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
              _Metric(label: 'Sources', value: '${researchSourceItems.length}', detail: 'Research registry'),
              _Metric(label: 'Preferred', value: '$preferred', detail: 'First target'),
              _Metric(label: 'Candidates', value: '$candidates', detail: 'Usage review'),
              _Metric(label: 'Future', value: '$future', detail: 'Later layers'),
            ],
          );
        }),
        const SizedBox(height: 22),
        TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search source, domain, use case, policy...'))),
          _FilterDropdown(label: 'Domain', value: domain, values: domains, onChanged: (value) => setState(() => domain = value)),
          _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
        ])),
        const SizedBox(height: 22),
        const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Research Rule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 10),
          Text('The terminal should separate facts, source metadata, citations, derived analysis, and user-authored notes. A source can be useful without being automatically ingestible.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
        ])),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Research Source Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} sources', style: const TextStyle(color: terminalTextMuted))])),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 30,
                columns: const [
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Domain')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Reliability')),
                  DataColumn(label: Text('Link / Rights Policy')),
                  DataColumn(label: Text('Use Case')),
                ],
                rows: [for (final item in filtered) DataRow(cells: [
                  DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
                  DataCell(SizedBox(width: 220, child: Text(item.sourceType))),
                  DataCell(Text(item.domain)),
                  DataCell(InfoPill(label: item.status)),
                  DataCell(SizedBox(width: 360, child: Text(item.reliability))),
                  DataCell(SizedBox(width: 520, child: Text(item.linkPolicy))),
                  DataCell(SizedBox(width: 520, child: Text(item.useCase))),
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
