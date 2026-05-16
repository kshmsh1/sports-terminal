import 'package:flutter/material.dart';

import '../data/workspace_studio_items.dart';
import '../widgets/terminal_primitives.dart';

class WorkspaceStudioScreen extends StatefulWidget {
  const WorkspaceStudioScreen({super.key});

  @override
  State<WorkspaceStudioScreen> createState() => _WorkspaceStudioScreenState();
}

class _WorkspaceStudioScreenState extends State<WorkspaceStudioScreen> {
  String selectedDataset = 'Player Season Stats';
  String selectedMode = 'Table Builder';
  String selectedOutput = 'Research Workspace';

  @override
  Widget build(BuildContext context) {
    final selectedDatasetSpec = _datasets.firstWhere((item) => item.name == selectedDataset);
    final selectedModeSpec = _modes.firstWhere((item) => item.name == selectedMode);
    final selectedOutputSpec = _outputs.firstWhere((item) => item.name == selectedOutput);
    final p0 = workspaceStudioItems.where((item) => item.priority == 'P0').length;
    final p1 = workspaceStudioItems.where((item) => item.priority == 'P1').length;
    final planned = workspaceStudioItems.where((item) => item.status == 'Planned').length;
    final future = workspaceStudioItems.where((item) => item.status == 'Future').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Workspace Studio', subtitle: 'Excel-like cockpit for building custom sports datasets, formulas, joins, charts, scenario sheets, reports, saved views, exports, and audit-ready analysis from terminal data.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Studio Capabilities', value: '${workspaceStudioItems.length}', detail: '$p0 P0 / $p1 P1'),
          _Metric(label: 'Planned / Future', value: '$planned / $future', detail: 'Implementation state'),
          _Metric(label: 'Datasets', value: '${_datasets.length}', detail: 'Workspace starting points'),
          _Metric(label: 'Builder Modes', value: '${_modes.length}', detail: 'Table, chart, formula, scenario'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        _Picker(label: 'Dataset', value: selectedDataset, values: _datasets.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedDataset = value)),
        _Picker(label: 'Mode', value: selectedMode, values: _modes.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedMode = value)),
        _Picker(label: 'Output', value: selectedOutput, values: _outputs.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedOutput = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final left = _SelectedBuildPanel(dataset: selectedDatasetSpec, mode: selectedModeSpec, output: selectedOutputSpec);
        final right = const _FormulaPreviewPanel();
        if (constraints.maxWidth < 1050) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 22),
      const _WorkspacePipelinePanel(),
      const SizedBox(height: 22),
      _DatasetMatrix(selectedDataset: selectedDataset),
      const SizedBox(height: 22),
      const _CapabilityTable(),
    ]);
  }
}

class _WorkspaceDataset {
  const _WorkspaceDataset(this.name, this.readiness, this.joinKeys, this.primaryUse, this.firstColumns);
  final String name;
  final String readiness;
  final String joinKeys;
  final String primaryUse;
  final String firstColumns;
}

class _WorkspaceMode {
  const _WorkspaceMode(this.name, this.status, this.description);
  final String name;
  final String status;
  final String description;
}

class _WorkspaceOutput {
  const _WorkspaceOutput(this.name, this.status, this.description);
  final String name;
  final String status;
  final String description;
}

const _datasets = <_WorkspaceDataset>[
  _WorkspaceDataset('Player Season Stats', 'Source pending', 'playerId + seasonId + teamId', 'Player rankings, award models, fantasy projections, compare tables', 'GP, MPG, PTS, REB, AST, PF, TS%, eFG%, USG%, ORtg, DRtg'),
  _WorkspaceDataset('Team Season Stats', 'Source pending', 'teamId + seasonId', 'Team profiles, pace context, standings analysis, era comparisons', 'W, L, Win%, PPG, Opp PPG, Pace, ORtg, DRtg, Net, TS%'),
  _WorkspaceDataset('Games', 'Source pending', 'gameId + seasonId + homeTeamId + awayTeamId', 'Schedules, results, trend charts, matchup work, fantasy matchup density', 'Date, teams, score, arena, city, season type, source'),
  _WorkspaceDataset('Rosters', 'Source pending', 'playerId + teamId + seasonId', 'Player-team history, lineup context, development paths, eligibility windows', 'Player, team, season, position, jersey, status, contract type, start, end'),
  _WorkspaceDataset('Awards', 'Source pending', 'awardId + playerId + seasonId', 'Award races, voting boards, historical recognition, report sections', 'Award, season, player, team, rank, first votes, points, share'),
  _WorkspaceDataset('Draft', 'Source pending', 'draftYear + pickNumber + playerId + teamId', 'Draft class boards, team history, development tracking, outcome studies', 'Year, round, pick, team, player, school, country'),
  _WorkspaceDataset('Transactions', 'Source pending', 'transactionId + playerId + fromTeamId + toTeamId', 'Movement timelines, trade trees, roster changes, contract events', 'Date, type, player, from, to, description'),
  _WorkspaceDataset('Standings and Playoffs', 'Source pending', 'teamId + seasonId + seriesId', 'Postseason paths, seeds, records, playoff context, franchise history', 'Seed, W, L, Win%, round, winner, loser, series result'),
];

