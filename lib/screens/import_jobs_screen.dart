import 'package:flutter/material.dart';

import '../data/import_job_plans.dart';
import '../widgets/terminal_primitives.dart';

class ImportJobsScreen extends StatefulWidget {
  const ImportJobsScreen({super.key});

  @override
  State<ImportJobsScreen> createState() => _ImportJobsScreenState();
}

class _ImportJobsScreenState extends State<ImportJobsScreen> {
  String selectedDomain = 'All';
  String selectedStatus = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final domains = ['All', ...importJobPlans.map((item) => item.domain).toSet().toList()..sort()];
    final statuses = ['All', ...importJobPlans.map((item) => item.status).toSet().toList()..sort()];
    final filtered = importJobPlans.where((item) {
      final normalized = query.trim().toLowerCase();
      return (selectedDomain == 'All' || item.domain == selectedDomain) &&
          (selectedStatus == 'All' || item.status == selectedStatus) &&
          (normalized.isEmpty || item.name.toLowerCase().contains(normalized) || item.domain.toLowerCase().contains(normalized) || item.input.toLowerCase().contains(normalized) || item.output.toLowerCase().contains(normalized) || item.validation.toLowerCase().contains(normalized));
    }).toList();

    final started = importJobPlans.where((item) => item.status.contains('Started')).length;
    final planned = importJobPlans.where((item) => item.status == 'Planned').length;
    final next = importJobPlans.where((item) => item.status == 'Next').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Import Jobs', subtitle: 'Operational plan for converting approved sources into normalized JSON assets, model objects, and validated app-ready datasets.'),
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
              _Metric(label: 'Jobs', value: '${importJobPlans.length}', detail: 'Import plan'),
              _Metric(label: 'Started', value: '$started', detail: 'Asset loaders'),
              _Metric(label: 'Next', value: '$next', detail: 'Player identity'),
              _Metric(label: 'Planned', value: '$planned', detail: 'Historical data'),
            ],
          );
        }),
        const SizedBox(height: 22),
        TerminalCard(
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search jobs, inputs, outputs, validation...'))),
            _FilterDropdown(label: 'Domain', value: selectedDomain, values: domains, onChanged: (value) => setState(() => selectedDomain = value)),
            _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Import Job Plan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} jobs', style: const TextStyle(color: terminalTextMuted))])),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 30,
                columns: const [DataColumn(label: Text('Job')), DataColumn(label: Text('Domain')), DataColumn(label: Text('Status')), DataColumn(label: Text('Input')), DataColumn(label: Text('Output')), DataColumn(label: Text('Validation'))],
                rows: [
                  for (final item in filtered)
                    DataRow(cells: [
                      DataCell(SizedBox(width: 280, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Text(item.domain)),
                      DataCell(InfoPill(label: item.status)),
                      DataCell(SizedBox(width: 380, child: Text(item.input))),
                      DataCell(SizedBox(width: 420, child: Text(item.output))),
                      DataCell(SizedBox(width: 640, child: Text(item.validation))),
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
