import 'package:flutter/material.dart';

import '../data/report_library_items.dart';
import '../data/report_section_template_items.dart';
import '../models/report_section_template.dart';
import '../models/terminal_report.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_ReportPayload> payloadFuture = _loadPayload();
  String selectedCategory = 'All';
  String selectedStatus = 'All';
  String selectedReportType = 'All';
  String selectedReportId = reportLibraryItems.first.id;
  String query = '';

  Future<_ReportPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadPlayerProfiles(),
      repository.loadPlayerSeasonStats(),
      repository.loadTeamSeasonStats(),
      repository.loadTeams(),
      repository.loadSeasons(),
      repository.loadStandings(),
      repository.loadPlayoffSeries(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadRosters(),
      repository.loadTransactions(),
      repository.loadGames(),
    ]);
    return _ReportPayload(
      players: (results[0] as List).length,
      playerStats: (results[1] as List).length,
      teamStats: (results[2] as List).length,
      teams: (results[3] as List).length,
      seasons: (results[4] as List).length,
      standings: (results[5] as List).length,
      playoffs: (results[6] as List).length,
      awards: (results[7] as List).length,
      draft: (results[8] as List).length,
      rosters: (results[9] as List).length,
      transactions: (results[10] as List).length,
      games: (results[11] as List).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        final payload = snapshot.data ?? const _ReportPayload(players: 0, playerStats: 0, teamStats: 0, teams: 0, seasons: 0, standings: 0, playoffs: 0, awards: 0, draft: 0, rosters: 0, transactions: 0, games: 0);
        final categories = ['All', ...reportLibraryItems.map((item) => item.category).toSet().toList()..sort()];
        final statuses = ['All', ...reportLibraryItems.map((item) => item.status).toSet().toList()..sort()];
        final reportTypes = ['All', ...reportSectionTemplateItems.map((item) => item.reportType).toSet().toList()..sort()];
        final gates = {for (final report in reportLibraryItems) report.id: _ReportGate.fromReport(report, payload)};
        final filteredReports = reportLibraryItems.where((item) {
          final normalized = query.trim().toLowerCase();
          final matchesCategory = selectedCategory == 'All' || item.category == selectedCategory;
          final matchesStatus = selectedStatus == 'All' || item.status == selectedStatus;
          final matchesQuery = normalized.isEmpty ||
              item.title.toLowerCase().contains(normalized) ||
              item.category.toLowerCase().contains(normalized) ||
              item.description.toLowerCase().contains(normalized) ||
              item.primaryEntities.toLowerCase().contains(normalized) ||
              item.requiredDatasets.toLowerCase().contains(normalized);
          return matchesCategory && matchesStatus && matchesQuery;
        }).toList();
        final filteredSections = reportSectionTemplateItems.where((item) {
          final normalized = query.trim().toLowerCase();
          final matchesType = selectedReportType == 'All' || item.reportType == selectedReportType;
          final matchesQuery = normalized.isEmpty || item.reportType.toLowerCase().contains(normalized) || item.section.toLowerCase().contains(normalized) || item.description.toLowerCase().contains(normalized) || item.dataInputs.toLowerCase().contains(normalized);
          return matchesType && matchesQuery;
        }).toList();
        final selectedReport = _selectedReport(filteredReports);
        final selectedGate = gates[selectedReport.id] ?? _ReportGate.empty();
        final selectedSections = _sectionsForReport(selectedReport, filteredSections);
        final templateReady = reportSectionTemplateItems.where((item) => item.status == 'Template ready').length;
        final dataPending = reportSectionTemplateItems.where((item) => item.status == 'Data pending').length;
        final reportableNow = gates.values.where((gate) => gate.readyCount > 0).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Reports', subtitle: 'Asset-aware report command center for reusable player, team, season, draft, award, transaction, franchise, era, and development intelligence workflows.'),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
              _ReportMetric(label: 'Reports', value: '${reportLibraryItems.length}', detail: 'Initial library'),
              _ReportMetric(label: 'Sections', value: '${reportSectionTemplateItems.length}', detail: '$templateReady ready / $dataPending pending'),
              _ReportMetric(label: 'Data-Aware', value: '$reportableNow', detail: 'At least one populated input'),
              _ReportMetric(label: 'Filtered', value: '${filteredReports.length}', detail: 'Current report view'),
            ]);
          }),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search reports, sections, entities, datasets...'))),
            _FilterDropdown(label: 'Category', value: selectedCategory, values: categories, onChanged: (value) => setState(() => selectedCategory = value)),
            _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
            _FilterDropdown(label: 'Report Type', value: selectedReportType, values: reportTypes, onChanged: (value) => setState(() => selectedReportType = value)),
            _FilterDropdown(label: 'Selected Report', value: selectedReportId, values: reportLibraryItems.map((item) => item.id).toList(), display: (value) => reportLibraryItems.firstWhere((item) => item.id == value).title, onChanged: (value) => setState(() => selectedReportId = value)),
          ])),
          const SizedBox(height: 22),
          _ReportMvpReadiness(payload: payload),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1050;
            final selected = _SelectedReportCard(report: selectedReport, gate: selectedGate, sections: selectedSections);
            final builder = _ReportBuilderPreview(report: selectedReport, gate: selectedGate, sections: selectedSections, payload: payload);
            if (!isWide) return Column(children: [selected, const SizedBox(height: 14), builder]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: selected), const SizedBox(width: 14), Expanded(child: builder)]);
          }),
          const SizedBox(height: 22),
          _ReportInputMatrix(payload: payload),
          const SizedBox(height: 22),
          _ReportBuildOrder(),
          const SizedBox(height: 22),
          _ReportLibraryTable(filtered: filteredReports, gates: gates, selectedReportId: selectedReport.id, onSelected: (report) => setState(() => selectedReportId = report.id)),
          const SizedBox(height: 22),
          _ReportSectionsTable(filteredSections: filteredSections, payload: payload),
        ]);
      },
    );
  }

  TerminalReport _selectedReport(List<TerminalReport> filtered) {
    for (final item in reportLibraryItems) {
      if (item.id == selectedReportId) return item;
    }
    if (filtered.isNotEmpty) return filtered.first;
    return reportLibraryItems.first;
  }

  List<ReportSectionTemplate> _sectionsForReport(TerminalReport report, List<ReportSectionTemplate> sections) {
    final title = report.title.toLowerCase();
    String type;
    if (title.contains('player')) {
      type = 'Player Report';
    } else if (title.contains('team') || title.contains('franchise')) {
      type = 'Team Report';
    } else if (title.contains('draft')) {
      type = 'Draft Report';
    } else if (title.contains('transaction')) {
      type = 'Transaction Report';
    } else if (title.contains('award')) {
      type = 'Player Report';
    } else {
      type = 'Season Report';
    }
    final matched = reportSectionTemplateItems.where((item) => item.reportType == type).toList();
    return matched.isEmpty ? sections.take(3).toList() : matched;
  }
}