const _modes = <_WorkspaceMode>[
  _WorkspaceMode('Table Builder', 'First', 'Choose dataset, columns, filters, sorts, visible rows, source fields, and saved table templates.'),
  _WorkspaceMode('Formula Sheet', 'Second', 'Create controlled formulas, custom metrics, composite scores, flags, and weighted rankings.'),
  _WorkspaceMode('Join Builder', 'Second', 'Attach related datasets through approved join recipes instead of unsafe free-form joins.'),
  _WorkspaceMode('Chart Board', 'Third', 'Build trend charts, rankings, scatter plots, distributions, and comparison visuals.'),
  _WorkspaceMode('Scenario Lab', 'Future', 'Model fantasy projections, trade scenarios, award rankings, depth charts, and playoff paths.'),
];

const _outputs = <_WorkspaceOutput>[
  _WorkspaceOutput('Research Workspace', 'MVP', 'Private working table for analysis, filtering, sorting, formulas, and notes.'),
  _WorkspaceOutput('Saved View', 'MVP', 'Reusable workspace state that can later power alerts and reports.'),
  _WorkspaceOutput('Report Input', 'Planned', 'Structured table block that can flow into player, team, season, fantasy, or draft reports.'),
  _WorkspaceOutput('CSV Export', 'Planned', 'Downloadable table once export center and table state are reliable.'),
  _WorkspaceOutput('Community Embed', 'Future', 'Shareable table or chart inside a blog post, forum thread, fantasy room, or creator workspace.'),
];

class _SelectedBuildPanel extends StatelessWidget {
  const _SelectedBuildPanel({required this.dataset, required this.mode, required this.output});
  final _WorkspaceDataset dataset;
  final _WorkspaceMode mode;
  final _WorkspaceOutput output;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Workspace Build Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 14),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: dataset.readiness), InfoPill(label: mode.status), InfoPill(label: output.status)]),
    const SizedBox(height: 16),
    _DetailLine(label: 'Dataset', value: dataset.name),
    _DetailLine(label: 'Join Keys', value: dataset.joinKeys),
    _DetailLine(label: 'Primary Use', value: dataset.primaryUse),
    _DetailLine(label: 'First Columns', value: dataset.firstColumns),
    _DetailLine(label: 'Builder Mode', value: '${mode.name}: ${mode.description}'),
    _DetailLine(label: 'Output', value: '${output.name}: ${output.description}'),
  ]));
}

class _FormulaPreviewPanel extends StatelessWidget {
  const _FormulaPreviewPanel();

  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Formula / Model Examples', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 12),
    Text('Custom MVP Score = weighted player production + team record + efficiency + games played adjustment.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 8),
    Text('Fantasy Value = scoring rules applied to player game or season stats plus schedule and roster context.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 8),
    Text('Trade Board = current player value, contract context later, team need, role, age, production, and source-backed notes.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 14),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Custom columns'), InfoPill(label: 'Safe formulas'), InfoPill(label: 'Source-aware'), InfoPill(label: 'Saved views'), InfoPill(label: 'Report ready')]),
  ]));
}

class _WorkspacePipelinePanel extends StatelessWidget {
  const _WorkspacePipelinePanel();

  @override
  Widget build(BuildContext context) {
    final steps = ['Pick dataset', 'Choose columns', 'Filter and sort', 'Add formulas', 'Join context', 'Build chart', 'Save view', 'Export or report'];
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Workspace Pipeline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')]),
    ]));
  }
}

class _DatasetMatrix extends StatelessWidget {
  const _DatasetMatrix({required this.selectedDataset});
  final String selectedDataset;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Workspace Dataset Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Dataset')), DataColumn(label: Text('Readiness')), DataColumn(label: Text('Join Keys')), DataColumn(label: Text('Primary Use')), DataColumn(label: Text('Starter Columns'))], rows: [for (final dataset in _datasets) DataRow(selected: dataset.name == selectedDataset, cells: [DataCell(SizedBox(width: 210, child: Text(dataset.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: dataset.readiness)), DataCell(SizedBox(width: 320, child: Text(dataset.joinKeys))), DataCell(SizedBox(width: 520, child: Text(dataset.primaryUse))), DataCell(SizedBox(width: 520, child: Text(dataset.firstColumns)))])])),
  ]));
}

class _CapabilityTable extends StatelessWidget {
  const _CapabilityTable();

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Workspace Capability Roadmap', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Capability')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Next Step'))], rows: [for (final item in workspaceStudioItems) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.description))), DataCell(SizedBox(width: 480, child: Text(item.nextStep)))])])),
  ]));
}

class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(width: 280, child: DropdownButtonFormField<String>(value: value, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
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
