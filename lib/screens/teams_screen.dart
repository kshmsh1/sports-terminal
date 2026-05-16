import 'package:flutter/material.dart';

import '../data/nba_teams.dart';
import '../models/team.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eastTeams = nbaTeams.where((team) => team.conference == 'East').toList();
    final westTeams = nbaTeams.where((team) => team.conference == 'West').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NBA Teams',
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Real NBA franchise directory organized by conference and division.',
          style: TextStyle(color: Color(0xFF9AA7B6), fontSize: 15),
        ),
        const SizedBox(height: 22),
        _TeamsTable(title: 'Eastern Conference', teams: eastTeams),
        const SizedBox(height: 20),
        _TeamsTable(title: 'Western Conference', teams: westTeams),
      ],
    );
  }
}

class _TeamsTable extends StatelessWidget {
  const _TeamsTable({required this.title, required this.teams});

  final String title;
  final List<Team> teams;

  @override
  Widget build(BuildContext context) {
    final sortedTeams = [...teams]..sort((a, b) {
        final divisionCompare = a.division.compareTo(b.division);
        if (divisionCompare != 0) return divisionCompare;
        return a.name.compareTo(b.name);
      });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${teams.length} teams', style: const TextStyle(color: Color(0xFF8794A5), fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF263241)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF0D1218)),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 54,
              headingTextStyle: const TextStyle(color: Color(0xFF8794A5), fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columns: const [
                DataColumn(label: Text('Team')),
                DataColumn(label: Text('Abbrev.')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Conference')),
                DataColumn(label: Text('Division')),
              ],
              rows: [
                for (final team in sortedTeams)
                  DataRow(
                    cells: [
                      DataCell(Text(team.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text(team.abbreviation)),
                      DataCell(Text(team.city)),
                      DataCell(Text(team.conference)),
                      DataCell(Text(team.division)),
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
