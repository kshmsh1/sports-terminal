import 'package:flutter/material.dart';

import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import '../widgets/terminal_primitives.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final repository = const NbaAssetRepository();
  late final Future<List<Team>> teamsFuture = repository.loadTeams();
  String selectedConference = 'All';
  String selectedDivision = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Team>>(
      future: teamsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingState();
        }

        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }

        final teams = snapshot.data ?? [];
        final divisions = ['All', ...teams.map((team) => team.division).toSet().toList()..sort()];
        final filteredTeams = teams.where((team) {
          final matchesConference = selectedConference == 'All' || team.conference == selectedConference;
          final matchesDivision = selectedDivision == 'All' || team.division == selectedDivision;
          final normalizedQuery = query.trim().toLowerCase();
          final matchesQuery = normalizedQuery.isEmpty ||
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

        final eastTeams = teams.where((team) => team.conference == 'East').length;
        final westTeams = teams.where((team) => team.conference == 'West').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'NBA Teams',
              subtitle: 'Asset-backed NBA franchise directory with conference, division, city, and abbreviation filtering.',
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
                    _TeamMetric(label: 'NBA Teams', value: '${teams.length}', detail: 'Loaded from JSON asset'),
                    _TeamMetric(label: 'East', value: '$eastTeams', detail: 'Conference teams'),
                    _TeamMetric(label: 'West', value: '$westTeams', detail: 'Conference teams'),
                    _TeamMetric(label: 'Filtered', value: '${filteredTeams.length}', detail: 'Current view'),
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
                      decoration: _inputDecoration('Search team, city, abbreviation, division...'),
                    ),
                  ),
                  _FilterDropdown(
                    label: 'Conference',
                    value: selectedConference,
                    values: const ['All', 'East', 'West'],
                    onChanged: (value) => setState(() => selectedConference = value),
                  ),
                  _FilterDropdown(
                    label: 'Division',
                    value: selectedDivision,
                    values: divisions,
                    onChanged: (value) => setState(() => selectedDivision = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _TeamsTable(title: 'Team Directory', teams: filteredTeams),
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
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: terminalBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: terminalAccent),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: terminalPanelDark,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: terminalTextMuted),
          filled: true,
          fillColor: terminalPanelDark,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: terminalBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: terminalAccent),
          ),
        ),
        items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _TeamsTable extends StatelessWidget {
  const _TeamsTable({required this.title, required this.teams});

  final String title;
  final List<Team> teams;

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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${teams.length} teams', style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 54,
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columnSpacing: 42,
              columns: const [
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Abbrev.')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Conference')),
                DataColumn(label: Text('Division')),
                DataColumn(label: Text('Source')),
              ],
              rows: [
                for (final team in teams)
                  DataRow(
                    cells: [
                      DataCell(SizedBox(width: 240, child: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Text(team.abbreviation)),
                      DataCell(SizedBox(width: 160, child: Text(team.city))),
                      DataCell(Text(team.conference)),
                      DataCell(Text(team.division)),
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

class _TeamMetric extends StatelessWidget {
  const _TeamMetric({required this.label, required this.value, required this.detail});

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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const TerminalCard(
      child: Text('Loading team directory...', style: TextStyle(color: terminalTextSoft)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Text('Unable to load team directory: $message', style: const TextStyle(color: terminalTextSoft)),
    );
  }
}
