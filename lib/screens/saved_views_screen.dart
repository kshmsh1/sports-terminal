import 'package:flutter/material.dart';

import '../data/saved_view_items.dart';
import '../widgets/terminal_primitives.dart';

class SavedViewsScreen extends StatefulWidget {
  const SavedViewsScreen({super.key});

  @override
  State<SavedViewsScreen> createState() => _SavedViewsScreenState();
}

class _SavedViewsScreenState extends State<SavedViewsScreen> {
  String selectedWorkspace = 'All';
  String selectedStatus = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final workspaces = ['All', ...savedViewItems.map((item) => item.workspace).toSet().toList()..sort()];
    final statuses = ['All', ...savedViewItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = savedViewItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesWorkspace = selectedWorkspace == 'All' || item.workspace == selectedWorkspace;
      final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
      final matchesQuery = normalized.isEmpty ||
          item.name.toLowerCase().contains(normalized) ||
          item.workspace.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized) ||
          item.filters.toLowerCase().contains(normalized) ||
          item.output.toLowerCase().contains(normalized);
      return matchesWorkspace && matchesStatus && matchesQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Saved Views',
          subtitle: 'Future workspace presets for repeatable player, team, draft, award, transaction, and development workflows.',
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
                _SavedViewMetric(label: 'Saved Views', value: '${savedViewItems.length}', detail: 'Initial presets'),
                _SavedViewMetric(label: 'Workspaces', value: '${workspaces.length - 1}', detail: 'Covered areas'),
                _SavedViewMetric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
                const _SavedViewMetric(label: 'Mode', value: 'Design', detail: 'Persistence later'),
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
              SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search saved views, filters, outputs...'))),
              _FilterDropdown(label: 'Workspace', value: selectedWorkspace, values: workspaces, onChanged: (value) => setState(() => selectedWorkspace = value)),
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
                child: Row(children: [const Text('Saved View Library', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} views', style: const TextStyle(color: terminalTextMuted))]),
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
                    DataColumn(label: Text('View')),
                    DataColumn(label: Text('Workspace')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Filters')),
                    DataColumn(label: Text('Output')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in filtered)
                      DataRow(cells: [
                        DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                        DataCell(Text(item.workspace)),
                        DataCell(InfoPill(label: item.status)),
                        DataCell(SizedBox(width: 440, child: Text(item.filters))),
                        DataCell(SizedBox(width: 460, child: Text(item.output))),
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

class _SavedViewMetric extends StatelessWidget {
  const _SavedViewMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
  }
}
