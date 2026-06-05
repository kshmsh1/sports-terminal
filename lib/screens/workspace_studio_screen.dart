import 'package:flutter/material.dart';

import '../data/action_surface_items.dart';
import '../data/saved_view_items.dart';
import '../data/workspace_builder_stage_items.dart';
import '../data/workspace_studio_items.dart';
import '../models/registry_item.dart';
import '../widgets/active_route_payload_panel.dart';
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
  String selectedStageCategory = 'All';
  String selectedFormulaRecipe = 'Custom MVP Score';
  String selectedJoinRecipe = 'Player to Team Season';

  @override
  Widget build(BuildContext context) {
    final selectedDatasetSpec = _datasets.firstWhere((item) => item.name == selectedDataset);
    final selectedModeSpec = _modes.firstWhere((item) => item.name == selectedMode);
    final selectedOutputSpec = _outputs.firstWhere((item) => item.name == selectedOutput);
    final stageCategories = ['All', ...workspaceBuilderStageItems.map((item) => item.category).toSet().toList()..sort()];
    final filteredStages = workspaceBuilderStageItems.where((item) => selectedStageCategory == 'All' || item.category == selectedStageCategory).toList();
    final formula = _formulaRecipes.firstWhere((item) => item.name == selectedFormulaRecipe);
    final join = _joinRecipes.firstWhere((item) => item.name == selectedJoinRecipe);
    final p0 = workspaceStudioItems.where((item) => item.priority == 'P0').length;
    final p1 = workspaceStudioItems.where((item) => item.priority == 'P1').length;
    final planned = workspaceStudioItems.where((item) => item.status == 'Planned').length;
    final future = workspaceStudioItems.where((item) => item.status == 'Future').length;
    final p0Stages = workspaceBuilderStageItems.where((item) => item.priority == 'P0').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Workspace Studio', subtitle: 'Excel-like cockpit for building custom sports datasets, formulas, joins, charts, scenario sheets, reports, saved views, exports, alerts, source audits, and future community embeds from terminal data.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _Metric(label: 'Studio Capabilities', value: '${workspaceStudioItems.length}', detail: '$p0 P0 / $p1 P1'),
          _Metric(label: 'Builder Stages', value: '${workspaceBuilderStageItems.length}', detail: '$p0Stages P0 stages'),
          _Metric(label: 'Planned / Future', value: '$planned / $future', detail: 'Implementation state'),
          _Metric(label: 'Hooks', value: '${savedViewItems.length + actionSurfaceItems.length}', detail: 'Saved views + actions'),
        ]);
      }),
      const SizedBox(height: 22),
      const ActiveRoutePayloadPanel(consumerName: 'Workspace Studio', description: 'Workspace Studio now reads the active shared RoutePayload as a workspace seed. Publish a Team, Season, or Operations payload from the route engine, then retarget it to Workspace to inspect selected rows, columns, filters, source snapshot, blockers, and route actions.', compact: true),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        _Picker(label: 'Dataset', value: selectedDataset, values: _datasets.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedDataset = value)),
        _Picker(label: 'Mode', value: selectedMode, values: _modes.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedMode = value)),
        _Picker(label: 'Output', value: selectedOutput, values: _outputs.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedOutput = value)),
        _Picker(label: 'Stage Category', value: selectedStageCategory, values: stageCategories, onChanged: (value) => setState(() => selectedStageCategory = value)),
        _Picker(label: 'Formula Recipe', value: selectedFormulaRecipe, values: _formulaRecipes.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedFormulaRecipe = value)),
        _Picker(label: 'Join Recipe', value: selectedJoinRecipe, values: _joinRecipes.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedJoinRecipe = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final left = _SelectedBuildPanel(dataset: selectedDatasetSpec, mode: selectedModeSpec, output: selectedOutputSpec, formula: formula, join: join);
        final right = const _WorkspaceArchitecturePanel();
        if (constraints.maxWidth < 1050) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 22),
      const _WorkspacePipelinePanel(),
      const SizedBox(height: 22),
      const _WorkspaceStateMatrix(),
      const SizedBox(height: 22),
      const _FormulaRecipeMatrix(),
      const SizedBox(height: 22),
      const _JoinRecipeMatrix(),
      const SizedBox(height: 22),
      _DatasetMatrix(selectedDataset: selectedDataset),
      const SizedBox(height: 22),
      _BuilderStageTable(items: filteredStages),
      const SizedBox(height: 22),
      const _CapabilityTable(),
    ]);
  }
}

