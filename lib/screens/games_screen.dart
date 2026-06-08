import 'package:flutter/material.dart';

import '../data/workspace_build_items.dart';
import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/game_record.dart';
import '../models/player_profile.dart';
import '../models/roster_entry.dart';
import '../models/team.dart';
import '../models/transaction_record.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<GameRecord>(
      title: 'Games',
      subtitle: 'Game command center for schedules, results, box-score hooks, player game logs, team game logs, matchup context, playoff games, and future trend charts.',
      items: gameWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadGames,
      recordLabel: 'Game Records',
      emptyTitle: 'Game Records Source Pending',
      emptyBody: 'The game records asset is connected and empty. Once schedule, result, and box-score sources are approved, this page becomes the bridge between teams, seasons, playoffs, player game logs, reports, and charts.',
      columns: const ['Game', 'Date', 'Season', 'Type', 'Away', 'Home', 'Score', 'Arena', 'Source'],
      rowBuilder: (game) => [game.id, game.gameDate ?? '—', game.seasonId, game.seasonType ?? '—', game.awayTeamId ?? '—', game.homeTeamId ?? '—', _score(game), game.arena ?? '—', game.sourceId ?? '—'],
      recordKey: (game) => game.id,
      factBuilder: (game) => [_RecordFact('Game ID', game.id), _RecordFact('Season', game.seasonId), _RecordFact('Season Type', game.seasonType ?? '—'), _RecordFact('Date', game.gameDate ?? '—'), _RecordFact('Away Team', game.awayTeamId ?? '—'), _RecordFact('Home Team', game.homeTeamId ?? '—'), _RecordFact('Score', _score(game)), _RecordFact('Arena / City', '${game.arena ?? '—'} / ${game.city ?? '—'}'), _RecordFact('Source', game.sourceId ?? 'Source pending'), _RecordFact('asOf', game.asOf ?? '—')],
      activationSteps: const [_ActivationStep('Schedule backbone', 'Add date, season, home team, away team, arena, city, and season type.'), _ActivationStep('Result layer', 'Add scores, status, overtime flags, and source metadata.'), _ActivationStep('Box-score layer', 'Attach player game stats and team game stats after season stats are stable.'), _ActivationStep('Playoff linkage', 'Connect series, game number, series score, round, seeds, and bracket context.'), _ActivationStep('Chart layer', 'Use game rows to power within-season player and team trend charts.')],
      leadTitle: 'Game Center Principle',
      leadBody: 'Games should become the bridge between season summaries and granular player/team performance. The MVP starts with schedules and results, then grows into box scores, game logs, matchup pages, playoff detail, and finance-style stat trend charts.',
    );
  }

  static String _score(GameRecord game) => game.awayScore == null || game.homeScore == null ? '—' : '${game.awayScore}-${game.homeScore}';
}

class RostersScreen extends StatefulWidget {
  const RostersScreen({super.key});

  @override
  State<RostersScreen> createState() => _RostersScreenState();
}

class _RostersScreenState extends State<RostersScreen> {
  late final Future<_RosterPayload> payloadFuture = _loadPayload();
  String query = '';
  String selectedTeamId = 'All teams';
  _RosterSort sort = _RosterSort.team;
  bool sortAscending = true;

