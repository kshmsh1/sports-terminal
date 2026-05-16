import 'package:flutter/material.dart';

import '../models/season.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class SeasonsScreen extends StatefulWidget {
  const SeasonsScreen({super.key});

  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<List<Season>> seasonsFuture = repository.loadSeasons();
  String selectedLeague = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Season>>(
      future: seasonsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(child: Text('Loading season catalog...', style: TextStyle(color: terminalTextSoft)));
        }

        if (snapshot.hasError) {
          return TerminalCard(child: Text('Unable to load season catalog: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)));
        }

        final seasons = snapshot.data ?? [];
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'NBA Seasons',
              subtitle: seasons.isEmpty
                  ? 'Historical NBA/BAA season catalog loaded from normalized JSON assets.'
                  : 'Historical season catalog from ${seasons.last.label} through ${seasons.first.label}, loaded from normalized JSON assets.',
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
            _SeasonsTable(seasons: filteredSeasons),
          ],
        );
      },
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
  const _SeasonsTable({required this.seasons});

  final List<Season> seasons;

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
              columnSpacing: 56,
              columns: const [
                DataColumn(label: Text('Season')),
                DataColumn(label: Text('Start Year')),
                DataColumn(label: Text('End Year')),
                DataColumn(label: Text('League')),
                DataColumn(label: Text('Stats Status')),
                DataColumn(label: Text('Source')),
              ],
              rows: [
                for (final season in seasons)
                  DataRow(
                    cells: [
                      DataCell(Text(season.label, style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text('${season.startYear}')),
                      DataCell(Text('${season.endYear}')),
                      DataCell(Text(season.league)),
                      const DataCell(InfoPill(label: 'Pending')),
                      const DataCell(InfoPill(label: 'JSON asset')),
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
