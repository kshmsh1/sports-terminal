import 'package:flutter/material.dart';

import '../data/player_command_stage_items.dart';
import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/player_profile.dart';
import '../models/player_season_stat.dart';
import '../models/registry_item.dart';
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
  String selectedStageCategory = 'All';

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
          return const TerminalCard(
            child: Text('Loading player command workspace...', style: TextStyle(color: terminalTextSoft)),
          );
        }
        if (snapshot.hasError) {
          return TerminalCard(
            child: Text('Unable to load player command workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)),
          );
        }

        final payload = snapshot.data ?? const _PlayerPayload(players: [], stats: [], teams: [], seasons: [], rosters: [], awards: [], draftPicks: [], transactions: []);
        final categories = ['All', ...playerCommandStageItems.map((item) => item.category).toSet().toList()..sort()];
        final filteredStages = playerCommandStageItems.where((item) => selectedStageCategory == 'All' || item.category == selectedStageCategory).toList();
        final players = payload.players.where((player) {
          final q = query.trim().toLowerCase();
          final matchesQuery = q.isEmpty ||
              player.id.toLowerCase().contains(q) ||
              player.displayName.toLowerCase().contains(q) ||
              (player.position ?? '').toLowerCase().contains(q) ||
              (player.primaryTeamAbbreviation ?? '').toLowerCase().contains(q) ||
              (player.college ?? '').toLowerCase().contains(q) ||
              (player.birthCountry ?? '').toLowerCase().contains(q);
          final matchesStatus = selectedStatus == 'All' ||
              (selectedStatus == 'Active' && player.isActive == true) ||
              (selectedStatus == 'Inactive' && player.isActive == false) ||
              (selectedStatus == 'Unknown' && player.isActive == null);
          return matchesQuery && matchesStatus;
        }).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Players',
              subtitle: 'Player command workspace for identity, stat coverage, rosters, awards, draft links, transactions, action routes, and source-aware empty states.',
            ),
            const SizedBox(height: 22),
            _MetricGrid(metrics: [
              _MetricSpec('Player Profiles', '${payload.players.length}', payload.players.isEmpty ? 'Source pending' : 'Loaded'),
              _MetricSpec('Season Stat Rows', '${payload.stats.length}', 'Player-season rows'),
              _MetricSpec('Attachment Rows', '${payload.rosters.length + payload.awards.length + payload.draftPicks.length + payload.transactions.length}', 'Roster + awards + movement'),
              _MetricSpec('Command Stages', '${playerCommandStageItems.length}', 'Player model'),
            ]),
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
                  _FilterDropdown(label: 'Status', value: selectedStatus, values: const ['All', 'Active', 'Inactive', 'Unknown'], onChanged: (value) => setState(() => selectedStatus = value)),
                  _FilterDropdown(label: 'Stage Category', value: selectedStageCategory, values: categories, onChanged: (value) => setState(() => selectedStageCategory = value)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _PlayerCommandTicket(payload: payload, visiblePlayers: players.length),
            const SizedBox(height: 22),
            payload.players.isEmpty ? _PendingPlayersPanel(payload: payload) : _PlayersTable(players: players, payload: payload),
            const SizedBox(height: 22),
            _PlayerAttachmentMap(payload: payload),
            const SizedBox(height: 22),
            _StatsReadinessTable(stats: payload.stats),
            const SizedBox(height: 22),
            _PlayerCommandStageTable(items: filteredStages),
          ],
        );
      },
    );
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

class _PlayerCommandTicket extends StatelessWidget {
  const _PlayerCommandTicket({required this.payload, required this.visiblePlayers});

  final _PlayerPayload payload;
  final int visiblePlayers;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Player Command Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('This keeps Players focused on real identity records, linked stat coverage, source honesty, and future routes into compare, workspace, reports, fantasy, scouting, and source audit.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoPill(label: '$visiblePlayers visible'),
            InfoPill(label: '${payload.teams.length} teams'),
            InfoPill(label: '${payload.seasons.length} seasons'),
            InfoPill(label: payload.players.isEmpty ? 'Identity source pending' : 'Identity connected'),
          ]),
        ],
      ),
    );
  }
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
          const Text('No fake players are displayed. Once a player identity source is approved, this screen can immediately attach stats, rosters, awards, draft rows, transactions, reports, comparisons, and workspace routes.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoPill(label: '${payload.stats.length} stat rows'),
            InfoPill(label: '${payload.rosters.length} roster rows'),
            InfoPill(label: '${payload.awards.length} award rows'),
            InfoPill(label: '${payload.draftPicks.length} draft rows'),
            InfoPill(label: '${payload.transactions.length} transaction rows'),
          ]),
        ],
      ),
    );
  }
}

class _PlayersTable extends StatelessWidget {
  const _PlayersTable({required this.players, required this.payload});