  Future<_RosterPayload> _loadPayload() async {
    final repository = const NbaAssetRepository();
    final results = await Future.wait<dynamic>([
      repository.loadRosters(),
      repository.loadPlayerProfiles(),
      repository.loadTeams(),
    ]);
    return _RosterPayload(
      rosters: results[0] as List<RosterEntry>,
      players: results[1] as List<PlayerProfile>,
      teams: results[2] as List<Team>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RosterPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading final roster workspace...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load final roster workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final payload = snapshot.data ?? const _RosterPayload(rosters: [], players: [], teams: []);
        final playerById = {for (final player in payload.players) player.id: player};
        final teamById = {for (final team in payload.teams) team.id: team};
        final rows = payload.rosters.map((entry) => _RosterRow(entry: entry, player: playerById[entry.playerId], team: teamById[entry.teamId])).where(_matchesFilters).toList();
        rows.sort(_compareRows);
        final importedTeamIds = payload.rosters.map((entry) => entry.teamId).toSet();
        final teamOptions = payload.teams.where((team) => importedTeamIds.contains(team.id)).toList()..sort((a, b) => a.name.compareTo(b.name));
        final sourced = payload.rosters.where((entry) => entry.sourceId != null && entry.sourceId!.trim().isNotEmpty).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Rosters', subtitle: 'Final 2025-26 NBA roster workspace. Player names and team names are clickable, tables are sortable, and every row preserves the screenshot-backed roster snapshot used before live data ingestion.'),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
              _WorkspaceMetric(label: 'Roster Rows', value: '${payload.rosters.length}', detail: 'Final 2025-26 snapshot'),
              _WorkspaceMetric(label: 'Teams Covered', value: '${importedTeamIds.length} / ${payload.teams.length}', detail: importedTeamIds.length == payload.teams.length ? 'All teams staged' : 'Coverage incomplete'),
              _WorkspaceMetric(label: 'Visible Rows', value: '${rows.length}', detail: 'After filters'),
              _WorkspaceMetric(label: 'Sourced Rows', value: '$sourced', detail: 'Manual screenshot source'),
            ]);
          }),
          const SizedBox(height: 22),
          TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Final Roster Contract', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            Text('These rows are identified as the final rosters at the end of the 2025-2026 NBA season. The page is intentionally usable before full stats ingestion: it supports player/team profile stubs, height and weight conversions, sortable columns, source metadata, jersey number, position, salary, and From context.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
            SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '2025-26 final roster'), InfoPill(label: 'Clickable players'), InfoPill(label: 'Clickable teams'), InfoPill(label: 'Sortable physicals'), InfoPill(label: 'Source-backed seed')]),
          ])),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search player, team, jersey, position, from...'))),
            _FilterDropdown(label: 'Team', value: selectedTeamId, values: ['All teams', ...teamOptions.map((team) => team.id)], displayBuilder: (value) => value == 'All teams' ? value : teamById[value]?.name ?? value, onChanged: (value) => setState(() => selectedTeamId = value)),
          ])),
          const SizedBox(height: 22),
          payload.rosters.isEmpty ? const _EmptyAssetPanel(title: 'Roster Source Pending', body: 'The roster entries asset is connected and empty. Once roster snapshots are approved, this page connects players, teams, seasons, contracts, transactions, and profile routes.') : _RosterTable(rows: rows, sort: sort, sortAscending: sortAscending, onSort: _setSort),
          const SizedBox(height: 22),
          _BuildMap(title: 'Rosters', items: rosterWorkspaceItems),
        ]);
      },
    );
  }

  bool _matchesFilters(_RosterRow row) {
    final q = query.trim().toLowerCase();
    final values = [
      row.playerName,
      row.teamName,
      row.teamAbbreviation,
      row.entry.jerseyNumber ?? '',
      row.entry.position ?? '',
      row.entry.college ?? '',
      row.entry.salaryDisplay ?? '',
      row.entry.sourceId ?? '',
    ].join(' ').toLowerCase();
    return (selectedTeamId == 'All teams' || row.entry.teamId == selectedTeamId) && (q.isEmpty || values.contains(q));
  }

  void _setSort(_RosterSort nextSort, bool ascending) {
    setState(() {
      if (sort == nextSort) {
        sortAscending = ascending;
      } else {
        sort = nextSort;
        sortAscending = true;
      }
    });
  }

  int _compareRows(_RosterRow a, _RosterRow b) {
    final result = switch (sort) {
      _RosterSort.player => a.playerName.compareTo(b.playerName),
      _RosterSort.team => a.teamName.compareTo(b.teamName),
      _RosterSort.jersey => _jerseyNumber(a.entry).compareTo(_jerseyNumber(b.entry)),
      _RosterSort.position => (a.entry.position ?? '').compareTo(b.entry.position ?? ''),
      _RosterSort.age => (a.entry.age ?? -1).compareTo(b.entry.age ?? -1),
      _RosterSort.height => _heightInches(a.entry.height).compareTo(_heightInches(b.entry.height)),
      _RosterSort.weight => (a.entry.weightPounds ?? -1).compareTo(b.entry.weightPounds ?? -1),
      _RosterSort.from => (a.entry.college ?? '').compareTo(b.entry.college ?? ''),
      _RosterSort.salary => (a.entry.salaryUsd ?? -1).compareTo(b.entry.salaryUsd ?? -1),
    };
    return sortAscending ? result : -result;
  }
}