class _ReportPayload {
  const _ReportPayload({required this.players, required this.playerStats, required this.teamStats, required this.teams, required this.seasons, required this.standings, required this.playoffs, required this.awards, required this.draft, required this.rosters, required this.transactions, required this.games});
  final int players;
  final int playerStats;
  final int teamStats;
  final int teams;
  final int seasons;
  final int standings;
  final int playoffs;
  final int awards;
  final int draft;
  final int rosters;
  final int transactions;
  final int games;
}

class _ReportGate {
  const _ReportGate({required this.required, required this.readyCount, required this.blockers});
  factory _ReportGate.fromReport(TerminalReport report, _ReportPayload payload) {
    final required = _requiredInputs(report.requiredDatasets);
    final blockers = <String>[];
    var ready = 0;
    for (final input in required) {
      final count = _countFor(input, payload);
      if (count > 0) {
        ready += 1;
      } else {
        blockers.add(input);
      }
    }
    return _ReportGate(required: required, readyCount: ready, blockers: blockers);
  }
  factory _ReportGate.empty() => const _ReportGate(required: [], readyCount: 0, blockers: []);
  final List<String> required;
  final int readyCount;
  final List<String> blockers;
  int get total => required.length;
  String get status => total == 0 ? 'Not mapped' : readyCount == total ? 'Ready' : readyCount == 0 ? 'Source pending' : 'Partial';

  static List<String> _requiredInputs(String rawText) {
    final raw = rawText.toLowerCase();
    final inputs = <String>[];
    if (raw.contains('player identity')) inputs.add('Player identity');
    if (raw.contains('player stats') || raw.contains('nba stats')) inputs.add('Player stats');
    if (raw.contains('team stats')) inputs.add('Team stats');
    if (raw.contains('team directory')) inputs.add('Team directory');
    if (raw.contains('season')) inputs.add('Seasons');
    if (raw.contains('standings')) inputs.add('Standings');
    if (raw.contains('playoff')) inputs.add('Playoffs');
    if (raw.contains('award')) inputs.add('Awards');
    if (raw.contains('draft')) inputs.add('Draft');
    if (raw.contains('roster')) inputs.add('Rosters');
    if (raw.contains('transaction')) inputs.add('Transactions');
    if (raw.contains('games') || raw.contains('schedule')) inputs.add('Games');
    if (raw.contains('contract')) inputs.add('Contracts');
    if (raw.contains('g league')) inputs.add('G League');
    if (raw.contains('era')) inputs.add('Era definitions');
    return inputs;
  }

