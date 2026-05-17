import 'package:flutter/material.dart';

import '../data/action_execution_stage_items.dart';
import '../data/action_surface_items.dart';
import '../data/action_workflow_items.dart';
import '../models/registry_item.dart';
import '../widgets/terminal_primitives.dart';

class ActionCenterScreen extends StatefulWidget {
  const ActionCenterScreen({super.key});

  @override
  State<ActionCenterScreen> createState() => _ActionCenterScreenState();
}

class _ActionCenterScreenState extends State<ActionCenterScreen> {
  String selectedAction = 'Add to Workspace';
  String selectedRoute = 'Player Row to Compare';
  String selectedStage = 'Capture Active Context';
  String selectedReadiness = 'Source Pending';

  @override
  Widget build(BuildContext context) {
    final action = actionSurfaceItems.firstWhere((item) => item.title == selectedAction, orElse: () => actionSurfaceItems.first);
    final route = actionWorkflowItems.firstWhere((item) => item.title == selectedRoute, orElse: () => actionWorkflowItems.first);
    final stage = actionExecutionStageItems.firstWhere((item) => item.title == selectedStage, orElse: () => actionExecutionStageItems.first);
    final readiness = _readinessStates.firstWhere((item) => item.name == selectedReadiness);
    final allItems = [...actionSurfaceItems, ...actionWorkflowItems, ...actionExecutionStageItems];
    final p0 = allItems.where((item) => item.priority == 'P0').length;
    final p1 = allItems.where((item) => item.priority == 'P1').length;
    final planned = allItems.where((item) => item.status == 'Planned').length;
    final future = allItems.where((item) => item.status == 'Future').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Action Center', subtitle: 'Universal action, route, readiness, and execution cockpit for turning terminal objects into workspaces, comparisons, reports, exports, alerts, fantasy workflows, scouting packets, community embeds, and source audits.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Actions', value: '${actionSurfaceItems.length}', detail: 'Surface-level verbs'),
          _Metric(label: 'Routes', value: '${actionWorkflowItems.length}', detail: 'Object-to-workflow paths'),
          _Metric(label: 'Execution Stages', value: '${actionExecutionStageItems.length}', detail: 'Implementation gates'),
          _Metric(label: 'P0 / P1', value: '$p0 / $p1', detail: '$planned planned / $future future'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        _Picker(label: 'Action', value: selectedAction, values: actionSurfaceItems.map((item) => item.title).toList(), onChanged: (value) => setState(() => selectedAction = value)),
        _Picker(label: 'Route', value: selectedRoute, values: actionWorkflowItems.map((item) => item.title).toList(), onChanged: (value) => setState(() => selectedRoute = value)),
        _Picker(label: 'Stage', value: selectedStage, values: actionExecutionStageItems.map((item) => item.title).toList(), onChanged: (value) => setState(() => selectedStage = value)),
        _Picker(label: 'Readiness', value: selectedReadiness, values: _readinessStates.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedReadiness = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final left = _ActionTicket(action: action, route: route, stage: stage, readiness: readiness);
        final right = const _ActionArchitecturePanel();
        if (constraints.maxWidth < 1050) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 22),
      const _ActionPipelinePanel(),
      const SizedBox(height: 22),
      _RegistryTable(title: 'Action Surface Registry', items: actionSurfaceItems, selectedTitle: selectedAction),
      const SizedBox(height: 22),
      _RegistryTable(title: 'Action Route Registry', items: actionWorkflowItems, selectedTitle: selectedRoute),
      const SizedBox(height: 22),
      _RegistryTable(title: 'Execution Stage Registry', items: actionExecutionStageItems, selectedTitle: selectedStage),
      const SizedBox(height: 22),
      const _ReadinessTable(),
    ]);
  }
}

class _ReadinessState {
  const _ReadinessState(this.name, this.status, this.meaning, this.nextStep);
  final String name;
  final String status;
  final String meaning;
  final String nextStep;
}

