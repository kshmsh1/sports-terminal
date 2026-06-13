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
  String selectedConference = 'All conferences';
  String selectedDivision = 'All divisions';
  String selectedCompleteness = 'All teams';
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
    final joined = const RosterDirectoryService().join(
      rosters: rosters,
      players: players,
      teams: teams,
    );
    final completeness = const RosterCompletenessService().analyze(joined);
    final completenessByTeam = {
      for (final team in completeness.teams) team.teamId: team,
    };
    final rosterByTeam = <String, List<RosterDirectoryRow>>{};
    for (final row in joined.where((item) => item.entry.seasonId == '2025-26')) {
      rosterByTeam.putIfAbsent(row.teamId, () => []).add(row);
    }

    final rows = [
      for (final team in teams)
        _TeamDirectoryRow(
          team: team,
          roster: rosterByTeam[team.id] ?? const [],
          completeness: completenessByTeam[team.id],
        ),
    ];

    return _TeamsPayload(
      teams: teams,
      players: players,
      rosters: rosters,
      stats: results[3] as List<TeamSeasonStat>,
      rows: rows,
      completeness: completeness,
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
        final divisions = payload.teams.map((team) => team.division).toSet().toList()..sort();
        final rows = payload.rows.where(_matchesFilters).toList()..sort(_compareRows);
        final totalKnownPayroll = payload.rows.fold<int>(0, (sum, row) => sum + row.knownPayrollUsd);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'NBA Teams',
              subtitle:
                  'Connected team directory with final 2025-26 roster coverage, roster physicals, known payroll, metadata completeness, and shared team profile routes.',
            ),
            const SizedBox(height: 22),
            _MetricGrid(
              metrics: [
                _MetricValue('NBA Teams', '${payload.teams.length}', 'Canonical reference rows'),
                _MetricValue('Roster Coverage', '${payload.completeness.teamsCovered} / ${payload.teams.length}', 'Final 2025-26 snapshot'),
                _MetricValue('Final Roster Players', '${payload.completeness.totalRows}', 'Joined player-team rows'),
                _MetricValue('Known Payroll', _money(totalKnownPayroll), 'Missing salaries excluded'),
              ],
            ),
            const SizedBox(height: 22),
            _TeamFilterBar(
              queryChanged: (value) => setState(() => query = value),
              selectedConference: selectedConference,
              conferenceChanged: (value) => setState(() => selectedConference = value),
              selectedDivision: selectedDivision,
              divisions: ['All divisions', ...divisions],
              divisionChanged: (value) => setState(() => selectedDivision = value),
              selectedCompleteness: selectedCompleteness,
              completenessChanged: (value) => setState(() => selectedCompleteness = value),
            ),
            const SizedBox(height: 22),
            _TeamDirectoryTable(
              rows: rows,
              stats: payload.stats,
              sort: sort,
              sortAscending: sortAscending,
              onSort: (nextSort, ascending) {
                setState(() {
                  sort = nextSort;
                  sortAscending = ascending;
                });
              },
            ),
            const SizedBox(height: 22),
            _LeagueRosterCoverage(summary: payload.completeness),
            const SizedBox(height: 22),
            _TeamCommandStageTable(items: teamCommandStageItems),
          ],
        );
      },
    );
  }

  bool _matchesFilters(_TeamDirectoryRow row) {
    final normalizedQuery = query.trim().toLowerCase();
    final searchable = [
      row.team.id,
      row.team.name,
      row.team.abbreviation,
      row.team.city,
      row.team.conference,
      row.team.division,
    ].join(' ').toLowerCase();

    final conferenceMatch = selectedConference == 'All conferences' || row.team.conference == selectedConference;
    final divisionMatch = selectedDivision == 'All divisions' || row.team.division == selectedDivision;
    final completenessMatch = switch (selectedCompleteness) {
      'Identity complete' => row.identityIssueCount == 0,
      'Has open identity issues' => row.identityIssueCount > 0,
      'Has missing salaries' => row.missingSalaryCount > 0,
      _ => true,
    };

    return (normalizedQuery.isEmpty || searchable.contains(normalizedQuery)) &&
        conferenceMatch &&
        divisionMatch &&
        completenessMatch;
  }

  int _compareRows(_TeamDirectoryRow a, _TeamDirectoryRow b) {
    final result = switch (sort) {
      _TeamSort.team => a.team.name.compareTo(b.team.name),
      _TeamSort.city => a.team.city.compareTo(b.team.city),
      _TeamSort.conference => a.team.conference.compareTo(b.team.conference),
      _TeamSort.division => a.team.division.compareTo(b.team.division),
      _TeamSort.roster => a.roster.length.compareTo(b.roster.length),
      _TeamSort.averageAge => a.averageAge.compareTo(b.averageAge),
      _TeamSort.averageHeight => a.averageHeightInches.compareTo(b.averageHeightInches),
      _TeamSort.averageWeight => a.averageWeightPounds.compareTo(b.averageWeightPounds),
      _TeamSort.payroll => a.knownPayrollUsd.compareTo(b.knownPayrollUsd),
      _TeamSort.completeness => a.identityCompletionRate.compareTo(b.identityCompletionRate),
    };
    return sortAscending ? result : -result;
  }
}

