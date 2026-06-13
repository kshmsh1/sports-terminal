import 'package:flutter/material.dart';

import '../data/player_command_stage_items.dart';
import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/registry_item.dart';
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

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  late final Future<_PlayersPayload> payloadFuture = _loadPayload();

  String query = '';
  String selectedTeam = 'All teams';
  String selectedPosition = 'All positions';
  String selectedCompleteness = 'All rows';
  _PlayerSort sort = _PlayerSort.player;
  bool sortAscending = true;

  Future<_PlayersPayload> _loadPayload() async {
    const repository = NbaAssetRepository();
    final results = await Future.wait<dynamic>([
      repository.loadPlayerProfiles(),
      repository.loadRosters(),
      repository.loadTeams(),
      repository.loadPlayerSeasonStats(),
    ]);

    final players = results[0] as List<PlayerProfile>;
    final rosters = results[1] as List<RosterEntry>;
    final teams = results[2] as List<Team>;
    final rows = const RosterDirectoryService().join(
      rosters: rosters,
      players: players,
      teams: teams,
    );

    return _PlayersPayload(
      players: players,
      rosters: rosters,
      teams: teams,
      stats: results[3] as List<PlayerSeasonStat>,
      rows: rows,
      completeness: const RosterCompletenessService().analyze(rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayersPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(
            child: Text('Loading player directory...', style: TextStyle(color: terminalTextSoft)),
          );
        }
        if (snapshot.hasError) {
          return TerminalCard(
            child: Text('Unable to load player directory: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)),
          );
        }

        final payload = snapshot.data ?? _PlayersPayload.empty();
        final teamById = {for (final team in payload.teams) team.id: team};
        final teamIds = payload.rows.map((row) => row.teamId).toSet().toList()
          ..sort((a, b) => (teamById[a]?.name ?? a).compareTo(teamById[b]?.name ?? b));
        final positions = payload.rows.map((row) => row.position).where((value) => value != '—').toSet().toList()..sort();
        final rows = payload.rows.where(_matchesFilters).toList()..sort(_compareRows);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Players',
              subtitle:
                  'Source-backed player directory for the final 2025-26 NBA roster snapshot. Player and team names open shared profile pages, while every physical, roster, origin, and salary column is sortable.',
            ),
            const SizedBox(height: 22),
            _MetricGrid(
              metrics: [
                _MetricValue('Player Profiles', '${payload.players.length}', 'Connected identity rows'),
                _MetricValue('Final Roster Rows', '${payload.rows.length}', '${payload.completeness.teamsCovered} teams covered'),
                _MetricValue('Visible Players', '${rows.length}', 'After filters'),
                _MetricValue(
                  'Identity Complete',
                  '${(payload.completeness.identityCompletionRate * 100).toStringAsFixed(1)}%',
                  '${payload.completeness.identityIssueCount} open field issues',
                ),
              ],
            ),
            const SizedBox(height: 22),
            _PlayerFilterBar(
              queryChanged: (value) => setState(() => query = value),
              selectedTeam: selectedTeam,
              teamIds: ['All teams', ...teamIds],
              teamLabel: (value) => value == 'All teams' ? value : teamById[value]?.name ?? value,
              teamChanged: (value) => setState(() => selectedTeam = value),
              selectedPosition: selectedPosition,
              positions: ['All positions', ...positions],
              positionChanged: (value) => setState(() => selectedPosition = value),
              selectedCompleteness: selectedCompleteness,
              completenessChanged: (value) => setState(() => selectedCompleteness = value),
            ),
            const SizedBox(height: 22),
            _PlayerDirectoryTable(
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
            _PlayerCoveragePanel(summary: payload.completeness),
            const SizedBox(height: 22),
            _PlayerCommandStageTable(items: playerCommandStageItems),
          ],
        );
      },
    );
  }

  bool _matchesFilters(RosterDirectoryRow row) {
    final normalizedQuery = query.trim().toLowerCase();
    final searchable = [
      row.playerName,
      row.playerId,
      row.teamName,
      row.teamAbbreviation,
      row.entry.jerseyNumber ?? '',
      row.position,
      row.from,
      row.entry.salaryDisplay ?? '',
      row.sourceId,
    ].join(' ').toLowerCase();

    final teamMatch = selectedTeam == 'All teams' || row.teamId == selectedTeam;
    final positionMatch = selectedPosition == 'All positions' || row.position == selectedPosition;
    final completenessMatch = switch (selectedCompleteness) {
      'Identity complete' => _isIdentityComplete(row),
      'Missing From' => row.from == '—',
      'Missing jersey' => row.entry.jerseyNumber == null || row.entry.jerseyNumber!.trim().isEmpty,
      'Missing salary' => row.entry.salaryUsd == null,
      _ => true,
    };

    return (normalizedQuery.isEmpty || searchable.contains(normalizedQuery)) &&
        teamMatch &&
        positionMatch &&
        completenessMatch;
  }

  bool _isIdentityComplete(RosterDirectoryRow row) {
    const measurements = RosterMeasurementFormatter();
    return row.player != null &&
        row.team != null &&
        row.entry.jerseyNumber != null &&
        row.entry.jerseyNumber!.trim().isNotEmpty &&
        row.position != '—' &&
        row.from != '—' &&
        measurements.heightInches(row.entry.height ?? row.player?.height) >= 0 &&
        (row.entry.weightPounds ?? row.player?.weightPounds) != null;
  }

  int _compareRows(RosterDirectoryRow a, RosterDirectoryRow b) {
    const measurements = RosterMeasurementFormatter();
    final result = switch (sort) {
      _PlayerSort.player => a.playerName.compareTo(b.playerName),
      _PlayerSort.team => a.teamName.compareTo(b.teamName),
      _PlayerSort.jersey => measurements.jerseySortValue(a.entry.jerseyNumber).compareTo(measurements.jerseySortValue(b.entry.jerseyNumber)),
      _PlayerSort.position => a.position.compareTo(b.position),
      _PlayerSort.age => (a.entry.age ?? -1).compareTo(b.entry.age ?? -1),
      _PlayerSort.height => measurements.heightInches(a.entry.height ?? a.player?.height).compareTo(measurements.heightInches(b.entry.height ?? b.player?.height)),
      _PlayerSort.weight => (a.entry.weightPounds ?? a.player?.weightPounds ?? -1).compareTo(b.entry.weightPounds ?? b.player?.weightPounds ?? -1),
      _PlayerSort.from => a.from.compareTo(b.from),
      _PlayerSort.salary => (a.entry.salaryUsd ?? -1).compareTo(b.entry.salaryUsd ?? -1),
    };
    return sortAscending ? result : -result;
  }
}

