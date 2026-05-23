import 'package:flutter/material.dart';

import '../data/action_surface_items.dart';
import '../data/alert_rule_items.dart';
import '../data/coverage_items.dart';
import '../data/import_job_plans.dart';
import '../data/report_library_items.dart';
import '../data/saved_view_items.dart';
import '../data/source_registry_entries.dart';
import '../data/terminal_operating_layer_items.dart';
import '../widgets/first_release_payload_preview.dart';
import '../widgets/first_release_route_outputs.dart';
import '../widgets/terminal_primitives.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectedDatasets = coverageItems.where((item) => item.status == 'Connected').length;
    final pendingDatasets = coverageItems.where((item) => item.status.toLowerCase().contains('pending')).length;
    final knownRows = coverageItems.fold<int>(0, (sum, item) => sum + item.recordCount);
    final connectedSources = sourceRegistryEntries.where((item) => item.status == 'Connected').length;
    final targetSources = sourceRegistryEntries.where((item) => item.status == 'Target').length;
    final startedJobs = importJobPlans.where((item) => item.status.contains('Started')).length;
    final workflowCount = reportLibraryItems.length + savedViewItems.length + alertRuleItems.length + actionSurfaceItems.length;
    final inProgressLayers = terminalOperatingLayerItems.where((item) => item.status == 'In Progress').length;
    final plannedLayers = terminalOperatingLayerItems.where((item) => item.status == 'Planned').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'NBA Command Center', subtitle: 'Historical-first operating system for NBA entities, events, performance, postseason context, recognition, movement, workspaces, reports, saved views, alerts, sources, and data operations.'),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, constraints) { final isWide = constraints.maxWidth > 900; return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 1.8 : 1.45, children: [
        _MetricCard(label: 'Coverage Datasets', value: '${coverageItems.length}', detail: '$connectedDatasets connected / $pendingDatasets pending'),
        _MetricCard(label: 'Known Records', value: '$knownRows', detail: 'Real rows only'),
        _MetricCard(label: 'Source Registry', value: '${sourceRegistryEntries.length}', detail: '$connectedSources connected / $targetSources targets'),
        _MetricCard(label: 'Import Jobs', value: '${importJobPlans.length}', detail: '$startedJobs started loaders'),
        _MetricCard(label: 'Workflow Items', value: '$workflowCount', detail: 'Reports + views + alerts + actions'),
        _MetricCard(label: 'Operating Layers', value: '${terminalOperatingLayerItems.length}', detail: '$inProgressLayers active / $plannedLayers planned'),
        _MetricCard(label: 'Saved Views', value: '${savedViewItems.length}', detail: 'Workspace presets'),
        const _MetricCard(label: 'Data Policy', value: 'Real', detail: 'No fake sports records'),
      ]); }),
      const SizedBox(height: 24),
      const _MvpCockpitPanel(),
      const SizedBox(height: 24),
      const FirstReleasePayloadPreview(
        title: 'Dashboard First-Release Payloads',
        subtitle: 'Command-center view of the connected Teams, Seasons, and operational registries that can already power Workspace, Compare, Reports, Saved Views, Export previews, Alert previews, Dashboard cards, Search routes, and Action Center routes.',
        rowLimit: 6,
        showImmediatePanel: false,
      ),
      const SizedBox(height: 24),
      const FirstReleaseRouteOutputs(),
      const SizedBox(height: 24),
      const _CoreModuleMatrix(),
      const SizedBox(height: 24),
      const _OperatingLayerMap(),
      const SizedBox(height: 24),
      _CoveragePanel(items: coverageItems),
      const SizedBox(height: 24),
      _OperationsPanel(connectedSources: connectedSources, targetSources: targetSources, startedJobs: startedJobs),
      const SizedBox(height: 24),
      const _BuildSequencePanel(),
      const SizedBox(height: 24),
      const _TerminalPanel(title: 'Current Product Direction', lines: [
        '1. Build NBA first and treat every future sport as an extension of the same operating model.',
        '2. Use stable local JSON assets now, then replace or augment them with approved source imports later.',
        '3. Keep missing values blank. Never convert unknown statistics into fake zeros.',
        '4. Separate source data, user analysis, actions, reports, saved views, alerts, and Build Lab governance.',
        '5. Keep broadening the terminal across players, teams, seasons, games, rosters, awards, draft, transactions, contracts, stats, standings, playoffs, compare, workspace, fantasy, community, reports, media, scouting, and operations.',
      ]),
      const SizedBox(height: 24),
      const _TerminalPanel(title: 'Near-Term Build Priority', lines: [
        '1. Convert more core product surfaces into selected-detail workspaces with joins into adjacent modules.',
        '2. Make Dashboard, Search, Action Center, Saved Views, Alerts, Reports, Data Coverage, Data Health, QA, and Source Registry act like operating controls rather than static planning pages.',
        '3. Begin the player identity source path before importing player stats, award races, rosters, draft links, or transactions.',
        '4. Keep Stats important but not dominant: the terminal also needs games, rosters, awards, draft, transactions, contracts, scouting, media, saved views, alerts, reports, fantasy, and community.',
        '5. Preserve the end-platform shape: source-backed data, joined entities, reusable workflows, trust controls, and future sport expansion.',
      ]),
    ]);
  }
}

