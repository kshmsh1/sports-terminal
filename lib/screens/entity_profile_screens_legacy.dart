import 'package:flutter/material.dart';

import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/game_record.dart';
import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/roster_directory_row.dart';
import '../models/roster_entry.dart';
import '../models/standings_record.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../models/transaction_record.dart';
import '../services/nba_asset_repository.dart';
import '../services/roster_completeness_service.dart';
import '../services/roster_directory_service.dart';
import '../services/roster_measurement_formatter.dart';
import '../widgets/terminal_primitives.dart';

Future<void> openPlayerProfile(BuildContext context, String playerId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerProfileScreen(playerId: playerId),
    ),
  );
}

Future<void> openTeamProfile(BuildContext context, String teamId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TeamProfileScreen(teamId: teamId),
    ),
  );
}

class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({super.key, required this.playerId});

  final String playerId;

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  late final Future<_PlayerProfileBundle> bundleFuture = _loadBundle();

  Future<_PlayerProfileBundle> _loadBundle() async {
    const repository = NbaAssetRepository();
    final results = await Future.wait<dynamic>([
      repository.loadPlayerProfiles(),
      repository.loadTeams(),
      repository.loadRosters(),
      repository.loadPlayerSeasonStats(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadTransactions(),
    ]);

    final players = results[0] as List<PlayerProfile>;
    final teams = results[1] as List<Team>;
    final rosters = results[2] as List<RosterEntry>;
    final stats = results[3] as List<PlayerSeasonStat>;
    final awards = results[4] as List<AwardRecord>;
    final draftPicks = results[5] as List<DraftPick>;
    final transactions = results[6] as List<TransactionRecord>;
    final player = players.where((item) => item.id == widget.playerId).firstOrNull;
    final playerRosters = rosters.where((item) => item.playerId == widget.playerId).toList()
      ..sort((a, b) => b.seasonId.compareTo(a.seasonId));
    final currentRoster = playerRosters.where((item) => item.seasonId == '2025-26').firstOrNull ??
        playerRosters.firstOrNull;
    final currentTeam = currentRoster == null
        ? null
        : teams.where((item) => item.id == currentRoster.teamId).firstOrNull;

    return _PlayerProfileBundle(
      player: player,
      teams: teams,
      rosters: playerRosters,
      currentRoster: currentRoster,
      currentTeam: currentTeam,
      stats: stats.where((item) => item.playerId == widget.playerId).toList(),
      awards: awards.where((item) => item.playerId == widget.playerId).toList(),
      draftPicks: draftPicks
          .where((item) => item.playerId == widget.playerId || item.playerName == player?.displayName)
          .toList(),
      transactions: transactions
          .where((item) => item.playerId == widget.playerId || item.playerName == player?.displayName)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: terminalBackground,
      appBar: AppBar(
        backgroundColor: terminalBackground,
        foregroundColor: Colors.white,
        title: const Text('Player Profile'),
      ),
      body: FutureBuilder<_PlayerProfileBundle>(
        future: bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: terminalAccent));
          }
          if (snapshot.hasError) {
            return _ProfileError(message: 'Unable to load player profile: ${snapshot.error}');
          }
          final bundle = snapshot.data;
          if (bundle == null || bundle.player == null) {
            return _ProfileError(message: 'No player profile exists for ${widget.playerId}.');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _PlayerProfileBody(bundle: bundle),
          );
        },
      ),
    );
  }
}

class _PlayerProfileBody extends StatelessWidget {
  const _PlayerProfileBody({required this.bundle});

  final _PlayerProfileBundle bundle;
  static const measurements = RosterMeasurementFormatter();

