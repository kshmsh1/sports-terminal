import 'package:flutter/material.dart';

import '../data/fantasy_product_items.dart';
import '../widgets/terminal_primitives.dart';

class FantasyTerminalScreen extends StatefulWidget {
  const FantasyTerminalScreen({super.key});

  @override
  State<FantasyTerminalScreen> createState() => _FantasyTerminalScreenState();
}

class _FantasyTerminalScreenState extends State<FantasyTerminalScreen> {
  String selectedLeague = 'Manual Points League';
  String selectedWorkflow = 'Roster Decision';
  String selectedHorizon = 'This Week';

  @override
  Widget build(BuildContext context) {
    final league = _leagueModes.firstWhere((item) => item.name == selectedLeague);
    final workflow = _fantasyWorkflows.firstWhere((item) => item.name == selectedWorkflow);
    final horizon = _horizons.firstWhere((item) => item.name == selectedHorizon);
    final p1 = fantasyProductItems.where((item) => item.priority == 'P1').length;
    final p2 = fantasyProductItems.where((item) => item.priority == 'P2').length;
    final future = fantasyProductItems.where((item) => item.status == 'Future').length;
    final planned = fantasyProductItems.where((item) => item.status == 'Planned').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(
        title: 'Fantasy Terminal',
        subtitle: 'Terminal-native fantasy cockpit for scoring rules, rosters, projections, waiver boards, trade analysis, matchup labs, alerts, and shareable fantasy workspaces.',
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
            _Metric(label: 'Fantasy Capabilities', value: '${fantasyProductItems.length}', detail: '$p1 P1 / $p2 P2'),
            _Metric(label: 'Planned / Future', value: '$planned / $future', detail: 'Implementation timing'),
            _Metric(label: 'League Modes', value: '${_leagueModes.length}', detail: 'Manual first'),
            _Metric(label: 'Workflows', value: '${_fantasyWorkflows.length}', detail: 'Roster, waiver, trade, matchup'),
          ],
        );
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        _Picker(label: 'League Mode', value: selectedLeague, values: _leagueModes.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedLeague = value)),
        _Picker(label: 'Workflow', value: selectedWorkflow, values: _fantasyWorkflows.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedWorkflow = value)),
        _Picker(label: 'Decision Horizon', value: selectedHorizon, values: _horizons.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedHorizon = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final left = _FantasyBuildTicket(league: league, workflow: workflow, horizon: horizon);
        final right = const _FantasyDataDependencyPanel();
        if (constraints.maxWidth < 1050) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 22),
      const _FantasyWorkflowPipeline(),
      const SizedBox(height: 22),
      _FantasyMatrix(selectedWorkflow: selectedWorkflow),
      const SizedBox(height: 22),
      const _ScoringRulePanel(),
      const SizedBox(height: 22),
      const _FantasyCapabilityTable(),
    ]);
  }
}

class _LeagueMode {
  const _LeagueMode(this.name, this.status, this.description, this.requiredData);
  final String name;
  final String status;
  final String description;
  final String requiredData;
}

class _FantasyWorkflow {
  const _FantasyWorkflow(this.name, this.status, this.question, this.output);
  final String name;
  final String status;
  final String question;
  final String output;
}

class _DecisionHorizon {
  const _DecisionHorizon(this.name, this.description, this.metrics);
  final String name;
  final String description;
  final String metrics;
}

const _leagueModes = <_LeagueMode>[
  _LeagueMode('Manual Points League', 'MVP First', 'User manually defines roster slots, scoring rules, teams, and watchlist before external league sync exists.', 'Player identity, player stats, scoring rules, user-entered roster'),
  _LeagueMode('Manual Category League', 'MVP First', 'User manually defines category targets and roster construction rules for head-to-head or roto analysis.', 'Player identity, stat categories, team schedule later, user-entered roster'),
  _LeagueMode('Synced League', 'Future', 'Connect ESPN, Yahoo, Sleeper, Fantrax, or other platforms after auth and integration policy are clear.', 'External connectors, auth, league settings, roster sync, permissions'),
  _LeagueMode('Creator Projection Room', 'Future', 'Creator publishes custom projections and fantasy boards using terminal data and Workspace Studio formulas.', 'Workspace persistence, formulas, community publishing, user accounts'),
];

const _fantasyWorkflows = <_FantasyWorkflow>[
  _FantasyWorkflow('Roster Decision', 'MVP', 'Who should I start, sit, bench, drop, or watch?', 'Ranked roster table with scoring fit, source fields, and decision notes.'),
  _FantasyWorkflow('Waiver Board', 'Planned', 'Who are the best available pickups for my league format?', 'Waiver board with value, schedule, trend, risk, and role context.'),
  _FantasyWorkflow('Trade Analyzer', 'Planned', 'Does this trade improve my roster under my scoring settings?', 'Side-by-side trade board using Compare, scoring rules, team needs, and replacement value.'),
  _FantasyWorkflow('Matchup Lab', 'Future', 'How does my weekly matchup look across schedule, categories, and expected output?', 'Matchup dashboard with games remaining, projected category exposure, and risk flags.'),
  _FantasyWorkflow('Projection Board', 'Future', 'What assumptions drive projected value and where can I adjust them?', 'Editable projection sheet powered by Workspace Studio formulas and saved scenarios.'),
  _FantasyWorkflow('Fantasy Alerts', 'Future', 'What changed that affects my roster or watchlist?', 'Alerts for roster changes, stat trends, schedule compression, waiver opportunities, and saved views.'),
];

