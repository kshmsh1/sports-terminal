import 'package:flutter/material.dart';

import '../data/action_surface_items.dart';
import '../data/alert_evaluator_stage_items.dart';
import '../data/alert_rule_items.dart';
import '../data/saved_view_items.dart';
import '../models/registry_item.dart';
import '../widgets/active_route_payload_panel.dart';
import '../widgets/terminal_primitives.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String selectedCategory = 'All';
  String selectedStatus = 'All';
  String selectedStageCategory = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...alertRuleItems.map((item) => item.category).toSet().toList()..sort()];
    final statuses = ['All', ...alertRuleItems.map((item) => item.status).toSet().toList()..sort()];
    final stageCategories = ['All', ...alertEvaluatorStageItems.map((item) => item.category).toSet().toList()..sort()];
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
    final filteredStages = alertEvaluatorStageItems.where((item) => selectedStageCategory == 'All' || item.category == selectedStageCategory).toList();
    final planned = alertRuleItems.where((item) => item.status == 'Planned').length;
    final future = alertRuleItems.where((item) => item.status == 'Future').length;
    final p0Stages = alertEvaluatorStageItems.where((item) => item.priority == 'P0').length;
    final p1Stages = alertEvaluatorStageItems.where((item) => item.priority == 'P1').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Alerts', subtitle: 'Monitoring cockpit for source health, saved views, workspace formulas, player/team intelligence, games, awards, draft, transactions, fantasy, community moderation, development, and scouting workflows.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _AlertMetric(label: 'Alert Rules', value: '${alertRuleItems.length}', detail: '$planned planned / $future future'),
          _AlertMetric(label: 'Categories', value: '${categories.length - 1}', detail: 'Monitoring areas'),
          _AlertMetric(label: 'Evaluator Stages', value: '${alertEvaluatorStageItems.length}', detail: '$p0Stages P0 / $p1Stages P1'),
          _AlertMetric(label: 'Hooks', value: '${savedViewItems.length + actionSurfaceItems.length}', detail: 'Saved views + actions'),
        ]);
      }),
      const SizedBox(height: 22),
      const ActiveRoutePayloadPanel(consumerName: 'Alerts', description: 'Alerts now read the active shared RoutePayload as a monitor-rule preview source. Retarget a Team, Season, or Operations object to Alerts to inspect row, source, field, and blocker monitoring inputs.', compact: true),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search alerts, triggers, required data...'))),
        _FilterDropdown(label: 'Category', value: selectedCategory, values: categories, onChanged: (value) => setState(() => selectedCategory = value)),
        _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
        _FilterDropdown(label: 'Stage Category', value: selectedStageCategory, values: stageCategories, onChanged: (value) => setState(() => selectedStageCategory = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final left = const _AlertEvaluatorPanel();
        final right = _AlertActionPanel(actionCount: actionSurfaceItems.length, savedViewCount: savedViewItems.length);
        if (constraints.maxWidth < 1050) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 22),
      _AlertRuleTable(filtered: filtered),
      const SizedBox(height: 22),
      _EvaluatorStageTable(items: filteredStages),
    ]);
  }
}

class _AlertEvaluatorPanel extends StatelessWidget {
  const _AlertEvaluatorPanel();

  @override
  Widget build(BuildContext context) {
    final steps = ['Bind source', 'Define trigger', 'Set scope', 'Choose cadence', 'Snapshot baseline', 'Compare current state', 'Assign severity', 'Route next action'];
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Alert Evaluator Pipeline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Text('Alerts should become the monitoring layer for saved views, imports, source freshness, data quality, workspace formulas, player/team changes, fantasy boards, community moderation, and workflow blockers.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')]),
    ]));
  }
}

class _AlertActionPanel extends StatelessWidget {
  const _AlertActionPanel({required this.actionCount, required this.savedViewCount});
  final int actionCount;
  final int savedViewCount;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Alert Routing Hooks', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    Text('Alerts should not only notify. They should route users into work: open saved view, audit source, refresh import, inspect data health, generate report, update fantasy board, review community queue, or pin to dashboard. Current design links to $savedViewCount saved view presets and $actionCount Action Center verbs.', style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 16),
    const Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Open saved view'), InfoPill(label: 'Audit source'), InfoPill(label: 'Refresh import'), InfoPill(label: 'Generate report'), InfoPill(label: 'Pin dashboard'), InfoPill(label: 'Fantasy board'), InfoPill(label: 'Moderation queue')]),
  ]));
}

class _AlertRuleTable extends StatelessWidget {
  const _AlertRuleTable({required this.filtered});
  final List<dynamic> filtered;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Alert Rule Library', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} rules', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Rule')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Trigger')), DataColumn(label: Text('Required Data')), DataColumn(label: Text('Description'))], rows: [for (final item in filtered) DataRow(cells: [DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 190, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 520, child: Text(item.trigger))), DataCell(SizedBox(width: 420, child: Text(item.requiredData))), DataCell(SizedBox(width: 560, child: Text(item.description)))])])),
  ]));
}

class _EvaluatorStageTable extends StatelessWidget {
  const _EvaluatorStageTable({required this.items});
  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Alert Evaluator Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 360, child: Text(item.inputs))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])])),
  ]));
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

class _AlertMetric extends StatelessWidget {
  const _AlertMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