  @override
  Widget build(BuildContext context) {
    final player = bundle.player!;
    final roster = bundle.currentRoster;
    final team = bundle.currentTeam;
    final height = roster?.height ?? player.height;
    final weight = roster?.weightPounds ?? player.weightPounds;
    final from = roster?.fromDisplay ?? player.college ?? player.birthCountry;
    final missingCoreFields = [
      roster?.jerseyNumber,
      roster?.position ?? player.position,
      height,
      weight?.toString(),
      from,
    ].where((value) => value == null || value.trim().isEmpty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: player.displayName,
          subtitle:
              'Source-backed player profile shell connected to the final 2025-26 roster snapshot. Statistical, award, draft, and transaction sections activate automatically as those assets are ingested.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            InfoPill(label: roster?.jerseyNumber == null ? 'Jersey pending' : '#${roster!.jerseyNumber}'),
            InfoPill(label: roster?.position ?? player.position ?? 'Position pending'),
            InfoPill(label: roster?.rosterStatus ?? 'Profile connected'),
            InfoPill(label: missingCoreFields == 0 ? 'Core identity complete' : '$missingCoreFields core fields pending'),
          ],
        ),
        const SizedBox(height: 22),
        _MetricGrid(
          metrics: [
            _MetricValue('Age', roster?.age?.toString() ?? '—', 'Final roster snapshot'),
            _MetricValue('Height', measurements.heightLabel(height), 'Imperial + metric'),
            _MetricValue('Weight', measurements.weightLabel(weight), 'Pounds + kilograms'),
            _MetricValue('Salary', roster?.salaryDisplay ?? '—', 'Source snapshot value'),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final identity = _PlayerIdentityCard(
              player: player,
              roster: roster,
              from: from,
            );
            final contextCard = _PlayerContextCard(bundle: bundle);
            if (constraints.maxWidth < 900) {
              return Column(children: [identity, const SizedBox(height: 14), contextCard]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 14),
                Expanded(child: contextCard),
              ],
            );
          },
        ),
        if (team != null) ...[
          const SizedBox(height: 22),
          TerminalCard(
            child: Row(
              children: [
                const Icon(Icons.groups_outlined, color: terminalAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Team', style: TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(team.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('${team.conference} • ${team.division}', style: const TextStyle(color: terminalTextSoft)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => openTeamProfile(context, team.id),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open team'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        _PlayerRosterHistoryTable(rosters: bundle.rosters, teams: bundle.teams),
        const SizedBox(height: 22),
        _PlayerStatsTable(stats: bundle.stats),
        const SizedBox(height: 22),
        _AttachmentReadinessCard(
          title: 'Player Attachment Readiness',
          rows: [
            _AttachmentStatus('Roster history', bundle.rosters.length, 'Connected now'),
            _AttachmentStatus('Season statistics', bundle.stats.length, 'Activates with player-season ingestion'),
            _AttachmentStatus('Awards', bundle.awards.length, 'Activates with award-race ingestion'),
            _AttachmentStatus('Draft records', bundle.draftPicks.length, 'Activates with draft ingestion'),
            _AttachmentStatus('Transactions', bundle.transactions.length, 'Activates with transaction ingestion'),
          ],
        ),
      ],
    );
  }
}

class _PlayerIdentityCard extends StatelessWidget {
  const _PlayerIdentityCard({required this.player, required this.roster, required this.from});

  final PlayerProfile player;
  final RosterEntry? roster;
  final String? from;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Identity'),
          _FactRow('Player ID', player.id),
          _FactRow('First name', player.firstName ?? '—'),
          _FactRow('Last name', player.lastName ?? '—'),
          _FactRow('Position(s)', roster?.position ?? player.position ?? '—'),
          _FactRow('Jersey', roster?.jerseyNumber ?? '—'),
          _FactRow('From', from ?? '—'),
          _FactRow('Birth country', player.birthCountry ?? '—'),
          _FactRow('Active', player.isActive == true ? 'Yes' : player.isActive == false ? 'No' : 'Unknown'),
        ],
      ),
    );
  }
}

class _PlayerContextCard extends StatelessWidget {
  const _PlayerContextCard({required this.bundle});

  final _PlayerProfileBundle bundle;

  @override
  Widget build(BuildContext context) {
    final player = bundle.player!;
    final roster = bundle.currentRoster;
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Snapshot & Source'),
          _FactRow('Season', roster?.seasonId ?? '—'),
          _FactRow('Snapshot', roster?.snapshotLabel ?? '—'),
          _FactRow('Roster status', roster?.rosterStatus ?? '—'),
          _FactRow('Team', bundle.currentTeam?.name ?? roster?.teamId ?? '—'),
          _FactRow('Source ID', roster?.sourceId ?? player.sourceId ?? '—'),
          _FactRow('As of', roster?.asOf ?? player.asOf ?? '—'),
          _FactRow('Contract type', roster?.contractType ?? '—'),
          _FactRow('Salary', roster?.salaryDisplay ?? '—'),
        ],
      ),
    );
  }
}

class _PlayerRosterHistoryTable extends StatelessWidget {
  const _PlayerRosterHistoryTable({required this.rosters, required this.teams});

