import 'package:flutter/material.dart';

import '../data/team_command_stage_items.dart';
import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/game_record.dart';
import '../models/playoff_series_record.dart';
import '../models/registry_item.dart';
import '../models/roster_entry.dart';
import '../models/standings_record.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
import '../models/transaction_record.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_TeamPayload> payloadFuture = _loadPayload();
  String selectedConference = 'All';
  String selectedDivision = 'All';
  String selectedStageCategory = 'All';
  String query = '';

  Future<_TeamPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadTeams(),
      repository.loadTeamSeasonStats(),
      repository.loadStandings(),
      repository.loadPlayoffSeries(),
      repository.loadGames(),
      repository.loadRosters(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadTransactions(),
    ]);
    return _TeamPayload(
      teams: results[0] as List<Team>,
      stats: results[1] as List<TeamSeasonStat>,
      standings: results[2] as List<StandingsRecord>,
      playoffs: results[3] as List<PlayoffSeriesRecord>,
      games: results[4] as List<GameRecord>,
      rosters: results[5] as List<RosterEntry>,
      awards: results[6] as List<AwardRecord>,
      draftPicks: results[7] as List<DraftPick>,
      transactions: results[8] as List<TransactionRecord>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TeamPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading team command workspace...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load team command workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final payload = snapshot.data ?? const _TeamPayload(teams: [], stats: [], standings: [], playoffs: [], games: [], rosters: [], awards: [], draftPicks: [], transactions: []);
        final divisions = ['All', ...payload.teams.map((team) => team.division).toSet().toList()..sort()];
        final categories = ['All', ...teamCommandStageItems.map((item) => item.category).toSet().toList()..sort()];
        final filteredStages = teamCommandStageItems.where((item) => selectedStageCategory == 'All' || item.category == selectedStageCategory).toList();
        final teams = payload.teams.where((team) {
          final q = query.trim().toLowerCase();
          final matchesConference = selectedConference == 'All' || team.conference == selectedConference;
          final matchesDivision = selectedDivision == 'All' || team.division == selectedDivision;
          final matchesQuery = q.isEmpty || team.id.toLowerCase().contains(q) || team.name.toLowerCase().contains(q) || team.city.toLowerCase().contains(q) || team.abbreviation.toLowerCase().contains(q) || team.division.toLowerCase().contains(q) || team.conference.toLowerCase().contains(q);
          return matchesConference && matchesDivision && matchesQuery;
        }).toList()
          ..sort((a, b) => '${a.conference}${a.division}${a.name}'.compareTo('${b.conference}${b.division}${b.name}'));

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'NBA Teams', subtitle: 'Team command workspace for identity, league structure, team-season stats, standings, playoff paths, games, rosters, awards, draft, transactions, reports, workspaces, and source trust.'),
          const SizedBox(height: 22),
          _MetricGrid(metrics: [
            _MetricSpec('NBA Teams', '${payload.teams.length}', 'Reference asset'),
            _MetricSpec('Team Stat Rows', '${payload.stats.length}', 'Team seasons'),
            _MetricSpec('Context Rows', '${payload.standings.length + payload.playoffs.length + payload.games.length + payload.rosters.length}', 'Standings + playoffs + games + rosters'),
            _MetricSpec('Command Stages', '${teamCommandStageItems.length}', 'Team model'),
          ]),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: 330, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search team, city, abbreviation, division...'))),
            _FilterDropdown(label: 'Conference', value: selectedConference, values: const ['All', 'East', 'West'], onChanged: (value) => setState(() => selectedConference = value)),
            _FilterDropdown(label: 'Division', value: selectedDivision, values: divisions, onChanged: (value) => setState(() => selectedDivision = value)),
            _FilterDropdown(label: 'Stage Category', value: selectedStageCategory, values: categories, onChanged: (value) => setState(() => selectedStageCategory = value)),
          ])),
          const SizedBox(height: 22),
          _TeamCommandTicket(payload: payload, visibleTeams: teams.length),
          const SizedBox(height: 22),
          _TeamsTable(teams: teams, payload: payload),
          const SizedBox(height: 22),
          _TeamAttachmentMap(payload: payload),
          const SizedBox(height: 22),
          _TeamStatsReadinessTable(stats: payload.stats),
          const SizedBox(height: 22),
          _RegistryTable(title: 'Team Command Stage Model', items: filteredStages),
        ]);
      },
    );
  }
}

class _TeamPayload {
  const _TeamPayload({required this.teams, required this.stats, required this.standings, required this.playoffs, required this.games, required this.rosters, required this.awards, required this.draftPicks, required this.transactions});

  final List<Team> teams;
  final List<TeamSeasonStat> stats;
  final List<StandingsRecord> standings;
  final List<PlayoffSeriesRecord> playoffs;
  final List<GameRecord> games;
  final List<RosterEntry> rosters;
  final List<AwardRecord> awards;
  final List<DraftPick> draftPicks;
  final List<TransactionRecord> transactions;
}

class _TeamCommandTicket extends StatelessWidget {
  const _TeamCommandTicket({required this.payload, required this.visibleTeams});

  final _TeamPayload payload;
  final int visibleTeams;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Team Command Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('This keeps Teams focused on identity, league structure, connected context rows, future action routes, and missing-data honesty while source-backed team stats are populated.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: '$visibleTeams visible'), InfoPill(label: '${payload.stats.length} stat rows'), InfoPill(label: '${payload.standings.length} standings rows'), InfoPill(label: '${payload.playoffs.length} playoff rows')]),
    ]));
  }
}

class _TeamsTable extends StatelessWidget {
  const _TeamsTable({required this.teams, required this.payload});