class _PlayersPayload {
  const _PlayersPayload({
    required this.players,
    required this.rosters,
    required this.teams,
    required this.stats,
    required this.rows,
    required this.completeness,
  });

  factory _PlayersPayload.empty() {
    return _PlayersPayload(
      players: const [],
      rosters: const [],
      teams: const [],
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

  final List<PlayerProfile> players;
  final List<RosterEntry> rosters;
  final List<Team> teams;
  final List<PlayerSeasonStat> stats;
  final List<RosterDirectoryRow> rows;
  final RosterCompletenessSummary completeness;
}

class _PlayerFilterBar extends StatelessWidget {
  const _PlayerFilterBar({
    required this.queryChanged,
    required this.selectedTeam,
    required this.teamIds,
    required this.teamLabel,
    required this.teamChanged,
    required this.selectedPosition,
    required this.positions,
    required this.positionChanged,
    required this.selectedCompleteness,
    required this.completenessChanged,
  });

  final ValueChanged<String> queryChanged;
  final String selectedTeam;
  final List<String> teamIds;
  final String Function(String value) teamLabel;
  final ValueChanged<String> teamChanged;
  final String selectedPosition;
  final List<String> positions;
  final ValueChanged<String> positionChanged;
  final String selectedCompleteness;
  final ValueChanged<String> completenessChanged;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final fieldWidth = compact ? constraints.maxWidth : 240.0;
          final searchWidth = compact ? constraints.maxWidth : 390.0;
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
                label: 'Position',
                value: selectedPosition,
                values: positions,
                width: fieldWidth,
                onChanged: positionChanged,
              ),
              TerminalFilterDropdown(
                label: 'Completeness',
                value: selectedCompleteness,
                values: const ['All rows', 'Identity complete', 'Missing From', 'Missing jersey', 'Missing salary'],
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

class _PlayerDirectoryTable extends StatelessWidget {
  const _PlayerDirectoryTable({
    required this.rows,
    required this.stats,
    required this.sort,
    required this.sortAscending,
    required this.onSort,
  });

  final List<RosterDirectoryRow> rows;
  final List<PlayerSeasonStat> stats;
  final _PlayerSort sort;
  final bool sortAscending;
  final void Function(_PlayerSort sort, bool ascending) onSort;
  static const measurements = RosterMeasurementFormatter();

  @override
  Widget build(BuildContext context) {
    final statsByPlayer = <String, int>{};
    for (final stat in stats) {
      statsByPlayer[stat.playerId] = (statsByPlayer[stat.playerId] ?? 0) + 1;
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
                    'Final 2025-26 Player Directory',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${rows.length} players', style: const TextStyle(color: terminalTextMuted)),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No players match the current filters.', style: TextStyle(color: terminalTextSoft)),
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
                  _column('Player', _PlayerSort.player, 0),
                  _column('Team', _PlayerSort.team, 1),
                  _column('No.', _PlayerSort.jersey, 2, numeric: true),
                  _column('Position(s)', _PlayerSort.position, 3),
                  _column('Age', _PlayerSort.age, 4, numeric: true),
                  _column('Height', _PlayerSort.height, 5),
                  _column('Weight', _PlayerSort.weight, 6),
                  _column('From', _PlayerSort.from, 7),
                  _column('Salary', _PlayerSort.salary, 8, numeric: true),
                  const DataColumn(label: Text('Stat Rows'), numeric: true),
                  const DataColumn(label: Text('Source')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 205,
                            child: TextButton(
                              style: _linkStyle(),
                              onPressed: () => openPlayerProfile(context, row.playerId),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(row.playerName, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: TextButton(
                              style: _linkStyle(),
                              onPressed: () => openTeamProfile(context, row.teamId),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(row.teamName, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(row.entry.jerseyNumber ?? '—')),
                        DataCell(Text(row.position)),
                        DataCell(Text(row.entry.age?.toString() ?? '—')),
                        DataCell(Text(measurements.heightLabel(row.entry.height ?? row.player?.height))),
                        DataCell(Text(measurements.weightLabel(row.entry.weightPounds ?? row.player?.weightPounds))),
                        DataCell(SizedBox(width: 160, child: Text(row.from, overflow: TextOverflow.ellipsis))),
                        DataCell(Text(row.entry.salaryDisplay ?? '—')),
                        DataCell(Text('${statsByPlayer[row.playerId] ?? 0}')),
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

  DataColumn _column(String label, _PlayerSort columnSort, int index, {bool numeric = false}) {
    return DataColumn(
      label: Text(label),
      numeric: numeric,
      onSort: (_, ascending) => onSort(columnSort, ascending),
    );
  }

  int _sortColumnIndex(_PlayerSort value) => switch (value) {
        _PlayerSort.player => 0,
        _PlayerSort.team => 1,
        _PlayerSort.jersey => 2,
        _PlayerSort.position => 3,
        _PlayerSort.age => 4,
        _PlayerSort.height => 5,
        _PlayerSort.weight => 6,
        _PlayerSort.from => 7,
        _PlayerSort.salary => 8,
      };

  ButtonStyle _linkStyle() {
    return TextButton.styleFrom(
      foregroundColor: terminalAccent,
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }
}

class _PlayerCoveragePanel extends StatelessWidget {
  const _PlayerCoveragePanel({required this.summary});

  final RosterCompletenessSummary summary;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Roster Metadata Completion', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text(
            'These are completeness gaps, not failed joins. Missing From values should eventually be replaced with a verified college, prior club, or country. Missing salaries remain visibly unknown rather than being estimated.',
            style: TextStyle(color: terminalTextSoft, height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoPill(label: '${summary.missingFrom} missing From'),
              InfoPill(label: '${summary.missingJersey} missing jersey'),
              InfoPill(label: '${summary.missingSalary} missing salary'),
              InfoPill(label: '${summary.invalidHeight} invalid height'),
              InfoPill(label: '${summary.invalidWeight} invalid weight'),
              InfoPill(label: '${summary.missingPlayerJoins + summary.missingTeamJoins} broken joins'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerCommandStageTable extends StatelessWidget {
  const _PlayerCommandStageTable({required this.items});

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
            child: Text('Player Command Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
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

enum _PlayerSort { player, team, jersey, position, age, height, weight, from, salary }

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
