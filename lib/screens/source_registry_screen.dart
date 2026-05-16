import 'package:flutter/material.dart';

import '../data/source_registry_entries.dart';
import '../widgets/terminal_primitives.dart';

class SourceRegistryScreen extends StatefulWidget {
  const SourceRegistryScreen({super.key});

  @override
  State<SourceRegistryScreen> createState() => _SourceRegistryScreenState();
}

class _SourceRegistryScreenState extends State<SourceRegistryScreen> {
  String selectedDomain = 'All';
  String selectedStatus = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final domains = ['All', ...sourceRegistryEntries.map((item) => item.domain).toSet().toList()..sort()];
    final statuses = ['All', ...sourceRegistryEntries.map((item) => item.status).toSet().toList()..sort()];
    final filtered = sourceRegistryEntries.where((item) {
      final normalized = query.trim().toLowerCase();
      return (selectedDomain == 'All' || item.domain == selectedDomain) &&
          (selectedStatus == 'All' || item.status == selectedStatus) &&
          (normalized.isEmpty || item.name.toLowerCase().contains(normalized) || item.domain.toLowerCase().contains(normalized) || item.sourceType.toLowerCase().contains(normalized) || item.rightsPosture.toLowerCase().contains(normalized) || item.notes.toLowerCase().contains(normalized));
    }).toList();

    final connected = sourceRegistryEntries.where((item) => item.status == 'Connected').length;
    final target = sourceRegistryEntries.where((item) => item.status == 'Target').length;
    final sourceNeeded = sourceRegistryEntries.where((item) => item.status == 'Source needed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Source Registry', subtitle: 'Source-level operating view for connected assets, target sources, candidates, rights posture, and refresh cadence.'),
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
              _Metric(label: 'Sources', value: '${sourceRegistryEntries.length}', detail: 'Registry entries'),
              _Metric(label: 'Connected', value: '$connected', detail: 'Usable now'),
              _Metric(label: 'Targets', value: '$target', detail: 'Near-term focus'),
              _Metric(label: 'Needed', value: '$sourceNeeded', detail: 'Provider decision'),
            ],
          );
        }),
        const SizedBox(height: 22),
        TerminalCard(
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search sources, rights, notes...'))),
            _FilterDropdown(label: 'Domain', value: selectedDomain, values: domains, onChanged: (value) => setState(() => selectedDomain = value)),
            _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Source Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} entries', style: const TextStyle(color: terminalTextMuted))])),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 30,
                columns: const [DataColumn(label: Text('Source')), DataColumn(label: Text('Domain')), DataColumn(label: Text('Type')), DataColumn(label: Text('Status')), DataColumn(label: Text('Rights')), DataColumn(label: Text('Cadence')), DataColumn(label: Text('Notes'))],
                rows: [
                  for (final item in filtered)
                    DataRow(cells: [
                      DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Text(item.domain)),
                      DataCell(SizedBox(width: 250, child: Text(item.sourceType))),
                      DataCell(InfoPill(label: item.status)),
                      DataCell(SizedBox(width: 260, child: Text(item.rightsPosture))),
                      DataCell(SizedBox(width: 220, child: Text(item.refreshCadence))),
                      DataCell(SizedBox(width: 560, child: Text(item.notes))),
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
