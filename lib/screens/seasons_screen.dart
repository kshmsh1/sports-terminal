import 'package:flutter/material.dart';

import '../data/season_command_stage_items.dart';
import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/game_record.dart';
import '../models/player_season_stat.dart';
import '../models/playoff_series_record.dart';
import '../models/registry_item.dart';
import '../models/roster_entry.dart';
import '../models/season.dart';
import '../models/standings_record.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../models/transaction_record.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class SeasonsScreen extends StatefulWidget {
  const SeasonsScreen({super.key});

  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_SeasonPayload> payloadFuture = _loadPayload();
  String selectedLeague = 'All';
  String selectedView = 'Season Overview';
  String selectedAction = 'Season Report';
  String selectedStageCategory = 'All';
  String query = '';
  String? selectedSeasonId;

  Future<_SeasonPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadSeasons(),
      repository.loadTeams(),
      repository.loadStandings(),
      repository.loadTeamSeasonStats(),
      repository.loadPlayoffSeries(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadGames(),
      repository.loadPlayerSeasonStats(),
      repository.loadRosters(),
      repository.loadTransactions(),
    ]);

    return _SeasonPayload(
      seasons: results[0] as List<Season>,
      teams: results[1] as List<Team>,
      standings: results[2] as List<StandingsRecord>,
      teamStats: results[3] as List<TeamSeasonStat>,
      playoffs: results[4] as List<PlayoffSeriesRecord>,
      awards: results[5] as List<AwardRecord>,
      draftPicks: results[6] as List<DraftPick>,
      games: results[7] as List<GameRecord>,
      playerStats: results[8] as List<PlayerSeasonStat>,
      rosters: results[9] as List<RosterEntry>,
      transactions: results[10] as List<TransactionRecord>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SeasonPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(
            child: Text('Loading season command workspace...', style: TextStyle(color: terminalTextSoft)),
          );
        }
        if (snapshot.hasError) {
          return TerminalCard(
            child: Text('Unable to load season command workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)),
          );
        }

        final payload = snapshot.data ?? const _SeasonPayload(seasons: [], teams: [], standings: [], teamStats: [], playoffs: [], awards: [], draftPicks: [], games: [], playerStats: [], rosters: [], transactions: []);
        final seasons = payload.seasons.where((season) {
          final q = query.trim().toLowerCase();
          final matchesLeague = selectedLeague == 'All' || season.league == selectedLeague;
          final matchesQuery = q.isEmpty || season.id.toLowerCase().contains(q) || season.label.toLowerCase().contains(q) || season.startYear.toString().contains(q) || season.endYear.toString().contains(q) || season.league.toLowerCase().contains(q);
          return matchesLeague && matchesQuery;
        }).toList();
        final selectedSeason = _resolveSelectedSeason(seasons, payload.seasons);
        final selectedSummary = selectedSeason == null ? null : _SeasonSummary.fromPayload(selectedSeason, payload);
        final categories = ['All', ...seasonCommandStageItems.map((item) => item.category).toSet().toList()..sort()];
        final filteredStages = seasonCommandStageItems.where((item) => selectedStageCategory == 'All' || item.category == selectedStageCategory).toList();
        final baaSeasons = payload.seasons.where((season) => season.league == 'BAA').length;
        final nbaSeasons = payload.seasons.length - baaSeasons;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'NBA Seasons',
              subtitle: 'Season command workspace for the NBA time spine: seasons, standings, stats, playoffs, awards, draft classes, games, rosters, transactions, reports, workspaces, compare, exports, alerts, and source trust.',
            ),
            const SizedBox(height: 22),
            _MetricGrid(metrics: [
              _MetricSpec('Configured Seasons', '${payload.seasons.length}', '$nbaSeasons NBA / $baaSeasons BAA'),
              _MetricSpec('Context Rows', '${payload.standings.length + payload.playoffs.length + payload.games.length}', 'Standings + playoffs + games'),
              _MetricSpec('Performance Rows', '${payload.teamStats.length + payload.playerStats.length}', 'Team + player stats'),
              _MetricSpec('Command Stages', '${seasonCommandStageItems.length}', 'Season model'),
            ]),
            const SizedBox(height: 22),
            TerminalCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 320,
                    child: TextField(
                      onChanged: (value) => setState(() => query = value),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: terminalAccent,
                      decoration: _inputDecoration('Search season, year, league...'),
                    ),
                  ),
                  _FilterDropdown(label: 'League', value: selectedLeague, values: const ['All', 'NBA', 'BAA'], onChanged: (value) => setState(() => selectedLeague = value)),
                  _FilterDropdown(label: 'View', value: selectedView, values: _seasonViews.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedView = value)),
                  _FilterDropdown(label: 'Action', value: selectedAction, values: _seasonActions.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedAction = value)),
                  _FilterDropdown(label: 'Stage Category', value: selectedStageCategory, values: categories, onChanged: (value) => setState(() => selectedStageCategory = value)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SeasonCommandTicket(view: _seasonViews.firstWhere((item) => item.name == selectedView), action: _seasonActions.firstWhere((item) => item.name == selectedAction), summary: selectedSummary, payload: payload),
            const SizedBox(height: 22),
            if (selectedSummary != null) ...[
              _SelectedSeasonPanel(summary: selectedSummary, totalTeams: payload.teams.length),
              const SizedBox(height: 22),
            ],
            _SeasonsTable(seasons: seasons, selectedSeasonId: selectedSeason?.id, onSelected: (season) => setState(() => selectedSeasonId = season.id), summaries: {for (final season in payload.seasons) season.id: _SeasonSummary.fromPayload(season, payload)}),
            const SizedBox(height: 22),
            const _ModeMatrix(title: 'Season View Modes', items: _seasonViews),
            const SizedBox(height: 22),
            const _ModeMatrix(title: 'Season Action Routes', items: _seasonActions),
            const SizedBox(height: 22),
            _SeasonAttachmentMap(payload: payload),
            const SizedBox(height: 22),
            _RegistryTable(title: 'Season Command Stage Model', items: filteredStages),
          ],
        );
      },
    );
  }

  Season? _resolveSelectedSeason(List<Season> filtered, List<Season> all) {
    for (final season in filtered) {
      if (season.id == selectedSeasonId) return season;
    }
    for (final season in all) {
      if (season.id == selectedSeasonId) return season;
    }
    if (filtered.isNotEmpty) return filtered.first;
    if (all.isNotEmpty) return all.first;
    return null;
  }
}

