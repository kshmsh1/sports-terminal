import 'package:flutter/material.dart';

import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/roster_entry.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../models/transaction_record.dart';
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
  String? selectedPlayerId;

  Future<_PlayerPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      repository.loadPlayerProfiles(),
      repository.loadPlayerSeasonStats(),
      repository.loadTeams(),
      repository.loadSeasons(),
      repository.loadRosters(),
      repository.loadAwards(),
      repository.loadDraftPicks(),
      repository.loadTransactions(),
    ]);

    return _PlayerPayload(
      players: results[0] as List<PlayerProfile>,
      stats: results[1] as List<PlayerSeasonStat>,
      teams: results[2] as List<Team>,
      seasons: results[3] as List<Season>,
      rosters: results[4] as List<RosterEntry>,
      awards: results[5] as List<AwardRecord>,
      draftPicks: results[6] as List<DraftPick>,
      transactions: results[7] as List<TransactionRecord>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayerPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading player command workspace...', style: TextStyle(color: terminalTextSoft)));
        }

        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load player command workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final payload = snapshot.data ?? const _PlayerPayload(players: [], stats: [], teams: [], seasons: [], rosters: [], awards: [], draftPicks: [], transactions: []);
        final filteredPlayers = payload.players.where((player) {
          final normalized = query.trim().toLowerCase();
          final matchesStatus = selectedStatus == 'All' ||
              (selectedStatus == 'Active' && player.isActive == true) ||
              (selectedStatus == 'Inactive' && player.isActive == false) ||
              (selectedStatus == 'Unknown' && player.isActive == null);
          final matchesQuery = normalized.isEmpty ||
              player.id.toLowerCase().contains(normalized) ||
              player.displayName.toLowerCase().contains(normalized) ||
              (player.position ?? '').toLowerCase().contains(normalized) ||
              (player.primaryTeamAbbreviation ?? '').toLowerCase().contains(normalized) ||
              (player.college ?? '').toLowerCase().contains(normalized) ||
              (player.birthCountry ?? '').toLowerCase().contains(normalized);
          return matchesStatus && matchesQuery;
        }).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

        final selectedPlayer = _resolveSelectedPlayer(filteredPlayers, payload.players);
        final selectedSummary = selectedPlayer == null ? null : _PlayerSummary.fromPayload(selectedPlayer, payload);
        final activeCount = payload.players.where((player) => player.isActive == true).length;
        final inactiveCount = payload.players.where((player) => player.isActive == false).length;
        final unknownCount = payload.players.where((player) => player.isActive == null).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Players',
              subtitle: 'Player command workspace for identity, season stats, rosters, awards, draft links, transactions, and source coverage. Real records only; source-pending assets stay blank.',
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
                    _Metric(label: 'Player Profiles', value: '${payload.players.length}', detail: payload.players.isEmpty ? 'Source pending' : 'Real records'),
                    _Metric(label: 'Season Stat Rows', value: '${payload.stats.length}', detail: 'Traditional stats asset'),
                    _Metric(label: 'Active / Inactive', value: '$activeCount / $inactiveCount', detail: '$unknownCount unknown'),
                    _Metric(label: 'Filtered', value: '${filteredPlayers.length}', detail: 'Current view'),
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
                      decoration: _inputDecoration('Search player, ID, team, college, country...'),
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
            if (payload.players.isEmpty) ...[
              _PendingPlayersPanel(payload: payload),
              const SizedBox(height: 22),
            ] else ...[
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 1050;
                final table = _PlayersTable(
                  players: filteredPlayers,
                  selectedPlayerId: selectedPlayer?.id,
                  onSelected: (player) => setState(() => selectedPlayerId = player.id),
                  summaries: {for (final player in payload.players) player.id: _PlayerSummary.fromPayload(player, payload)},
                );
                final detail = _SelectedPlayerPanel(summary: selectedSummary);
                if (!isWide) {
                  return Column(children: [table, const SizedBox(height: 14), detail]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: table), const SizedBox(width: 14), Expanded(flex: 2, child: detail)]);
              }),
              const SizedBox(height: 22),
            ],
            _PlayerAttachmentMap(payload: payload),
            const SizedBox(height: 22),
            _StatsReadinessTable(stats: payload.stats),
          ],
        );
      },
    );
  }

  PlayerProfile? _resolveSelectedPlayer(List<PlayerProfile> filtered, List<PlayerProfile> all) {
    for (final player in filtered) {
      if (player.id == selectedPlayerId) return player;
    }
    for (final player in all) {
      if (player.id == selectedPlayerId) return player;
    }
    if (filtered.isNotEmpty) return filtered.first;
    if (all.isNotEmpty) return all.first;
    return null;
  }
}

class _PlayerPayload {
  const _PlayerPayload({required this.players, required this.stats, required this.teams, required this.seasons, required this.rosters, required this.awards, required this.draftPicks, required this.transactions});

  final List<PlayerProfile> players;
  final List<PlayerSeasonStat> stats;
  final List<Team> teams;
  final List<Season> seasons;
  final List<RosterEntry> rosters;
  final List<AwardRecord> awards;
  final List<DraftPick> draftPicks;
  final List<TransactionRecord> transactions;
}

