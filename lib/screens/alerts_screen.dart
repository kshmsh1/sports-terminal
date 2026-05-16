import 'package:flutter/material.dart';

import '../data/alert_rule_items.dart';
import '../widgets/terminal_primitives.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String selectedCategory = 'All';
  String selectedStatus = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...alertRuleItems.map((item) => item.category).toSet().toList()..sort()];
    final statuses = ['All', ...alertRuleItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = alertRuleItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesCategory = selectedCategory == 'All' || item.category == selectedCategory;
      final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
      final matchesQuery = normalized.isEmpty ||
          item.name.toLowerCase().contains(normalized) ||
          item.category.toLowerCase().contains(normalized) ||
          item.trigger.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized) ||
          item.requiredData.toLowerCase().contains(normalized);
      return matchesCategory && matchesStatus && matchesQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Alerts',
          subtitle: 'Future alert-rule library for dataset changes, data quality failures, player updates, team movement, source-policy risk, and development-path events.',
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
                _AlertMetric(label: 'Alert Rules', value: '${alertRuleItems.length}', detail: 'Initial rules'),
                _AlertMetric(label: 'Categories', value: '${categories.length - 1}', detail: 'Monitoring areas'),
                _AlertMetric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
                const _AlertMetric(label: 'Mode', value: 'Design', detail: 'No live jobs yet'),
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
                width: 340,
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: terminalAccent,
                  decoration: _inputDecoration('Search alerts, triggers, required data...'),
                ),
              ),
              _FilterDropdown(label: 'Category', value: selectedCategory, values: categories, onChanged: (value) => setState(() => selectedCategory = value)),
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
                child: Row(
                  children: [
                    const Text('Alert Rule Library', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${filtered.length} rules', style: const TextStyle(color: terminalTextMuted)),
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
                    DataColumn(label: Text('Rule')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Trigger')),
                    DataColumn(label: Text('Required Data')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in filtered)
                      DataRow(cells: [
                        DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                        DataCell(SizedBox(width: 190, child: Text(item.category))),
                        DataCell(InfoPill(label: item.status)),
                        DataCell(SizedBox(width: 520, child: Text(item.trigger))),
                        DataCell(SizedBox(width: 420, child: Text(item.requiredData))),
                        DataCell(SizedBox(width: 560, child: Text(item.description))),
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
}

class _AlertMetric extends StatelessWidget {
  const _AlertMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
  }
}