class _SeasonPayload {
  const _SeasonPayload({required this.seasons, required this.teams, required this.standings, required this.teamStats, required this.playoffs, required this.awards, required this.draftPicks, required this.games, required this.playerStats, required this.rosters, required this.transactions});

  final List<Season> seasons;
  final List<Team> teams;
  final List<StandingsRecord> standings;
  final List<TeamSeasonStat> teamStats;
  final List<PlayoffSeriesRecord> playoffs;
  final List<AwardRecord> awards;
  final List<DraftPick> draftPicks;
  final List<GameRecord> games;
  final List<PlayerSeasonStat> playerStats;
  final List<RosterEntry> rosters;
  final List<TransactionRecord> transactions;
}

class _SeasonSummary {
  const _SeasonSummary({required this.season, required this.standingsRows, required this.teamStatRows, required this.playerStatRows, required this.playoffRows, required this.awardRows, required this.draftRows, required this.gameRows, required this.rosterRows, required this.transactionRows, required this.bestTeamPpg, required this.bestNetRating});

  factory _SeasonSummary.fromPayload(Season season, _SeasonPayload payload) {
    final teamStats = payload.teamStats.where((item) => item.seasonId == season.id).toList();
    final ppgs = teamStats.map((item) => item.pointsPerGame).whereType<double>().toList()..sort((a, b) => b.compareTo(a));
    final nets = teamStats.map((item) => item.netRating).whereType<double>().toList()..sort((a, b) => b.compareTo(a));
    return _SeasonSummary(
      season: season,
      standingsRows: payload.standings.where((item) => item.seasonId == season.id).length,
      teamStatRows: teamStats.length,
      playerStatRows: payload.playerStats.where((item) => item.seasonId == season.id).length,
      playoffRows: payload.playoffs.where((item) => item.seasonId == season.id).length,
      awardRows: payload.awards.where((item) => item.seasonId == season.id).length,
      draftRows: payload.draftPicks.where((item) => item.draftYear == season.startYear).length,
      gameRows: payload.games.where((item) => item.seasonId == season.id).length,
      rosterRows: payload.rosters.where((item) => item.seasonId == season.id).length,
      transactionRows: payload.transactions.where((item) => _dateMapsToSeason(item.date, season)).length,
      bestTeamPpg: ppgs.isEmpty ? null : ppgs.first,
      bestNetRating: nets.isEmpty ? null : nets.first,
    );
  }

  final Season season;
  final int standingsRows;
  final int teamStatRows;
  final int playerStatRows;
  final int playoffRows;
  final int awardRows;
  final int draftRows;
  final int gameRows;
  final int rosterRows;
  final int transactionRows;
  final double? bestTeamPpg;
  final double? bestNetRating;

