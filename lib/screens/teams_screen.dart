import 'package:flutter/material.dart';

import '../data/team_command_stage_items.dart';
import '../models/player_profile.dart';
import '../models/registry_item.dart';
import '../models/roster_directory_row.dart';
import '../models/roster_entry.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../services/nba_asset_repository.dart';
import '../services/roster_completeness_service.dart';
import '../services/roster_directory_service.dart';
import '../services/roster_measurement_formatter.dart';
import '../widgets/terminal_filter_dropdown.dart';
import '../widgets/terminal_primitives.dart';
import 'entity_profile_screens.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  late final Future<_TeamsPayload> payloadFuture = _loadPayload();
  String query = '';
  String conference = 'All conferences';
  String division = 'All divisions';
  String completenessFilter = 'All teams';
  _TeamSort sort = _TeamSort.team;
  bool sortAscending = true;

  Future<_TeamsPayload> _loadPayload() async {
    const repository = NbaAssetRepository();
    final results = await Future.wait<dynamic>([
      repository.loadTeams(),
      repository.loadPlayerProfiles(),
      repository.loadRosters(),
      repository.loadTeamSeasonStats(),
    ]);
    final teams = results[0] as List<Team>;
    final players = results[1] as List<PlayerProfile>;
    final rosters = results[2] as List<RosterEntry>;
    final stats = results[3] as List<TeamSeasonStat>;
    final joined = const RosterDirectoryService().join(
      rosters: rosters,
      players: players,
      teams: teams,
    );
    final summary = const RosterCompletenessService().analyze(joined);
    final teamSummary = {for (final item in summary.teams) item.teamId: item};
    final rosterByTeam = <String, List<RosterDirectoryRow>>{};
    for (final row in joined.where((item) => item.entry.seasonId == '2025-26')) {
      rosterByTeam.putIfAbsent(row.teamId, () => []).add(row);
    }
    return _TeamsPayload(
      teams: teams,
      stats: stats,
      summary: summary,
      rows: [
        for (final team in teams)
          _TeamRow(
            team: team,
            roster: rosterByTeam[team.id] ?? const [],
            completeness: teamSummary[team.id],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TeamsPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(
            child: Text('Loading team directory...', style: TextStyle(color: terminalTextSoft)),
          );
        }
        if (snapshot.hasError) {
          return TerminalCard(
            child: Text('Unable to load team directory: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)),
          );
        }
        final payload = snapshot.data ?? _TeamsPayload.empty();
        final divisions = payload.teams.map((item) => item.division).toSet().toList()..sort();
        final visibleRows = payload.rows.where(_matches).toList()..sort(_compare);
        final knownPayroll = payload.rows.fold<int>(0, (sum, row) => sum + row.knownPayrollUsd);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'NBA Teams',
              subtitle:
                  'Connected team directory with final 2025-26 roster coverage, roster physicals, known payroll, metadata completeness, and shared team profile routes.',
            ),
            const SizedBox(height: 22),
            _MetricGrid(values: [
              _Metric('NBA Teams', '${payload.teams.length}', 'Canonical reference rows'),
              _Metric('Roster Coverage', '${payload.summary.teamsCovered} / ${payload.teams.length}', 'Final 2025-26 snapshot'),
              _Metric('Roster Players', '${payload.summary.totalRows}', 'Joined player-team rows'),
              _Metric('Known Payroll', _money(knownPayroll), 'Missing salaries excluded'),
            ]),
            const SizedBox(height: 22),
            _TeamFilters(
              queryChanged: (value) => setState(() => query = value),
              conference: conference,
              conferenceChanged: (value) => setState(() => conference = value),
              division: division,
              divisions: ['All divisions', ...divisions],
              divisionChanged: (value) => setState(() => division = value),
              completeness: completenessFilter,
              completenessChanged: (value) => setState(() => completenessFilter = value),
            ),
            const SizedBox(height: 22),
            _TeamTable(
              rows: visibleRows,
              stats: payload.stats,
              sort: sort,
              sortAscending: sortAscending,
              onSort: (value, ascending) {
                setState(() {
                  sort = value;
                  sortAscending = ascending;
                });
              },
            ),
            const SizedBox(height: 22),
            _CoverageTable(summary: payload.summary),
            const SizedBox(height: 22),
            _StageTable(items: teamCommandStageItems),
          ],
        );
      },
    );
  }

  bool _matches(_TeamRow row) {
    final q = query.trim().toLowerCase();
    final text = '${row.team.id} ${row.team.name} ${row.team.abbreviation} ${row.team.city} ${row.team.conference} ${row.team.division}'.toLowerCase();
    final completionMatch = switch (completenessFilter) {
      'Identity complete' => row.identityIssueCount == 0,
      'Has open identity issues' => row.identityIssueCount > 0,
      'Has missing salaries' => row.missingSalaryCount > 0,
      _ => true,
    };
    return (q.isEmpty || text.contains(q)) &&
        (conference == 'All conferences' || row.team.conference == conference) &&
        (division == 'All divisions' || row.team.division == division) &&
        completionMatch;
  }

  int _compare(_TeamRow a, _TeamRow b) {
    final result = switch (sort) {
      _TeamSort.team => a.team.name.compareTo(b.team.name),
      _TeamSort.city => a.team.city.compareTo(b.team.city),
      _TeamSort.conference => a.team.conference.compareTo(b.team.conference),
      _TeamSort.division => a.team.division.compareTo(b.team.division),
      _TeamSort.roster => a.roster.length.compareTo(b.roster.length),
      _TeamSort.age => a.averageAge.compareTo(b.averageAge),
      _TeamSort.height => a.averageHeightInches.compareTo(b.averageHeightInches),
      _TeamSort.weight => a.averageWeightPounds.compareTo(b.averageWeightPounds),
      _TeamSort.payroll => a.knownPayrollUsd.compareTo(b.knownPayrollUsd),
      _TeamSort.completeness => a.identityCompletionRate.compareTo(b.identityCompletionRate),
    };
    return sortAscending ? result : -result;
  }
}