class _MetricCard extends StatelessWidget { const _MetricCard({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }

class _MvpCockpitPanel extends StatelessWidget { const _MvpCockpitPanel(); @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MVP Cockpit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), const Text('The first working platform should feel like a complete local NBA terminal before live feeds exist. The user should be able to search across the system, inspect source-aware entities, understand missing data, route objects into actions, build workspaces, compare records, generate report shells, save views, monitor alerts, and trust every blank value.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: const [InfoPill(label: 'NBA first'), InfoPill(label: 'Historical first'), InfoPill(label: 'Local assets'), InfoPill(label: 'No fake records'), InfoPill(label: 'Source metadata'), InfoPill(label: 'Workflow ready'), InfoPill(label: 'G League later')]) ])); }
class _TerminalPanel extends StatelessWidget { const _TerminalPanel({required this.title, required this.lines}); final String title; final List<String> lines; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 14), for (final line in lines) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line, style: const TextStyle(color: terminalTextSoft, height: 1.4)))])); }

class _CoreModuleMatrix extends StatelessWidget { const _CoreModuleMatrix(); @override Widget build(BuildContext context) { final rows = <_ModuleRow>[
  const _ModuleRow('Search', 'Command layer', 'Asset-aware', 'Route to entities, reports, datasets, saved views, and source operations.'), const _ModuleRow('Action Center', 'Action layer', 'Route-aware', 'Move terminal objects into workspace, compare, report, export, alerts, source audit, fantasy, and community.'), const _ModuleRow('Players', 'Identity hub', 'Source pending', 'Load player identity and activate player detail, roster, award, draft, and transaction joins.'), const _ModuleRow('Teams', 'Franchise hub', 'Reference ready', 'Attach team-season stats, standings, rosters, games, transactions, and franchise history.'), const _ModuleRow('Seasons', 'Time spine', 'Reference ready', 'Attach standings, awards, playoffs, leaders, league context, draft class, and era notes.'), const _ModuleRow('Games', 'Event layer', 'Asset-backed', 'Add schedules, results, box scores, matchup context, game logs, and chart inputs.'), const _ModuleRow('Rosters', 'Player-team graph', 'Asset-backed', 'Add roster windows, contract type, two-way status, assignments, recalls, and game eligibility.'), const _ModuleRow('Awards', 'Recognition layer', 'Race-ready model', 'Add winners, runners-up, finalists, first-place votes, points, shares, and season boards.'), const _ModuleRow('Draft', 'Talent pipeline', 'Asset-backed', 'Connect picks to player identity, outcomes, development pathways, awards, and team history.'), const _ModuleRow('Transactions', 'Movement graph', 'Asset-backed', 'Build movement timelines, roster effects, trade trees, contract events, and team-building reports.'), const _ModuleRow('Contracts', 'Front office layer', 'Planned', 'Add salary, guarantees, options, extensions, cap context, and transaction linkage.'), const _ModuleRow('Stats', 'Analytical engine', 'Schema expanding', 'Add regular/playoff splits, view modes, stat families, advanced fields, and trend charts.'), const _ModuleRow('Reports', 'Output layer', 'Builder shell', 'Generate player, team, season, draft, award, transaction, fantasy, community, and source-backed reports.'), const _ModuleRow('Saved Views', 'Workspace memory', 'State model', 'Persist repeated filters, tables, formulas, joins, charts, comparisons, and report states.'), const _ModuleRow('Alerts', 'Monitoring layer', 'Evaluator model', 'Evaluate saved-view changes, stat thresholds, import failures, roster changes, fantasy boards, and data-health events.'), const _ModuleRow('Source Ops', 'Trust layer', 'Build Lab', 'Track sources, imports, lineage, policy, QA, data health, and validation output.'),
]; return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Core Module Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Module')), DataColumn(label: Text('Role')), DataColumn(label: Text('MVP State')), DataColumn(label: Text('Next Capability'))], rows: [for (final row in rows) row.toDataRow()]))])); } }
class _ModuleRow { const _ModuleRow(this.module, this.role, this.state, this.nextCapability); final String module; final String role; final String state; final String nextCapability; DataRow toDataRow() => DataRow(cells: [DataCell(SizedBox(width: 160, child: Text(module, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 210, child: Text(role))), DataCell(InfoPill(label: state)), DataCell(SizedBox(width: 640, child: Text(nextCapability)))]); }

class _OperatingLayerMap extends StatelessWidget { const _OperatingLayerMap(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Terminal Operating Layer Map', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${terminalOperatingLayerItems.length} layers', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Layer')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Next Step'))], rows: [for (final item in terminalOperatingLayerItems) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 650, child: Text(item.description))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])]))])); }

