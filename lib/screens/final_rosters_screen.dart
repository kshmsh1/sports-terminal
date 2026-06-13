import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../models/roster_directory_row.dart';
import '../models/roster_entry.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import '../services/roster_completeness_service.dart';
import '../services/roster_directory_service.dart';
import '../services/roster_measurement_formatter.dart';
import '../widgets/terminal_filter_dropdown.dart';
import '../widgets/terminal_primitives.dart';
import 'entity_profile_screens.dart';

class FinalRostersScreen extends StatefulWidget {
  const FinalRostersScreen({super.key});

  @override
  State<FinalRostersScreen> createState() => _FinalRostersScreenState();
}

class _FinalRostersScreenState extends State<FinalRostersScreen> {
  late final Future<_RosterPayload> payloadFuture = _loadPayload();

  String query = '';
  String selectedTeam = 'All teams';
  String selectedIssue = 'All rows';
  _RosterSort sort = _RosterSort.team;
  bool sortAscending = true;

  Future<_RosterPayload> _loadPayload() async {
    const repository = NbaAssetRepository();
    final results = await Future.wait<dynamic>([
      repository.loadPlayerProfiles(),
      repository.loadTeams(),
      repository.loadRosters(),
    ]);
    final players = results[0] as List<PlayerProfile>;
    final teams = results[1] as List<Team>;
    final rosters = results[2] as List<RosterEntry>;
    final rows = const RosterDirectoryService().join(
      rosters: rosters,
      players: players,
      teams: teams,
    );
    return _RosterPayload(
      players: players,
      teams: teams,
      rosters: rosters,
      rows: rows,
      summary: const RosterCompletenessService().analyze(rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RosterPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(
            child: Text('Loading final roster control center...', style: TextStyle(color: terminalTextSoft)),
          );
        }
        if (snapshot.hasError) {
          return TerminalCard(
            child: Text('Unable to load final roster control center: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)),
          );
        }
        final payload = snapshot.data ?? _RosterPayload.empty();
        final teamById = {for (final team in payload.teams) team.id: team};
        final teamIds = payload.rows.map((row) => row.teamId).toSet().toList()
          ..sort((a, b) => (teamById[a]?.name ?? a).compareTo(teamById[b]?.name ?? b));
        final rows = payload.rows.where(_matchesFilters).toList()..sort(_compareRows);
        final visibleIssues = payload.summary.issues.where((issue) {
          if (selectedTeam != 'All teams' && issue.teamId != selectedTeam) return false;
          if (selectedIssue == 'All rows') return true;
          return issue.field == selectedIssue;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Final 2025-26 Rosters',
              subtitle:
                  'League-wide final roster control center with 30-team coverage, linked player and team profiles, sortable roster dimensions, known payroll, and visible metadata-completion work.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                const InfoPill(label: '2025-26 final roster snapshot'),
                const InfoPill(label: 'Manual source-backed'),
                InfoPill(label: '${payload.summary.teamsCovered} teams'),
                InfoPill(label: '${payload.summary.totalRows} players'),
                InfoPill(label: '${payload.summary.identityIssueCount} identity issues'),
              ],
            ),
            const SizedBox(height: 22),
            _MetricGrid(
              summary: payload.summary,
              visibleRows: rows.length,
            ),
            const SizedBox(height: 22),
            _RosterFilterBar(
              queryChanged: (value) => setState(() => query = value),
              selectedTeam: selectedTeam,
              teamIds: ['All teams', ...teamIds],
              teamLabel: (value) => value == 'All teams' ? value : teamById[value]?.name ?? value,
              teamChanged: (value) => setState(() => selectedTeam = value),
              selectedIssue: selectedIssue,
              issueChanged: (value) => setState(() => selectedIssue = value),
            ),
            const SizedBox(height: 22),
            _RosterTable(
              rows: rows,
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
            _CompletenessIssueTable(issues: visibleIssues),
            const SizedBox(height: 22),
            _TeamCoverageTable(teams: payload.summary.teams),
            const SizedBox(height: 22),
            const _RosterContractCard(),
          ],
        );
      },
    );
  }

  bool _matchesFilters(RosterDirectoryRow row) {
    final normalizedQuery = query.trim().toLowerCase();
    final searchable = [
      row.playerName,
      row.teamName,
      row.teamAbbreviation,
      row.entry.jerseyNumber ?? '',
      row.position,
      row.from,
      row.entry.salaryDisplay ?? '',
    ].join(' ').toLowerCase();
    final teamMatch = selectedTeam == 'All teams' || row.teamId == selectedTeam;
    final issueMatch = switch (selectedIssue) {
      'From' => row.from == '—',
      'Jersey' => row.entry.jerseyNumber == null || row.entry.jerseyNumber!.trim().isEmpty,
      'Salary' => row.entry.salaryUsd == null,
      'Position' => row.position == '—',
      'Height' => const RosterMeasurementFormatter().heightInches(row.entry.height ?? row.player?.height) < 0,
      'Weight' => (row.entry.weightPounds ?? row.player?.weightPounds) == null,
      _ => true,
    };
    return (normalizedQuery.isEmpty || searchable.contains(normalizedQuery)) && teamMatch && issueMatch;
  }

  int _compareRows(RosterDirectoryRow a, RosterDirectoryRow b) {
    const measurements = RosterMeasurementFormatter();
    final result = switch (sort) {
      _RosterSort.player => a.playerName.compareTo(b.playerName),
      _RosterSort.team => a.teamName.compareTo(b.teamName),
      _RosterSort.jersey => measurements.jerseySortValue(a.entry.jerseyNumber).compareTo(measurements.jerseySortValue(b.entry.jerseyNumber)),
      _RosterSort.position => a.position.compareTo(b.position),
      _RosterSort.age => (a.entry.age ?? -1).compareTo(b.entry.age ?? -1),
      _RosterSort.height => measurements.heightInches(a.entry.height ?? a.player?.height).compareTo(measurements.heightInches(b.entry.height ?? b.player?.height)),
      _RosterSort.weight => (a.entry.weightPounds ?? a.player?.weightPounds ?? -1).compareTo(b.entry.weightPounds ?? b.player?.weightPounds ?? -1),
      _RosterSort.from => a.from.compareTo(b.from),
      _RosterSort.salary => (a.entry.salaryUsd ?? -1).compareTo(b.entry.salaryUsd ?? -1),
    };
    return sortAscending ? result : -result;
  }
}

