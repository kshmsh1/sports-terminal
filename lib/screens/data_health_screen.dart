import 'package:flutter/material.dart';

import '../data/data_health_check_items.dart';
import '../widgets/terminal_primitives.dart';

class DataHealthScreen extends StatefulWidget {
  const DataHealthScreen({super.key});

  @override
  State<DataHealthScreen> createState() => _DataHealthScreenState();
}

class _DataHealthScreenState extends State<DataHealthScreen> {
  String selectedDomain = 'All';
  String selectedSeverity = 'All';
  String selectedStatus = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final domains = ['All', ...dataHealthCheckItems.map((item) => item.domain).toSet().toList()..sort()];
    final severities = ['All', ...dataHealthCheckItems.map((item) => item.severity).toSet().toList()..sort()];
    final statuses = ['All', ...dataHealthCheckItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = dataHealthCheckItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesDomain = selectedDomain == 'All' || item.domain == selectedDomain;
      final matchesSeverity = selectedSeverity == 'All' || item.severity == selectedSeverity;
      final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
      final matchesQuery = normalized.isEmpty ||
          item.name.toLowerCase().contains(normalized) ||
          item.domain.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized) ||
          item.remediation.toLowerCase().contains(normalized);
      return matchesDomain && matchesSeverity && matchesStatus && matchesQuery;
    }).toList();

    final critical = dataHealthCheckItems.where((item) => item.severity == 'Critical').length;
    final started = dataHealthCheckItems.where((item) => item.status == 'Started').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Data Health',
          subtitle: 'Operational data health command center for asset loading, reference coverage, broken joins, null/zero handling, duplicates, and source-rights checks.',
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
                _HealthMetric(label: 'Checks', value: '${dataHealthCheckItems.length}', detail: 'Health registry'),
                _HealthMetric(label: 'Critical', value: '$critical', detail: 'Must pass'),
                _HealthMetric(label: 'Started', value: '$started', detail: 'Reflected now'),
                _HealthMetric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
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
              SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search checks, remediation, domains...'))),
              _FilterDropdown(label: 'Domain', value: selectedDomain, values: domains, onChanged: (value) => setState(() => selectedDomain = value)),
              _FilterDropdown(label: 'Severity', value: selectedSeverity, values: severities, onChanged: (value) => setState(() => selectedSeverity = value)),
              _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [const Text('Health Check Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} checks', style: const TextStyle(color: terminalTextMuted))]),
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
                    DataColumn(label: Text('Check')),
                    DataColumn(label: Text('Domain')),
                    DataColumn(label: Text('Severity')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Remediation')),
                  ],
                  rows: [
                    for (final item in filtered)
                      DataRow(cells: [
                        DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                        DataCell(Text(item.domain)),
                        DataCell(InfoPill(label: item.severity)),
                        DataCell(InfoPill(label: item.status)),
                        DataCell(SizedBox(width: 560, child: Text(item.description))),
                        DataCell(SizedBox(width: 520, child: Text(item.remediation))),
                      ]),
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

InputDecoration _inputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: terminalTextMuted),
    prefixIcon: const Icon(Icons.search, color: terminalTextMuted),
    filled: true,
    fillColor: terminalPanelDark,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
  );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
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
}

class _HealthMetric extends StatelessWidget {
  const _HealthMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
  }
}
