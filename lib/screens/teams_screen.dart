import 'package:flutter/material.dart';

import '../data/action_surface_items.dart';
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
  String selectedProfileView = 'Identity';
  String selectedMetricPackage = 'Fundamental';
  String selectedActionRoute = 'Compare';
  String selectedStageCategory = 'All';
  String query = '';
  String? selectedTeamId;

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
        if (snapshot.connectionState != ConnectionState.done) return const _LoadingState();
        if (snapshot.hasError) return _ErrorState(message: snapshot.error.toString());

        final payload = snapshot.data ?? const _TeamPayload(teams: [], stats: [], standings: [], playoffs: [], games: [], rosters: [], awards: [], draftPicks: [], transactions: []);
        final teams = payload.teams;
        final divisions = ['All', ...teams.map((team) => team.division).toSet().toList()..sort()];
        final conferenceCounts = _countsBy(teams, (team) => team.conference);
        final divisionCounts = _countsBy(teams, (team) => team.division);
        final filteredTeams = teams.where((team) {
          final matchesConference = selectedConference == 'All' || team.conference == selectedConference;
          final matchesDivision = selectedDivision == 'All' || team.division == selectedDivision;
          final normalizedQuery = query.trim().toLowerCase();
          final matchesQuery = normalizedQuery.isEmpty ||
              team.id.toLowerCase().contains(normalizedQuery) ||
              team.name.toLowerCase().contains(normalizedQuery) ||
              team.city.toLowerCase().contains(normalizedQuery) ||
              team.abbreviation.toLowerCase().contains(normalizedQuery) ||
              team.division.toLowerCase().contains(normalizedQuery) ||
              team.conference.toLowerCase().contains(normalizedQuery);
          return matchesConference && matchesDivision && matchesQuery;
        }).toList()
          ..sort((a, b) {
            final conferenceCompare = a.conference.compareTo(b.conference);
            if (conferenceCompare != 0) return conferenceCompare;
            final divisionCompare = a.division.compareTo(b.division);
            if (divisionCompare != 0) return divisionCompare;
            return a.name.compareTo(b.name);
          });

        final selectedTeam = teams.where((team) => team.id == selectedTeamId).firstOrNull ?? (filteredTeams.isNotEmpty ? filteredTeams.first : null);
        final selectedSummary = selectedTeam == null ? null : _TeamSummary.fromPayload(selectedTeam, payload);
        final stageCategories = ['All', ...teamCommandStageItems.map((item) => item.category).toSet().toList()..sort()];
        final filteredStages = teamCommandStageItems.where((item) => selectedStageCategory == 'All' || item.category == selectedStageCategory).toList();
        final p0Stages = teamCommandStageItems.where((item) => item.priority == 'P0').length;
        final plannedStages = teamCommandStageItems.where((item) => item.status == 'Planned').length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'NBA Teams', subtitle: 'Team command workspace for team identity, franchise context, team stats, standings, playoff paths, rosters, awards, draft history, transactions, action routes, source coverage, and future front-office workflows.'),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
              _TeamMetric(label: 'NBA Teams', value: '${teams.length}', detail: 'Reference asset'),
              _TeamMetric(label: 'Team Stat Rows', value: '${payload.stats.length}', detail: 'Traditional + advanced schema'),
              _TeamMetric(label: 'Context Rows', value: '${payload.standings.length + payload.playoffs.length + payload.rosters.length}', detail: 'Standings + playoffs + rosters'),
              _TeamMetric(label: 'Command Stages', value: '${teamCommandStageItems.length}', detail: '$p0Stages P0 / $plannedStages planned'),
            ]);
          }),
          const SizedBox(height: 22),
          TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 320, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search team, city, abbreviation, division...'))),
            _FilterDropdown(label: 'Conference', value: selectedConference, values: const ['All', 'East', 'West'], onChanged: (value) => setState(() => selectedConference = value)),
            _FilterDropdown(label: 'Division', value: selectedDivision, values: divisions, onChanged: (value) => setState(() => selectedDivision = value)),
            _FilterDropdown(label: 'Profile View', value: selectedProfileView, values: _teamProfileViews.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedProfileView = value)),
            _FilterDropdown(label: 'Metric Package', value: selectedMetricPackage, values: _teamMetricPackages.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedMetricPackage = value)),
            _FilterDropdown(label: 'Action Route', value: selectedActionRoute, values: _teamActionRoutes.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedActionRoute = value)),
            _FilterDropdown(label: 'Stage Category', value: selectedStageCategory, values: stageCategories, onChanged: (value) => setState(() => selectedStageCategory = value)),
          ])),
          const SizedBox(height: 22),
          _TeamCommandTicket(profileView: _teamProfileViews.firstWhere((item) => item.name == selectedProfileView), metricPackage: _teamMetricPackages.firstWhere((item) => item.name == selectedMetricPackage), actionRoute: _teamActionRoutes.firstWhere((item) => item.name == selectedActionRoute), summary: selectedSummary, payload: payload),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 980;
            final children = [_ConferenceDivisionPanel(conferenceCounts: conferenceCounts, divisionCounts: divisionCounts), _SelectedTeamPanel(summary: selectedSummary, metricPackage: selectedMetricPackage, actionRoute: selectedActionRoute)];
            if (!isWide) return Column(children: [for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: child)]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: children[0]), const SizedBox(width: 14), Expanded(child: children[1])]);
          }),
          const SizedBox(height: 22),
          _TeamsTable(title: 'Team Directory', teams: filteredTeams, selectedTeamId: selectedTeam?.id, summaries: {for (final team in teams) team.id: _TeamSummary.fromPayload(team, payload)}, onSelected: (team) => setState(() => selectedTeamId = team.id)),
          const SizedBox(height: 22),
          const _TeamProfileViewMatrix(),
          const SizedBox(height: 22),
          const _TeamMetricPackageMatrix(),
          const SizedBox(height: 22),
          const _TeamActionRouteMatrix(),
          const SizedBox(height: 22),
          _TeamAttachmentMap(payload: payload),
          const SizedBox(height: 22),
          _TeamStatsReadinessTable(stats: payload.stats),
          const SizedBox(height: 22),
          _TeamCommandStageTable(items: filteredStages),
        ]);
      },
    );
  }
}

