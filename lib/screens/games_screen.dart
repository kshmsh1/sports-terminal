import 'package:flutter/material.dart';

import '../data/workspace_build_items.dart';
import '../models/award_record.dart';
import '../models/draft_pick.dart';
import '../models/game_record.dart';
import '../models/roster_entry.dart';
import '../models/transaction_record.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<GameRecord>(
      title: 'Games',
      subtitle: 'Asset-backed game center for schedules, results, box scores, game logs, playoff series, and matchup-level historical analysis.',
      items: gameWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadGames,
      recordLabel: 'Game Records',
      emptyTitle: 'Game Records Source Pending',
      emptyBody: 'The game records asset is connected and empty. Once a historical schedule and results source is selected, this page will load game rows without changing the UI architecture.',
      columns: const ['Game', 'Date', 'Season', 'Type', 'Away', 'Home', 'Score', 'Source'],
      rowBuilder: (game) => [game.id, game.gameDate ?? '—', game.seasonId, game.seasonType ?? '—', game.awayTeamId ?? '—', game.homeTeamId ?? '—', _score(game), game.sourceId ?? '—'],
      leadTitle: 'Game Center Principle',
      leadBody: 'Games should become the bridge between season summaries and granular player/team performance. The page now loads the normalized game asset and can accept real schedule, result, and box-score data later.',
    );
  }

  static String _score(GameRecord game) {
    if (game.awayScore == null || game.homeScore == null) return '—';
    return '${game.awayScore}-${game.homeScore}';
  }
}

class RostersScreen extends StatelessWidget {
  const RostersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<RosterEntry>(
      title: 'Rosters',
      subtitle: 'Asset-backed roster workspace for team-season rosters, player active windows, two-way players, assignments, recalls, and lineup context.',
      items: rosterWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadRosters,
      recordLabel: 'Roster Entries',
      emptyTitle: 'Roster Source Pending',
      emptyBody: 'The roster entries asset is connected and empty. Once roster snapshots or transaction-derived roster data are approved, this page will load roster rows and link players, teams, and seasons.',
      columns: const ['Player', 'Team', 'Season', 'No.', 'Position', 'Status', 'Contract', 'Source'],
      rowBuilder: (entry) => [entry.playerId, entry.teamId, entry.seasonId, entry.jerseyNumber ?? '—', entry.position ?? '—', entry.rosterStatus ?? '—', entry.contractType ?? '—', entry.sourceId ?? '—'],
      leadTitle: 'Roster Graph Principle',
      leadBody: 'Rosters are the connective tissue between players, teams, seasons, transactions, games, and G League development paths. This screen now has a connected asset path ready for real roster data.',
    );
  }
}

class AwardsScreen extends StatelessWidget {
  const AwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<AwardRecord>(
      title: 'Awards',
      subtitle: 'Asset-backed awards workspace for MVP, All-NBA, All-Star, defensive honors, rookie honors, voting shares, and historical recognition.',
      items: awardWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadAwards,
      recordLabel: 'Award Records',
      emptyTitle: 'Awards Source Pending',
      emptyBody: 'The awards asset is connected and empty. Historical award records are a strong near-term dataset because they enrich player, season, team, comparison, and report pages.',
      columns: const ['Award', 'Season', 'Player', 'Team', 'Rank', '1st Votes', 'Share', 'Source'],
      rowBuilder: (award) => [award.awardName, award.seasonId, award.playerId ?? '—', award.teamId ?? '—', award.rank?.toString() ?? '—', award.votesFirstPlace?.toString() ?? '—', award.share?.toStringAsFixed(3) ?? '—', award.sourceId ?? '—'],
      leadTitle: 'Awards Context Principle',
      leadBody: 'Awards are high-value historical context that can make player and season pages feel rich before every live feed is solved. The awards module now has a real asset loader and table surface.',
    );
  }
}

class DraftScreen extends StatelessWidget {
  const DraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<DraftPick>(
      title: 'Draft',
      subtitle: 'Asset-backed draft workspace for draft picks, draft classes, prospect pathways, team draft history, and long-term development outcomes.',
      items: draftWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadDraftPicks,
      recordLabel: 'Draft Picks',
      emptyTitle: 'Draft Source Pending',
      emptyBody: 'The draft picks asset is connected and empty. Once historical draft records are approved, this page will connect draft years, teams, players, schools, countries, and outcomes.',
      columns: const ['Year', 'Round', 'Pick', 'Team', 'Player', 'School/Club', 'Country', 'Source'],
      rowBuilder: (pick) => [pick.draftYear.toString(), pick.round?.toString() ?? '—', pick.pickNumber?.toString() ?? '—', pick.teamId ?? '—', pick.playerName ?? pick.playerId ?? '—', pick.schoolOrClub ?? '—', pick.country ?? '—', pick.sourceId ?? '—'],
      leadTitle: 'Draft Intelligence Principle',
      leadBody: 'Draft history should connect player identity, team-building, franchise eras, G League development, and prospect outcomes. The draft module now has a normalized asset loader.',
    );
  }
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<TransactionRecord>(
      title: 'Transactions',
      subtitle: 'Asset-backed transaction workspace for trades, signings, waivers, assignments, recalls, contract events, and roster movement history.',
      items: transactionWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadTransactions,
      recordLabel: 'Transaction Records',
      emptyTitle: 'Transactions Source Pending',
      emptyBody: 'The transaction asset is connected and empty. Once a transaction source is selected, this page will become the movement graph connecting players, rosters, teams, contracts, and development pathways.',
      columns: const ['Date', 'Type', 'Player', 'From', 'To', 'Description', 'Source'],
      rowBuilder: (tx) => [tx.date ?? '—', tx.transactionType ?? '—', tx.playerName ?? tx.playerId ?? '—', tx.fromTeamId ?? '—', tx.toTeamId ?? '—', tx.description ?? '—', tx.sourceId ?? '—'],
      leadTitle: 'Transaction Graph Principle',
      leadBody: 'Transactions are relationship events that change rosters, team context, player timelines, contract status, draft assets, and G League movement. This module is now asset-backed.',
    );
  }
}