class _RosterPayload {
  const _RosterPayload({required this.rosters, required this.players, required this.teams});
  final List<RosterEntry> rosters;
  final List<PlayerProfile> players;
  final List<Team> teams;
}

class _RosterRow {
  const _RosterRow({required this.entry, required this.player, required this.team});
  final RosterEntry entry;
  final PlayerProfile? player;
  final Team? team;
  String get playerName => player?.displayName ?? entry.playerId;
  String get teamName => team?.name ?? entry.teamId;
  String get teamAbbreviation => team?.abbreviation ?? entry.teamId;
}

enum _RosterSort { player, team, jersey, position, age, height, weight, from, salary }

class _RosterTable extends StatelessWidget {
  const _RosterTable({required this.rows, required this.sort, required this.sortAscending, required this.onSort});
  final List<_RosterRow> rows;
  final _RosterSort sort;
  final bool sortAscending;
  final void Function(_RosterSort sort, bool ascending) onSort;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Final 2025-26 Roster Table', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${rows.length} rows', style: const TextStyle(color: terminalTextMuted))])),
      const Divider(height: 1, color: terminalBorder),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        sortColumnIndex: _sortColumnIndex(sort),
        sortAscending: sortAscending,
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columnSpacing: 28,
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
            DataRow(cells: [
              DataCell(SizedBox(width: 210, child: TextButton(style: _linkButtonStyle(), onPressed: row.player == null ? null : () => _openPlayer(context, row), child: Align(alignment: Alignment.centerLeft, child: Text(row.playerName, overflow: TextOverflow.ellipsis))))),
              DataCell(SizedBox(width: 190, child: TextButton(style: _linkButtonStyle(), onPressed: row.team == null ? null : () => _openTeam(context, row), child: Align(alignment: Alignment.centerLeft, child: Text(row.teamName, overflow: TextOverflow.ellipsis))))),
              DataCell(Text(row.entry.seasonId)),
              DataCell(Text(row.entry.jerseyNumber ?? '—')),
              DataCell(Text(row.entry.position ?? '—')),
              DataCell(Text(row.entry.age?.toString() ?? '—')),
              DataCell(Text(_heightLabel(row.entry.height))),
              DataCell(Text(_weightLabel(row.entry.weightPounds))),
              DataCell(SizedBox(width: 170, child: Text(row.entry.college ?? '—', overflow: TextOverflow.ellipsis))),
              DataCell(Text(row.entry.salaryDisplay ?? '—')),
              DataCell(InfoPill(label: row.entry.rosterStatus ?? 'Final roster')),
              DataCell(SizedBox(width: 230, child: Text(row.entry.sourceId ?? '—', overflow: TextOverflow.ellipsis))),
            ]),
        ],
      )),
    ]));
  }

  DataColumn _column(String label, _RosterSort columnSort, int index, {bool numeric = false}) {
    return DataColumn(label: Text(label), numeric: numeric, onSort: (_, ascending) => onSort(columnSort, ascending));
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

  static ButtonStyle _linkButtonStyle() => TextButton.styleFrom(foregroundColor: terminalAccent, padding: EdgeInsets.zero, alignment: Alignment.centerLeft, textStyle: const TextStyle(fontWeight: FontWeight.w800));

  static void _openPlayer(BuildContext context, _RosterRow row) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PlayerProfileStub(row: row)));
  }

  static void _openTeam(BuildContext context, _RosterRow row) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _TeamProfileStub(row: row)));
  }
}

class _PlayerProfileStub extends StatelessWidget {
  const _PlayerProfileStub({required this.row});
  final _RosterRow row;
  @override
  Widget build(BuildContext context) {
    final player = row.player;
    return Scaffold(backgroundColor: terminalBackground, appBar: AppBar(backgroundColor: terminalBackground, foregroundColor: Colors.white, title: Text(player?.displayName ?? row.entry.playerId)), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title: player?.displayName ?? row.entry.playerId, subtitle: 'Incomplete player profile shell. This route proves that roster rows can open stable player pages before full stat ingestion.'),
      const SizedBox(height: 22),
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Profile Snapshot', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _FactLine(label: 'Player ID', value: row.entry.playerId),
        _FactLine(label: 'Team', value: row.teamName),
        _FactLine(label: 'Season', value: row.entry.seasonId),
        _FactLine(label: 'Jersey', value: row.entry.jerseyNumber ?? '—'),
        _FactLine(label: 'Position(s)', value: row.entry.position ?? '—'),
        _FactLine(label: 'Height', value: _heightLabel(row.entry.height)),
        _FactLine(label: 'Weight', value: _weightLabel(row.entry.weightPounds)),
        _FactLine(label: 'From', value: row.entry.college ?? '—'),
        _FactLine(label: 'Salary', value: row.entry.salaryDisplay ?? '—'),
        _FactLine(label: 'Source', value: row.entry.sourceId ?? '—'),
      ])),
    ])));
  }
}