  final List<RosterEntry> rosters;
  final List<Team> teams;

  @override
  Widget build(BuildContext context) {
    final teamById = {for (final team in teams) team.id: team};
    return _DataSection(
      title: 'Roster History',
      rowCount: rosters.length,
      emptyMessage: 'No roster rows are attached to this player.',
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: const [
          DataColumn(label: Text('Season')),
          DataColumn(label: Text('Team')),
          DataColumn(label: Text('No.')),
          DataColumn(label: Text('Position(s)')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Salary')),
          DataColumn(label: Text('Source')),
        ],
        rows: [
          for (final roster in rosters)
            DataRow(
              cells: [
                DataCell(Text(roster.seasonId)),
                DataCell(
                  TextButton(
                    onPressed: () => openTeamProfile(context, roster.teamId),
                    child: Text(teamById[roster.teamId]?.name ?? roster.teamId),
                  ),
                ),
                DataCell(Text(roster.jerseyNumber ?? '—')),
                DataCell(Text(roster.position ?? '—')),
                DataCell(Text(roster.rosterStatus ?? '—')),
                DataCell(Text(roster.salaryDisplay ?? '—')),
                DataCell(Text(roster.sourceId ?? '—')),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlayerStatsTable extends StatelessWidget {
  const _PlayerStatsTable({required this.stats});

  final List<PlayerSeasonStat> stats;

  @override
  Widget build(BuildContext context) {
    return _DataSection(
      title: 'Season Statistics',
      rowCount: stats.length,
      emptyMessage: 'Player-season statistics have not been ingested yet. This section is wired and will activate without a profile-page redesign.',
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: const [
          DataColumn(label: Text('Season')),
          DataColumn(label: Text('Team')),
          DataColumn(label: Text('GP')),
          DataColumn(label: Text('MPG')),
          DataColumn(label: Text('PPG')),
          DataColumn(label: Text('RPG')),
          DataColumn(label: Text('APG')),
          DataColumn(label: Text('TS%')),
          DataColumn(label: Text('Source')),
        ],
        rows: [
          for (final stat in stats)
            DataRow(
              cells: [
                DataCell(Text(stat.seasonId)),
                DataCell(Text(stat.teamId ?? '—')),
                DataCell(Text(stat.gamesPlayed?.toString() ?? '—')),
                DataCell(Text(_number(stat.minutesPerGame))),
                DataCell(Text(_number(stat.pointsPerGame))),
                DataCell(Text(_number(stat.reboundsPerGame))),
                DataCell(Text(_number(stat.assistsPerGame))),
                DataCell(Text(_percent(stat.trueShootingPercentage))),
                DataCell(Text(stat.sourceId ?? '—')),
              ],
            ),
        ],
      ),
    );
  }
}

class TeamProfileScreen extends StatefulWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  late final Future<_TeamProfileBundle> bundleFuture = _loadBundle();
  _TeamRosterSort sort = _TeamRosterSort.player;
  bool sortAscending = true;

  Future<_TeamProfileBundle> _loadBundle() async {
    const repository = NbaAssetRepository();
    final results = await Future.wait<dynamic>([
      repository.loadTeams(),
      repository.loadPlayerProfiles(),
      repository.loadRosters(),
      repository.loadTeamSeasonStats(),
      repository.loadStandings(),
      repository.loadGames(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadTransactions(),
    ]);

    final teams = results[0] as List<Team>;
    final players = results[1] as List<PlayerProfile>;
    final rosters = results[2] as List<RosterEntry>;
    final joined = const RosterDirectoryService().join(
      rosters: rosters,
      players: players,
      teams: teams,
    );

    return _TeamProfileBundle(
      team: teams.where((item) => item.id == widget.teamId).firstOrNull,
      rosterRows: joined
          .where((item) => item.teamId == widget.teamId && item.entry.seasonId == '2025-26')
          .toList(),
      stats: (results[3] as List<TeamSeasonStat>)
          .where((item) => item.teamId == widget.teamId)
          .toList(),
      standings: (results[4] as List<StandingsRecord>)
          .where((item) => item.teamId == widget.teamId)
          .toList(),
      games: (results[5] as List<GameRecord>)
          .where((item) => item.homeTeamId == widget.teamId || item.awayTeamId == widget.teamId)
          .toList(),
      awards: (results[6] as List<AwardRecord>)
          .where((item) => item.teamId == widget.teamId)
          .toList(),
      draftPicks: (results[7] as List<DraftPick>)
          .where((item) => item.teamId == widget.teamId)
          .toList(),
      transactions: (results[8] as List<TransactionRecord>)
          .where((item) => item.fromTeamId == widget.teamId || item.toTeamId == widget.teamId)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: terminalBackground,
      appBar: AppBar(
        backgroundColor: terminalBackground,
        foregroundColor: Colors.white,
        title: const Text('Team Profile'),
      ),
      body: FutureBuilder<_TeamProfileBundle>(
        future: bundleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: terminalAccent));
          }
          if (snapshot.hasError) {
            return _ProfileError(message: 'Unable to load team profile: ${snapshot.error}');
          }
          final bundle = snapshot.data;
          if (bundle == null || bundle.team == null) {
            return _ProfileError(message: 'No team profile exists for ${widget.teamId}.');
          }

          final rows = [...bundle.rosterRows]..sort(_compareRows);
          final completeness = const RosterCompletenessService().analyze(bundle.rosterRows);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _TeamProfileBody(
              bundle: bundle,
              rows: rows,
              completeness: completeness,
              sort: sort,
              sortAscending: sortAscending,
              onSort: (nextSort, ascending) {
                setState(() {
                  sort = nextSort;
                  sortAscending = ascending;
                });
              },
            ),
          );
        },
      ),
    );
  }

  int _compareRows(RosterDirectoryRow a, RosterDirectoryRow b) {
    const measurements = RosterMeasurementFormatter();
    final result = switch (sort) {
      _TeamRosterSort.player => a.playerName.compareTo(b.playerName),
      _TeamRosterSort.jersey => measurements.jerseySortValue(a.entry.jerseyNumber).compareTo(measurements.jerseySortValue(b.entry.jerseyNumber)),
      _TeamRosterSort.position => a.position.compareTo(b.position),
      _TeamRosterSort.age => (a.entry.age ?? -1).compareTo(b.entry.age ?? -1),
      _TeamRosterSort.height => measurements.heightInches(a.entry.height ?? a.player?.height).compareTo(measurements.heightInches(b.entry.height ?? b.player?.height)),
      _TeamRosterSort.weight => (a.entry.weightPounds ?? a.player?.weightPounds ?? -1).compareTo(b.entry.weightPounds ?? b.player?.weightPounds ?? -1),
      _TeamRosterSort.from => a.from.compareTo(b.from),
      _TeamRosterSort.salary => (a.entry.salaryUsd ?? -1).compareTo(b.entry.salaryUsd ?? -1),
    };
    return sortAscending ? result : -result;
  }
}

class _TeamProfileBody extends StatelessWidget {
  const _TeamProfileBody({
    required this.bundle,
    required this.rows,
    required this.completeness,
    required this.sort,
    required this.sortAscending,
    required this.onSort,
  });

