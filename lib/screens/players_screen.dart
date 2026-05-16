import 'package:flutter/material.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NBA PLAYER DATABASE',
            style: TextStyle(color: Color(0xFF8AB4F8), fontSize: 12, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10),
          Text(
            'Historical player data source pending',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 12),
          Text(
            'We are not displaying fake player statistics. This screen will connect to historical NBA player identity, roster, and stat datasets once the ingestion workflow is selected. Missing values will render as blank rather than zero.',
            style: TextStyle(color: Color(0xFFB6C0CC), fontSize: 15, height: 1.45),
          ),
          SizedBox(height: 20),
          _BlankDataTable(),
        ],
      ),
    );
  }
}

class _BlankDataTable extends StatelessWidget {
  const _BlankDataTable();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(Color(0xFF0D1218)),
        headingTextStyle: TextStyle(color: Color(0xFF8794A5), fontWeight: FontWeight.w700),
        dataTextStyle: TextStyle(color: Color(0xFFDDE6F1)),
        columns: [
          DataColumn(label: Text('Player')),
          DataColumn(label: Text('Team')),
          DataColumn(label: Text('Season')),
          DataColumn(label: Text('GP')),
          DataColumn(label: Text('PPG')),
          DataColumn(label: Text('RPG')),
          DataColumn(label: Text('APG')),
          DataColumn(label: Text('Source')),
        ],
        rows: [
          DataRow(
            cells: [
              DataCell(Text('—')),
              DataCell(Text('—')),
              DataCell(Text('—')),
              DataCell(Text('—')),
              DataCell(Text('—')),
              DataCell(Text('—')),
              DataCell(Text('—')),
              DataCell(Text('Pending')),
            ],
          ),
        ],
      ),
    );
  }
}