class _TeamProfileStub extends StatelessWidget {
  const _TeamProfileStub({required this.row});
  final _RosterRow row;
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: terminalBackground, appBar: AppBar(backgroundColor: terminalBackground, foregroundColor: Colors.white, title: Text(row.teamName)), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title: row.teamName, subtitle: 'Incomplete team profile shell. This route proves that every roster row can open a stable team page before standings, games, and full team stat ingestion.'),
      const SizedBox(height: 22),
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Team Snapshot', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _FactLine(label: 'Team ID', value: row.entry.teamId),
        _FactLine(label: 'Abbreviation', value: row.teamAbbreviation),
        _FactLine(label: 'Conference', value: row.team?.conference ?? '—'),
        _FactLine(label: 'Division', value: row.team?.division ?? '—'),
        _FactLine(label: 'Roster Season', value: row.entry.seasonId),
        _FactLine(label: 'Snapshot Type', value: '2025-26 final roster'),
        _FactLine(label: 'Source', value: row.entry.sourceId ?? '—'),
      ])),
    ])));
  }
}

int _jerseyNumber(RosterEntry entry) => int.tryParse(entry.jerseyNumber ?? '') ?? 999;
int _heightInches(String? height) {
  if (height == null) return -1;
  final match = RegExp(r"(\d+)'\s*(\d+)").firstMatch(height);
  if (match == null) return -1;
  return int.parse(match.group(1)!) * 12 + int.parse(match.group(2)!);
}

String _heightLabel(String? height) {
  final inches = _heightInches(height);
  if (height == null || inches < 0) return '—';
  return '$height (${(inches * 0.0254).toStringAsFixed(2)} m)';
}

String _weightLabel(int? pounds) {
  if (pounds == null) return '—';
  return '$pounds lbs (${(pounds * 0.45359237).toStringAsFixed(1)} kg)';
}

class AwardsScreen extends StatelessWidget {
  const AwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<AwardRecord>(
      title: 'Awards',
      subtitle: 'Awards command center for winners, runners-up, finalists, voting ranks, vote shares, first-place votes, points, season context, player links, team links, and award-race history.',
      items: awardWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadAwards,
      recordLabel: 'Award Race Records',
      emptyTitle: 'Awards Source Pending',
      emptyBody: 'The awards asset is connected and empty. The target is not just winners. The model already supports rank, first-place votes, points, and share, so awards can become full race boards once voting rows are sourced.',
      columns: const ['Award', 'Season', 'Player', 'Team', 'Rank', '1st Votes', 'Points', 'Share', 'Source'],
      rowBuilder: (award) => [award.awardName, award.seasonId, award.playerId ?? '—', award.teamId ?? '—', award.rank?.toString() ?? '—', award.votesFirstPlace?.toString() ?? '—', award.points?.toStringAsFixed(1) ?? '—', award.share?.toStringAsFixed(3) ?? '—', award.sourceId ?? '—'],
      recordKey: (award) => award.id,
      factBuilder: (award) => [_RecordFact('Award', award.awardName), _RecordFact('Season', award.seasonId), _RecordFact('Player ID', award.playerId ?? '—'), _RecordFact('Team ID', award.teamId ?? '—'), _RecordFact('Race Rank', award.rank?.toString() ?? 'Winner/finalist rank pending'), _RecordFact('First-Place Votes', award.votesFirstPlace?.toString() ?? '—'), _RecordFact('Voting Points', award.points?.toStringAsFixed(1) ?? '—'), _RecordFact('Vote Share', award.share?.toStringAsFixed(3) ?? '—'), _RecordFact('Source', award.sourceId ?? 'Source pending'), _RecordFact('asOf', award.asOf ?? '—')],
      activationSteps: const [_ActivationStep('Winner records', 'Load major award winners by season, player, team, and source.'), _ActivationStep('Race records', 'Load runners-up, finalists, rank, vote points, first-place votes, and vote share.'), _ActivationStep('Season boards', 'Show each season’s major award races and voting context.'), _ActivationStep('Player award profile', 'Attach wins, finalist finishes, vote shares, and award history to player pages.'), _ActivationStep('Context joins', 'Attach stats, standings, team record, games played, and playoff context to each race.')],
      leadTitle: 'Award Race Principle',
      leadBody: 'Awards should preserve the full race, not only the winner. The end platform should show who won, who finished behind, how votes broke down, what team context mattered, and how each race links back to player, team, season, compare, and reports.',
    );
  }
}