class _TeamPayload { const _TeamPayload({required this.teams, required this.stats, required this.standings, required this.playoffs, required this.games, required this.rosters, required this.awards, required this.draftPicks, required this.transactions}); final List<Team> teams; final List<TeamSeasonStat> stats; final List<StandingsRecord> standings; final List<PlayoffSeriesRecord> playoffs; final List<GameRecord> games; final List<RosterEntry> rosters; final List<AwardRecord> awards; final List<DraftPick> draftPicks; final List<TransactionRecord> transactions; }
class _TeamProfileView { const _TeamProfileView(this.name, this.status, this.description); final String name; final String status; final String description; }
class _TeamMetricPackage { const _TeamMetricPackage(this.name, this.status, this.fields, this.use); final String name; final String status; final String fields; final String use; }
class _TeamActionRoute { const _TeamActionRoute(this.name, this.status, this.target, this.use); final String name; final String status; final String target; final String use; }
class _TeamSummary { const _TeamSummary({required this.team, required this.statRows, required this.standingsRows, required this.playoffRows, required this.gameRows, required this.rosterRows, required this.awardRows, required this.draftRows, required this.transactionRows, required this.bestWinPct, required this.bestNetRating, required this.latestSeasonId}); factory _TeamSummary.fromPayload(Team team, _TeamPayload payload) { final stats = payload.stats.where((item) => item.teamId == team.id).toList()..sort((a, b) => b.seasonId.compareTo(a.seasonId)); final winPcts = stats.map((item) => item.winPercentage).whereType<double>().toList()..sort((a, b) => b.compareTo(a)); final nets = stats.map((item) => item.netRating).whereType<double>().toList()..sort((a, b) => b.compareTo(a)); final playoffRows = payload.playoffs.where((item) => item.winningTeamId == team.id || item.losingTeamId == team.id).length; final gameRows = payload.games.where((item) => item.homeTeamId == team.id || item.awayTeamId == team.id).length; final txRows = payload.transactions.where((item) => item.fromTeamId == team.id || item.toTeamId == team.id).length; return _TeamSummary(team: team, statRows: stats.length, standingsRows: payload.standings.where((item) => item.teamId == team.id).length, playoffRows: playoffRows, gameRows: gameRows, rosterRows: payload.rosters.where((item) => item.teamId == team.id).length, awardRows: payload.awards.where((item) => item.teamId == team.id).length, draftRows: payload.draftPicks.where((item) => item.teamId == team.id).length, transactionRows: txRows, bestWinPct: winPcts.isEmpty ? null : winPcts.first, bestNetRating: nets.isEmpty ? null : nets.first, latestSeasonId: stats.isEmpty ? null : stats.first.seasonId); } final Team team; final int statRows; final int standingsRows; final int playoffRows; final int gameRows; final int rosterRows; final int awardRows; final int draftRows; final int transactionRows; final double? bestWinPct; final double? bestNetRating; final String? latestSeasonId; int get connectedSections => [statRows, standingsRows, playoffRows, gameRows, rosterRows, awardRows, draftRows, transactionRows].where((count) => count > 0).length; }

