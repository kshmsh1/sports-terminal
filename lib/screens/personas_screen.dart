import 'package:flutter/material.dart';

import '../data/persona_items.dart';
import '../widgets/terminal_primitives.dart';

class PersonasScreen extends StatefulWidget {
  const PersonasScreen({super.key});

  @override
  State<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends State<PersonasScreen> {
  String query = '';
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    final filtered = personaItems.where((item) {
      final q = query.trim().toLowerCase();
      return q.isEmpty ||
          item.persona.toLowerCase().contains(q) ||
          item.primaryJobs.toLowerCase().contains(q) ||
          item.keyScreens.toLowerCase().contains(q) ||
          item.mustHaveData.toLowerCase().contains(q) ||
          item.workflowNeeds.toLowerCase().contains(q);
    }).toList();
    final selected = personaItems.where((item) => item.id == selectedId).firstOrNull ?? (filtered.isNotEmpty ? filtered.first : null);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Personas', subtitle: 'User and stakeholder map for how the terminal should serve front-office analysts, media researchers, scouts, fantasy users, betting-adjacent analysts, and league operators.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Personas', value: '${personaItems.length}', detail: 'Stakeholder map'),
          _Metric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
          const _Metric(label: 'Priority', value: 'NBA', detail: 'First sport'),
          const _Metric(label: 'Mode', value: 'Design', detail: 'Product strategy'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: SizedBox(width: 420, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search persona, screens, data needs, workflows...')))),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1050;
        final table = _PersonaTable(items: filtered, selectedId: selected?.id, onSelected: (item) => setState(() => selectedId = item.id));
        final detail = _PersonaDetail(item: selected);
        if (!isWide) return Column(children: [table, const SizedBox(height: 14), detail]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: table), const SizedBox(width: 14), Expanded(flex: 2, child: detail)]);
      }),
    ]);
  }
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _PersonaTable extends StatelessWidget {
  const _PersonaTable({required this.items, required this.selectedId, required this.onSelected});
  final List<dynamic> items;
  final String? selectedId;
  final ValueChanged<dynamic> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Persona Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} personas', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Persona')), DataColumn(label: Text('Primary Jobs')), DataColumn(label: Text('Key Screens')), DataColumn(label: Text('Must-Have Data')), DataColumn(label: Text('Workflow Needs'))], rows: [for (final item in items) DataRow(selected: selectedId == item.id, onSelectChanged: (_) => onSelected(item), cells: [DataCell(SizedBox(width: 240, child: Text(item.persona, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 460, child: Text(item.primaryJobs))), DataCell(SizedBox(width: 420, child: Text(item.keyScreens))), DataCell(SizedBox(width: 440, child: Text(item.mustHaveData))), DataCell(SizedBox(width: 460, child: Text(item.workflowNeeds)))])])),
  ]));
}

class _PersonaDetail extends StatelessWidget {
  const _PersonaDetail({required this.item});
  final dynamic item;
  @override
  Widget build(BuildContext context) {
    if (item == null) return const TerminalCard(child: Text('Select a persona to inspect needs.', style: TextStyle(color: terminalTextSoft)));
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.persona, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      const Text('Primary jobs', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(item.primaryJobs, style: const TextStyle(color: terminalTextSoft, height: 1.4)),
      const SizedBox(height: 14),
      const Text('Key screens', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(item.keyScreens, style: const TextStyle(color: terminalTextSoft, height: 1.4)),
      const SizedBox(height: 14),
      const Text('Workflow needs', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(item.workflowNeeds, style: const TextStyle(color: terminalTextSoft, height: 1.4)),
    ]));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