class _PlayerSummary {
  const _PlayerSummary({required this.player, required this.statRows, required this.rosterRows, required this.awardRows, required this.draftRows, required this.transactionRows, required this.bestPpg, required this.latestSeasonId});

  factory _PlayerSummary.fromPayload(PlayerProfile player, _PlayerPayload payload) {
    final statRows = payload.stats.where((item) => item.playerId == player.id).toList();
    statRows.sort((a, b) => b.seasonId.compareTo(a.seasonId));
    final ppgValues = statRows.map((item) => item.pointsPerGame).whereType<double>().toList();
    ppgValues.sort((a, b) => b.compareTo(a));
    return _PlayerSummary(
      player: player,
      statRows: statRows.length,
      rosterRows: payload.rosters.where((item) => item.playerId == player.id).length,
      awardRows: payload.awards.where((item) => item.playerId == player.id).length,
      draftRows: payload.draftPicks.where((item) => item.playerId == player.id || item.playerName == player.displayName).length,
      transactionRows: payload.transactions.where((item) => item.playerId == player.id || item.playerName == player.displayName).length,
      bestPpg: ppgValues.isEmpty ? null : ppgValues.first,
      latestSeasonId: statRows.isEmpty ? null : statRows.first.seasonId,
    );
  }

  final PlayerProfile player;
  final int statRows;
  final int rosterRows;
  final int awardRows;
  final int draftRows;
  final int transactionRows;
  final double? bestPpg;
  final String? latestSeasonId;

  int get connectedSections => [statRows, rosterRows, awardRows, draftRows, transactionRows].where((count) => count > 0).length;
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
  const _PendingPlayersPanel({required this.payload});
  final _PlayerPayload payload;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Player Identity Source Pending', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('No fake players are displayed. The player profile asset is connected, but currently empty. Once a lawful official-source-preferred player identity export is selected, this screen will immediately support searchable player profiles, selected-player detail, linked stat rows, roster history, awards, draft context, transactions, and report hooks.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoPill(label: '${payload.teams.length} teams ready'),
            InfoPill(label: '${payload.seasons.length} seasons ready'),
            InfoPill(label: '${payload.stats.length} stat rows'),
            InfoPill(label: '${payload.rosters.length} roster rows'),
            InfoPill(label: '${payload.awards.length} award rows'),
            InfoPill(label: '${payload.draftPicks.length} draft rows'),
          ]),
        ],
      ),
    );
  }
}

class _SelectedPlayerPanel extends StatelessWidget {
  const _SelectedPlayerPanel({required this.summary});
  final _PlayerSummary? summary;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return const TerminalCard(child: Text('Select a player to inspect profile coverage.', style: TextStyle(color: terminalTextSoft)));
    }
    final player = summary!.player;
    return TerminalCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(player.displayName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
          InfoPill(label: player.isActive == true ? 'Active' : player.isActive == false ? 'Inactive' : 'Unknown'),
        ]),
        const SizedBox(height: 10),
        Text('${player.position ?? 'Position pending'} • ${player.primaryTeamAbbreviation ?? 'Team pending'} • ${player.birthCountry ?? 'Country pending'}', style: const TextStyle(color: terminalTextSoft, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          InfoPill(label: '${summary!.connectedSections}/5 sections connected'),
          InfoPill(label: player.sourceId ?? 'Source pending'),
          if (player.asOf != null) InfoPill(label: 'asOf ${player.asOf}'),
        ]),
        const SizedBox(height: 18),
        _DetailLine(label: 'Internal ID', value: player.id),
        _DetailLine(label: 'Height / Weight', value: '${player.height ?? '—'} / ${player.weightPounds == null ? '—' : '${player.weightPounds} lbs'}'),
        _DetailLine(label: 'Birth Date', value: player.birthDate ?? '—'),
        _DetailLine(label: 'College', value: player.college ?? '—'),
        _DetailLine(label: 'Draft', value: player.draftYear == null ? '—' : '${player.draftYear} / R${player.draftRound ?? '-'} / P${player.draftPick ?? '-'}'),
        _DetailLine(label: 'NBA Debut', value: player.nbaDebutYear?.toString() ?? '—'),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 420;
          return GridView.count(
            crossAxisCount: isWide ? 2 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isWide ? 2.2 : 3.4,
            children: [
              _MiniBadge(label: 'Stats', value: '${summary!.statRows}', detail: summary!.latestSeasonId ?? 'Source pending'),
              _MiniBadge(label: 'Best PPG', value: summary!.bestPpg?.toStringAsFixed(1) ?? '—', detail: 'Traditional stats'),
              _MiniBadge(label: 'Rosters', value: '${summary!.rosterRows}', detail: 'Team-season rows'),
              _MiniBadge(label: 'Awards', value: '${summary!.awardRows}', detail: 'Recognition rows'),
              _MiniBadge(label: 'Draft', value: '${summary!.draftRows}', detail: 'Draft links'),
              _MiniBadge(label: 'Moves', value: '${summary!.transactionRows}', detail: 'Transactions'),
            ],
          );
        }),
      ]),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))),
          Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3))),
        ]),
      );
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: terminalBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(detail, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalAccent, fontSize: 11)),
        ]),
      );
}