const _horizons = <_DecisionHorizon>[
  _DecisionHorizon('Today', 'Single-day decision view for lineup choices and immediate matchups.', 'Game status, opponent, role, recent trend, scoring projection'),
  _DecisionHorizon('This Week', 'Weekly fantasy matchup window for schedule volume and roster decisions.', 'Games remaining, category exposure, usage trend, injury status later'),
  _DecisionHorizon('Rest of Season', 'Longer-term roster construction, buy/sell, waiver, and trade view.', 'Role stability, per-game value, trend, schedule, team context'),
  _DecisionHorizon('Playoffs', 'Fantasy playoff planning by schedule, team quality, risk, and category needs.', 'Playoff weeks, games count, opponent strength, role confidence'),
];

class _FantasyBuildTicket extends StatelessWidget {
  const _FantasyBuildTicket({required this.league, required this.workflow, required this.horizon});
  final _LeagueMode league;
  final _FantasyWorkflow workflow;
  final _DecisionHorizon horizon;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Fantasy Build Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 14),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: league.status), InfoPill(label: workflow.status), InfoPill(label: horizon.name)]),
    const SizedBox(height: 16),
    _DetailLine(label: 'League', value: '${league.name}: ${league.description}'),
    _DetailLine(label: 'Workflow', value: '${workflow.name}: ${workflow.question}'),
    _DetailLine(label: 'Output', value: workflow.output),
    _DetailLine(label: 'Horizon', value: horizon.description),
    _DetailLine(label: 'Metrics', value: horizon.metrics),
    _DetailLine(label: 'Data Need', value: league.requiredData),
  ]));
}

class _FantasyDataDependencyPanel extends StatelessWidget {
  const _FantasyDataDependencyPanel();

  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Fantasy Dependency Stack', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 12),
    Text('Fantasy should sit on top of the terminal rather than becoming a disconnected mini-app. The same player identity, stats, games, rosters, saved views, alerts, reports, and Workspace Studio formulas should power fantasy decisions.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 16),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Player identity'), InfoPill(label: 'Stats'), InfoPill(label: 'Games'), InfoPill(label: 'Rosters'), InfoPill(label: 'Scoring rules'), InfoPill(label: 'Workspace formulas'), InfoPill(label: 'Saved views'), InfoPill(label: 'Alerts')]),
  ]));
}

class _FantasyWorkflowPipeline extends StatelessWidget {
  const _FantasyWorkflowPipeline();

  @override
  Widget build(BuildContext context) {
    final steps = ['Create league', 'Define scoring', 'Add roster', 'Pick workflow', 'Select horizon', 'Apply model', 'Save board', 'Alert or share'];
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Fantasy Workflow Pipeline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')]),
    ]));
  }
}

class _FantasyMatrix extends StatelessWidget {
  const _FantasyMatrix({required this.selectedWorkflow});
  final String selectedWorkflow;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Fantasy Workflow Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Workflow')), DataColumn(label: Text('Status')), DataColumn(label: Text('Question')), DataColumn(label: Text('Output'))],
      rows: [for (final workflow in _fantasyWorkflows) DataRow(selected: workflow.name == selectedWorkflow, cells: [DataCell(SizedBox(width: 210, child: Text(workflow.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: workflow.status)), DataCell(SizedBox(width: 480, child: Text(workflow.question))), DataCell(SizedBox(width: 560, child: Text(workflow.output)))])],
    )),
  ]));
}

class _ScoringRulePanel extends StatelessWidget {
  const _ScoringRulePanel();

  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Scoring Rule Engine Plan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 12),
    Text('The first scoring model should support points leagues and category leagues without hard-coding one fantasy platform. Users should define stat weights, category targets, roster slots, eligibility rules, replacement assumptions, and custom formula overrides.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 16),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Points'), InfoPill(label: 'Categories'), InfoPill(label: 'Custom weights'), InfoPill(label: 'Roster slots'), InfoPill(label: 'Eligibility'), InfoPill(label: 'Replacement value'), InfoPill(label: 'Manual override')]),
  ]));
}

class _FantasyCapabilityTable extends StatelessWidget {
  const _FantasyCapabilityTable();

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Fantasy Capability Roadmap', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Capability')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Next Step'))],
      rows: [for (final item in fantasyProductItems) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.description))), DataCell(SizedBox(width: 480, child: Text(item.nextStep)))])],
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
  Widget build(BuildContext context) => SizedBox(width: 280, child: DropdownButtonFormField<String>(
    value: value,
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