  final _TeamProfileBundle bundle;
  final List<RosterDirectoryRow> rows;
  final RosterCompletenessSummary completeness;
  final _TeamRosterSort sort;
  final bool sortAscending;
  final void Function(_TeamRosterSort sort, bool ascending) onSort;

  @override
  Widget build(BuildContext context) {
    final team = bundle.team!;
    final averageAge = rows.isEmpty
        ? null
        : rows.where((row) => row.entry.age != null).fold<int>(0, (sum, row) => sum + row.entry.age!) /
            rows.where((row) => row.entry.age != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: team.name,
          subtitle:
              'Team profile connected to the final 2025-26 roster snapshot, player profile routes, roster quality, and future team-season statistics, standings, games, awards, draft, and transaction layers.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            InfoPill(label: team.abbreviation),
            InfoPill(label: team.conference),
            InfoPill(label: team.division),
            InfoPill(label: '${rows.length} final roster players'),
          ],
        ),
        const SizedBox(height: 22),
        _MetricGrid(
          metrics: [
            _MetricValue('Roster', '${rows.length}', '2025-26 final snapshot'),
            _MetricValue('Average Age', averageAge == null || averageAge.isNaN ? '—' : averageAge.toStringAsFixed(1), 'Known roster ages'),
            _MetricValue('Known Payroll', _money(completeness.knownPayrollUsd), 'Missing salaries excluded'),
            _MetricValue('Identity Complete', '${(completeness.identityCompletionRate * 100).toStringAsFixed(1)}%', '${completeness.identityIssueCount} open identity issues'),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final identity = TerminalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle('Team Identity'),
                  _FactRow('Team ID', team.id),
                  _FactRow('Name', team.name),
                  _FactRow('Abbreviation', team.abbreviation),
                  _FactRow('City', team.city),
                  _FactRow('Conference', team.conference),
                  _FactRow('Division', team.division),
                ],
              ),
            );
            final readiness = _AttachmentReadinessCard(
              title: 'Team Attachment Readiness',
              rows: [
                _AttachmentStatus('Final roster', rows.length, 'Connected now'),
                _AttachmentStatus('Team season stats', bundle.stats.length, 'Activates with team-stat ingestion'),
                _AttachmentStatus('Standings', bundle.standings.length, 'Activates with standings ingestion'),
                _AttachmentStatus('Games', bundle.games.length, 'Activates with game ingestion'),
                _AttachmentStatus('Awards', bundle.awards.length, 'Activates with awards ingestion'),
                _AttachmentStatus('Draft picks', bundle.draftPicks.length, 'Activates with draft ingestion'),
                _AttachmentStatus('Transactions', bundle.transactions.length, 'Activates with transaction ingestion'),
              ],
            );
            if (constraints.maxWidth < 900) {
              return Column(children: [identity, const SizedBox(height: 14), readiness]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 14),
                Expanded(child: readiness),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _TeamRosterTable(
          rows: rows,
          sort: sort,
          sortAscending: sortAscending,
          onSort: onSort,
        ),
        const SizedBox(height: 22),
        _TeamStatsTable(stats: bundle.stats),
      ],
    );
  }
}

