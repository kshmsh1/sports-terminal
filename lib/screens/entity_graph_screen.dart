import 'package:flutter/material.dart';

import '../data/entity_relationship_items.dart';
import '../widgets/terminal_primitives.dart';

class EntityGraphScreen extends StatefulWidget {
  const EntityGraphScreen({super.key});

  @override
  State<EntityGraphScreen> createState() => _EntityGraphScreenState();
}

class _EntityGraphScreenState extends State<EntityGraphScreen> {
  String selectedStatus = 'All';
  String selectedEntity = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final statuses = ['All', ...entityRelationshipItems.map((item) => item.status).toSet().toList()..sort()];
    final entities = ['All', ...entityRelationshipItems.expand((item) => [item.fromEntity, item.toEntity]).toSet().toList()..sort()];
    final filtered = entityRelationshipItems.where((item) {
      final normalized = query.trim().toLowerCase();
      final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
      final matchesEntity = selectedEntity == 'All' || item.fromEntity == selectedEntity || item.toEntity == selectedEntity;
      final matchesQuery = normalized.isEmpty ||
          item.fromEntity.toLowerCase().contains(normalized) ||
          item.toEntity.toLowerCase().contains(normalized) ||
          item.relationship.toLowerCase().contains(normalized) ||
          item.description.toLowerCase().contains(normalized) ||
          item.requiredDataset.toLowerCase().contains(normalized);
      return matchesStatus && matchesEntity && matchesQuery;
    }).toList();

    final schemaReady = entityRelationshipItems.where((item) => item.status == 'Schema ready').length;
    final planned = entityRelationshipItems.where((item) => item.status == 'Planned').length;
    final future = entityRelationshipItems.where((item) => item.status == 'Future').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Entity Graph',
          subtitle: 'Relationship map for how players, teams, seasons, games, rosters, awards, draft, transactions, injuries, playoffs, and G League layers connect.',
        ),
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
              _Metric(label: 'Relationships', value: '${entityRelationshipItems.length}', detail: 'Entity map'),
              _Metric(label: 'Schema Ready', value: '$schemaReady', detail: 'Join keys exist'),
              _Metric(label: 'Planned', value: '$planned', detail: 'Source pending'),
              _Metric(label: 'Future', value: '$future', detail: 'Later depth'),
            ],
          );
        }),
        const SizedBox(height: 22),
        TerminalCard(
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search entity, relationship, dataset...'))),
            _FilterDropdown(label: 'Entity', value: selectedEntity, values: entities, onChanged: (value) => setState(() => selectedEntity = value)),
            _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Graph Principle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text('The terminal should be built around durable entity relationships, not isolated tables. A player profile, team record, season, game, roster row, transaction, award, draft pick, and injury record all become more valuable when their join keys are explicit and validated.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
          ]),
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Relationship Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} relationships', style: const TextStyle(color: terminalTextMuted))])),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 30,
                columns: const [
                  DataColumn(label: Text('From')),
                  DataColumn(label: Text('Relationship')),
                  DataColumn(label: Text('To')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Required Dataset')),
                  DataColumn(label: Text('Description')),
                ],
                rows: [
                  for (final item in filtered)
                    DataRow(cells: [
                      DataCell(Text(item.fromEntity, style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(item.relationship)),
                      DataCell(Text(item.toEntity, style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(InfoPill(label: item.status)),
                      DataCell(SizedBox(width: 360, child: Text(item.requiredDataset))),
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
  Widget build(BuildContext context) => SizedBox(width: 240, child: DropdownButtonFormField<String>(value: value, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
