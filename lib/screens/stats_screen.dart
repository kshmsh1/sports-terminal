import 'package:flutter/material.dart';

import '../models/player_season_stat.dart';
import '../models/team_season_stat.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_StatsPayload> payloadFuture = _loadPayload();
  String query = '';
  String selectedTable = 'All';

  Future<_StatsPayload> _loadPayload() async {
    final playerStats = await repository.loadPlayerSeasonStats();
    final teamStats = await repository.loadTeamSeasonStats();
    return _StatsPayload(playerStats: playerStats, teamStats: teamStats);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StatsPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading statistics workspace...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load statistics workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final payload = snapshot.data ?? const _StatsPayload(playerStats: [], teamStats: []);
        final showPlayers = selectedTable == 'All' || selectedTable == 'Player season stats';
        final showTeams = selectedTable == 'All' || selectedTable == 'Team season stats';
        final normalized = query.trim().toLowerCase();
        final playerRows = payload.playerStats.where((row) {
          if (normalized.isEmpty) return true;
          return [row.playerId, row.teamId, row.seasonId, row.seasonType, row.sourceId].whereType<String>().join(' ').toLowerCase().contains(normalized);
        }).toList();
        final teamRows = payload.teamStats.where((row) {
          if (normalized.isEmpty) return true;
          return [row.teamId, row.seasonId, row.seasonType, row.sourceId].whereType<String>().join(' ').toLowerCase().contains(normalized);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Stats',
              subtitle: 'Central statistical workspace for player-season and team-season tables, built around normalized assets and strict null-versus-zero handling.',
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
                    _Metric(label: 'Player Stat Rows', value: '${payload.playerStats.length}', detail: 'Traditional season table'),
                    _Metric(label: 'Team Stat Rows', value: '${payload.teamStats.length}', detail: 'Team season table'),
                    _Metric(label: 'Visible Player Rows', value: '${showPlayers ? playerRows.length : 0}', detail: 'Filtered view'),
                    _Metric(label: 'Visible Team Rows', value: '${showTeams ? teamRows.length : 0}', detail: 'Filtered view'),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            TerminalCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      onChanged: (value) => setState(() => query = value),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: terminalAccent,
                      decoration: _inputDecoration('Search player, team, season, source...'),
                    ),
                  ),
                  _FilterDropdown(
                    label: 'Table',
                    value: selectedTable,
                    values: const ['All', 'Player season stats', 'Team season stats'],
                    onChanged: (value) => setState(() => selectedTable = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const TerminalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Statistics Design Rule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 10),
                  Text('This page intentionally treats unavailable data as blank. A zero should only appear when the source record says the value was truly zero. That rule matters before we ingest historical player and team tables.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (showPlayers) _PlayerStatsTable(records: playerRows),
            if (showPlayers && showTeams) const SizedBox(height: 22),
            if (showTeams) _TeamStatsTable(records: teamRows),
          ],
        );
      },
    );
  }
}

class _StatsPayload {
  const _StatsPayload({required this.playerStats, required this.teamStats});

  final List<PlayerSeasonStat> playerStats;
  final List<TeamSeasonStat> teamStats;
}

InputDecoration _inputDecoration(String hintText) => InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: terminalTextMuted),
      prefixIcon: const Icon(Icons.search, color: terminalTextMuted),
      filled: true,
      fillColor: terminalPanelDark,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
    );

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged});

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        child: DropdownButtonFormField<String>(
          value: value,
          dropdownColor: terminalPanelDark,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))),
          items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: (value) { if (value != null) onChanged(value); },
        ),
      );
}

class _PlayerStatsTable extends StatelessWidget {
  const _PlayerStatsTable({required this.records});
  final List<PlayerSeasonStat> records;

  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Player Season Stats', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])),
          const Divider(height: 1, color: terminalBorder),
          records.isEmpty
              ? const Padding(padding: EdgeInsets.all(18), child: Text('Player season stats source pending. No fake stat rows are displayed.', style: TextStyle(color: terminalTextSoft)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                    headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                    dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                    columns: const [DataColumn(label: Text('Player')), DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Type')), DataColumn(label: Text('GP')), DataColumn(label: Text('MPG')), DataColumn(label: Text('PPG')), DataColumn(label: Text('RPG')), DataColumn(label: Text('APG')), DataColumn(label: Text('STL')), DataColumn(label: Text('BLK')), DataColumn(label: Text('TOV')), DataColumn(label: Text('Source'))],
                    rows: [for (final row in records) DataRow(cells: [DataCell(Text(row.playerId)), DataCell(Text(row.teamId ?? '—')), DataCell(Text(row.seasonId)), DataCell(Text(row.seasonType ?? '—')), DataCell(Text(row.gamesPlayed?.toString() ?? '—')), DataCell(Text(row.minutesPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.pointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.reboundsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.assistsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.stealsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.blocksPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.turnoversPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.sourceId ?? '—'))])],
                  ),
                ),
        ]),
      );
}

class _TeamStatsTable extends StatelessWidget {
  const _TeamStatsTable({required this.records});
  final List<TeamSeasonStat> records;

  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Team Season Stats', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])),
          const Divider(height: 1, color: terminalBorder),
          records.isEmpty
              ? const Padding(padding: EdgeInsets.all(18), child: Text('Team season stats source pending. No fake stat rows are displayed.', style: TextStyle(color: terminalTextSoft)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                    headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                    dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                    columns: const [DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Type')), DataColumn(label: Text('W')), DataColumn(label: Text('L')), DataColumn(label: Text('Win %')), DataColumn(label: Text('PPG')), DataColumn(label: Text('Opp PPG')), DataColumn(label: Text('Pace')), DataColumn(label: Text('ORtg')), DataColumn(label: Text('DRtg')), DataColumn(label: Text('Net')), DataColumn(label: Text('Source'))],
                    rows: [for (final row in records) DataRow(cells: [DataCell(Text(row.teamId)), DataCell(Text(row.seasonId)), DataCell(Text(row.seasonType ?? '—')), DataCell(Text(row.wins?.toString() ?? '—')), DataCell(Text(row.losses?.toString() ?? '—')), DataCell(Text(row.winPercentage?.toStringAsFixed(3) ?? '—')), DataCell(Text(row.pointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.opponentPointsPerGame?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.pace?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.offensiveRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.defensiveRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.netRating?.toStringAsFixed(1) ?? '—')), DataCell(Text(row.sourceId ?? '—'))])],
                  ),
                ),
        ]),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