class DraftScreen extends StatelessWidget {
  const DraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<DraftPick>(
      title: 'Draft',
      subtitle: 'Draft command center for draft classes, picks, team draft history, player identity links, school/club context, international context, development outcomes, and franchise-building analysis.',
      items: draftWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadDraftPicks,
      recordLabel: 'Draft Picks',
      emptyTitle: 'Draft Source Pending',
      emptyBody: 'The draft picks asset is connected and empty. Once historical draft records are approved, this page will connect draft years, teams, players, schools, countries, outcomes, development pathways, and long-run value.',
      columns: const ['Year', 'Round', 'Pick', 'Team', 'Player', 'School/Club', 'Country', 'Source'],
      rowBuilder: (pick) => [pick.draftYear.toString(), pick.round?.toString() ?? '—', pick.pickNumber?.toString() ?? '—', pick.teamId ?? '—', pick.playerName ?? pick.playerId ?? '—', pick.schoolOrClub ?? '—', pick.country ?? '—', pick.sourceId ?? '—'],
      recordKey: (pick) => pick.id,
      factBuilder: (pick) => [_RecordFact('Draft Year', pick.draftYear.toString()), _RecordFact('Round', pick.round?.toString() ?? '—'), _RecordFact('Pick Number', pick.pickNumber?.toString() ?? '—'), _RecordFact('Team ID', pick.teamId ?? '—'), _RecordFact('Player', pick.playerName ?? pick.playerId ?? '—'), _RecordFact('Player ID', pick.playerId ?? 'Identity link pending'), _RecordFact('School / Club', pick.schoolOrClub ?? '—'), _RecordFact('Country', pick.country ?? '—'), _RecordFact('Source', pick.sourceId ?? '—'), _RecordFact('asOf', pick.asOf ?? '—')],
      activationSteps: const [_ActivationStep('Draft board', 'Load year, round, pick, team, player, school/club, country, and source metadata.'), _ActivationStep('Player identity join', 'Attach drafted players to player profiles.'), _ActivationStep('Outcome layer', 'Connect picks to rookie season, career stats, awards, transactions, and team tenure.'), _ActivationStep('Team strategy', 'Summarize team draft history, positional focus, hit rate, and retained value.'), _ActivationStep('Development path', 'Connect G League assignments, roster windows, and player progression.')],
      leadTitle: 'Draft Intelligence Principle',
      leadBody: 'Draft history should connect player identity, team-building, franchise eras, G League development, prospect outcomes, awards, rosters, transactions, and long-term value. The MVP starts with pick records, then builds outcome intelligence around them.',
    );
  }
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<TransactionRecord>(
      title: 'Transactions',
      subtitle: 'Transaction command center for trades, signings, waivers, assignments, recalls, contract events, player movement, roster changes, team-building history, and timeline reports.',
      items: transactionWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadTransactions,
      recordLabel: 'Transaction Records',
      emptyTitle: 'Transactions Source Pending',
      emptyBody: 'The transaction asset is connected and empty. Once a transaction source is selected, this page will become the movement graph connecting players, rosters, teams, contracts, draft assets, G League movement, and reports.',
      columns: const ['Date', 'Type', 'Player', 'From', 'To', 'Description', 'Source', 'asOf'],
      rowBuilder: (tx) => [tx.date ?? '—', tx.transactionType ?? '—', tx.playerName ?? tx.playerId ?? '—', tx.fromTeamId ?? '—', tx.toTeamId ?? '—', tx.description ?? '—', tx.sourceId ?? '—', tx.asOf ?? '—'],
      recordKey: (tx) => tx.id,
      factBuilder: (tx) => [_RecordFact('Transaction ID', tx.id), _RecordFact('Date', tx.date ?? '—'), _RecordFact('Type', tx.transactionType ?? '—'), _RecordFact('Player', tx.playerName ?? tx.playerId ?? '—'), _RecordFact('Player ID', tx.playerId ?? 'Identity link pending'), _RecordFact('From Team', tx.fromTeamId ?? '—'), _RecordFact('To Team', tx.toTeamId ?? '—'), _RecordFact('Description', tx.description ?? '—'), _RecordFact('Source', tx.sourceId ?? 'Source pending'), _RecordFact('asOf', tx.asOf ?? '—')],
      activationSteps: const [_ActivationStep('Movement event', 'Load date, type, player, from team, to team, description, and source metadata.'), _ActivationStep('Roster effect', 'Connect each movement event to roster windows and team-season pages.'), _ActivationStep('Trade tree', 'Later connect multi-player trades, picks, protections, cash, exceptions, and outcomes.'), _ActivationStep('Contract context', 'Connect signings, extensions, waivers, and option decisions to contracts.'), _ActivationStep('Timeline reports', 'Generate player movement timelines, team transaction histories, and franchise-building reports.')],
      leadTitle: 'Transaction Graph Principle',
      leadBody: 'Transactions are relationship events that change rosters, team context, player timelines, contract status, draft assets, and G League movement. This module should become the connective graph for how teams are built over time.',
    );
  }
}