const _readinessStates = <_ReadinessState>[
  _ReadinessState('Ready', 'Future state', 'All required source rows, selected rows, route payload, and target workspace exist.', 'Enable action button and create target output.'),
  _ReadinessState('Source Pending', 'Current reality', 'The screen and route are designed, but underlying player, stat, game, roster, award, or transaction rows are not loaded yet.', 'Show disabled action with source-pending explanation.'),
  _ReadinessState('Needs Player Identity', 'Blocker', 'The action requires playerId or player profile rows before it can safely route.', 'Prioritize player identity import before player-centric workflows.'),
  _ReadinessState('Needs Persistence', 'Blocker', 'The action needs saved views, workspace state, reports, watchlists, or snapshots to be stored.', 'Define local persistence model before enabling action.'),
  _ReadinessState('Needs Accounts', 'Later blocker', 'The action requires users, permissions, private groups, creator profiles, or publishing identity.', 'Delay network actions until backend/account architecture exists.'),
  _ReadinessState('Needs Review', 'Later blocker', 'The action creates public or shared content that requires moderation, source labels, or claim flags.', 'Build moderation before public community publishing.'),
];

class _ActionTicket extends StatelessWidget {
  const _ActionTicket({required this.action, required this.route, required this.stage, required this.readiness});
  final RegistryItem action;
  final RegistryItem route;
  final RegistryItem stage;
  final _ReadinessState readiness;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Action Route Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 14),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: action.priority), InfoPill(label: action.status), InfoPill(label: route.category), InfoPill(label: stage.category), InfoPill(label: readiness.name)]),
    const SizedBox(height: 16),
    _DetailLine(label: 'Action', value: '${action.title}: ${action.description}'),
    _DetailLine(label: 'Route', value: '${route.title}: ${route.description}'),
    _DetailLine(label: 'Stage', value: '${stage.title}: ${stage.description}'),
    _DetailLine(label: 'Inputs', value: stage.inputs),
    _DetailLine(label: 'Readiness', value: '${readiness.status}: ${readiness.meaning}'),
    _DetailLine(label: 'Next Step', value: stage.nextStep),
    _DetailLine(label: 'Action Step', value: action.nextStep),
    _DetailLine(label: 'Route Step', value: route.nextStep),
  ]));
}

class _ActionArchitecturePanel extends StatelessWidget {
  const _ActionArchitecturePanel();

  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Action Architecture', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 12),
    Text('Action Center is the routing layer between information and work. It defines what users can do from tables, entity pages, selected records, workspaces, fantasy boards, reports, and community posts. The execution stage registry turns that design into an implementation plan.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 16),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Source object'), InfoPill(label: 'Action verb'), InfoPill(label: 'Route payload'), InfoPill(label: 'Readiness gate'), InfoPill(label: 'Target workspace'), InfoPill(label: 'Audit event')]),
  ]));
}

class _ActionPipelinePanel extends StatelessWidget {
  const _ActionPipelinePanel();

  @override
  Widget build(BuildContext context) {
    final steps = ['Capture context', 'Normalize selection', 'Choose action', 'Validate readiness', 'Build route payload', 'Open target module', 'Write audit event', 'Save or export'];
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Action Execution Pipeline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')]),
    ]));
  }
}

class _RegistryTable extends StatelessWidget {
  const _RegistryTable({required this.title, required this.items, required this.selectedTitle});
  final String title;
  final List<RegistryItem> items;
  final String selectedTitle;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} items', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Title')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))],
      rows: [for (final item in items) DataRow(selected: item.title == selectedTitle, cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 360, child: Text(item.inputs))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])],
    )),
  ]));
}

class _ReadinessTable extends StatelessWidget {
  const _ReadinessTable();

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Action Readiness Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('State')), DataColumn(label: Text('Status')), DataColumn(label: Text('Meaning')), DataColumn(label: Text('Next Step'))],
      rows: [for (final state in _readinessStates) DataRow(cells: [DataCell(SizedBox(width: 190, child: Text(state.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: state.status)), DataCell(SizedBox(width: 680, child: Text(state.meaning))), DataCell(SizedBox(width: 460, child: Text(state.nextStep)))])],
    )),
  ]));
}

class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(width: 300, child: DropdownButtonFormField<String>(
    value: values.contains(value) ? value : values.first,
    dropdownColor: terminalPanelDark,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))),
    items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
    onChanged: (value) { if (value != null) onChanged(value); },
  ));
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
