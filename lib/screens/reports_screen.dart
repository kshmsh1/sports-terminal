import 'package:flutter/material.dart';

import '../data/report_library_items.dart';
import '../data/report_section_template_items.dart';
import '../widgets/terminal_primitives.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String selectedCategory = 'All';
  String selectedStatus = 'All';
  String selectedReportType = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...reportLibraryItems.map((item) => item.category).toSet().toList()..sort()];
    final statuses = ['All', ...reportLibraryItems.map((item) => item.status).toSet().toList()..sort()];
    final reportTypes = ['All', ...reportSectionTemplateItems.map((item) => item.reportType).toSet().toList()..sort()];
    final filtered = reportLibraryItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesCategory = selectedCategory == 'All' || item.category == selectedCategory;
      final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
      final matchesQuery = normalized.isEmpty ||
          item.title.toLowerCase().contains(normalized) ||
          item.category.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized) ||
          item.primaryEntities.toLowerCase().contains(normalized) ||
          item.requiredDatasets.toLowerCase().contains(normalized);
      return matchesCategory && matchesStatus && matchesQuery;
    }).toList();
    final filteredSections = reportSectionTemplateItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesType = selectedReportType == 'All' || item.reportType == selectedReportType;
      final matchesQuery = normalized.isEmpty ||
          item.reportType.toLowerCase().contains(normalized) ||
          item.section.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized) ||
          item.dataInputs.toLowerCase().contains(normalized);
      return matchesType && matchesQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Reports',
          subtitle: 'Terminal report library for reusable player, team, season, draft, award, transaction, and development intelligence workflows.',
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
                _ReportMetric(label: 'Reports', value: '${reportLibraryItems.length}', detail: 'Initial library'),
                _ReportMetric(label: 'Report Sections', value: '${reportSectionTemplateItems.length}', detail: 'Template blocks'),
                _ReportMetric(label: 'Filtered Reports', value: '${filtered.length}', detail: 'Current view'),
                _ReportMetric(label: 'Filtered Sections', value: '${filteredSections.length}', detail: 'Current template view'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: terminalAccent,
                  decoration: _inputDecoration('Search reports, sections, entities, datasets...'),
                ),
              ),
              _FilterDropdown(label: 'Category', value: selectedCategory, values: categories, onChanged: (value) => setState(() => selectedCategory = value)),
              _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
              _FilterDropdown(label: 'Report Type', value: selectedReportType, values: reportTypes, onChanged: (value) => setState(() => selectedReportType = value)),
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
                    const Text('Report Library', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${filtered.length} reports', style: const TextStyle(color: terminalTextMuted)),
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
                    DataColumn(label: Text('Priority')),
                    DataColumn(label: Text('Report')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Primary Entities')),
                    DataColumn(label: Text('Required Datasets')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in filtered)
                      DataRow(cells: [
                        DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                        DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
                        DataCell(SizedBox(width: 190, child: Text(item.category))),
                        DataCell(InfoPill(label: item.status)),
                        DataCell(SizedBox(width: 260, child: Text(item.primaryEntities))),
                        DataCell(SizedBox(width: 420, child: Text(item.requiredDatasets))),
                        DataCell(SizedBox(width: 620, child: Text(item.description))),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Report Section Templates', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filteredSections.length} sections', style: const TextStyle(color: terminalTextMuted))])),
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
                  DataColumn(label: Text('Report Type')),
                  DataColumn(label: Text('Section')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Data Inputs')),
                  DataColumn(label: Text('Description')),
                ],
                rows: [
                  for (final item in filteredSections)
                    DataRow(cells: [
                      DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(SizedBox(width: 190, child: Text(item.reportType))),
                      DataCell(SizedBox(width: 230, child: Text(item.section, style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(InfoPill(label: item.status)),
                      DataCell(SizedBox(width: 440, child: Text(item.dataInputs))),
                      DataCell(SizedBox(width: 620, child: Text(item.description))),
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
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: terminalTextMuted),
          filled: true,
          fillColor: terminalPanelDark,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
        ),
        items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
        ],
      ),
    );
  }
}