class _AssetWorkspaceScreen<T> extends StatefulWidget {
  const _AssetWorkspaceScreen({required this.title, required this.subtitle, required this.items, required this.loadRecords, required this.recordLabel, required this.emptyTitle, required this.emptyBody, required this.columns, required this.rowBuilder, required this.recordKey, required this.factBuilder, required this.activationSteps, required this.leadTitle, required this.leadBody});

  final String title;
  final String subtitle;
  final List<WorkspaceBuildItem> items;
  final Future<List<T>> Function() loadRecords;
  final String recordLabel;
  final String emptyTitle;
  final String emptyBody;
  final List<String> columns;
  final List<String> Function(T record) rowBuilder;
  final String Function(T record) recordKey;
  final List<_RecordFact> Function(T record) factBuilder;
  final List<_ActivationStep> activationSteps;
  final String leadTitle;
  final String leadBody;

  @override
  State<_AssetWorkspaceScreen<T>> createState() => _AssetWorkspaceScreenState<T>();
}

class _AssetWorkspaceScreenState<T> extends State<_AssetWorkspaceScreen<T>> {
  late final Future<List<T>> recordsFuture = widget.loadRecords();
  String query = '';
  String statusFilter = 'All';
  String? selectedRecordKey;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return TerminalCard(child: Text('Loading ${widget.title.toLowerCase()} workspace...', style: const TextStyle(color: terminalTextSoft)));
        if (snapshot.hasError) return TerminalCard(child: Text('Unable to load ${widget.title.toLowerCase()} workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        final records = snapshot.data ?? [];
        final filtered = records.where((record) {
          final values = widget.rowBuilder(record);
          final q = query.trim().toLowerCase();
          final sourceValue = values.isEmpty ? '' : values.last;
          return (q.isEmpty || values.join(' ').toLowerCase().contains(q)) && (statusFilter == 'All' || (statusFilter == 'Sourced' && sourceValue != '—') || (statusFilter == 'Source pending' && sourceValue == '—'));
        }).toList();
        final selected = _selectedRecord(filtered, records);
        final schemaReady = widget.items.where((item) => item.status.contains('Schema')).length;
        final planned = widget.items.where((item) => item.status == 'Planned').length;
        final future = widget.items.where((item) => item.status == 'Future').length;
        final sourced = records.where((record) => widget.rowBuilder(record).last != '—').length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title: widget.title, subtitle: widget.subtitle),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [_WorkspaceMetric(label: widget.recordLabel, value: '${records.length}', detail: records.isEmpty ? 'Source pending' : 'Loaded from asset'), _WorkspaceMetric(label: 'Visible', value: '${filtered.length}', detail: 'After filters'), _WorkspaceMetric(label: 'Sourced', value: '$sourced', detail: 'Rows with source metadata'), _WorkspaceMetric(label: 'Schema / Planned / Future', value: '$schemaReady / $planned / $future', detail: 'Build map')]);
          }),
          const SizedBox(height: 22),
          TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.leadTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(widget.leadBody, style: const TextStyle(color: terminalTextSoft, height: 1.45))])),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [SizedBox(width: 360, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search ${widget.title.toLowerCase()} records...'))), _FilterDropdown(label: 'Source Status', value: statusFilter, values: const ['All', 'Sourced', 'Source pending'], onChanged: (value) => setState(() => statusFilter = value))])),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final detail = _SelectedRecordPanel<T>(title: widget.title, record: selected, factBuilder: widget.factBuilder);
            final activation = _ActivationPanel(title: widget.title, steps: widget.activationSteps);
            if (constraints.maxWidth < 1050) return Column(children: [detail, const SizedBox(height: 14), activation]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: detail), const SizedBox(width: 14), Expanded(child: activation)]);
          }),
          const SizedBox(height: 22),
          records.isEmpty ? _EmptyAssetPanel(title: widget.emptyTitle, body: widget.emptyBody) : _RecordTable<T>(title: widget.recordLabel, records: filtered, columns: widget.columns, rowBuilder: widget.rowBuilder, recordKey: widget.recordKey, selectedKey: selected == null ? null : widget.recordKey(selected), onSelected: (record) => setState(() => selectedRecordKey = widget.recordKey(record))),
          const SizedBox(height: 22),
          _BuildMap(title: widget.title, items: widget.items),
        ]);
      },
    );
  }

  T? _selectedRecord(List<T> filtered, List<T> records) {
    for (final record in filtered) {
      if (widget.recordKey(record) == selectedRecordKey) return record;
    }
    if (filtered.isNotEmpty) return filtered.first;
    if (records.isNotEmpty) return records.first;
    return null;
  }
}