class _CoveragePanel extends StatelessWidget { const _CoveragePanel({required this.items}); final List<dynamic> items; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Data Coverage Snapshot', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Dataset')), DataColumn(label: Text('Domain')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Status')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 220, child: Text(item.dataset, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(item.domain)), DataCell(Text('${item.recordCount}')), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 520, child: Text(item.nextStep)))])]))])); }
class _OperationsPanel extends StatelessWidget { const _OperationsPanel({required this.connectedSources, required this.targetSources, required this.startedJobs}); final int connectedSources; final int targetSources; final int startedJobs; @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) { final isWide = constraints.maxWidth > 900; return GridView.count(crossAxisCount: isWide ? 3 : 1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.2 : 2.8, children: [_MetricCard(label: 'Connected Sources', value: '$connectedSources', detail: 'Reference layers live'), _MetricCard(label: 'Target Sources', value: '$targetSources', detail: 'Near-term source work'), _MetricCard(label: 'Started Jobs', value: '$startedJobs', detail: 'Repository loaders ready')]); }); }
class _BuildSequencePanel extends StatelessWidget { const _BuildSequencePanel(); @override Widget build(BuildContext context) { final rows = <_BuildRow>[const _BuildRow('1', 'Reference foundation', 'Teams, seasons, source registry, data policy, search, and navigation behave consistently.'), const _BuildRow('2', 'Entity activation', 'Players, teams, seasons, games, rosters, awards, draft, and transactions each have selected-detail workflows.'), const _BuildRow('3', 'Statistical core', 'Player/team regular season and playoff stats support families, view modes, source metadata, and clean joins.'), const _BuildRow('4', 'Context graph', 'Standings, playoffs, award races, draft outcomes, roster windows, and movement history connect to entities.'), const _BuildRow('5', 'Workflow layer', 'Action Center, Workspace Studio, Compare, Reports, Saved Views, Alerts, Exports, and QA operate from the same local data model.'), const _BuildRow('6', 'Ingestion layer', 'Approved import scripts create raw snapshots, normalized assets, validation output, and lineage records.'), const _BuildRow('7', 'Expansion layer', 'Fantasy, community, scouting, G League, front office, and future sports reuse the same operating architecture.')]; return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('End-Platform Build Sequence', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 34, columns: const [DataColumn(label: Text('Phase')), DataColumn(label: Text('Objective')), DataColumn(label: Text('Exit Condition'))], rows: [for (final row in rows) row.toDataRow()]))])); } }
class _BuildRow { const _BuildRow(this.phase, this.objective, this.exitCondition); final String phase; final String objective; final String exitCondition; DataRow toDataRow() => DataRow(cells: [DataCell(Text(phase, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 320, child: Text(objective, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 680, child: Text(exitCondition)))]); }