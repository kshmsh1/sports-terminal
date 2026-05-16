import 'package:flutter/material.dart';

import '../data/nba_data_sources.dart';
import '../data/nba_seasons.dart';
import '../data/nba_teams.dart';
import '../models/data_source.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectedSources = nbaDataSources
        .where((source) => source.status == DataSourceStatus.connected)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NBA Command Center',
          style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Historical-first architecture for organizing NBA teams, players, seasons, sources, and statistics.',
          style: TextStyle(color: Color(0xFF9AA7B6), fontSize: 15),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 1.8 : 1.5,
              children: [
                _MetricCard(label: 'NBA Teams', value: '${nbaTeams.length}', detail: 'Real team directory'),
                _MetricCard(label: 'NBA Seasons', value: '${nbaSeasons.length}', detail: '${nbaSeasons.last.label} to ${nbaSeasons.first.label}'),
                const _MetricCard(label: 'Historical Data', value: 'Planned', detail: 'Official-source preferred'),
                _MetricCard(label: 'Connected Sources', value: '$connectedSources', detail: 'No fake stat feeds'),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _TerminalPanel(
          title: 'Current Build Direction',
          lines: [
            '1. Build the terminal around NBA first.',
            '2. Store real stable reference data immediately.',
            '3. Keep statistics nullable until a real source is connected.',
            '4. Prefer historical NBA data before live/current data.',
            '5. Add official or licensed sources behind a clean data layer later.',
          ],
        ),
        const SizedBox(height: 24),
        _DataSourcePanel(sources: nbaDataSources),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail});

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

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: const TextStyle(color: Color(0xFFB6C0CC), height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class _DataSourcePanel extends StatelessWidget {
  const _DataSourcePanel({required this.sources});

  final List<DataSource> sources;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Source Registry',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          for (final source in sources) _DataSourceRow(source: source),
        ],
      ),
    );
  }
}

class _DataSourceRow extends StatelessWidget {
  const _DataSourceRow({required this.source});

  final DataSource source;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (source.status) {
      DataSourceStatus.connected => 'Connected',
      DataSourceStatus.planned => 'Planned',
      DataSourceStatus.restricted => 'Restricted',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1218),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF152235),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF385A86)),
            ),
            child: Text(
              statusLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8AB4F8), fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(source.description, style: const TextStyle(color: Color(0xFFB6C0CC), height: 1.35)),
                if (source.asOf != null) ...[
                  const SizedBox(height: 4),
                  Text('As of ${source.asOf}', style: const TextStyle(color: Color(0xFF8794A5), fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