class _RosterPayload {
  const _RosterPayload({
    required this.players,
    required this.teams,
    required this.rosters,
    required this.rows,
    required this.summary,
  });

  factory _RosterPayload.empty() {
    return _RosterPayload(
      players: const [],
      teams: const [],
      rosters: const [],
      rows: const [],
      summary: const RosterCompletenessSummary(
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

  final List<PlayerProfile> players;
  final List<Team> teams;
  final List<RosterEntry> rosters;
  final List<RosterDirectoryRow> rows;
  final RosterCompletenessSummary summary;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary, required this.visibleRows});

  final RosterCompletenessSummary summary;
  final int visibleRows;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricValue('Roster Rows', '${summary.totalRows}', '$visibleRows currently visible'),
      _MetricValue('Teams Covered', '${summary.teamsCovered} / 30', summary.teamsCovered == 30 ? 'League coverage complete' : 'Coverage incomplete'),
      _MetricValue('Identity Complete', '${(summary.identityCompletionRate * 100).toStringAsFixed(1)}%', '${summary.identityCompleteRows} rows'),
      _MetricValue('Known Payroll', _money(summary.knownPayrollUsd), '${summary.missingSalary} salaries missing'),
      _MetricValue('Missing From', '${summary.missingFrom}', 'College, prior club, or country'),
      _MetricValue('Missing Jersey', '${summary.missingJersey}', 'Current number pending'),
      _MetricValue('Invalid Physicals', '${summary.invalidHeight + summary.invalidWeight}', 'Height or weight issues'),
      _MetricValue('Broken Joins', '${summary.missingPlayerJoins + summary.missingTeamJoins}', 'Player or team references'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100 ? 4 : constraints.maxWidth > 620 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.2 : columns == 2 ? 2.0 : 1.9,
          children: [
            for (final metric in metrics)
              TerminalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(metric.label, style: const TextStyle(color: terminalTextMuted, fontSize: 12)),
                    Text(metric.value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
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

class _MetricValue {
  const _MetricValue(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class _RosterFilterBar extends StatelessWidget {
  const _RosterFilterBar({
    required this.queryChanged,
    required this.selectedTeam,
    required this.teamIds,
    required this.teamLabel,
    required this.teamChanged,
    required this.selectedIssue,
    required this.issueChanged,
  });

  final ValueChanged<String> queryChanged;
  final String selectedTeam;
  final List<String> teamIds;
  final String Function(String value) teamLabel;
  final ValueChanged<String> teamChanged;
  final String selectedIssue;
  final ValueChanged<String> issueChanged;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final fieldWidth = compact ? constraints.maxWidth : 250.0;
          final searchWidth = compact ? constraints.maxWidth : 420.0;
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
                  decoration: _inputDecoration('Search player, team, jersey, position, From...'),
                ),
              ),
              TerminalFilterDropdown(
                label: 'Team',
                value: selectedTeam,
                values: teamIds,
                width: fieldWidth,
                displayBuilder: teamLabel,
                onChanged: teamChanged,
              ),
              TerminalFilterDropdown(
                label: 'Issue / completeness',
                value: selectedIssue,
                values: const ['All rows', 'From', 'Jersey', 'Salary', 'Position', 'Height', 'Weight'],
                width: fieldWidth,
                onChanged: issueChanged,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RosterTable extends StatelessWidget {
  const _RosterTable({
    required this.rows,
    required this.sort,
    required this.sortAscending,
    required this.onSort,
  });

  final List<RosterDirectoryRow> rows;
  final _RosterSort sort;
  final bool sortAscending;
  final void Function(_RosterSort sort, bool ascending) onSort;
  static const measurements = RosterMeasurementFormatter();

  @override
  Widget build(BuildContext context) {
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
                    'League Roster Table',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${rows.length} rows', style: const TextStyle(color: terminalTextMuted)),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No roster rows match the current filters.', style: TextStyle(color: terminalTextSoft)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex(sort),
                sortAscending: sortAscending,
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columnSpacing: 26,
                columns: [
                  _column('Player', _RosterSort.player, 0),
                  _column('Team', _RosterSort.team, 1),
                  const DataColumn(label: Text('Season')),
                  _column('No.', _RosterSort.jersey, 3, numeric: true),
                  _column('Position(s)', _RosterSort.position, 4),
                  _column('Age', _RosterSort.age, 5, numeric: true),
                  _column('Height', _RosterSort.height, 6),
                  _column('Weight', _RosterSort.weight, 7),
                  _column('From', _RosterSort.from, 8),
                  _column('Salary', _RosterSort.salary, 9, numeric: true),
                  const DataColumn(label: Text('Status')),
                  const DataColumn(label: Text('Source')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(_EntityLink(label: row.playerName, onTap: () => openPlayerProfile(context, row.playerId), width: 205)),
                        DataCell(_EntityLink(label: row.teamName, onTap: () => openTeamProfile(context, row.teamId), width: 185)),
                        DataCell(Text(row.entry.seasonId)),
                        DataCell(Text(row.entry.jerseyNumber ?? '—')),
                        DataCell(Text(row.position)),
                        DataCell(Text(row.entry.age?.toString() ?? '—')),
                        DataCell(Text(measurements.heightLabel(row.entry.height ?? row.player?.height))),
                        DataCell(Text(measurements.weightLabel(row.entry.weightPounds ?? row.player?.weightPounds))),
                        DataCell(SizedBox(width: 165, child: Text(row.from, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(row.entry.salaryDisplay ?? '—')),
                        DataCell(InfoPill(label: row.entry.rosterStatus ?? 'Final roster')),
                        DataCell(SizedBox(width: 220, child: Text(row.sourceId, overflow: TextOverflow.ellipsis))),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  DataColumn _column(String label, _RosterSort columnSort, int index, {bool numeric = false}) {
    return DataColumn(
      label: Text(label),
      numeric: numeric,
      onSort: (_, ascending) => onSort(columnSort, ascending),
    );
  }

  int _sortColumnIndex(_RosterSort value) => switch (value) {
        _RosterSort.player => 0,
        _RosterSort.team => 1,
        _RosterSort.jersey => 3,
        _RosterSort.position => 4,
        _RosterSort.age => 5,
        _RosterSort.height => 6,
        _RosterSort.weight => 7,
        _RosterSort.from => 8,
        _RosterSort.salary => 9,
      };
}

class _CompletenessIssueTable extends StatelessWidget {
  const _CompletenessIssueTable({required this.issues});

  final List<RosterCompletenessIssue> issues;

  @override
  Widget build(BuildContext context) {
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
                  child: Text('Metadata Completion Queue', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Text('${issues.length} issues', style: const TextStyle(color: terminalTextMuted)),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          if (issues.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No metadata issues match the current filters.', style: TextStyle(color: terminalTextSoft)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columns: const [
                  DataColumn(label: Text('Player')),
                  DataColumn(label: Text('Team')),
                  DataColumn(label: Text('Field')),
                  DataColumn(label: Text('Issue')),
                ],
                rows: [
                  for (final issue in issues.take(150))
                    DataRow(
                      cells: [
                        DataCell(_EntityLink(label: issue.playerName, onTap: () => openPlayerProfile(context, issue.playerId), width: 205)),
                        DataCell(_EntityLink(label: issue.teamName, onTap: () => openTeamProfile(context, issue.teamId), width: 185)),
                        DataCell(InfoPill(label: issue.field)),
                        DataCell(SizedBox(width: 420, child: Text(issue.message))),
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

class _TeamCoverageTable extends StatelessWidget {
  const _TeamCoverageTable({required this.teams});

  final List<TeamRosterCompleteness> teams;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Team-by-Team Completion', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
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
                DataColumn(label: Text('Rows'), numeric: true),
                DataColumn(label: Text('Identity Complete'), numeric: true),
                DataColumn(label: Text('Fully Populated'), numeric: true),
                DataColumn(label: Text('Issues'), numeric: true),
                DataColumn(label: Text('Known Payroll'), numeric: true),
              ],
              rows: [
                for (final team in teams)
                  DataRow(
                    cells: [
                      DataCell(_EntityLink(label: team.teamName, onTap: () => openTeamProfile(context, team.teamId), width: 205)),
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

class _RosterContractCard extends StatelessWidget {
  const _RosterContractCard();

  @override
  Widget build(BuildContext context) {
    return const TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Roster Snapshot Contract', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 10),
          Text(
            'Every connected row is identified as a final 2025-26 roster row. Player IDs, team IDs, source IDs, as-of metadata, roster status, height, weight, age, and league-wide team coverage are validated before the roster seed is accepted. Missing From, jersey, or salary values remain explicitly visible instead of being guessed.',
            style: TextStyle(color: terminalTextSoft, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _EntityLink extends StatelessWidget {
  const _EntityLink({required this.label, required this.onTap, required this.width});

  final String label;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: terminalAccent,
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: onTap,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

enum _RosterSort { player, team, jersey, position, age, height, weight, from, salary }

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