  int get connectedSections => [standingsRows, teamStatRows, playerStatRows, playoffRows, awardRows, draftRows, gameRows, rosterRows, transactionRows].where((count) => count > 0).length;
}

class _SeasonMode {
  const _SeasonMode(this.name, this.status, this.description);
  final String name;
  final String status;
  final String description;
}

const _seasonViews = <_SeasonMode>[
  _SeasonMode('Season Overview', 'Connected', 'Season identity, league marker, year range, connected sections, source coverage, and report readiness.'),
  _SeasonMode('Standings', 'Planned', 'Conference/division standings, seed, wins, losses, win percentage, games back, and playoff qualification context.'),
  _SeasonMode('Stat Environment', 'Planned', 'Team and player statistical environment, leaders, pace, ratings, shooting, scoring, and era context.'),
  _SeasonMode('Playoff Path', 'Planned', 'Round-by-round bracket, winners, losers, seeds, games played, series results, and championship path.'),
  _SeasonMode('Award Races', 'Planned', 'Award winners, finalists, vote ranks, first-place votes, points, shares, team context, and player stat context.'),
  _SeasonMode('Draft Class', 'Future', 'Draft class, team picks, player outcomes, development paths, and franchise-building context.'),
  _SeasonMode('Roster and Movement', 'Future', 'Roster windows, trades, signings, assignments, recalls, contract events, and team-building timeline.'),
];

const _seasonActions = <_SeasonMode>[
  _SeasonMode('Season Report', 'Planned', 'Generate a season command packet with overview, standings, playoffs, awards, draft, leaders, source coverage, and missing-data flags.'),
  _SeasonMode('Workspace', 'Planned', 'Send standings, team stats, player leaders, playoff series, award rows, draft class, and source context into custom tables.'),
  _SeasonMode('Compare', 'Planned', 'Compare seasons by league context, scoring environment, standings depth, awards, playoff format, and data coverage.'),
  _SeasonMode('Save View', 'Planned', 'Persist season filters, selected panels, metric packages, source snapshots, and output intent.'),
  _SeasonMode('Alert', 'Future', 'Monitor season source updates, row-count changes, leaderboard changes, award updates, and saved-view movement.'),
  _SeasonMode('Export', 'Planned', 'Export season packet, standings, playoff path, award boards, draft class, or source audit appendix.'),
  _SeasonMode('Dashboard Pin', 'Future', 'Pin a season command board for fast access to selected year, source coverage, alerts, and reports.'),
];

class _SeasonCommandTicket extends StatelessWidget {
  const _SeasonCommandTicket({required this.view, required this.action, required this.summary, required this.payload});

  final _SeasonMode view;
  final _SeasonMode action;
  final _SeasonSummary? summary;
  final _SeasonPayload payload;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Season Command Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('This keeps Season Command focused on the time spine, selected view, route intent, source coverage, and the nine major attachment sections needed for NBA MVP functionality.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: view.status), InfoPill(label: action.status), InfoPill(label: '${payload.seasons.length} seasons'), InfoPill(label: summary == null ? 'No selection' : '${summary!.connectedSections}/9 sections')]),
      const SizedBox(height: 12),
      _DetailLine(label: 'View', value: '${view.name}: ${view.description}'),
      _DetailLine(label: 'Action', value: '${action.name}: ${action.description}'),
    ]));
  }
}

class _SelectedSeasonPanel extends StatelessWidget {
  const _SelectedSeasonPanel({required this.summary, required this.totalTeams});

  final _SeasonSummary summary;
  final int totalTeams;

  @override
  Widget build(BuildContext context) {
    final season = summary.season;
    final badges = [
      _BadgeSpec('Teams', '$totalTeams', 'Current directory'),
      _BadgeSpec('Standings', '${summary.standingsRows}', 'Rows'),
      _BadgeSpec('Team Stats', '${summary.teamStatRows}', 'Rows'),
      _BadgeSpec('Player Stats', '${summary.playerStatRows}', 'Rows'),
      _BadgeSpec('Games', '${summary.gameRows}', 'Rows'),
      _BadgeSpec('Playoffs', '${summary.playoffRows}', 'Series'),
      _BadgeSpec('Awards', '${summary.awardRows}', 'Rows'),
      _BadgeSpec('Draft', '${summary.draftRows}', '${season.startYear} class'),
      _BadgeSpec('Rosters', '${summary.rosterRows}', 'Rows'),
      _BadgeSpec('Transactions', '${summary.transactionRows}', 'Rows'),
      _BadgeSpec('Best Team PPG', _num(summary.bestTeamPpg), 'Team max'),
      _BadgeSpec('Best Net', _num(summary.bestNetRating), 'Team max'),
    ];

    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(season.label, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('${season.league} season covering ${season.startYear}-${season.endYear}. This panel is now a season command board rather than a simple directory detail.', style: const TextStyle(color: terminalTextSoft, height: 1.4)),
        ])),
        const SizedBox(width: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [InfoPill(label: season.league), InfoPill(label: '${summary.connectedSections}/9 sections')]),
      ]),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.45 : 1.85,
          children: [for (final badge in badges) _DataBadge(label: badge.label, value: badge.value, detail: badge.detail)],
        );
      }),
    ]));
  }
}

