import 'package:flutter/material.dart';

import '../data/field_dictionary_items.dart';
import '../widgets/terminal_primitives.dart';

class FieldDictionaryScreen extends StatefulWidget {
  const FieldDictionaryScreen({super.key});

  @override
  State<FieldDictionaryScreen> createState() => _FieldDictionaryScreenState();
}

class _FieldDictionaryScreenState extends State<FieldDictionaryScreen> {
  String selectedDomain = 'All';
  String selectedRequired = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final domains = ['All', ...fieldDictionaryItems.map((item) => item.domain).toSet().toList()..sort()];
    final requiredValues = ['All', ...fieldDictionaryItems.map((item) => item.required).toSet().toList()..sort()];
    final filtered = fieldDictionaryItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesDomain = selectedDomain == 'All' || item.domain == selectedDomain;
      final matchesRequired = selectedRequired == 'All' || item.required == selectedRequired;
      final matchesQuery = normalized.isEmpty ||
          item.field.toLowerCase().contains(normalized) ||
          item.domain.toLowerCase().contains(normalized) ||
          item.type.toLowerCase().contains(normalized) ||
          item.nullPolicy.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized);
      return matchesDomain && matchesRequired && matchesQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Field Dictionary',
          subtitle: 'Shared data dictionary for entity identifiers, source metadata, join keys, null behavior, and core terminal fields.',
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
                _FieldMetric(label: 'Fields', value: '${fieldDictionaryItems.length}', detail: 'Initial dictionary'),
                _FieldMetric(label: 'Domains', value: '${domains.length - 1}', detail: 'Field groups'),
                _FieldMetric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
                const _FieldMetric(label: 'Rule', value: 'Join', detail: 'IDs before stats'),
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
                  decoration: _inputDecoration('Search fields, domains, null rules...'),
                ),
              ),
              _FilterDropdown(label: 'Domain', value: selectedDomain, values: domains, onChanged: (value) => setState(() => selectedDomain = value)),
              _FilterDropdown(label: 'Required', value: selectedRequired, values: requiredValues, onChanged: (value) => setState(() => selectedRequired = value)),
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
                child: Row(children: [const Text('Dictionary', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} fields', style: const TextStyle(color: terminalTextMuted))]),
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
                    DataColumn(label: Text('Domain')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Required')),
                    DataColumn(label: Text('Null Policy')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in filtered)
                      DataRow(cells: [
                        DataCell(Text(item.field, style: const TextStyle(fontWeight: FontWeight.w900))),
                        DataCell(SizedBox(width: 220, child: Text(item.domain))),
                        DataCell(Text(item.type)),
                        DataCell(InfoPill(label: item.required)),
                        DataCell(SizedBox(width: 260, child: Text(item.nullPolicy))),
                        DataCell(SizedBox(width: 620, child: Text(item.description))),
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

class _FieldMetric extends StatelessWidget {
  const _FieldMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
  }
}