class _WorkspaceDataset { const _WorkspaceDataset(this.name, this.readiness, this.joinKeys, this.primaryUse, this.firstColumns); final String name; final String readiness; final String joinKeys; final String primaryUse; final String firstColumns; }
class _WorkspaceMode { const _WorkspaceMode(this.name, this.status, this.description); final String name; final String status; final String description; }
class _WorkspaceOutput { const _WorkspaceOutput(this.name, this.status, this.description); final String name; final String status; final String description; }
class _FormulaRecipe { const _FormulaRecipe(this.name, this.status, this.fields, this.use); final String name; final String status; final String fields; final String use; }
class _JoinRecipe { const _JoinRecipe(this.name, this.status, this.keys, this.use); final String name; final String status; final String keys; final String use; }
class _StateField { const _StateField(this.field, this.category, this.status, this.description); final String field; final String category; final String status; final String description; }

const _datasets = <_WorkspaceDataset>[
  _WorkspaceDataset('Player Season Stats', 'Source pending', 'playerId + seasonId + teamId', 'Player rankings, award models, fantasy projections, compare tables', 'GP, MPG, PTS, REB, AST, PF, TS%, eFG%, USG%, ORtg, DRtg'),
  _WorkspaceDataset('Team Season Stats', 'Source pending', 'teamId + seasonId', 'Team profiles, pace context, standings analysis, era comparisons', 'W, L, Win%, PPG, Opp PPG, Pace, ORtg, DRtg, Net, TS%'),
  _WorkspaceDataset('Games', 'Source pending', 'gameId + seasonId + homeTeamId + awayTeamId', 'Schedules, results, trend charts, matchup work, fantasy matchup density', 'Date, teams, score, arena, city, season type, source'),
  _WorkspaceDataset('Rosters', 'Source pending', 'playerId + teamId + seasonId', 'Player-team history, lineup context, development paths, eligibility windows', 'Player, team, season, position, jersey, status, contract type, start, end'),
  _WorkspaceDataset('Awards', 'Source pending', 'awardId + playerId + seasonId', 'Award races, voting boards, historical recognition, report sections', 'Award, season, player, team, rank, first votes, points, share'),
  _WorkspaceDataset('Draft', 'Source pending', 'draftYear + pickNumber + playerId + teamId', 'Draft class boards, team history, development tracking, outcome studies', 'Year, round, pick, team, player, school, country'),
  _WorkspaceDataset('Transactions', 'Source pending', 'transactionId + playerId + fromTeamId + toTeamId', 'Movement timelines, trade trees, roster changes, contract events', 'Date, type, player, from, to, description'),
  _WorkspaceDataset('Standings and Playoffs', 'Source pending', 'teamId + seasonId + seriesId', 'Postseason paths, seeds, records, playoff context, franchise history', 'Seed, W, L, Win%, round, winner, loser, series result'),
  _WorkspaceDataset('Saved Views', 'State model planned', 'savedViewId + datasetId', 'Reusable workspaces, reports, alerts, exports, dashboard pins', 'Name, workspace, filters, output, source snapshot, action readiness'),
  _WorkspaceDataset('Source Operations', 'Planned', 'datasetId + sourceId + lineageId', 'Source audits, QA, import monitors, rights review, data health', 'Source, dataset, rows, status, as-of, validation, rights'),
];
const _modes = <_WorkspaceMode>[
  _WorkspaceMode('Table Builder', 'First', 'Choose dataset, columns, filters, sorts, visible rows, source fields, and saved table templates.'),
  _WorkspaceMode('Formula Sheet', 'Second', 'Create controlled formulas, custom metrics, composite scores, flags, and weighted rankings.'),
  _WorkspaceMode('Join Builder', 'Second', 'Attach related datasets through approved join recipes instead of unsafe free-form joins.'),
  _WorkspaceMode('Chart Board', 'Third', 'Build trend charts, rankings, scatter plots, distributions, and comparison visuals.'),
  _WorkspaceMode('Scenario Lab', 'Future', 'Model fantasy projections, trade scenarios, award rankings, depth charts, and playoff paths.'),
  _WorkspaceMode('Source Audit Workspace', 'Planned', 'Inspect source coverage, missing fields, row counts, rights posture, lineage, and validation state.'),
];
const _outputs = <_WorkspaceOutput>[
  _WorkspaceOutput('Research Workspace', 'MVP', 'Private working table for analysis, filtering, sorting, formulas, and notes.'),
  _WorkspaceOutput('Saved View', 'MVP', 'Reusable workspace state that can later power alerts and reports.'),
  _WorkspaceOutput('Report Input', 'Planned', 'Structured table block that can flow into player, team, season, fantasy, or draft reports.'),
  _WorkspaceOutput('CSV Export', 'Planned', 'Downloadable table once export center and table state are reliable.'),
  _WorkspaceOutput('Comparison Input', 'Planned', 'Prepared row set that can route into Compare as entity slots or selected metric packages.'),
  _WorkspaceOutput('Dashboard Pin', 'Planned', 'Pinned workspace card for data health, watchlists, saved models, source operations, or fantasy boards.'),
  _WorkspaceOutput('Community Embed', 'Future', 'Shareable table or chart inside a blog post, forum thread, fantasy room, or creator workspace.'),
];
const _formulaRecipes = <_FormulaRecipe>[
  _FormulaRecipe('Custom MVP Score', 'Planned', 'Production, efficiency, team record, availability, usage, source flags', 'Award models and player ranking boards.'),
  _FormulaRecipe('Fantasy Value', 'Future', 'Scoring weights, games remaining, role, schedule density, category fit', 'Manual fantasy roster, waiver, trade, and matchup analysis.'),
  _FormulaRecipe('Availability Score', 'Planned', 'Games played, minutes, starts later, roster status, injury status later', 'Player reliability and award qualification views.'),
  _FormulaRecipe('Team Context Grade', 'Planned', 'Win%, seed, net rating, pace, playoff result, roster strength later', 'Context around player seasons and team comparisons.'),
  _FormulaRecipe('Source Risk Flag', 'Planned', 'Source type, stale source, missing fields, manual fields, rights posture', 'Trust/audit workspaces and export gating.'),
  _FormulaRecipe('Weighted Rank', 'Planned', 'Selected metrics, z-scores later, weights, null policy, tie handling', 'Custom rankings across players, teams, awards, fantasy, and draft.'),
];
const _joinRecipes = <_JoinRecipe>[
  _JoinRecipe('Player to Team Season', 'Planned', 'playerId + seasonId + teamId', 'Add team record and context to player-season rows.'),
  _JoinRecipe('Player to Awards', 'Planned', 'playerId + seasonId + awardId', 'Add award winner/finalist/voting context to player rows.'),
  _JoinRecipe('Team to Standings', 'Planned', 'teamId + seasonId', 'Add seed, win percentage, conference, and playoff qualification to team rows.'),
  _JoinRecipe('Team to Playoffs', 'Planned', 'teamId + seasonId + seriesId', 'Add postseason path, round, opponent, and series result.'),
  _JoinRecipe('Draft to Player', 'Future', 'draftYear + playerId', 'Connect draft class rows to NBA outcomes and player reports.'),
  _JoinRecipe('Transaction to Roster Window', 'Future', 'transactionId + playerId + teamId', 'Connect movement records to roster windows and team-building effects.'),
  _JoinRecipe('Game to Teams', 'Future', 'gameId + homeTeamId + awayTeamId', 'Add team context, schedule density, and future box-score links.'),
  _JoinRecipe('Saved View to Alert', 'Future', 'savedViewId + alertRuleId', 'Turn saved workspaces into monitorable alerts.'),
];
const _stateFields = <_StateField>[
  _StateField('datasetId', 'Identity', 'P0', 'Starting dataset for the workspace.'),
  _StateField('columnState', 'Table', 'P0', 'Visible, hidden, ordered, and source-linked columns.'),
  _StateField('filterState', 'Table', 'P0', 'Structured filters and thresholds.'),
  _StateField('sortState', 'Table', 'P0', 'Sort fields, rank mode, and null behavior.'),
  _StateField('selectedRows', 'Action', 'P0', 'Row keys for compare, report, export, and audit.'),
  _StateField('formulaState', 'Formula', 'P1', 'Custom columns, recipes, dependencies, and validation.'),
  _StateField('joinState', 'Join', 'P1', 'Approved join recipes, keys, coverage, and warnings.'),
  _StateField('chartState', 'Visualization', 'P2', 'Chart config, selected metrics, dates, and entities.'),
  _StateField('sourceSnapshot', 'Trust', 'P0', 'Source-as-of, lineage, rights, and missing-field status.'),
  _StateField('outputIntent', 'Workflow', 'P1', 'Research, report, export, alert, fantasy, community, or dashboard output.'),
];