class _SeasonsTable extends StatelessWidget {
  const _SeasonsTable({required this.seasons, required this.selectedSeasonId, required this.onSelected, required this.summaries});

  final List<Season> seasons;
  final String? selectedSeasonId;
  final ValueChanged<Season> onSelected;
  final Map<String, _SeasonSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Season Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${seasons.length} seasons', style: const TextStyle(color: terminalTextMuted))])),
      const Divider(height: 1, color: terminalBorder),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: const [DataColumn(label: Text('Season')), DataColumn(label: Text('Start')), DataColumn(label: Text('End')), DataColumn(label: Text('League')), DataColumn(label: Text('Connected')), DataColumn(label: Text('Standings')), DataColumn(label: Text('Team Stats')), DataColumn(label: Text('Player Stats')), DataColumn(label: Text('Games')), DataColumn(label: Text('Playoffs')), DataColumn(label: Text('Awards')), DataColumn(label: Text('Draft')), DataColumn(label: Text('Rosters')), DataColumn(label: Text('Transactions'))],
        rows: [
          for (final season in seasons)
            DataRow(selected: selectedSeasonId == season.id, onSelectChanged: (_) => onSelected(season), cells: [
              DataCell(Text(season.label, style: const TextStyle(fontWeight: FontWeight.w800))),
              DataCell(Text('${season.startYear}')),
              DataCell(Text('${season.endYear}')),
              DataCell(Text(season.league)),
              DataCell(InfoPill(label: '${summaries[season.id]?.connectedSections ?? 0}/9')),
              DataCell(Text('${summaries[season.id]?.standingsRows ?? 0}')),
              DataCell(Text('${summaries[season.id]?.teamStatRows ?? 0}')),
              DataCell(Text('${summaries[season.id]?.playerStatRows ?? 0}')),
              DataCell(Text('${summaries[season.id]?.gameRows ?? 0}')),
              DataCell(Text('${summaries[season.id]?.playoffRows ?? 0}')),
              DataCell(Text('${summaries[season.id]?.awardRows ?? 0}')),
              DataCell(Text('${summaries[season.id]?.draftRows ?? 0}')),
              DataCell(Text('${summaries[season.id]?.rosterRows ?? 0}')),
              DataCell(Text('${summaries[season.id]?.transactionRows ?? 0}')),
            ]),
        ],
      )),
    ]));
  }
}

class _ModeMatrix extends StatelessWidget {
  const _ModeMatrix({required this.title, required this.items});

  final String title;
  final List<_SeasonMode> items;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(18), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
      const Divider(height: 1, color: terminalBorder),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: const [DataColumn(label: Text('Name')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description'))],
        rows: [for (final item in items) DataRow(cells: [DataCell(SizedBox(width: 240, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 860, child: Text(item.description)))])],
      )),
    ]));
  }
}

class _SeasonAttachmentMap extends StatelessWidget {
  const _SeasonAttachmentMap({required this.payload});