const _teamProfileViews = <_TeamProfileView>[
  _TeamProfileView('Identity', 'Connected', 'Team name, city, abbreviation, conference, division, internal ID, and reference asset status.'),
  _TeamProfileView('Season Stats', 'Planned', 'Team-season records, scoring, pace, ORtg, DRtg, net rating, shooting, turnovers, rebounding, assists, steals, blocks, and PF.'),
  _TeamProfileView('Standings', 'Planned', 'Seed, conference/division standing, wins, losses, win percentage, games back, and playoff qualification.'),
  _TeamProfileView('Playoff Path', 'Planned', 'Playoff series as winner/loser, round, opponent, seeds, games played, series results, and championship path.'),
  _TeamProfileView('Roster Construction', 'Planned', 'Roster windows, player-team history, contract type later, two-way status, assignments, recalls, and eligibility.'),
  _TeamProfileView('Draft and Transactions', 'Future', 'Draft picks, incoming/outgoing movement, trade trees, signings, waivers, and roster effects.'),
  _TeamProfileView('Contracts and Cap', 'Future', 'Salary, guarantees, options, extensions, cap sheet, payroll, tax context, and contract-linked movement.'),
  _TeamProfileView('Fantasy and Scouting Context', 'Future', 'Team schedule density, depth chart context, role changes, player development, and scouting notes.'),
];
const _teamMetricPackages = <_TeamMetricPackage>[
  _TeamMetricPackage('Fundamental', 'First', 'W, L, Win%, PPG, Opp PPG, RPG, APG, SPG, BPG, TOV, PF', 'Core team tables, compare, reports, standings, fantasy, and season command.'),
  _TeamMetricPackage('Efficiency', 'Planned', 'FG%, 3P%, FT%, eFG%, TS%, pace, possession context, points per possession later', 'Team quality, era context, and trend views.'),
  _TeamMetricPackage('Advanced Ratings', 'Planned', 'ORtg, DRtg, Net Rating, pace, lineup ratings later, opponent shot profile later', 'Team power analysis and franchise-era comparisons.'),
  _TeamMetricPackage('Context', 'Planned', 'Seed, standings, playoff round, roster window, award context, draft class, movement history', 'Adds environment to team-season stats.'),
  _TeamMetricPackage('Front Office', 'Future', 'Contracts, cap sheet, guarantees, options, extensions, draft rights, transaction effects', 'Roster construction and trade-tree work.'),
  _TeamMetricPackage('Source Audit', 'Planned', 'Source, as-of date, missing fields, lineage, rights posture, validation state', 'Trust and governance workflows.'),
];
const _teamActionRoutes = <_TeamActionRoute>[
  _TeamActionRoute('Compare', 'Planned', 'Compare', 'Send selected team rows into team-season, playoff path, franchise-era, roster construction, or draft history comparison.'),
  _TeamActionRoute('Workspace', 'Planned', 'Workspace Studio', 'Send team rows, metric packages, standings, rosters, playoff paths, and movement context into custom tables.'),
  _TeamActionRoute('Report', 'Planned', 'Reports', 'Generate Team Season Report, Franchise History Report, Roster Construction Report, or Source Audit Report.'),
  _TeamActionRoute('Save View', 'Planned', 'Saved Views', 'Persist team filters, selected metrics, season windows, source snapshots, and output intent.'),
  _TeamActionRoute('Alert', 'Future', 'Alerts', 'Monitor standings movement, team threshold changes, roster changes, transaction activity, and source changes.'),
  _TeamActionRoute('Export', 'Planned', 'Export Center', 'Export team report, team table, saved view, roster board, or source audit with missing-data flags.'),
  _TeamActionRoute('Fantasy', 'Future', 'Fantasy Terminal', 'Send team context into schedule density, depth chart, roster role, and matchup workflows.'),
  _TeamActionRoute('Audit Source', 'Planned', 'Source Operations', 'Inspect team profile and team stat provenance, source freshness, and rights posture.'),
];