  static int _countFor(String input, _ReportPayload payload) {
    switch (input) {
      case 'Player identity':
        return payload.players;
      case 'Player stats':
        return payload.playerStats;
      case 'Team stats':
        return payload.teamStats;
      case 'Team directory':
        return payload.teams;
      case 'Seasons':
        return payload.seasons;
      case 'Standings':
        return payload.standings;
      case 'Playoffs':
        return payload.playoffs;
      case 'Awards':
        return payload.awards;
      case 'Draft':
        return payload.draft;
      case 'Rosters':
        return payload.rosters;
      case 'Transactions':
        return payload.transactions;
      case 'Games':
        return payload.games;
      default:
        return 0;
    }
  }
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged, this.display});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final String Function(String value)? display;
  @override
  Widget build(BuildContext context) => SizedBox(width: label == 'Selected Report' ? 320 : 230, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(display == null ? item : display!(item), overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
}

class _ReportMvpReadiness extends StatelessWidget {
  const _ReportMvpReadiness({required this.payload});
  final _ReportPayload payload;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('NBA MVP Report Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    const Text('Reports become real when they can assemble source-backed identity, statistics, team context, season context, standings, awards, draft, roster, movement, and source metadata. Until those rows exist, the report builder stays honest about what is template-ready versus data-pending.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 18),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '${payload.players} players'), InfoPill(label: '${payload.playerStats} player stats'), InfoPill(label: '${payload.teamStats} team stats'), InfoPill(label: '${payload.teams} teams'), InfoPill(label: '${payload.seasons} seasons'), InfoPill(label: '${payload.standings} standings'), InfoPill(label: '${payload.games} games')]),
  ]));
}

class _SelectedReportCard extends StatelessWidget {
  const _SelectedReportCard({required this.report, required this.gate, required this.sections});
  final TerminalReport report;
  final _ReportGate gate;
  final List<ReportSectionTemplate> sections;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(report.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))), const SizedBox(width: 10), InfoPill(label: gate.status)]),
    const SizedBox(height: 8),
    Text(report.description, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 16),
    _DetailLine(label: 'Category', value: report.category),
    _DetailLine(label: 'Priority', value: report.priority),
    _DetailLine(label: 'Template Status', value: report.status),
    _DetailLine(label: 'Primary Entities', value: report.primaryEntities),
    _DetailLine(label: 'Required Data', value: report.requiredDatasets),
    _DetailLine(label: 'Gate', value: '${gate.readyCount}/${gate.total} required inputs currently populated'),
    _DetailLine(label: 'Blockers', value: gate.blockers.isEmpty ? 'No blockers from currently mapped inputs.' : gate.blockers.join(', ')),
    _DetailLine(label: 'Matched Sections', value: sections.map((item) => item.section).join(', ')),
  ]));
}

class _ReportBuilderPreview extends StatelessWidget {
  const _ReportBuilderPreview({required this.report, required this.gate, required this.sections, required this.payload});
  final TerminalReport report;
  final _ReportGate gate;
  final List<ReportSectionTemplate> sections;
  final _ReportPayload payload;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Report Builder Preview', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    Text(gate.status == 'Ready' ? 'This report has all mapped input layers populated and is ready for a generated-output workflow.' : 'This report is not yet fully generatable. The template is visible, but source-pending sections should stay blank until the required datasets are populated.', style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 16),
    for (final section in sections.take(6)) _BuilderSectionRow(section: section, payload: payload),
  ]));
}

class _BuilderSectionRow extends StatelessWidget {
  const _BuilderSectionRow({required this.section, required this.payload});
  final ReportSectionTemplate section;
  final _ReportPayload payload;
  @override
  Widget build(BuildContext context) {
    final gate = _ReportGate(required: _ReportGate._requiredInputs(section.dataInputs), readyCount: _ReportGate._requiredInputs(section.dataInputs).where((input) => _ReportGate._countFor(input, payload) > 0).length, blockers: _ReportGate._requiredInputs(section.dataInputs).where((input) => _ReportGate._countFor(input, payload) == 0).toList());
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: terminalBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(section.section, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))), InfoPill(label: gate.status)]),
      const SizedBox(height: 6),
      Text(section.description, style: const TextStyle(color: terminalTextSoft, height: 1.35)),
      const SizedBox(height: 6),
      Text('Inputs: ${section.dataInputs}', style: const TextStyle(color: terminalTextMuted, fontSize: 12)),
    ]));
  }
}