  final _SeasonPayload payload;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _AttachmentRow('Seasons', payload.seasons.length, 'seasonId', 'Connected', 'Time spine and command board'),
      _AttachmentRow('Teams', payload.teams.length, 'teamId', payload.teams.isEmpty ? 'Source pending' : 'Connected', 'League structure and team context'),
      _AttachmentRow('Standings', payload.standings.length, 'seasonId + teamId', payload.standings.isEmpty ? 'Source pending' : 'Connected', 'Seed, record, playoff race'),
      _AttachmentRow('Team Stats', payload.teamStats.length, 'seasonId + teamId', payload.teamStats.isEmpty ? 'Source pending' : 'Connected', 'Team environment and comparison'),
      _AttachmentRow('Player Stats', payload.playerStats.length, 'seasonId + playerId', payload.playerStats.isEmpty ? 'Source pending' : 'Connected', 'Leaders, awards, custom models'),
      _AttachmentRow('Games', payload.games.length, 'seasonId + gameId', payload.games.isEmpty ? 'Source pending' : 'Connected', 'Schedule, results, trend charts'),
      _AttachmentRow('Playoffs', payload.playoffs.length, 'seasonId + seriesId', payload.playoffs.isEmpty ? 'Source pending' : 'Connected', 'Bracket and postseason path'),
      _AttachmentRow('Awards', payload.awards.length, 'seasonId + awardId', payload.awards.isEmpty ? 'Source pending' : 'Connected', 'Award races and recognition'),
      _AttachmentRow('Draft Picks', payload.draftPicks.length, 'draftYear', payload.draftPicks.isEmpty ? 'Source pending' : 'Connected', 'Draft class and team-building'),
      _AttachmentRow('Rosters', payload.rosters.length, 'seasonId + teamId', payload.rosters.isEmpty ? 'Source pending' : 'Connected', 'Roster windows and eligibility'),
      _AttachmentRow('Transactions', payload.transactions.length, 'date to season', payload.transactions.isEmpty ? 'Source pending' : 'Connected', 'Movement timeline'),
    ];
    return _AttachmentTable(title: 'Season Data Attachment Map', rows: rows);
  }
}

class _AttachmentRow {
  const _AttachmentRow(this.layer, this.rows, this.joinKey, this.status, this.use);
  final String layer;
  final int rows;
  final String joinKey;
  final String status;
  final String use;
}

class _AttachmentTable extends StatelessWidget {
  const _AttachmentTable({required this.title, required this.rows});

  final String title;
  final List<_AttachmentRow> rows;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(18), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
      const Divider(height: 1, color: terminalBorder),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: const [DataColumn(label: Text('Layer')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Join Key')), DataColumn(label: Text('Status')), DataColumn(label: Text('Use'))],
        rows: [
          for (final row in rows)
            DataRow(cells: [
              DataCell(SizedBox(width: 220, child: Text(row.layer, style: const TextStyle(fontWeight: FontWeight.w800)))),
              DataCell(Text('${row.rows}')),
              DataCell(SizedBox(width: 240, child: Text(row.joinKey))),
              DataCell(InfoPill(label: row.status)),
              DataCell(SizedBox(width: 560, child: Text(row.use))),
            ]),
        ],
      )),
    ]));
  }
}

class _RegistryTable extends StatelessWidget {
  const _RegistryTable({required this.title, required this.items});

  final String title;
  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])),
      const Divider(height: 1, color: terminalBorder),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Next Step'))],
        rows: [
          for (final item in items)
            DataRow(cells: [
              DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
              DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
              DataCell(SizedBox(width: 180, child: Text(item.category))),
              DataCell(InfoPill(label: item.status)),
              DataCell(SizedBox(width: 560, child: Text(item.description))),
              DataCell(SizedBox(width: 460, child: Text(item.nextStep))),
            ]),
        ],
      )),
    ]));
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 235,
      child: DropdownButtonFormField<String>(
        initialValue: values.contains(value) ? value : values.first,
        dropdownColor: terminalPanelDark,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: terminalTextMuted),
          filled: true,
          fillColor: terminalPanelDark,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
        ),
        items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _MetricSpec {
  const _MetricSpec(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricSpec> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;
      return GridView.count(
        crossAxisCount: isWide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isWide ? 2.0 : 1.5,
        children: [for (final metric in metrics) _SeasonMetric(label: metric.label, value: metric.value, detail: metric.detail)],
      );
    });
  }
}

class _SeasonMetric extends StatelessWidget {
  const _SeasonMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
      Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
    ]));
  }
}

class _DataBadge extends StatelessWidget {
  const _DataBadge({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: terminalBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        Text(detail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalAccent, fontSize: 12)),
      ]),
    );
  }
}

class _BadgeSpec {
  const _BadgeSpec(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))),
        Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3))),
      ]),
    );
  }
}

bool _dateMapsToSeason(String? date, Season season) {
  if (date == null || date.length < 4) return false;
  final year = int.tryParse(date.substring(0, 4));
  return year == season.startYear || year == season.endYear;
}

String _num(double? value) => value?.toStringAsFixed(1) ?? '—';

InputDecoration _inputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: terminalTextMuted),
    prefixIcon: const Icon(Icons.search, color: terminalTextMuted),
    filled: true,
    fillColor: terminalPanelDark,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
  );
}