Map<String, int> _countsBy(List<Team> teams, String Function(Team team) selector) { final counts = <String, int>{}; for (final team in teams) { final key = selector(team); counts[key] = (counts[key] ?? 0) + 1; } return counts; }
String _pct(double? value) => value == null ? '—' : value <= 1 ? '${(value * 100).toStringAsFixed(1)}%' : '${value.toStringAsFixed(1)}%';
InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));
class _FilterDropdown extends StatelessWidget { const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged}); final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; @override Widget build(BuildContext context) => SizedBox(width: 235, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); }

class _TeamCommandTicket extends StatelessWidget { const _TeamCommandTicket({required this.profileView, required this.metricPackage, required this.actionRoute, required this.summary, required this.payload}); final _TeamProfileView profileView; final _TeamMetricPackage metricPackage; final _TeamActionRoute actionRoute; final _TeamSummary? summary; final _TeamPayload payload; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Team Command Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), const Text('This is the team-page operating model: pick a team view, choose a metric package, bind an action route, check source readiness, and keep source-pending values blank until real team context is loaded.', style: TextStyle(color: terminalTextSoft, height: 1.45)), const SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: profileView.status), InfoPill(label: metricPackage.status), InfoPill(label: actionRoute.status), InfoPill(label: 'Teams connected'), InfoPill(label: '${actionSurfaceItems.length} action hooks')]), const SizedBox(height: 14), _DetailLine(label: 'Selected Team', value: summary == null ? 'No selected team yet' : '${summary!.team.city} ${summary!.team.name}'), _DetailLine(label: 'Profile View', value: '${profileView.name}: ${profileView.description}'), _DetailLine(label: 'Metric Package', value: '${metricPackage.name}: ${metricPackage.fields}'), _DetailLine(label: 'Action Route', value: '${actionRoute.name} → ${actionRoute.target}. ${actionRoute.use}'), _DetailLine(label: 'Readiness', value: summary == null ? 'No team selected.' : '${summary!.connectedSections}/8 selected-team attachment sections connected.') ])); }