class _TeamsPayload {
  const _TeamsPayload({
    required this.teams,
    required this.stats,
    required this.rows,
    required this.summary,
  });

  factory _TeamsPayload.empty() => const _TeamsPayload(
        teams: [],
        stats: [],
        rows: [],
        summary: RosterCompletenessSummary(
          totalRows: 0,
          teamsCovered: 0,
          identityCompleteRows: 0,
          fullyPopulatedRows: 0,
          missingFrom: 0,
          missingJersey: 0,
          missingSalary: 0,
          missingPosition: 0,
          invalidHeight: 0,
          invalidWeight: 0,
          missingPlayerJoins: 0,
          missingTeamJoins: 0,
          knownPayrollUsd: 0,
          issues: [],
          teams: [],
        ),
      );

  final List<Team> teams;
  final List<TeamSeasonStat> stats;
  final List<_TeamRow> rows;
  final RosterCompletenessSummary summary;
}

class _TeamRow {
  const _TeamRow({required this.team, required this.roster, required this.completeness});

  final Team team;
  final List<RosterDirectoryRow> roster;
  final TeamRosterCompleteness? completeness;
  static const measurements = RosterMeasurementFormatter();

  double get averageAge => _average(roster.map((row) => row.entry.age).whereType<int>());
  double get averageHeightInches => _average(
        roster.map((row) => measurements.heightInches(row.height)).where((value) => value >= 0),
      );
  double get averageWeightPounds => _average(roster.map((row) => row.weightPounds).whereType<int>());
  int get knownPayrollUsd => roster.fold<int>(0, (sum, row) => sum + (row.entry.salaryUsd ?? 0));
  int get missingSalaryCount => roster.where((row) => row.entry.salaryUsd == null).length;
  int get identityIssueCount => (completeness?.issueCount ?? 0) - missingSalaryCount;
  double get identityCompletionRate => completeness?.identityCompletionRate ?? 0;
}

class _TeamFilters extends StatelessWidget {
  const _TeamFilters({
    required this.queryChanged,
    required this.conference,
    required this.conferenceChanged,
    required this.division,
    required this.divisions,
    required this.divisionChanged,
    required this.completeness,
    required this.completenessChanged,
  });

