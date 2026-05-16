import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final repository = const NbaAssetRepository();
  late final Future<_PlayerPayload> payloadFuture = _loadPayload();
  String query = '';
  String selectedStatus = 'All';

  Future<_PlayerPayload> _loadPayload() async {
    final players = await repository.loadPlayerProfiles();
    final stats = await repository.loadPlayerSeasonStats();
    return _PlayerPayload(players: players, stats: stats);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayerPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading player workspace...', style: TextStyle(color: terminalTextSoft)));
        }

        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load player workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final payload = snapshot.data ?? const _PlayerPayload(players: [], stats: []);
        final filteredPlayers = payload.players.where((player) {
          final normalized = query.trim().toLowerCase();
          final matchesStatus = selectedStatus == 'All' || (selectedStatus == 'Active' && player.isActive == true) || (selectedStatus == 'Inactive' && player.isActive == false) || (selectedStatus == 'Unknown' && player.isActive == null);
          final matchesQuery = normalized.isEmpty ||
              player.displayName.toLowerCase().contains(normalized) ||
              (player.position ?? '').toLowerCase().contains(normalized) ||
              (player.primaryTeamAbbreviation ?? '').toLowerCase().contains(normalized) ||
              (player.college ?? '').toLowerCase().contains(normalized) ||
              (player.birthCountry ?? '').toLowerCase().contains(normalized);
          return matchesStatus && matchesQuery;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Players',
              subtitle: 'Asset-backed player workspace. Player identity and traditional season stats are schema-ready, with empty source-aware assets until real records are connected.',
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
                    _Metric(label: 'Player Profiles', value: '${payload.players.length}', detail: 'Real source pending'),
                    _Metric(label: 'Season Stat Rows', value: '${payload.stats.length}', detail: 'Traditional stats asset'),
                    _Metric(label: 'Filtered', value: '${filteredPlayers.length}', detail: 'Current view'),
                    const _Metric(label: 'Policy', value: 'Blank', detail: 'No fake player data'),
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
                    width: 340,
                    child: TextField(
                      onChanged: (value) => setState(() => query = value),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: terminalAccent,
                      decoration: _inputDecoration('Search player, team, college, country...'),
                    ),
                  ),
                  _FilterDropdown(
                    label: 'Status',
                    value: selectedStatus,
                    values: const ['All', 'Active', 'Inactive', 'Unknown'],
                    onChanged: (value) => setState(() => selectedStatus = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (payload.players.isEmpty)
              const _PendingPlayersPanel()
            else
              _PlayersTable(players: filteredPlayers),
            const SizedBox(height: 22),
            _StatsReadinessTable(stats: payload.stats),
          ],
        );
      },
    );
  }
}

class _PlayerPayload {
  const _PlayerPayload({required this.players, required this.stats});

  final List<PlayerProfile> players;
  final List<PlayerSeasonStat> stats;
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
        width: 220,
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

class _PendingPlayersPanel extends StatelessWidget {
  const _PendingPlayersPanel();

  @override
  Widget build(BuildContext context) {
    return const TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Player Identity Source Pending', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 10),
          Text('No fake players are displayed. The player profile asset is connected, but currently empty. Once a lawful official-source-preferred player identity export is selected, this screen will immediately support searchable player profiles and linked season stat rows.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
        ],
      ),
    );
  }
}

class _PlayersTable extends StatelessWidget {
  const _PlayersTable({required this.players});
  final List<PlayerProfile> players;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(terminalPanelDark),
          headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
          dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
          columns: const [
            DataColumn(label: Text('Player')),
            DataColumn(label: Text('Position')),
            DataColumn(label: Text('Team')),
            DataColumn(label: Text('College')),
            DataColumn(label: Text('Country')),
            DataColumn(label: Text('Draft')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Source')),
          ],
          rows: [
            for (final player in players)
              DataRow(cells: [
                DataCell(SizedBox(width: 220, child: Text(player.displayName, style: const TextStyle(fontWeight: FontWeight.w800)))),
                DataCell(Text(player.position ?? '—')),
                DataCell(Text(player.primaryTeamAbbreviation ?? '—')),
                DataCell(SizedBox(width: 180, child: Text(player.college ?? '—'))),
                DataCell(Text(player.birthCountry ?? '—')),
                DataCell(Text(player.draftYear == null ? '—' : '${player.draftYear} / R${player.draftRound ?? '-'} / P${player.draftPick ?? '-'}')),
                DataCell(InfoPill(label: player.isActive == true ? 'Active' : player.isActive == false ? 'Inactive' : 'Unknown')),
                DataCell(Text(player.sourceId ?? '—')),
              ]),
          ],
        ),
      ),
    );
  }
}

class _StatsReadinessTable extends StatelessWidget {
  const _StatsReadinessTable({required this.stats});
  final List<PlayerSeasonStat> stats;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Player Season Stats Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${stats.length} rows', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columns: const [
              DataColumn(label: Text('Player')),
              DataColumn(label: Text('Team')),
              DataColumn(label: Text('Season')),
              DataColumn(label: Text('GP')),
              DataColumn(label: Text('MPG')),
              DataColumn(label: Text('PPG')),
              DataColumn(label: Text('RPG')),
              DataColumn(label: Text('APG')),
              DataColumn(label: Text('Source')),
            ],
            rows: stats.isEmpty
                ? const [DataRow(cells: [DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('Pending source'))])]
                : [
                    for (final stat in stats)
                      DataRow(cells: [
                        DataCell(Text(stat.playerId)),
                        DataCell(Text(stat.teamId ?? '—')),
                        DataCell(Text(stat.seasonId)),
                        DataCell(Text(stat.gamesPlayed?.toString() ?? '—')),
                        DataCell(Text(stat.minutesPerGame?.toStringAsFixed(1) ?? '—')),
                        DataCell(Text(stat.pointsPerGame?.toStringAsFixed(1) ?? '—')),
                        DataCell(Text(stat.reboundsPerGame?.toStringAsFixed(1) ?? '—')),
                        DataCell(Text(stat.assistsPerGame?.toStringAsFixed(1) ?? '—')),
                        DataCell(Text(stat.sourceId ?? '—')),
                      ]),
                  ],
          ),
        ),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