class _ConferenceDivisionPanel extends StatelessWidget { const _ConferenceDivisionPanel({required this.conferenceCounts, required this.divisionCounts}); final Map<String, int> conferenceCounts; final Map<String, int> divisionCounts; @override Widget build(BuildContext context) { final sortedDivisions = divisionCounts.keys.toList()..sort(); return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('League Structure', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [for (final entry in conferenceCounts.entries) _StructureChip(label: entry.key, value: entry.value)]), const SizedBox(height: 16), const Text('Divisions', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700)), const SizedBox(height: 10), Wrap(spacing: 10, runSpacing: 10, children: [for (final division in sortedDivisions) _StructureChip(label: division, value: divisionCounts[division] ?? 0)])])); } }
class _SelectedTeamPanel extends StatelessWidget { const _SelectedTeamPanel({required this.summary, required this.metricPackage, required this.actionRoute}); final _TeamSummary? summary; final String metricPackage; final String actionRoute; @override Widget build(BuildContext context) { if (summary == null) return const TerminalCard(child: Text('Select a team from the table to inspect its reference record.', style: TextStyle(color: terminalTextSoft))); final team = summary!.team; return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Selected Team', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 14), Text(team.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('${team.city} • ${team.abbreviation}', style: const TextStyle(color: terminalTextSoft, fontSize: 14)), const SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: team.conference), InfoPill(label: team.division), const InfoPill(label: 'Reference asset'), InfoPill(label: metricPackage), InfoPill(label: actionRoute), InfoPill(label: '${summary!.connectedSections}/8 sections')]), const SizedBox(height: 16), _DetailLine(label: 'Internal ID', value: team.id), _DetailLine(label: 'Latest Season', value: summary!.latestSeasonId ?? '—'), _DetailLine(label: 'Best Win%', value: _pct(summary!.bestWinPct)), _DetailLine(label: 'Best Net', value: summary!.bestNetRating?.toStringAsFixed(1) ?? '—'), const SizedBox(height: 14), LayoutBuilder(builder: (context, constraints) { final isWide = constraints.maxWidth > 420; return GridView.count(crossAxisCount: isWide ? 2 : 1, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: isWide ? 2.2 : 3.4, children: [_MiniBadge(label: 'Stats', value: '${summary!.statRows}', detail: 'Team seasons'), _MiniBadge(label: 'Standings', value: '${summary!.standingsRows}', detail: 'Seed/record'), _MiniBadge(label: 'Playoffs', value: '${summary!.playoffRows}', detail: 'Series rows'), _MiniBadge(label: 'Games', value: '${summary!.gameRows}', detail: 'Schedule/results'), _MiniBadge(label: 'Rosters', value: '${summary!.rosterRows}', detail: 'Player-team rows'), _MiniBadge(label: 'Awards', value: '${summary!.awardRows}', detail: 'Recognition'), _MiniBadge(label: 'Draft', value: '${summary!.draftRows}', detail: 'Picks'), _MiniBadge(label: 'Moves', value: '${summary!.transactionRows}', detail: 'Transactions')]); })])); } }
class _StructureChip extends StatelessWidget { const _StructureChip({required this.label, required this.value}); final String label; final int value; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(999), border: Border.all(color: terminalBorder)), child: Text('$label  $value', style: const TextStyle(color: Color(0xFFDDE6F1), fontWeight: FontWeight.w700))); }
class _MiniBadge extends StatelessWidget { const _MiniBadge({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: terminalBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w700)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), Text(detail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalAccent, fontSize: 11))])); } }
class _DetailLine extends StatelessWidget { const _DetailLine({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))])); }

