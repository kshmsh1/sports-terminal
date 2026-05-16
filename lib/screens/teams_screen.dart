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
  String? selectedTeamId;

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
        final conferenceCounts = _countsBy(teams, (team) => team.conference);
        final divisionCounts = _countsBy(teams, (team) => team.division);
        final filteredTeams = teams.where((team) {
          final matchesConference = selectedConference == 'All' || team.conference == selectedConference;
          final matchesDivision = selectedDivision == 'All' || team.division == selectedDivision;
          final normalizedQuery = query.trim().toLowerCase();
          final matchesQuery = normalizedQuery.isEmpty ||
              team.id.toLowerCase().contains(normalizedQuery) ||
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

        final selectedTeam = teams.where((team) => team.id == selectedTeamId).firstOrNull ?? (filteredTeams.isNotEmpty ? filteredTeams.first : null);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'NBA Teams',
              subtitle: 'Asset-backed NBA franchise directory with conference, division, city, abbreviation, team detail, and data-readiness context.',
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
                    _TeamMetric(label: 'East', value: '${conferenceCounts['East'] ?? 0}', detail: 'Conference teams'),
                    _TeamMetric(label: 'West', value: '${conferenceCounts['West'] ?? 0}', detail: 'Conference teams'),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 980;
                final children = [
                  _ConferenceDivisionPanel(conferenceCounts: conferenceCounts, divisionCounts: divisionCounts),
                  _SelectedTeamPanel(team: selectedTeam),
                ];
                if (!isWide) {
                  return Column(children: [for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: child)]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 14),
                    Expanded(child: children[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            _TeamsTable(
              title: 'Team Directory',
              teams: filteredTeams,
              selectedTeamId: selectedTeam?.id,
              onSelected: (team) => setState(() => selectedTeamId = team.id),
            ),
            const SizedBox(height: 22),
            const _ReadinessPanel(),
          ],
        );
      },
    );
  }
}

Map<String, int> _countsBy(List<Team> teams, String Function(Team team) selector) {
  final counts = <String, int>{};
  for (final team in teams) {
    final key = selector(team);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
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
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
        ),
        items: values.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _ConferenceDivisionPanel extends StatelessWidget {
  const _ConferenceDivisionPanel({required this.conferenceCounts, required this.divisionCounts});

  final Map<String, int> conferenceCounts;
  final Map<String, int> divisionCounts;

  @override
  Widget build(BuildContext context) {
    final sortedDivisions = divisionCounts.keys.toList()..sort();
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('League Structure', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in conferenceCounts.entries) _StructureChip(label: entry.key, value: entry.value),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Divisions', style: TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final division in sortedDivisions) _StructureChip(label: division, value: divisionCounts[division] ?? 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedTeamPanel extends StatelessWidget {
  const _SelectedTeamPanel({required this.team});

  final Team? team;

  @override
  Widget build(BuildContext context) {
    if (team == null) {
      return const TerminalCard(
        child: Text('Select a team from the table to inspect its reference record.', style: TextStyle(color: terminalTextSoft)),
      );
    }
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selected Team', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(team!.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('${team!.city} • ${team!.abbreviation}', style: const TextStyle(color: terminalTextSoft, fontSize: 14)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoPill(label: team!.conference),
            InfoPill(label: team!.division),
            const InfoPill(label: 'Reference asset'),
          ]),
          const SizedBox(height: 16),
          Text('Internal ID: ${team!.id}', style: const TextStyle(color: terminalTextMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StructureChip extends StatelessWidget {
  const _StructureChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: terminalPanelDark,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: terminalBorder),
      ),
      child: Text('$label  $value', style: const TextStyle(color: Color(0xFFDDE6F1), fontWeight: FontWeight.w700)),
    );
  }
}

class _TeamsTable extends StatelessWidget {
  const _TeamsTable({required this.title, required this.teams, required this.selectedTeamId, required this.onSelected});

  final String title;
  final List<Team> teams;
  final String? selectedTeamId;
  final ValueChanged<Team> onSelected;

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
                DataColumn(label: Text('Internal ID')),
                DataColumn(label: Text('Source')),
              ],
              rows: [
                for (final team in teams)
                  DataRow(
                    selected: selectedTeamId == team.id,
                    onSelectChanged: (_) => onSelected(team),
                    cells: [
                      DataCell(SizedBox(width: 240, child: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                      DataCell(Text(team.abbreviation)),
                      DataCell(SizedBox(width: 160, child: Text(team.city))),
                      DataCell(Text(team.conference)),
                      DataCell(Text(team.division)),
                      DataCell(Text(team.id)),
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

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel();

  @override
  Widget build(BuildContext context) {
    return const TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Data Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 12),
          Text('Connected now: current team identity, abbreviation, city, conference, and division. Still pending: historical aliases, relocation continuity, arena history, team-season stats, standings rows, playoff series, rosters, transactions, contracts, media references, and franchise narrative timelines.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
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
    return const TerminalCard(child: Text('Loading team directory...', style: TextStyle(color: terminalTextSoft)));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Text('Unable to load team directory: $message', style: const TextStyle(color: terminalTextSoft)));
  }
}