  final ValueChanged<String> queryChanged;
  final String conference;
  final ValueChanged<String> conferenceChanged;
  final String division;
  final List<String> divisions;
  final ValueChanged<String> divisionChanged;
  final String completeness;
  final ValueChanged<String> completenessChanged;

  @override
  Widget build(BuildContext context) => TerminalCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final controlWidth = compact ? constraints.maxWidth : 230.0;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : 360,
                  child: TextField(
                    onChanged: queryChanged,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: terminalAccent,
                    decoration: _inputDecoration('Search team, city, abbreviation, division...'),
                  ),
                ),
                TerminalFilterDropdown(
                  label: 'Conference',
                  value: conference,
                  values: const ['All conferences', 'East', 'West'],
                  width: controlWidth,
                  onChanged: conferenceChanged,
                ),
                TerminalFilterDropdown(
                  label: 'Division',
                  value: division,
                  values: divisions,
                  width: controlWidth,
                  onChanged: divisionChanged,
                ),
                TerminalFilterDropdown(
                  label: 'Completeness',
                  value: completeness,
                  values: const ['All teams', 'Identity complete', 'Has open identity issues', 'Has missing salaries'],
                  width: controlWidth,
                  onChanged: completenessChanged,
                ),
              ],
            );
          },
        ),
      );
}

class _TeamTable extends StatelessWidget {
  const _TeamTable({
    required this.rows,
    required this.stats,
    required this.sort,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_TeamRow> rows;
  final List<TeamSeasonStat> stats;
  final _TeamSort sort;
  final bool sortAscending;
  final void Function(_TeamSort value, bool ascending) onSort;

  @override
  Widget build(BuildContext context) {
    final statCounts = <String, int>{};
    for (final stat in stats) {
      statCounts[stat.teamId] = (statCounts[stat.teamId] ?? 0) + 1;
    }
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TableHeader(title: 'Team Directory', count: '${rows.length} teams'),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortIndex(sort),
            sortAscending: sortAscending,
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columnSpacing: 28,
            columns: [
              _column('Team', _TeamSort.team, 0),
              const DataColumn(label: Text('Abbrev.')),
              _column('City', _TeamSort.city, 2),
              _column('Conference', _TeamSort.conference, 3),
              _column('Division', _TeamSort.division, 4),
              _column('Roster', _TeamSort.roster, 5, numeric: true),
              _column('Avg Age', _TeamSort.age, 6, numeric: true),
              _column('Avg Height', _TeamSort.height, 7),
              _column('Avg Weight', _TeamSort.weight, 8),
              _column('Known Payroll', _TeamSort.payroll, 9, numeric: true),
              _column('Identity Complete', _TeamSort.completeness, 10, numeric: true),
              const DataColumn(label: Text('Stat Rows'), numeric: true),
            ],
            rows: [
              for (final row in rows)
                DataRow(cells: [
                  DataCell(_TeamLink(team: row.team)),
                  DataCell(Text(row.team.abbreviation)),
                  DataCell(Text(row.team.city)),
                  DataCell(Text(row.team.conference)),
                  DataCell(Text(row.team.division)),
                  DataCell(Text('${row.roster.length}')),
                  DataCell(Text(_displayAverage(row.averageAge))),
                  DataCell(Text(row.averageHeightInches < 0 ? '—' : _heightLabel(row.averageHeightInches))),
                  DataCell(Text(row.averageWeightPounds < 0 ? '—' : '${row.averageWeightPounds.toStringAsFixed(1)} lbs (${(row.averageWeightPounds * 0.45359237).toStringAsFixed(1)} kg)')),
                  DataCell(Text(_money(row.knownPayrollUsd))),
                  DataCell(Text('${(row.identityCompletionRate * 100).toStringAsFixed(1)}%')),
                  DataCell(Text('${statCounts[row.team.id] ?? 0}')),
                ]),
            ],
          ),
        ),
      ]),
    );
  }

  DataColumn _column(String label, _TeamSort value, int index, {bool numeric = false}) => DataColumn(
        label: Text(label),
        numeric: numeric,
        onSort: (_, ascending) => onSort(value, ascending),
      );

  int _sortIndex(_TeamSort value) => switch (value) {
        _TeamSort.team => 0,
        _TeamSort.city => 2,
        _TeamSort.conference => 3,
        _TeamSort.division => 4,
        _TeamSort.roster => 5,
        _TeamSort.age => 6,
        _TeamSort.height => 7,
        _TeamSort.weight => 8,
        _TeamSort.payroll => 9,
        _TeamSort.completeness => 10,
      };
}