class _TeamsTable extends StatelessWidget { const _TeamsTable({required this.title, required this.teams, required this.selectedTeamId, required this.summaries, required this.onSelected}); final String title; final List<Team> teams; final String? selectedTeamId; final Map<String, _TeamSummary> summaries; final ValueChanged<Team> onSelected; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${teams.length} teams', style: const TextStyle(color: terminalTextMuted, fontSize: 13))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), dataRowMinHeight: 48, dataRowMaxHeight: 54, headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 34, columns: const [DataColumn(label: Text('Team')), DataColumn(label: Text('Abbrev.')), DataColumn(label: Text('City')), DataColumn(label: Text('Conference')), DataColumn(label: Text('Division')), DataColumn(label: Text('Linked')), DataColumn(label: Text('Stats')), DataColumn(label: Text('Best Win%')), DataColumn(label: Text('Best Net')), DataColumn(label: Text('Rosters')), DataColumn(label: Text('Source'))], rows: [for (final team in teams) DataRow(selected: selectedTeamId == team.id, onSelectChanged: (_) => onSelected(team), cells: [DataCell(SizedBox(width: 240, child: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text(team.abbreviation)), DataCell(SizedBox(width: 160, child: Text(team.city))), DataCell(Text(team.conference)), DataCell(Text(team.division)), DataCell(InfoPill(label: '${summaries[team.id]?.connectedSections ?? 0}/8')), DataCell(Text('${summaries[team.id]?.statRows ?? 0}')), DataCell(Text(_pct(summaries[team.id]?.bestWinPct))), DataCell(Text(summaries[team.id]?.bestNetRating?.toStringAsFixed(1) ?? '—')), DataCell(Text('${summaries[team.id]?.rosterRows ?? 0}')), const DataCell(InfoPill(label: 'JSON asset'))])]))])); }

class _TeamProfileViewMatrix extends StatelessWidget { const _TeamProfileViewMatrix(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Team Profile View Modes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('View')), DataColumn(label: Text('Status')), DataColumn(label: Text('Use'))], rows: [for (final item in _teamProfileViews) DataRow(cells: [DataCell(SizedBox(width: 250, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 850, child: Text(item.description)))])]))])); }
class _TeamMetricPackageMatrix extends StatelessWidget { const _TeamMetricPackageMatrix(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Team Metric Package Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Package')), DataColumn(label: Text('Status')), DataColumn(label: Text('Fields')), DataColumn(label: Text('Use'))], rows: [for (final item in _teamMetricPackages) DataRow(cells: [DataCell(SizedBox(width: 210, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 640, child: Text(item.fields))), DataCell(SizedBox(width: 540, child: Text(item.use)))])]))])); }
class _TeamActionRouteMatrix extends StatelessWidget { const _TeamActionRouteMatrix(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Team Action Route Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Action')), DataColumn(label: Text('Status')), DataColumn(label: Text('Target')), DataColumn(label: Text('Use'))], rows: [for (final item in _teamActionRoutes) DataRow(cells: [DataCell(SizedBox(width: 190, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 210, child: Text(item.target))), DataCell(SizedBox(width: 760, child: Text(item.use)))])]))])); }
class _TeamAttachmentMap extends StatelessWidget { const _TeamAttachmentMap({required this.payload}); final _TeamPayload payload; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Team Data Attachment Map', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Layer')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Join Key')), DataColumn(label: Text('Status')), DataColumn(label: Text('MVP Use'))], rows: [_attachmentRow('Team Reference', payload.teams.length, 'teamId', payload.teams.isEmpty ? 'Source pending' : 'Connected', 'Identity, detail pages, search, reports'), _attachmentRow('Team Season Stats', payload.stats.length, 'teamId + seasonId', payload.stats.isEmpty ? 'Source pending' : 'Connected', 'Stats, comparisons, rankings, reports'), _attachmentRow('Standings', payload.standings.length, 'teamId + seasonId', payload.standings.isEmpty ? 'Source pending' : 'Connected', 'Seed, record, playoff context'), _attachmentRow('Playoffs', payload.playoffs.length, 'winningTeamId / losingTeamId', payload.playoffs.isEmpty ? 'Source pending' : 'Connected', 'Series paths and postseason context'), _attachmentRow('Games', payload.games.length, 'homeTeamId / awayTeamId', payload.games.isEmpty ? 'Source pending' : 'Connected', 'Schedule, results, matchup context'), _attachmentRow('Rosters', payload.rosters.length, 'teamId + seasonId', payload.rosters.isEmpty ? 'Source pending' : 'Connected', 'Roster construction and eligibility'), _attachmentRow('Awards', payload.awards.length, 'teamId + seasonId', payload.awards.isEmpty ? 'Source pending' : 'Connected', 'Recognition and voting context'), _attachmentRow('Draft Picks', payload.draftPicks.length, 'teamId + draftYear', payload.draftPicks.isEmpty ? 'Source pending' : 'Connected', 'Draft class and franchise history'), _attachmentRow('Transactions', payload.transactions.length, 'fromTeamId / toTeamId', payload.transactions.isEmpty ? 'Source pending' : 'Connected', 'Movement timeline and team-building context')])]))); DataRow _attachmentRow(String layer, int rows, String joinKey, String status, String use) => DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(layer, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(Text('$rows')), DataCell(SizedBox(width: 260, child: Text(joinKey))), DataCell(InfoPill(label: status)), DataCell(SizedBox(width: 560, child: Text(use)))]); }
class _TeamStatsReadinessTable extends StatelessWidget { const _TeamStatsReadinessTable({required this.stats}); final List<TeamSeasonStat> stats; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Team Season Stats Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${stats.length} rows', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columns: const [DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Type')), DataColumn(label: Text('W')), DataColumn(label: Text('L')), DataColumn(label: Text('Win%')), DataColumn(label: Text('PPG')), DataColumn(label: Text('Opp PPG')), DataColumn(label: Text('Pace')), DataColumn(label: Text('ORtg')), DataColumn(label: Text('DRtg')), DataColumn(label: Text('Net')), DataColumn(label: Text('PF')), DataColumn(label: Text('FG%')), DataColumn(label: Text('3P%')), DataColumn(label: Text('FT%')), DataColumn(label: Text('eFG%')), DataColumn(label: Text('TS%')), DataColumn(label: Text('TOV')), DataColumn(label: Text('REB')), DataColumn(label: Text('AST')), DataColumn(label: Text('STL')), DataColumn(label: Text('BLK')), DataColumn(label: Text('Source'))], rows: stats.isEmpty ? const [DataRow(cells: [DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('Pending source'))])] : [for (final stat in stats) DataRow(cells: [DataCell(Text(stat.teamId)), DataCell(Text(stat.seasonId)), DataCell(Text(stat.seasonType ?? '—')), DataCell(Text(stat.wins?.toString() ?? '—')), DataCell(Text(stat.losses?.toString() ?? '—')), DataCell(Text(_pct(stat.winPercentage))), DataCell(Text(stat.pointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.opponentPointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.pace?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.offensiveRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.defensiveRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.netRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.personalFoulsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(_pct(stat.fieldGoalPercentage))), DataCell(Text(_pct(stat.threePointPercentage))), DataCell(Text(_pct(stat.freeThrowPercentage))), DataCell(Text(_pct(stat.effectiveFieldGoalPercentage))), DataCell(Text(_pct(stat.trueShootingPercentage))), DataCell(Text(stat.turnoversPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.reboundsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.assistsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.stealsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.blocksPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(stat.sourceId ?? '—'))])]))])); }
class _TeamCommandStageTable extends StatelessWidget { const _TeamCommandStageTable({required this.items}); final List<RegistryItem> items; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Team Command Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 360, child: Text(item.inputs))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])]))])); }
class _TeamMetric extends StatelessWidget { const _TeamMetric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
class _LoadingState extends StatelessWidget { const _LoadingState(); @override Widget build(BuildContext context) => const TerminalCard(child: Text('Loading team command workspace...', style: TextStyle(color: terminalTextSoft))); }
class _ErrorState extends StatelessWidget { const _ErrorState({required this.message}); final String message; @override Widget build(BuildContext context) => TerminalCard(child: Text('Unable to load team command workspace: $message', style: const TextStyle(color: terminalTextSoft))); }
