import 'package:flutter/material.dart';

import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/game_record.dart';
import '../models/playoff_series_record.dart';
import '../models/season.dart';
import '../models/standings_record.dart';
import '../models/team.dart';
import '../models/team_season_stat.dart';
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SeasonPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading season command workspace...', style: TextStyle(color: terminalTextSoft)));
        }

        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load season command workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final payload = snapshot.data ?? const _SeasonPayload(seasons: [], teams: [], standings: [], teamStats: [], playoffs: [], awards: [], draftPicks: [], games: []);
        final seasons = payload.seasons;
        final baaSeasons = seasons.where((season) => season.league == 'BAA').length;
        final nbaOnlySeasons = seasons.length - baaSeasons;
        final filteredSeasons = seasons.where((season) {
          final normalizedQuery = query.trim().toLowerCase();
          final matchesLeague = selectedLeague == 'All' || season.league == selectedLeague;
          final matchesQuery = normalizedQuery.isEmpty ||
              season.id.toLowerCase().contains(normalizedQuery) ||
              season.label.toLowerCase().contains(normalizedQuery) ||
              season.startYear.toString().contains(normalizedQuery) ||
              season.endYear.toString().contains(normalizedQuery) ||
              season.league.toLowerCase().contains(normalizedQuery);
          return matchesLeague && matchesQuery;
        }).toList();

        final selectedSeason = _resolveSelectedSeason(filteredSeasons, seasons);
        final selectedSummary = selectedSeason == null ? null : _SeasonSummary.fromPayload(selectedSeason, payload);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'NBA Seasons',
              subtitle: seasons.isEmpty
                  ? 'Historical NBA/BAA season catalog loaded from normalized JSON assets.'
                  : 'Historical season command workspace from ${seasons.last.label} through ${seasons.first.label}, with coverage checks for standings, stats, playoffs, awards, draft, and games.',
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isWide ? 2.0 : 1.5,
                  children: [
                    _SeasonMetric(label: 'Configured Seasons', value: '${seasons.length}', detail: 'Loaded from JSON asset'),
                    _SeasonMetric(label: 'NBA Seasons', value: '$nbaOnlySeasons', detail: 'Post-BAA naming era'),
                    _SeasonMetric(label: 'BAA Seasons', value: '$baaSeasons', detail: 'Pre-NBA naming era'),
                    _SeasonMetric(label: 'Filtered', value: '${filteredSeasons.length}', detail: 'Current view'),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            TerminalCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: selectedLeague,
                      dropdownColor: terminalPanelDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'League',
                        labelStyle: const TextStyle(color: terminalTextMuted),
                        filled: true,
                        fillColor: terminalPanelDark,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
                      ),
                      items: const ['All', 'NBA', 'BAA'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => selectedLeague = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (selectedSummary != null) ...[
              _SelectedSeasonPanel(summary: selectedSummary, totalTeams: payload.teams.length),
              const SizedBox(height: 22),
            ],
            _SeasonsTable(
              seasons: filteredSeasons,
              selectedSeasonId: selectedSeason?.id,
              onSelected: (season) => setState(() => selectedSeasonId = season.id),
              summaries: {for (final season in seasons) season.id: _SeasonSummary.fromPayload(season, payload)},
            ),
          ],
        );
      },
    );
  }

  Season? _resolveSelectedSeason(List<Season> filtered, List<Season> all) {
    if (filtered.isEmpty && all.isEmpty) return null;
    for (final season in filtered) {
      if (season.id == selectedSeasonId) return season;
    }
    for (final season in all) {
      if (season.id == selectedSeasonId) return season;
    }
    if (filtered.isNotEmpty) return filtered.first;
    return all.first;
  }
}

class _SeasonPayload {
  const _SeasonPayload({required this.seasons, required this.teams, required this.standings, required this.teamStats, required this.playoffs, required this.awards, required this.draftPicks, required this.games});

  final List<Season> seasons;
  final List<Team> teams;
  final List<StandingsRecord> standings;
  final List<TeamSeasonStat> teamStats;
  final List<PlayoffSeriesRecord> playoffs;
  final List<AwardRecord> awards;
  final List<DraftPick> draftPicks;
  final List<GameRecord> games;
}

class _SeasonSummary {
  const _SeasonSummary({required this.season, required this.standingsRows, required this.teamStatRows, required this.playoffSeriesRows, required this.awardRows, required this.draftRows, required this.gameRows});