  final List<Team> teams;
  final _TeamPayload payload;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Team Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${teams.length} teams', style: const TextStyle(color: terminalTextMuted))])),
      const Divider(height: 1, color: terminalBorder),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: const [DataColumn(label: Text('Team')), DataColumn(label: Text('Abbrev.')), DataColumn(label: Text('City')), DataColumn(label: Text('Conference')), DataColumn(label: Text('Division')), DataColumn(label: Text('Stats')), DataColumn(label: Text('Standings')), DataColumn(label: Text('Rosters'))],
        rows: [
          for (final team in teams)
            DataRow(cells: [
              DataCell(SizedBox(width: 220, child: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
              DataCell(Text(team.abbreviation)),
              DataCell(Text(team.city)),
              DataCell(Text(team.conference)),
              DataCell(Text(team.division)),
              DataCell(Text('${payload.stats.where((row) => row.teamId == team.id).length}')),
              DataCell(Text('${payload.standings.where((row) => row.teamId == team.id).length}')),
              DataCell(Text('${payload.rosters.where((row) => row.teamId == team.id).length}')),
            ]),
        ],
      )),
    ]));
  }
}

class _TeamAttachmentMap extends StatelessWidget {
  const _TeamAttachmentMap({required this.payload});

  final _TeamPayload payload;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _AttachmentRow('Team Reference', payload.teams.length, 'teamId', payload.teams.isEmpty ? 'Source pending' : 'Connected', 'Identity, detail pages, search, reports'),
      _AttachmentRow('Team Season Stats', payload.stats.length, 'teamId + seasonId', payload.stats.isEmpty ? 'Source pending' : 'Connected', 'Stats, comparisons, rankings, reports'),
      _AttachmentRow('Standings', payload.standings.length, 'teamId + seasonId', payload.standings.isEmpty ? 'Source pending' : 'Connected', 'Seed, record, playoff context'),
      _AttachmentRow('Playoffs', payload.playoffs.length, 'winningTeamId / losingTeamId', payload.playoffs.isEmpty ? 'Source pending' : 'Connected', 'Series paths and postseason context'),
      _AttachmentRow('Games', payload.games.length, 'homeTeamId / awayTeamId', payload.games.isEmpty ? 'Source pending' : 'Connected', 'Schedule and result context'),
      _AttachmentRow('Rosters', payload.rosters.length, 'teamId + seasonId', payload.rosters.isEmpty ? 'Source pending' : 'Connected', 'Roster construction'),
      _AttachmentRow('Awards', payload.awards.length, 'teamId + seasonId', payload.awards.isEmpty ? 'Source pending' : 'Connected', 'Recognition and voting context'),
      _AttachmentRow('Draft Picks', payload.draftPicks.length, 'teamId + draftYear', payload.draftPicks.isEmpty ? 'Source pending' : 'Connected', 'Draft class and franchise history'),
      _AttachmentRow('Transactions', payload.transactions.length, 'fromTeamId / toTeamId', payload.transactions.isEmpty ? 'Source pending' : 'Connected', 'Movement timeline'),
    ];
    return _AttachmentTable(title: 'Team Data Attachment Map', rows: rows);
  }
}

class _TeamStatsReadinessTable extends StatelessWidget {
  const _TeamStatsReadinessTable({required this.stats});

  final List<TeamSeasonStat> stats;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Team Season Stats Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${stats.length} rows', style: const TextStyle(color: terminalTextMuted))])),
      const Divider(height: 1, color: terminalBorder),
      if (stats.isEmpty)
        const Padding(padding: EdgeInsets.all(18), child: Text('Team season stats source pending. No fake stat rows are displayed.', style: TextStyle(color: terminalTextSoft)))
      else
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          headingRowColor: WidgetStateProperty.all(terminalPanelDark),
          headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
          dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
          columns: const [DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('W')), DataColumn(label: Text('L')), DataColumn(label: Text('PPG')), DataColumn(label: Text('Pace')), DataColumn(label: Text('ORtg')), DataColumn(label: Text('DRtg')), DataColumn(label: Text('Net')), DataColumn(label: Text('Source'))],
          rows: [
            for (final stat in stats)
              DataRow(cells: [DataCell(Text(stat.teamId)), DataCell(Text(stat.seasonId)), DataCell(Text(stat.wins?.toString() ?? '—')), DataCell(Text(stat.losses?.toString() ?? '—')), DataCell(Text(_number(stat.pointsPerGame))), DataCell(Text(_number(stat.pace))), DataCell(Text(_number(stat.offensiveRating))), DataCell(Text(_number(stat.defensiveRating))), DataCell(Text(_number(stat.netRating))), DataCell(Text(stat.sourceId ?? '—'))]),
          ],
        )),
    ]));
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
        rows: [for (final row in rows) DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(row.layer, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text('${row.rows}')), DataCell(SizedBox(width: 260, child: Text(row.joinKey))), DataCell(InfoPill(label: row.status)), DataCell(SizedBox(width: 560, child: Text(row.use)))])],
      )),
    ]));
  }
}

class _RegistryTable extends StatelessWidget {
  const _RegistryTable({required this.title, required this.items});
  final String title;
  final List<RegistryItem> items;
  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Next Step'))],
      rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])],
    )),
  ]));
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(width: 235, child: DropdownButtonFormField<String>(initialValue: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); }));
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
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final isWide = constraints.maxWidth > 900;
    return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [for (final metric in metrics) _Metric(label: metric.label, value: metric.value, detail: metric.detail)]);
  });
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));
String _number(double? value) => value == null ? '—' : value.toStringAsFixed(1);
