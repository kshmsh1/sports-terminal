import 'package:flutter/material.dart';

import '../models/playoff_series_record.dart';
import '../models/standings_record.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<List<StandingsRecord>> recordsFuture = repository.loadStandings();
  String query = '';
  String selectedConference = 'All';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StandingsRecord>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading standings workspace...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load standings workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final records = snapshot.data ?? [];
        final filtered = records.where((record) {
          final normalized = query.trim().toLowerCase();
          final matchesConference = selectedConference == 'All' || record.conference == selectedConference;
          final matchesQuery = normalized.isEmpty ||
              record.teamId.toLowerCase().contains(normalized) ||
              record.seasonId.toLowerCase().contains(normalized) ||
              (record.conference ?? '').toLowerCase().contains(normalized) ||
              (record.division ?? '').toLowerCase().contains(normalized);
          return matchesConference && matchesQuery;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Standings',
              subtitle: 'Asset-backed standings workspace for team records, seeds, conferences, divisions, win percentages, and playoff qualification context.',
            ),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isWide ? 2.0 : 1.5,
                children: [
                  _Metric(label: 'Standings Rows', value: '${records.length}', detail: 'Loaded from asset'),
                  _Metric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
                  const _Metric(label: 'Status', value: 'Ready', detail: 'Source pending'),
                  const _Metric(label: 'Policy', value: 'Blank', detail: 'No fake records'),
                ],
              );
            }),
            const SizedBox(height: 22),
            TerminalCard(
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search team, season, conference, division...'))),
                _FilterDropdown(label: 'Conference', value: selectedConference, values: const ['All', 'East', 'West'], onChanged: (value) => setState(() => selectedConference = value)),
              ]),
            ),
            const SizedBox(height: 22),
            records.isEmpty
                ? const _EmptyPanel(title: 'Standings Source Pending', body: 'The standings asset is connected and empty. Once standings records are approved, this page will show season-by-season records, seeds, conferences, divisions, win percentages, and games-back context.')
                : _StandingsTable(records: filtered),
          ],
        );
      },
    );
  }
}

class PlayoffsScreen extends StatefulWidget {
  const PlayoffsScreen({super.key});

  @override
  State<PlayoffsScreen> createState() => _PlayoffsScreenState();
}

class _PlayoffsScreenState extends State<PlayoffsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<List<PlayoffSeriesRecord>> recordsFuture = repository.loadPlayoffSeries();
  String query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlayoffSeriesRecord>>(
      future: recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading playoffs workspace...', style: TextStyle(color: terminalTextSoft)));
        }
        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load playoffs workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final records = snapshot.data ?? [];
        final filtered = records.where((record) {
          final normalized = query.trim().toLowerCase();
          if (normalized.isEmpty) return true;
          return [record.seriesName, record.round, record.seasonId, record.winningTeamId, record.losingTeamId].whereType<String>().join(' ').toLowerCase().contains(normalized);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Playoffs',
              subtitle: 'Asset-backed playoff workspace for series, rounds, seeds, winners, losers, game counts, and postseason paths.',
            ),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isWide ? 2.0 : 1.5,
                children: [
                  _Metric(label: 'Series Rows', value: '${records.length}', detail: 'Loaded from asset'),
                  _Metric(label: 'Filtered', value: '${filtered.length}', detail: 'Current view'),
                  const _Metric(label: 'Status', value: 'Ready', detail: 'Source pending'),
                  const _Metric(label: 'Policy', value: 'Blank', detail: 'No fake records'),
                ],
              );
            }),
            const SizedBox(height: 22),
            TerminalCard(
              child: SizedBox(
                width: 420,
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: terminalAccent,
                  decoration: _inputDecoration('Search series, round, season, team...'),
                ),
              ),
            ),
            const SizedBox(height: 22),
            records.isEmpty
                ? const _EmptyPanel(title: 'Playoff Series Source Pending', body: 'The playoff series asset is connected and empty. Once historical playoff bracket or series records are approved, this page will show series-level postseason context and link teams, seasons, games, and reports.')
                : _PlayoffTable(records: filtered),
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 10), Text(body, style: const TextStyle(color: terminalTextSoft, height: 1.45))]));
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({required this.records});
  final List<StandingsRecord> records;

  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columns: const [DataColumn(label: Text('Seed')), DataColumn(label: Text('Team')), DataColumn(label: Text('Season')), DataColumn(label: Text('Conf.')), DataColumn(label: Text('Division')), DataColumn(label: Text('W')), DataColumn(label: Text('L')), DataColumn(label: Text('Win %')), DataColumn(label: Text('GB')), DataColumn(label: Text('Source'))],
            rows: [for (final record in records) DataRow(cells: [DataCell(Text(record.seed?.toString() ?? '—')), DataCell(Text(record.teamId)), DataCell(Text(record.seasonId)), DataCell(Text(record.conference ?? '—')), DataCell(Text(record.division ?? '—')), DataCell(Text(record.wins?.toString() ?? '—')), DataCell(Text(record.losses?.toString() ?? '—')), DataCell(Text(record.winPercentage?.toStringAsFixed(3) ?? '—')), DataCell(Text(record.gamesBack?.toStringAsFixed(1) ?? '—')), DataCell(Text(record.sourceId ?? '—'))])],
          ),
        ),
      );
}

class _PlayoffTable extends StatelessWidget {
  const _PlayoffTable({required this.records});
  final List<PlayoffSeriesRecord> records;

  @override
  Widget build(BuildContext context) => TerminalCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(terminalPanelDark),
            headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
            dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
            columns: const [DataColumn(label: Text('Season')), DataColumn(label: Text('Round')), DataColumn(label: Text('Series')), DataColumn(label: Text('Winner')), DataColumn(label: Text('Loser')), DataColumn(label: Text('Seeds')), DataColumn(label: Text('Result')), DataColumn(label: Text('Source'))],
            rows: [for (final record in records) DataRow(cells: [DataCell(Text(record.seasonId)), DataCell(Text(record.round ?? '—')), DataCell(SizedBox(width: 220, child: Text(record.seriesName ?? '—'))), DataCell(Text(record.winningTeamId ?? '—')), DataCell(Text(record.losingTeamId ?? '—')), DataCell(Text('${record.winningSeed ?? '—'} / ${record.losingSeed ?? '—'}')), DataCell(Text('${record.winnerWins ?? '—'}-${record.loserWins ?? '—'}')), DataCell(Text(record.sourceId ?? '—'))])],
          ),
        ),
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