class _CoverageTable extends StatelessWidget {
  const _CoverageTable({required this.summary});

  final RosterCompletenessSummary summary;

  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _TableHeader(title: 'League Roster Coverage', count: '30-team gate'),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columns: const [
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Rows'), numeric: true),
                DataColumn(label: Text('Identity Complete'), numeric: true),
                DataColumn(label: Text('Fully Populated'), numeric: true),
                DataColumn(label: Text('Open Issues'), numeric: true),
                DataColumn(label: Text('Known Payroll'), numeric: true),
              ],
              rows: [
                for (final team in summary.teams)
                  DataRow(cells: [
                    DataCell(TextButton(onPressed: () => openTeamProfile(context, team.teamId), child: Text(team.teamName))),
                    DataCell(Text('${team.rows}')),
                    DataCell(Text('${(team.identityCompletionRate * 100).toStringAsFixed(1)}%')),
                    DataCell(Text('${(team.fullCompletionRate * 100).toStringAsFixed(1)}%')),
                    DataCell(Text('${team.issueCount}')),
                    DataCell(Text(_money(team.knownPayrollUsd))),
                  ]),
              ],
            ),
          ),
        ]),
      );
}

class _StageTable extends StatelessWidget {
  const _StageTable({required this.items});

  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _TableHeader(title: 'Team Command Stage Model', count: 'Roadmap'),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columns: const [
                DataColumn(label: Text('Priority')),
                DataColumn(label: Text('Stage')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Next Step')),
              ],
              rows: [
                for (final item in items)
                  DataRow(cells: [
                    DataCell(Text(item.priority)),
                    DataCell(SizedBox(width: 220, child: Text(item.title))),
                    DataCell(Text(item.category)),
                    DataCell(InfoPill(label: item.status)),
                    DataCell(SizedBox(width: 520, child: Text(item.nextStep))),
                  ]),
              ],
            ),
          ),
        ]),
      );
}

class _TeamLink extends StatelessWidget {
  const _TeamLink({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: terminalAccent,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          onPressed: () => openTeamProfile(context, team.id),
          child: Align(alignment: Alignment.centerLeft, child: Text(team.name, overflow: TextOverflow.ellipsis)),
        ),
      );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.title, required this.count});

  final String title;
  final String count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Text(count, style: const TextStyle(color: terminalTextMuted)),
        ]),
      );
}

class _Metric {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values});
  final List<_Metric> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 950 ? 4 : constraints.maxWidth > 520 ? 2 : 1;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 3.0 : 1.8,
            children: [
              for (final metric in values)
                TerminalCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(metric.label, style: const TextStyle(color: terminalTextMuted, fontSize: 12)),
                    Text(metric.value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    Text(metric.detail, style: const TextStyle(color: terminalAccent, fontSize: 11)),
                  ]),
                ),
            ],
          );
        },
      );
}

enum _TeamSort { team, city, conference, division, roster, age, height, weight, payroll, completeness }

double _average(Iterable<num> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return -1;
  return list.fold<double>(0, (sum, value) => sum + value.toDouble()) / list.length;
}

String _displayAverage(double value) => value < 0 ? '—' : value.toStringAsFixed(1);
String _heightLabel(double inches) {
  final rounded = inches.round();
  return '${rounded ~/ 12}\' ${rounded % 12}" (${(inches * 0.0254).toStringAsFixed(2)} m)';
}

String _money(int value) => '\$${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

InputDecoration _inputDecoration(String hintText) => InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: terminalTextMuted),
      prefixIcon: const Icon(Icons.search, color: terminalTextMuted),
      filled: true,
      fillColor: terminalPanelDark,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
    );
