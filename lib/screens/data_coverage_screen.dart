import 'package:flutter/material.dart';

import '../data/coverage_items.dart';
import '../widgets/terminal_primitives.dart';

class DataCoverageScreen extends StatefulWidget {
  const DataCoverageScreen({super.key});

  @override
  State<DataCoverageScreen> createState() => _DataCoverageScreenState();
}

class _DataCoverageScreenState extends State<DataCoverageScreen> {
  String selectedStatus = 'All';
  String selectedDomain = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final domains = ['All', ...coverageItems.map((item) => item.domain).toSet().toList()..sort()];
    final statuses = ['All', ...coverageItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = coverageItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesDomain = selectedDomain == 'All' || item.domain == selectedDomain;
      final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
      final matchesQuery = normalized.isEmpty ||
          item.dataset.toLowerCase().contains(normalized) ||
          item.domain.toLowerCase().contains(normalized) ||
          item.assetPath.toLowerCase().contains(normalized) ||
          item.nextStep.toLowerCase().contains(normalized);
      return matchesDomain && matchesStatus && matchesQuery;
    }).toList();

    final connected = coverageItems.where((item) => item.status == 'Connected').length;
    final pending = coverageItems.where((item) => item.status.contains('pending')).length;
    final totalRows = coverageItems.fold<int>(0, (sum, item) => sum + item.recordCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Data Coverage',
          subtitle: 'Coverage dashboard for connected assets, pending data layers, record counts, priority, and next ingestion steps.',
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
                _Metric(label: 'Datasets', value: '${coverageItems.length}', detail: 'Coverage map'),
                _Metric(label: 'Connected', value: '$connected', detail: 'Usable now'),
                _Metric(label: 'Pending', value: '$pending', detail: 'Source needed'),
                _Metric(label: 'Rows', value: '$totalRows', detail: 'Known records'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: terminalAccent,
                  decoration: _inputDecoration('Search dataset, path, next step...'),
                ),
              ),
              _FilterDropdown(label: 'Domain', value: selectedDomain, values: domains, onChanged: (value) => setState(() => selectedDomain = value)),
              _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Coverage Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} datasets', style: const TextStyle(color: terminalTextMuted))])),
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
                  DataColumn(label: Text('Dataset')),
                  DataColumn(label: Text('Domain')),
                  DataColumn(label: Text('Rows')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Asset Path')),
                  DataColumn(label: Text('Next Step')),
                ],
                rows: [
                  for (final item in filtered)
                    DataRow(cells: [
                      DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(SizedBox(width: 220, child: Text(item.dataset, style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Text(item.domain)),
                      DataCell(Text('${item.recordCount}')),
                      DataCell(InfoPill(label: item.status)),
                      DataCell(SizedBox(width: 420, child: Text(item.assetPath))),
                      DataCell(SizedBox(width: 520, child: Text(item.nextStep))),
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

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: DropdownButtonFormField<String>(
          value: value,
          dropdownColor: terminalPanelDark,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))),
          items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: (value) { if (value != null) onChanged(value); },
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