class _RecordFact { const _RecordFact(this.label, this.value); final String label; final String value; }
class _ActivationStep { const _ActivationStep(this.title, this.body); final String title; final String body; }

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));

class _FilterDropdown extends StatelessWidget { const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged, this.displayBuilder}); final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; final String Function(String value)? displayBuilder; @override Widget build(BuildContext context) => SizedBox(width: 230, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(displayBuilder?.call(item) ?? item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); }

class _SelectedRecordPanel<T> extends StatelessWidget { const _SelectedRecordPanel({required this.title, required this.record, required this.factBuilder}); final String title; final T? record; final List<_RecordFact> Function(T record) factBuilder; @override Widget build(BuildContext context) { if (record == null) return TerminalCard(child: Text('Select a $title record to inspect details, source status, and downstream links. This asset is currently source-pending.', style: const TextStyle(color: terminalTextSoft, height: 1.45))); final facts = factBuilder(record as T); return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Selected $title Record', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), for (final fact in facts) _FactLine(label: fact.label, value: fact.value)])); } }

class _FactLine extends StatelessWidget { const _FactLine({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))])); }

class _ActivationPanel extends StatelessWidget { const _ActivationPanel({required this.title, required this.steps}); final String title; final List<_ActivationStep> steps; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$title Activation Path', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), for (final step in steps) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: terminalBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(step.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(step.body, style: const TextStyle(color: terminalTextSoft, height: 1.35))]))])); }

class _EmptyAssetPanel extends StatelessWidget { const _EmptyAssetPanel({required this.title, required this.body}); final String title; final String body; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(body, style: const TextStyle(color: terminalTextSoft, height: 1.45))])); }

class _RecordTable<T> extends StatelessWidget { const _RecordTable({required this.title, required this.records, required this.columns, required this.rowBuilder, required this.recordKey, required this.selectedKey, required this.onSelected}); final String title; final List<T> records; final List<String> columns; final List<String> Function(T record) rowBuilder; final String Function(T record) recordKey; final String? selectedKey; final ValueChanged<T> onSelected; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columns: [for (final column in columns) DataColumn(label: Text(column))], rows: [for (final record in records) DataRow(selected: selectedKey == recordKey(record), onSelectChanged: (_) => onSelected(record), cells: [for (final value in rowBuilder(record)) DataCell(SizedBox(width: 160, child: Text(value, overflow: TextOverflow.ellipsis)))])]))])); }

class _BuildMap extends StatelessWidget { const _BuildMap({required this.title, required this.items}); final String title; final List<WorkspaceBuildItem> items; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Text('$title Build Map', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Area')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('First Data Need'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.description))), DataCell(SizedBox(width: 480, child: Text(item.firstDataNeed)))])]))])); }

class _WorkspaceMetric extends StatelessWidget { const _WorkspaceMetric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
