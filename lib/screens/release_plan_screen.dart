import 'package:flutter/material.dart';

import '../data/release_milestone_items.dart';
import '../widgets/terminal_primitives.dart';

class ReleasePlanScreen extends StatefulWidget {
  const ReleasePlanScreen({super.key});

  @override
  State<ReleasePlanScreen> createState() => _ReleasePlanScreenState();
}

class _ReleasePlanScreenState extends State<ReleasePlanScreen> {
  String query = '';
  String phase = 'All';
  String status = 'All';

  @override
  Widget build(BuildContext context) {
    final phases = ['All', ...releaseMilestoneItems.map((item) => item.phase).toSet().toList()..sort()];
    final statuses = ['All', ...releaseMilestoneItems.map((item) => item.status).toSet().toList()..sort()];
    final filtered = releaseMilestoneItems.where((item) {
      final q = query.trim().toLowerCase();
      return (phase == 'All' || item.phase == phase) &&
          (status == 'All' || item.status == status) &&
          (q.isEmpty || item.name.toLowerCase().contains(q) || item.goal.toLowerCase().contains(q) || item.scope.toLowerCase().contains(q) || item.exitCriteria.toLowerCase().contains(q));
    }).toList();
    final inProgress = releaseMilestoneItems.where((item) => item.status == 'In progress').length;
    final next = releaseMilestoneItems.where((item) => item.status == 'Next').length;
    final planned = releaseMilestoneItems.where((item) => item.status == 'Planned').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Release Plan', subtitle: 'Build and release sequencing for the zero-cost NBA-first terminal from MVP shell to data foundation, analytics, workflow, and expansion releases.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Milestones', value: '${releaseMilestoneItems.length}', detail: 'Release map'),
          _Metric(label: 'In Progress', value: '$inProgress', detail: 'Current'),
          _Metric(label: 'Next', value: '$next', detail: 'Immediate'),
          _Metric(label: 'Planned', value: '$planned', detail: 'Near-term'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search release, scope, exit criteria...'))),
        _FilterDropdown(label: 'Phase', value: phase, values: phases, onChanged: (value) => setState(() => phase = value)),
        _FilterDropdown(label: 'Status', value: status, values: statuses, onChanged: (value) => setState(() => status = value)),
      ])),
      const SizedBox(height: 22),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Release Milestones', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} milestones', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Milestone')), DataColumn(label: Text('Phase')), DataColumn(label: Text('Status')), DataColumn(label: Text('Goal')), DataColumn(label: Text('Scope')), DataColumn(label: Text('Exit Criteria'))], rows: [for (final item in filtered) DataRow(cells: [DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.phase)), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 440, child: Text(item.goal))), DataCell(SizedBox(width: 520, child: Text(item.scope))), DataCell(SizedBox(width: 620, child: Text(item.exitCriteria)))])])),
      ])),
    ]);
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