  final List<PlayerProfile> players;
  final _PlayerPayload payload;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Text('Player Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${players.length} players', style: const TextStyle(color: terminalTextMuted)),
            ]),
          ),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columns: const [
                DataColumn(label: Text('Player')),
                DataColumn(label: Text('Position')),
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Stats')),
                DataColumn(label: Text('Awards')),
                DataColumn(label: Text('College')),
                DataColumn(label: Text('Country')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Source')),
              ],
              rows: [
                for (final player in players)
                  DataRow(cells: [
                    DataCell(SizedBox(width: 220, child: Text(player.displayName, style: const TextStyle(fontWeight: FontWeight.w800)))),
                    DataCell(Text(player.position ?? '—')),
                    DataCell(Text(player.primaryTeamAbbreviation ?? '—')),
                    DataCell(Text('${payload.stats.where((row) => row.playerId == player.id).length}')),
                    DataCell(Text('${payload.awards.where((row) => row.playerId == player.id).length}')),
                    DataCell(SizedBox(width: 180, child: Text(player.college ?? '—'))),
                    DataCell(Text(player.birthCountry ?? '—')),
                    DataCell(InfoPill(label: player.isActive == true ? 'Active' : player.isActive == false ? 'Inactive' : 'Unknown')),
                    DataCell(Text(player.sourceId ?? '—')),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerAttachmentMap extends StatelessWidget {
  const _PlayerAttachmentMap({required this.payload});

  final _PlayerPayload payload;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _AttachmentRow('Player Profiles', payload.players.length, 'playerId', payload.players.isEmpty ? 'Source pending' : 'Connected', 'Identity, detail pages, search, reports'),
      _AttachmentRow('Player Season Stats', payload.stats.length, 'playerId + seasonId', payload.stats.isEmpty ? 'Source pending' : 'Connected', 'Stats, comparisons, rankings, reports'),
      _AttachmentRow('Rosters', payload.rosters.length, 'playerId + teamId + seasonId', payload.rosters.isEmpty ? 'Source pending' : 'Connected', 'Team context and role'),
      _AttachmentRow('Awards', payload.awards.length, 'playerId + seasonId', payload.awards.isEmpty ? 'Source pending' : 'Connected', 'Recognition and award races'),
      _AttachmentRow('Draft Picks', payload.draftPicks.length, 'playerId or playerName', payload.draftPicks.isEmpty ? 'Source pending' : 'Connected', 'Draft class and development'),
      _AttachmentRow('Transactions', payload.transactions.length, 'playerId or playerName', payload.transactions.isEmpty ? 'Source pending' : 'Connected', 'Movement timeline'),
    ];

    return _AttachmentTable(title: 'Player Data Attachment Map', rows: rows);
  }
}

class _StatsReadinessTable extends StatelessWidget {
  const _StatsReadinessTable({required this.stats});

  final List<PlayerSeasonStat> stats;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Text('Player Season Stats Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${stats.length} rows', style: const TextStyle(color: terminalTextMuted)),
            ]),
          ),
          const Divider(height: 1, color: terminalBorder),
          if (stats.isEmpty)
            const Padding(padding: EdgeInsets.all(18), child: Text('Player season stats source pending. No fake stat rows are displayed.', style: TextStyle(color: terminalTextSoft)))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columns: const [DataColumn(label: Text('Player')), DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('GP')), DataColumn(label: Text('PPG')), DataColumn(label: Text('RPG')), DataColumn(label: Text('APG')), DataColumn(label: Text('TS%')), DataColumn(label: Text('Source'))],
                rows: [
                  for (final stat in stats)
                    DataRow(cells: [
                      DataCell(Text(stat.playerId)),
                      DataCell(Text(stat.teamId ?? '—')),
                      DataCell(Text(stat.seasonId)),
                      DataCell(Text(stat.gamesPlayed?.toString() ?? '—')),
                      DataCell(Text(_number(stat.pointsPerGame))),
                      DataCell(Text(_number(stat.reboundsPerGame))),
                      DataCell(Text(_number(stat.assistsPerGame))),
                      DataCell(Text(_percent(stat.trueShootingPercentage))),
                      DataCell(Text(stat.sourceId ?? '—')),
                    ]),
                ],
              ),
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
  Widget build(BuildContext context) => _RegistryTable(title: 'Player Command Stage Model', items: items);
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
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.all(18), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columns: const [DataColumn(label: Text('Layer')), DataColumn(label: Text('Rows')), DataColumn(label: Text('Join Key')), DataColumn(label: Text('Status')), DataColumn(label: Text('Use'))],
              rows: [
                for (final row in rows)
                  DataRow(cells: [
                    DataCell(SizedBox(width: 220, child: Text(row.layer, style: const TextStyle(fontWeight: FontWeight.w800)))),
                    DataCell(Text('${row.rows}')),
                    DataCell(SizedBox(width: 260, child: Text(row.joinKey))),
                    DataCell(InfoPill(label: row.status)),
                    DataCell(SizedBox(width: 560, child: Text(row.use))),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistryTable extends StatelessWidget {
  const _RegistryTable({required this.title, required this.items});

  final String title;
  final List<RegistryItem> items;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted)),
            ]),
          ),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
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
            ),
          ),
        ],
      ),
    );
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
        children: [for (final metric in metrics) _Metric(label: metric.label, value: metric.value, detail: metric.detail)],
      );
    });
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});

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

String _number(double? value) => value == null ? '—' : value.toStringAsFixed(1);
String _percent(double? value) => value == null ? '—' : value <= 1 ? '${(value * 100).toStringAsFixed(1)}%' : '${value.toStringAsFixed(1)}%';