class _ReportInputMatrix extends StatelessWidget {
  const _ReportInputMatrix({required this.payload});
  final _ReportPayload payload;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Report Input Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 34, columns: const [DataColumn(label: Text('Input Layer')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Status')), DataColumn(label: Text('Report Use')), DataColumn(label: Text('MVP Order'))], rows: [
      _row('Player identity', payload.players, 'Player headers, report entities, player links', 'P0'),
      _row('Player stats', payload.playerStats, 'Production summaries, comparisons, award context', 'P0'),
      _row('Team stats', payload.teamStats, 'Team reports, context, league environment', 'P1'),
      _row('Team directory', payload.teams, 'Team headers, joins, franchise context', 'P0'),
      _row('Seasons', payload.seasons, 'Season headers, era context, timeline links', 'P0'),
      _row('Standings', payload.standings, 'Seed, record, conference/division context', 'P1'),
      _row('Playoffs', payload.playoffs, 'Postseason path and championship context', 'P2'),
      _row('Awards', payload.awards, 'Recognition sections and voting context', 'P2'),
      _row('Draft', payload.draft, 'Draft class reports and player outcomes', 'P2'),
      _row('Rosters', payload.rosters, 'Roster construction and role history', 'P2'),
      _row('Transactions', payload.transactions, 'Movement timelines and transaction trees', 'P3'),
      _row('Games', payload.games, 'Schedule, matchup, and box-score context', 'P3'),
    ])),
  ]));
  DataRow _row(String layer, int count, String use, String order) => DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(layer, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text('$count')), DataCell(InfoPill(label: count == 0 ? 'Source pending' : 'Connected')), DataCell(SizedBox(width: 560, child: Text(use))), DataCell(Text(order))]);
}

class _ReportBuildOrder extends StatelessWidget {
  const _ReportBuildOrder();
  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Report Build Order', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 10),
    Text('First, generate Season Report sections that can use the connected season and team directories. Second, activate Team Season Reports after team stats and standings are populated. Third, activate Player Season Profiles after player identity and traditional player stats are populated. Later, add draft class, award race, transaction tree, G League development, franchise history, and era comparison reports.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
  ]));
}

class _ReportLibraryTable extends StatelessWidget {
  const _ReportLibraryTable({required this.filtered, required this.gates, required this.selectedReportId, required this.onSelected});
  final List<TerminalReport> filtered;
  final Map<String, _ReportGate> gates;
  final String selectedReportId;
  final ValueChanged<TerminalReport> onSelected;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Report Library', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filtered.length} reports', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Report')), DataColumn(label: Text('Category')), DataColumn(label: Text('Template Status')), DataColumn(label: Text('Data Gate')), DataColumn(label: Text('Ready')), DataColumn(label: Text('Primary Entities')), DataColumn(label: Text('Required Datasets')), DataColumn(label: Text('Description'))], rows: [for (final item in filtered) DataRow(selected: selectedReportId == item.id, onSelectChanged: (_) => onSelected(item), cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 190, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(InfoPill(label: gates[item.id]?.status ?? 'Not mapped')), DataCell(Text('${gates[item.id]?.readyCount ?? 0}/${gates[item.id]?.total ?? 0}')), DataCell(SizedBox(width: 260, child: Text(item.primaryEntities))), DataCell(SizedBox(width: 420, child: Text(item.requiredDatasets))), DataCell(SizedBox(width: 620, child: Text(item.description)))])])),
  ]));
}

class _ReportSectionsTable extends StatelessWidget {
  const _ReportSectionsTable({required this.filteredSections, required this.payload});
  final List<ReportSectionTemplate> filteredSections;
  final _ReportPayload payload;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Report Section Templates', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${filteredSections.length} sections', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Report Type')), DataColumn(label: Text('Section')), DataColumn(label: Text('Template Status')), DataColumn(label: Text('Data Gate')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Description'))], rows: [for (final item in filteredSections) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 190, child: Text(item.reportType))), DataCell(SizedBox(width: 230, child: Text(item.section, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(InfoPill(label: _sectionGate(item).status)), DataCell(SizedBox(width: 440, child: Text(item.dataInputs))), DataCell(SizedBox(width: 620, child: Text(item.description)))])])),
  ]));
  _ReportGate _sectionGate(ReportSectionTemplate section) {
    final required = _ReportGate._requiredInputs(section.dataInputs);
    return _ReportGate(required: required, readyCount: required.where((input) => _ReportGate._countFor(input, payload) > 0).length, blockers: required.where((input) => _ReportGate._countFor(input, payload) == 0).toList());
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))]));
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