class _TeamRosterTable extends StatelessWidget {
  const _TeamRosterTable({
    required this.rows,
    required this.sort,
    required this.sortAscending,
    required this.onSort,
  });

  final List<RosterDirectoryRow> rows;
  final _TeamRosterSort sort;
  final bool sortAscending;
  final void Function(_TeamRosterSort sort, bool ascending) onSort;
  static const measurements = RosterMeasurementFormatter();

  @override
  Widget build(BuildContext context) {
    return _DataSection(
      title: 'Final 2025-26 Roster',
      rowCount: rows.length,
      emptyMessage: 'No final roster rows are attached to this team.',
      child: DataTable(
        sortColumnIndex: _sortColumnIndex(sort),
        sortAscending: sortAscending,
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: [
          _column('Player', _TeamRosterSort.player, 0),
          _column('No.', _TeamRosterSort.jersey, 1, numeric: true),
          _column('Position(s)', _TeamRosterSort.position, 2),
          _column('Age', _TeamRosterSort.age, 3, numeric: true),
          _column('Height', _TeamRosterSort.height, 4),
          _column('Weight', _TeamRosterSort.weight, 5),
          _column('From', _TeamRosterSort.from, 6),
          _column('Salary', _TeamRosterSort.salary, 7, numeric: true),
          const DataColumn(label: Text('Source')),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(
                  TextButton(
                    onPressed: () => openPlayerProfile(context, row.playerId),
                    child: Text(row.playerName),
                  ),
                ),
                DataCell(Text(row.entry.jerseyNumber ?? '—')),
                DataCell(Text(row.position)),
                DataCell(Text(row.entry.age?.toString() ?? '—')),
                DataCell(Text(measurements.heightLabel(row.entry.height ?? row.player?.height))),
                DataCell(Text(measurements.weightLabel(row.entry.weightPounds ?? row.player?.weightPounds))),
                DataCell(Text(row.from)),
                DataCell(Text(row.entry.salaryDisplay ?? '—')),
                DataCell(Text(row.sourceId)),
              ],
            ),
        ],
      ),
    );
  }

  DataColumn _column(String label, _TeamRosterSort value, int index, {bool numeric = false}) {
    return DataColumn(
      label: Text(label),
      numeric: numeric,
      onSort: (_, ascending) => onSort(value, ascending),
    );
  }

  int _sortColumnIndex(_TeamRosterSort value) => switch (value) {
        _TeamRosterSort.player => 0,
        _TeamRosterSort.jersey => 1,
        _TeamRosterSort.position => 2,
        _TeamRosterSort.age => 3,
        _TeamRosterSort.height => 4,
        _TeamRosterSort.weight => 5,
        _TeamRosterSort.from => 6,
        _TeamRosterSort.salary => 7,
      };
}

