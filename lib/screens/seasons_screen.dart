import 'package:flutter/material.dart';

import '../data/nba_seasons.dart';
import '../models/season.dart';

class SeasonsScreen extends StatelessWidget {
  const SeasonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baaSeasons = nbaSeasons.where((season) => season.league == 'BAA').length;
    final nbaOnlySeasons = nbaSeasons.length - baaSeasons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NBA Seasons',
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Historical season catalog from ${nbaSeasons.last.label} through ${nbaSeasons.first.label}.',
          style: const TextStyle(color: Color(0xFF9AA7B6), fontSize: 15),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 3 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 2.7 : 3.2,
              children: [
                _SeasonMetric(label: 'Configured Seasons', value: '${nbaSeasons.length}', detail: 'Historical catalog'),
                _SeasonMetric(label: 'NBA Seasons', value: '$nbaOnlySeasons', detail: 'Post-BAA merger era'),
                _SeasonMetric(label: 'BAA Seasons', value: '$baaSeasons', detail: 'Pre-NBA naming era'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _SeasonsTable(seasons: nbaSeasons),
      ],
    );
  }
}

class _SeasonMetric extends StatelessWidget {
  const _SeasonMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8794A5), fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(detail, style: const TextStyle(color: Color(0xFF8AB4F8), fontSize: 12)),
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
                const Text('Season Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${seasons.length} seasons', style: const TextStyle(color: Color(0xFF8794A5), fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF263241)),
          SizedBox(
            width: double.infinity,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF0D1218)),
              dataRowMinHeight: 46,
              dataRowMaxHeight: 50,
              headingTextStyle: const TextStyle(color: Color(0xFF8794A5), fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columns: const [
                DataColumn(label: Text('Season')),
                DataColumn(label: Text('Start Year')),
                DataColumn(label: Text('End Year')),
                DataColumn(label: Text('League')),
                DataColumn(label: Text('Stats Status')),
              ],
              rows: [
                for (final season in seasons)
                  DataRow(
                    cells: [
                      DataCell(Text(season.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text('${season.startYear}')),
                      DataCell(Text('${season.endYear}')),
                      DataCell(Text(season.league)),
                      const DataCell(Text('Pending')),
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
