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

class RostersScreen extends StatelessWidget {
  const RostersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AssetWorkspaceScreen<RosterEntry>(
      title: 'Rosters',
      subtitle: 'Roster command center for team-season rosters, player-team windows, two-way status, active/inactive context, assignments, recalls, lineups, and development pathways.',
      items: rosterWorkspaceItems,
      loadRecords: const NbaAssetRepository().loadRosters,
      recordLabel: 'Roster Entries',
      emptyTitle: 'Roster Source Pending',
      emptyBody: 'The roster entries asset is connected and empty. Once roster snapshots or transaction-derived roster data are approved, this page will connect players, teams, seasons, games, transactions, awards, contracts, and G League development.',
      columns: const ['Player', 'Team', 'Season', 'No.', 'Position', 'Status', 'Contract', 'Start', 'End', 'Source'],
      rowBuilder: (entry) => [entry.playerId, entry.teamId, entry.seasonId, entry.jerseyNumber ?? '—', entry.position ?? '—', entry.rosterStatus ?? '—', entry.contractType ?? '—', entry.startDate ?? '—', entry.endDate ?? '—', entry.sourceId ?? '—'],
      recordKey: (entry) => '${entry.playerId}-${entry.teamId}-${entry.seasonId}-${entry.startDate ?? 'na'}',
      factBuilder: (entry) => [_RecordFact('Player ID', entry.playerId), _RecordFact('Team ID', entry.teamId), _RecordFact('Season', entry.seasonId), _RecordFact('Jersey', entry.jerseyNumber ?? '—'), _RecordFact('Position', entry.position ?? '—'), _RecordFact('Roster Status', entry.rosterStatus ?? '—'), _RecordFact('Contract Type', entry.contractType ?? '—'), _RecordFact('Active Window', '${entry.startDate ?? '—'} to ${entry.endDate ?? '—'}'), _RecordFact('Source', entry.sourceId ?? 'Source pending'), _RecordFact('asOf', entry.asOf ?? '—')],
      activationSteps: const [_ActivationStep('Team-season snapshot', 'Start with playerId, teamId, seasonId, position, jersey, and source metadata.'), _ActivationStep('Roster windows', 'Add start dates, end dates, active status, inactive status, and two-way status.'), _ActivationStep('Transaction linkage', 'Use movement rows to explain roster changes.'), _ActivationStep('Game eligibility', 'Connect roster windows to game logs, box scores, injuries, and availability.'), _ActivationStep('G League pathway', 'Track assignments, recalls, two-way movement, and player development arcs.')],
      leadTitle: 'Roster Graph Principle',
      leadBody: 'Rosters are connective tissue between players, teams, seasons, transactions, games, contracts, and G League development. This module should answer who was on a team, when they were available, how they joined, and how their role changed.',
    );
  }
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
      factBuilder: (pick) => [_RecordFact('Draft Year', pick.draftYear.toString()), _RecordFact('Round', pick.round?.toString() ?? '—'), _RecordFact('Pick Number', pick.pickNumber?.toString() ?? '—'), _RecordFact('Team ID', pick.teamId ?? '—'), _RecordFact('Player', pick.playerName ?? pick.playerId ?? '—'), _RecordFact('Player ID', pick.playerId ?? 'Identity link pending'), _RecordFact('School / Club', pick.schoolOrClub ?? '—'), _RecordFact('Country', pick.country ?? '—'), _RecordFact('Source', pick.sourceId ?? 'Source pending'), _RecordFact('asOf', pick.asOf ?? '—')],
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

class _FilterDropdown extends StatelessWidget { const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged}); final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; @override Widget build(BuildContext context) => SizedBox(width: 230, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); }

class _SelectedRecordPanel<T> extends StatelessWidget { const _SelectedRecordPanel({required this.title, required this.record, required this.factBuilder}); final String title; final T? record; final List<_RecordFact> Function(T record) factBuilder; @override Widget build(BuildContext context) { if (record == null) return TerminalCard(child: Text('Select a $title record to inspect details, source status, and downstream links. This asset is currently source-pending.', style: const TextStyle(color: terminalTextSoft, height: 1.45))); final facts = factBuilder(record as T); return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Selected $title Record', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), for (final fact in facts) _FactLine(label: fact.label, value: fact.value)])); } }

class _FactLine extends StatelessWidget { const _FactLine({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 130, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))])); }

class _ActivationPanel extends StatelessWidget { const _ActivationPanel({required this.title, required this.steps}); final String title; final List<_ActivationStep> steps; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$title Activation Path', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), for (final step in steps) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: terminalPanelDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: terminalBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(step.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(step.body, style: const TextStyle(color: terminalTextSoft, height: 1.35))]))])); }

class _EmptyAssetPanel extends StatelessWidget { const _EmptyAssetPanel({required this.title, required this.body}); final String title; final String body; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(body, style: const TextStyle(color: terminalTextSoft, height: 1.45))])); }

class _RecordTable<T> extends StatelessWidget { const _RecordTable({required this.title, required this.records, required this.columns, required this.rowBuilder, required this.recordKey, required this.selectedKey, required this.onSelected}); final String title; final List<T> records; final List<String> columns; final List<String> Function(T record) rowBuilder; final String Function(T record) recordKey; final String? selectedKey; final ValueChanged<T> onSelected; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${records.length} rows', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columns: [for (final column in columns) DataColumn(label: Text(column))], rows: [for (final record in records) DataRow(selected: selectedKey == recordKey(record), onSelectChanged: (_) => onSelected(record), cells: [for (final value in rowBuilder(record)) DataCell(SizedBox(width: 160, child: Text(value, overflow: TextOverflow.ellipsis)))])]))])); }

class _BuildMap extends StatelessWidget { const _BuildMap({required this.title, required this.items}); final String title; final List<WorkspaceBuildItem> items; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Text('$title Build Map', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Area')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('First Data Need'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.area, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.description))), DataCell(SizedBox(width: 480, child: Text(item.firstDataNeed)))])]))])); }

class _WorkspaceMetric extends StatelessWidget { const _WorkspaceMetric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