class _AssetWorkspaceScreen<T> extends StatefulWidget {
  const _AssetWorkspaceScreen({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.loadRecords,
    required this.recordLabel,
    required this.emptyTitle,
    required this.emptyBody,
    required this.columns,
    required this.rowBuilder,
    required this.leadTitle,
    required this.leadBody,
  });

  final String title;
  final String subtitle;
  final List<WorkspaceBuildItem> items;
  final Future<List<T>> Function() loadRecords;
  final String recordLabel;
  final String emptyTitle;
  final String emptyBody;
  final List<String> columns;
  final List<String> Function(T record) rowBuilder;
  final String leadTitle;
  final String leadBody;

  @override
  State<_AssetWorkspaceScreen<T>> createState() => _AssetWorkspaceScreenState<T>();
}

class _AssetWorkspaceScreenState<T> extends State<_AssetWorkspaceScreen<T>> {
  late final Future<List<T>> recordsFuture = widget.loadRecords();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return TerminalCard(child: Text('Loading ${widget.title.toLowerCase()} workspace...', style: const TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load ${widget.title.toLowerCase()} workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final records = snapshot.data ?? [];
        final filtered = records.where((record) {
          final normalized = query.trim().toLowerCase();
          if (normalized.isEmpty) return true;
          return widget.rowBuilder(record).join(' ').toLowerCase().contains(normalized);
        }).toList();

        final schemaReady = widget.items.where((item) => item.status.contains('Schema')).length;
        final planned = widget.items.where((item) => item.status == 'Planned').length;
        final future = widget.items.where((item) => item.status == 'Future').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: widget.title, subtitle: widget.subtitle),
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
                    _WorkspaceMetric(label: widget.recordLabel, value: '${records.length}', detail: 'Loaded from asset'),
                    _WorkspaceMetric(label: 'Schema Ready', value: '$schemaReady', detail: 'Objects exist'),
                    _WorkspaceMetric(label: 'Planned', value: '$planned', detail: 'Data needed'),
                    _WorkspaceMetric(label: 'Future', value: '$future', detail: 'Later depth'),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            TerminalCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.leadTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(widget.leadBody, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
              ]),
            ),
            const SizedBox(height: 22),
            TerminalCard(
              child: SizedBox(
                width: 360,
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: terminalAccent,
                  decoration: _inputDecoration('Search ${widget.title.toLowerCase()} records...'),
                ),
              ),
            ),
            const SizedBox(height: 22),
            records.isEmpty ? _EmptyAssetPanel(title: widget.emptyTitle, body: widget.emptyBody) : _RecordTable<T>(title: widget.recordLabel, records: filtered, columns: widget.columns, rowBuilder: widget.rowBuilder),
            const SizedBox(height: 22),
            _BuildMap(title: widget.title, items: widget.items),
          ],
        );
      },
    );
  }
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

class _EmptyAssetPanel extends StatelessWidget {
  const _EmptyAssetPanel({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(body, style: const TextStyle(color: terminalTextSoft, height: 1.45))]));
}

class _RecordTable<T> extends StatelessWidget {
  const _RecordTable({required this.title, required this.records, required this.columns, required this.rowBuilder});
  final String title;
  final List<T> records;
  final List<String> columns;
  final List<String> Function(T record) rowBuilder;
  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columns: [for (final column in columns) DataColumn(label: Text(column))],
              rows: [for (final record in records) DataRow(cells: [for (final value in rowBuilder(record)) DataCell(SizedBox(width: 160, child: Text(value, overflow: TextOverflow.ellipsis)))])],
            ),
          ),
        ]),
      );
}

class _BuildMap extends StatelessWidget {
  const _BuildMap({required this.title, required this.items});
  final String title;
  final List<WorkspaceBuildItem> items;
  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(18), child: Text('$title Build Map', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columnSpacing: 30,
              columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Area')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('First Data Need'))],
              rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.description))), DataCell(SizedBox(width: 480, child: Text(item.firstDataNeed)))])],
            ),
          ),
        ]),
      );
}

class _WorkspaceMetric extends StatelessWidget {
  const _WorkspaceMetric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