class _SelectedBuildPanel extends StatelessWidget { const _SelectedBuildPanel({required this.dataset, required this.mode, required this.output, required this.formula, required this.join}); final _WorkspaceDataset dataset; final _WorkspaceMode mode; final _WorkspaceOutput output; final _FormulaRecipe formula; final _JoinRecipe join; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Workspace Build Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: dataset.readiness), InfoPill(label: mode.status), InfoPill(label: output.status), InfoPill(label: formula.status), InfoPill(label: join.status)]), const SizedBox(height: 16), _DetailLine(label: 'Dataset', value: dataset.name), _DetailLine(label: 'Join Keys', value: dataset.joinKeys), _DetailLine(label: 'Primary Use', value: dataset.primaryUse), _DetailLine(label: 'First Columns', value: dataset.firstColumns), _DetailLine(label: 'Builder Mode', value: '${mode.name}: ${mode.description}'), _DetailLine(label: 'Formula', value: '${formula.name}: ${formula.fields}'), _DetailLine(label: 'Join Recipe', value: '${join.name}: ${join.keys}'), _DetailLine(label: 'Output', value: '${output.name}: ${output.description}') ])); }
class _WorkspaceArchitecturePanel extends StatelessWidget { const _WorkspaceArchitecturePanel(); @override Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Workspace Architecture', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 12), Text('Workspace Studio is the Excel-like layer of the terminal. It should not be a separate spreadsheet app; it should preserve source-aware sports objects, approved joins, safe formulas, action routes, saved views, reports, exports, alerts, and future community embeds.', style: TextStyle(color: terminalTextSoft, height: 1.45)), SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Dataset'), InfoPill(label: 'Columns'), InfoPill(label: 'Filters'), InfoPill(label: 'Formulas'), InfoPill(label: 'Joins'), InfoPill(label: 'Source snapshot'), InfoPill(label: 'Saved view'), InfoPill(label: 'Action routes')]) ])); }
class _WorkspacePipelinePanel extends StatelessWidget { const _WorkspacePipelinePanel(); @override Widget build(BuildContext context) { final steps = ['Pick dataset', 'Choose columns', 'Filter and sort', 'Select rows', 'Add formulas', 'Join context', 'Snapshot sources', 'Route output']; return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Workspace Pipeline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')])])); } }
class _WorkspaceStateMatrix extends StatelessWidget { const _WorkspaceStateMatrix(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Workspace State Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Field')), DataColumn(label: Text('Category')), DataColumn(label: Text('Priority')), DataColumn(label: Text('Description'))], rows: [for (final item in _stateFields) DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(item.field, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 160, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 720, child: Text(item.description)))])]))])); }
class _FormulaRecipeMatrix extends StatelessWidget { const _FormulaRecipeMatrix(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Formula Recipe Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Recipe')), DataColumn(label: Text('Status')), DataColumn(label: Text('Fields')), DataColumn(label: Text('Use'))], rows: [for (final item in _formulaRecipes) DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 580, child: Text(item.fields))), DataCell(SizedBox(width: 520, child: Text(item.use)))])]))])); }
class _JoinRecipeMatrix extends StatelessWidget { const _JoinRecipeMatrix(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Join Recipe Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Join')), DataColumn(label: Text('Status')), DataColumn(label: Text('Keys')), DataColumn(label: Text('Use'))], rows: [for (final item in _joinRecipes) DataRow(cells: [DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 420, child: Text(item.keys))), DataCell(SizedBox(width: 620, child: Text(item.use)))])]))])); }
class _DatasetMatrix extends StatelessWidget { const _DatasetMatrix({required this.selectedDataset}); final String selectedDataset; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Workspace Dataset Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Dataset')), DataColumn(label: Text('Readiness')), DataColumn(label: Text('Join Keys')), DataColumn(label: Text('Primary Use')), DataColumn(label: Text('Starter Columns'))], rows: [for (final dataset in _datasets) DataRow(selected: dataset.name == selectedDataset, cells: [DataCell(SizedBox(width: 210, child: Text(dataset.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: dataset.readiness)), DataCell(SizedBox(width: 320, child: Text(dataset.joinKeys))), DataCell(SizedBox(width: 520, child: Text(dataset.primaryUse))), DataCell(SizedBox(width: 520, child: Text(dataset.firstColumns)))])]))])); }
class _BuilderStageTable extends StatelessWidget { const _BuilderStageTable({required this.items}); final List<RegistryItem> items; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Workspace Builder Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 360, child: Text(item.inputs))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])]))])); }
class _CapabilityTable extends StatelessWidget { const _CapabilityTable(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Workspace Capability Roadmap', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Capability')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Next Step'))], rows: [for (final item in workspaceStudioItems) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.description))), DataCell(SizedBox(width: 480, child: Text(item.nextStep)))])]))])); }
class _Picker extends StatelessWidget { const _Picker({required this.label, required this.value, required this.values, required this.onChanged}); final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; @override Widget build(BuildContext context) => SizedBox(width: 280, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); }
class _DetailLine extends StatelessWidget { const _DetailLine({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))])); }
class _Metric extends StatelessWidget { const _Metric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