class _PlayersTable extends StatelessWidget {
  const _PlayersTable({required this.players, required this.selectedPlayerId, required this.onSelected, required this.summaries});
  final List<PlayerProfile> players;
  final String? selectedPlayerId;
  final ValueChanged<PlayerProfile> onSelected;
  final Map<String, _PlayerSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Player Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${players.length} players', style: const TextStyle(color: terminalTextMuted))])),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columnSpacing: 28,
            columns: const [
              DataColumn(label: Text('Player')),
              DataColumn(label: Text('Position')),
              DataColumn(label: Text('Team')),
              DataColumn(label: Text('Linked')),
              DataColumn(label: Text('Stats')),
              DataColumn(label: Text('Awards')),
              DataColumn(label: Text('College')),
              DataColumn(label: Text('Country')),
              DataColumn(label: Text('Draft')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Source')),
            ],
            rows: [
              for (final player in players)
                DataRow(
                  selected: selectedPlayerId == player.id,
                  onSelectChanged: (_) => onSelected(player),
                  cells: [
                    DataCell(SizedBox(width: 220, child: Text(player.displayName, style: const TextStyle(fontWeight: FontWeight.w800)))),
                    DataCell(Text(player.position ?? '—')),
                    DataCell(Text(player.primaryTeamAbbreviation ?? '—')),
                    DataCell(InfoPill(label: '${summaries[player.id]?.connectedSections ?? 0}/5')),
                    DataCell(Text('${summaries[player.id]?.statRows ?? 0}')),
                    DataCell(Text('${summaries[player.id]?.awardRows ?? 0}')),
                    DataCell(SizedBox(width: 180, child: Text(player.college ?? '—'))),
                    DataCell(Text(player.birthCountry ?? '—')),
                    DataCell(Text(player.draftYear == null ? '—' : '${player.draftYear} / R${player.draftRound ?? '-'} / P${player.draftPick ?? '-'}')),
                    DataCell(InfoPill(label: player.isActive == true ? 'Active' : player.isActive == false ? 'Inactive' : 'Unknown')),
                    DataCell(Text(player.sourceId ?? '—')),
                  ],
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PlayerAttachmentMap extends StatelessWidget {
  const _PlayerAttachmentMap({required this.payload});
  final _PlayerPayload payload;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('Player Data Attachment Map', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columnSpacing: 30,
            columns: const [DataColumn(label: Text('Layer')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Join Key')), DataColumn(label: Text('Status')), DataColumn(label: Text('MVP Use'))],
            rows: [
              _attachmentRow('Player Profiles', payload.players.length, 'playerId', payload.players.isEmpty ? 'Source pending' : 'Connected', 'Identity, detail pages, search, reports'),
              _attachmentRow('Player Season Stats', payload.stats.length, 'playerId + seasonId', payload.stats.isEmpty ? 'Source pending' : 'Connected', 'Stats, comparisons, rankings, reports'),
              _attachmentRow('Rosters', payload.rosters.length, 'playerId + teamId + seasonId', payload.rosters.isEmpty ? 'Source pending' : 'Connected', 'Team context, role, contract status'),
              _attachmentRow('Awards', payload.awards.length, 'playerId + seasonId', payload.awards.isEmpty ? 'Source pending' : 'Connected', 'Recognition and historical context'),
              _attachmentRow('Draft Picks', payload.draftPicks.length, 'playerId or playerName', payload.draftPicks.isEmpty ? 'Source pending' : 'Connected', 'Draft class and development analysis'),
              _attachmentRow('Transactions', payload.transactions.length, 'playerId or playerName', payload.transactions.isEmpty ? 'Source pending' : 'Connected', 'Movement timeline and team-building context'),
            ],
          ),
        ),
      ]),
    );
  }

  DataRow _attachmentRow(String layer, int rows, String joinKey, String status, String use) => DataRow(cells: [
        DataCell(SizedBox(width: 220, child: Text(layer, style: const TextStyle(fontWeight: FontWeight.w800)))),
        DataCell(Text('$rows')),
        DataCell(SizedBox(width: 240, child: Text(joinKey))),
        DataCell(InfoPill(label: status)),
        DataCell(SizedBox(width: 520, child: Text(use))),
      ]);
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
              DataColumn(label: Text('SPG')),
              DataColumn(label: Text('BPG')),
              DataColumn(label: Text('TPG')),
              DataColumn(label: Text('Source')),
            ],
            rows: stats.isEmpty
                ? const [DataRow(cells: [DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('Pending source'))])]
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
                        DataCell(Text(stat.stealsPerGame?.toStringAsFixed(1) ?? '—')),
                        DataCell(Text(stat.blocksPerGame?.toStringAsFixed(1) ?? '—')),
                        DataCell(Text(stat.turnoversPerGame?.toStringAsFixed(1) ?? '—')),
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