class _TeamsPayload {
  const _TeamsPayload({
    required this.teams,
    required this.players,
    required this.rosters,
    required this.stats,
    required this.rows,
    required this.completeness,
  });

  factory _TeamsPayload.empty() {
    return _TeamsPayload(
      teams: const [],
      players: const [],
      rosters: const [],
      stats: const [],
      rows: const [],
      completeness: const RosterCompletenessSummary(
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
  }

  final List<Team> teams;
  final List<PlayerProfile> players;
  final List<RosterEntry> rosters;
  final List<TeamSeasonStat> stats;
  final List<_TeamDirectoryRow> rows;
  final RosterCompletenessSummary completeness;
}

class _TeamDirectoryRow {
  const _TeamDirectoryRow({
    required this.team,
    required this.roster,
    required this.completeness,
  });

  final Team team;
  final List<RosterDirectoryRow> roster;
  final TeamRosterCompleteness? completeness;

  static const measurements = RosterMeasurementFormatter();

  List<RosterDirectoryRow> get rowsWithAge => roster.where((row) => row.entry.age != null).toList();
  List<RosterDirectoryRow> get rowsWithHeight => roster.where((row) => measurements.heightInches(row.entry.height ?? row.player?.height) >= 0).toList();
  List<RosterDirectoryRow> get rowsWithWeight => roster.where((row) => (row.entry.weightPounds ?? row.player?.weightPounds) != null).toList();

  double get averageAge => rowsWithAge.isEmpty
      ? -1
      : rowsWithAge.fold<int>(0, (sum, row) => sum + row.entry.age!) / rowsWithAge.length;

  double get averageHeightInches => rowsWithHeight.isEmpty
      ? -1
      : rowsWithHeight.fold<int>(0, (sum, row) => sum + measurements.heightInches(row.entry.height ?? row.player?.height)) /
          rowsWithHeight.length;

  double get averageWeightPounds => rowsWithWeight.isEmpty
      ? -1
      : rowsWithWeight.fold<int>(0, (sum, row) => sum + (row.entry.weightPounds ?? row.player?.weightPounds!)) /
          rowsWithWeight.length;

  int get knownPayrollUsd => roster.fold<int>(0, (sum, row) => sum + (row.entry.salaryUsd ?? 0));
  int get identityIssueCount => completeness?.issueCount == null
      ? 0
      : completeness!.issueCount - missingSalaryCount;
  int get missingSalaryCount => roster.where((row) => row.entry.salaryUsd == null).length;
  double get identityCompletionRate => completeness?.identityCompletionRate ?? 0;
}

class _TeamFilterBar extends StatelessWidget {
  const _TeamFilterBar({
    required this.queryChanged,
    required this.selectedConference,
    required this.conferenceChanged,
    required this.selectedDivision,
    required this.divisions,
    required this.divisionChanged,
    required this.selectedCompleteness,
    required this.completenessChanged,
  });

  final ValueChanged<String> queryChanged;
  final String selectedConference;
  final ValueChanged<String> conferenceChanged;
  final String selectedDivision;
  final List<String> divisions;
  final ValueChanged<String> divisionChanged;
  final String selectedCompleteness;
  final ValueChanged<String> completenessChanged;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final fieldWidth = compact ? constraints.maxWidth : 230.0;
          final searchWidth = compact ? constraints.maxWidth : 360.0;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: searchWidth,
                child: TextField(
                  onChanged: queryChanged,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: terminalAccent,
                  decoration: _inputDecoration('Search team, city, abbreviation, division...'),
                ),
              ),
              TerminalFilterDropdown(
                label: 'Conference',
                value: selectedConference,
                values: const ['All conferences', 'East', 'West'],
                width: fieldWidth,
                onChanged: conferenceChanged,
              ),
              TerminalFilterDropdown(
                label: 'Division',
                value: selectedDivision,
                values: divisions,
                width: fieldWidth,
                onChanged: divisionChanged,
              ),
              TerminalFilterDropdown(
                label: 'Completeness',
                value: selectedCompleteness,
                values: const ['All teams', 'Identity complete', 'Has open identity issues', 'Has missing salaries'],
                width: fieldWidth,
                onChanged: completenessChanged,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamDirectoryTable extends StatelessWidget {
  const _TeamDirectoryTable({
    required this.rows,
    required this.stats,
    required this.sort,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_TeamDirectoryRow> rows;
  final List<TeamSeasonStat> stats;
  final _TeamSort sort;
  final bool sortAscending;
  final void Function(_TeamSort sort, bool ascending) onSort;

  @override
  Widget build(BuildContext context) {
    final statCounts = <String, int>{};
    for (final stat in stats) {
      statCounts[stat.teamId] = (statCounts[stat.teamId] ?? 0) + 1;
    }

    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Team Directory',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${rows.length} teams', style: const TextStyle(color: terminalTextMuted)),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: _sortColumnIndex(sort),
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
                _column('Avg Age', _TeamSort.averageAge, 6, numeric: true),
                _column('Avg Height', _TeamSort.averageHeight, 7),
                _column('Avg Weight', _TeamSort.averageWeight, 8),
                _column('Known Payroll', _TeamSort.payroll, 9, numeric: true),
                _column('Identity Complete', _TeamSort.completeness, 10, numeric: true),
                const DataColumn(label: Text('Stat Rows'), numeric: true),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 210,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: terminalAccent,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              textStyle: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            onPressed: () => openTeamProfile(context, row.team.id),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(row.team.name, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(row.team.abbreviation)),
                      DataCell(Text(row.team.city)),
                      DataCell(Text(row.team.conference)),
                      DataCell(Text(row.team.division)),
                      DataCell(Text('${row.roster.length}')),
                      DataCell(Text(row.averageAge < 0 ? '—' : row.averageAge.toStringAsFixed(1))),
                      DataCell(Text(row.averageHeightInches < 0 ? '—' : _heightFromInches(row.averageHeightInches))),
                      DataCell(Text(row.averageWeightPounds < 0 ? '—' : '${row.averageWeightPounds.toStringAsFixed(1)} lbs (${(row.averageWeightPounds * 0.45359237).toStringAsFixed(1)} kg)')),
                      DataCell(Text(_money(row.knownPayrollUsd))),
                      DataCell(Text('${(row.identityCompletionRate * 100).toStringAsFixed(1)}%')),
                      DataCell(Text('${statCounts[row.team.id] ?? 0}')),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _column(String label, _TeamSort columnSort, int index, {bool numeric = false}) {
    return DataColumn(
      label: Text(label),
      numeric: numeric,
      onSort: (_, ascending) => onSort(columnSort, ascending),
    );
  }

  int _sortColumnIndex(_TeamSort value) => switch (value) {
        _TeamSort.team => 0,
        _TeamSort.city => 2,
        _TeamSort.conference => 3,
        _TeamSort.division => 4,
        _TeamSort.roster => 5,
        _TeamSort.averageAge => 6,
        _TeamSort.averageHeight => 7,
        _TeamSort.averageWeight => 8,
        _TeamSort.payroll => 9,
        _TeamSort.completeness => 10,
      };
}

class _LeagueRosterCoverage extends StatelessWidget {
  const _LeagueRosterCoverage({required this.summary});

  final RosterCompletenessSummary summary;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('League Roster Coverage', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columns: const [
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Roster Rows'), numeric: true),
                DataColumn(label: Text('Identity Complete'), numeric: true),
                DataColumn(label: Text('Fully Populated'), numeric: true),
                DataColumn(label: Text('Open Issues'), numeric: true),
                DataColumn(label: Text('Known Payroll'), numeric: true),
              ],
              rows: [
                for (final team in summary.teams)
                  DataRow(
                    cells: [
                      DataCell(Text(team.teamName)),
                      DataCell(Text('${team.rows}')),
                      DataCell(Text('${(team.identityCompletionRate * 100).toStringAsFixed(1)}%')),
                      DataCell(Text('${(team.fullCompletionRate * 100).toStringAsFixed(1)}%')),
                      DataCell(Text('${team.issueCount}')),
                      DataCell(Text(_money(team.knownPayrollUsd))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamCommandStageTable extends StatelessWidget {
  const _TeamCommandStageTable({required this.items});

  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Team Command Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
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
                  DataRow(
                    cells: [
                      DataCell(Text(item.priority)),
                      DataCell(SizedBox(width: 220, child: Text(item.title))),
                      DataCell(Text(item.category)),
                      DataCell(InfoPill(label: item.status)),
                      DataCell(SizedBox(width: 520, child: Text(item.nextStep))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TeamSort {
  team,
  city,
  conference,
  division,
  roster,
  averageAge,
  averageHeight,
  averageWeight,
  payroll,
  completeness,
}

class _MetricValue {
  const _MetricValue(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricValue> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 950 ? 4 : constraints.maxWidth > 520 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.0 : columns == 2 ? 1.8 : 1.8,
          children: [
            for (final metric in metrics)
              TerminalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(metric.label, style: const TextStyle(color: terminalTextMuted, fontSize: 12)),
                    Text(metric.value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    Text(metric.detail, style: const TextStyle(color: terminalAccent, fontSize: 11)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

InputDecoration _inputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: terminalTextMuted),
    prefixIcon: const Icon(Icons.search, color: terminalTextMuted),
    filled: true,
    fillColor: terminalPanelDark,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: terminalBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: terminalAccent),
    ),
  );
}

String _money(int value) {
  final formatted = value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
  return '\$$formatted';
}

String _heightFromInches(double inches) {
  final rounded = inches.round();
  final feet = rounded ~/ 12;
  final remainder = rounded % 12;
  return '$feet\' $remainder" (${(inches * 0.0254).toStringAsFixed(2)} m)';
}