class _TeamStatsTable extends StatelessWidget {
  const _TeamStatsTable({required this.stats});

  final List<TeamSeasonStat> stats;

  @override
  Widget build(BuildContext context) {
    return _DataSection(
      title: 'Team Season Statistics',
      rowCount: stats.length,
      emptyMessage: 'Team-season statistics have not been ingested yet. This section is already wired to the team profile.',
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: const [
          DataColumn(label: Text('Season')),
          DataColumn(label: Text('W')),
          DataColumn(label: Text('L')),
          DataColumn(label: Text('PPG')),
          DataColumn(label: Text('Pace')),
          DataColumn(label: Text('ORtg')),
          DataColumn(label: Text('DRtg')),
          DataColumn(label: Text('Net')),
          DataColumn(label: Text('Source')),
        ],
        rows: [
          for (final stat in stats)
            DataRow(
              cells: [
                DataCell(Text(stat.seasonId)),
                DataCell(Text(stat.wins?.toString() ?? '—')),
                DataCell(Text(stat.losses?.toString() ?? '—')),
                DataCell(Text(_number(stat.pointsPerGame))),
                DataCell(Text(_number(stat.pace))),
                DataCell(Text(_number(stat.offensiveRating))),
                DataCell(Text(_number(stat.defensiveRating))),
                DataCell(Text(_number(stat.netRating))),
                DataCell(Text(stat.sourceId ?? '—')),
              ],
            ),
        ],
      ),
    );
  }
}

enum _TeamRosterSort { player, jersey, position, age, height, weight, from, salary }

class _PlayerProfileBundle {
  const _PlayerProfileBundle({
    required this.player,
    required this.teams,
    required this.rosters,
    required this.currentRoster,
    required this.currentTeam,
    required this.stats,
    required this.awards,
    required this.draftPicks,
    required this.transactions,
  });

  final PlayerProfile? player;
  final List<Team> teams;
  final List<RosterEntry> rosters;
  final RosterEntry? currentRoster;
  final Team? currentTeam;
  final List<PlayerSeasonStat> stats;
  final List<AwardRecord> awards;
  final List<DraftPick> draftPicks;
  final List<TransactionRecord> transactions;
}

class _TeamProfileBundle {
  const _TeamProfileBundle({
    required this.team,
    required this.rosterRows,
    required this.stats,
    required this.standings,
    required this.games,
    required this.awards,
    required this.draftPicks,
    required this.transactions,
  });

  final Team? team;
  final List<RosterDirectoryRow> rosterRows;
  final List<TeamSeasonStat> stats;
  final List<StandingsRecord> standings;
  final List<GameRecord> games;
  final List<AwardRecord> awards;
  final List<DraftPick> draftPicks;
  final List<TransactionRecord> transactions;
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
        final columns = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 560 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.1 : columns == 2 ? 2.0 : 1.85,
          children: [
            for (final metric in metrics)
              TerminalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(metric.label, style: const TextStyle(color: terminalTextMuted, fontSize: 12)),
                    Text(
                      metric.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
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

class _AttachmentStatus {
  const _AttachmentStatus(this.label, this.rows, this.detail);

  final String label;
  final int rows;
  final String detail;
}

class _AttachmentReadinessCard extends StatelessWidget {
  const _AttachmentReadinessCard({required this.title, required this.rows});

  final String title;
  final List<_AttachmentStatus> rows;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(title),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 145,
                    child: Text(row.label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${row.rows}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                  Expanded(child: Text(row.detail, style: const TextStyle(color: terminalTextSoft, fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection({
    required this.title,
    required this.rowCount,
    required this.emptyMessage,
    required this.child,
  });

  final String title;
  final int rowCount;
  final String emptyMessage;
  final Widget child;

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
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$rowCount rows', style: const TextStyle(color: terminalTextMuted)),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          if (rowCount == 0)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(emptyMessage, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
            )
          else
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3))),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TerminalCard(
          child: Text(message, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
        ),
      ),
    );
  }
}

String _number(double? value) => value == null ? '—' : value.toStringAsFixed(1);
String _percent(double? value) => value == null ? '—' : '${(value * 100).toStringAsFixed(1)}%';
String _money(int value) {
  final formatted = value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
  return '\$$formatted';
}