  factory _SeasonSummary.fromPayload(Season season, _SeasonPayload payload) {
    return _SeasonSummary(
      season: season,
      standingsRows: payload.standings.where((item) => item.seasonId == season.id).length,
      teamStatRows: payload.teamStats.where((item) => item.seasonId == season.id).length,
      playoffSeriesRows: payload.playoffs.where((item) => item.seasonId == season.id).length,
      awardRows: payload.awards.where((item) => item.seasonId == season.id).length,
      draftRows: payload.draftPicks.where((item) => item.draftYear == season.startYear).length,
      gameRows: payload.games.where((item) => item.seasonId == season.id).length,
    );
  }

  final Season season;
  final int standingsRows;
  final int teamStatRows;
  final int playoffSeriesRows;
  final int awardRows;
  final int draftRows;
  final int gameRows;

  int get connectedSections => [standingsRows, teamStatRows, playoffSeriesRows, awardRows, draftRows, gameRows].where((count) => count > 0).length;
}

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

class _SelectedSeasonPanel extends StatelessWidget {
  const _SelectedSeasonPanel({required this.summary, required this.totalTeams});

  final _SeasonSummary summary;
  final int totalTeams;

  @override
  Widget build(BuildContext context) {
    final season = summary.season;
    return TerminalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(season.label, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('${season.league} season covering ${season.startYear}-${season.endYear}. This selected-season panel is the first step toward a true Season Command page.', style: const TextStyle(color: terminalTextSoft, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 12),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [InfoPill(label: season.league), InfoPill(label: '${summary.connectedSections}/6 sections connected')]),
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
            children: [
              _DataBadge(label: 'Team Directory', value: '$totalTeams', detail: 'Current NBA teams loaded'),
              _DataBadge(label: 'Standings', value: '${summary.standingsRows}', detail: summary.standingsRows == 0 ? 'Source pending' : 'Rows connected'),
              _DataBadge(label: 'Team Stats', value: '${summary.teamStatRows}', detail: summary.teamStatRows == 0 ? 'Source pending' : 'Rows connected'),
              _DataBadge(label: 'Games', value: '${summary.gameRows}', detail: summary.gameRows == 0 ? 'Source pending' : 'Rows connected'),
              _DataBadge(label: 'Playoffs', value: '${summary.playoffSeriesRows}', detail: summary.playoffSeriesRows == 0 ? 'Source pending' : 'Series connected'),
              _DataBadge(label: 'Awards', value: '${summary.awardRows}', detail: summary.awardRows == 0 ? 'Source pending' : 'Rows connected'),
              _DataBadge(label: 'Draft Class', value: '${summary.draftRows}', detail: summary.draftRows == 0 ? 'Source pending' : '${season.startYear} draft rows'),
              _DataBadge(label: 'Report Hook', value: 'Ready', detail: 'Template planned'),
            ],
          );
        }),
      ]),
    );
  }
}

class _DataBadge extends StatelessWidget {
  const _DataBadge({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: terminalBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(detail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalAccent, fontSize: 12)),
        ]),
      );
}

class _SeasonMetric extends StatelessWidget {
  const _SeasonMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
        ],
      ),
    );
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
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Text('Season Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${seasons.length} seasons', style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              dataRowMinHeight: 46,
              dataRowMaxHeight: 50,
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columnSpacing: 48,
              columns: const [
                DataColumn(label: Text('Season')),
                DataColumn(label: Text('Start')),
                DataColumn(label: Text('End')),
                DataColumn(label: Text('League')),
                DataColumn(label: Text('Connected')),
                DataColumn(label: Text('Standings')),
                DataColumn(label: Text('Team Stats')),
                DataColumn(label: Text('Games')),
                DataColumn(label: Text('Playoffs')),
                DataColumn(label: Text('Awards')),
                DataColumn(label: Text('Draft')),
              ],
              rows: [
                for (final season in seasons)
                  DataRow(
                    selected: selectedSeasonId == season.id,
                    onSelectChanged: (_) => onSelected(season),
                    cells: [
                      DataCell(Text(season.label, style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text('${season.startYear}')),
                      DataCell(Text('${season.endYear}')),
                      DataCell(Text(season.league)),
                      DataCell(InfoPill(label: '${summaries[season.id]?.connectedSections ?? 0}/6')),
                      DataCell(Text('${summaries[season.id]?.standingsRows ?? 0}')),
                      DataCell(Text('${summaries[season.id]?.teamStatRows ?? 0}')),
                      DataCell(Text('${summaries[season.id]?.gameRows ?? 0}')),
                      DataCell(Text('${summaries[season.id]?.playoffSeriesRows ?? 0}')),
                      DataCell(Text('${summaries[season.id]?.awardRows ?? 0}')),
                      DataCell(Text('${summaries[season.id]?.draftRows ?? 0}')),
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
