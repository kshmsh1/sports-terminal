import 'package:flutter/material.dart';

import '../data/alert_rule_items.dart';
import '../data/coverage_items.dart';
import '../data/import_job_plans.dart';
import '../data/report_library_items.dart';
import '../data/saved_view_items.dart';
import '../data/source_registry_entries.dart';
import '../widgets/terminal_primitives.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connectedDatasets = coverageItems.where((item) => item.status == 'Connected').length;
    final pendingDatasets = coverageItems.where((item) => item.status.contains('pending')).length;
    final knownRows = coverageItems.fold<int>(0, (sum, item) => sum + item.recordCount);
    final connectedSources = sourceRegistryEntries.where((item) => item.status == 'Connected').length;
    final targetSources = sourceRegistryEntries.where((item) => item.status == 'Target').length;
    final startedJobs = importJobPlans.where((item) => item.status.contains('Started')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'NBA Command Center',
          subtitle: 'Historical-first operating system for NBA teams, players, seasons, statistics, sources, reports, saved views, alerts, and data operations.',
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
              childAspectRatio: isWide ? 1.8 : 1.45,
              children: [
                _MetricCard(label: 'Coverage Datasets', value: '${coverageItems.length}', detail: '$connectedDatasets connected / $pendingDatasets pending'),
                _MetricCard(label: 'Known Records', value: '$knownRows', detail: 'Real rows only'),
                _MetricCard(label: 'Source Registry', value: '${sourceRegistryEntries.length}', detail: '$connectedSources connected / $targetSources targets'),
                _MetricCard(label: 'Import Jobs', value: '${importJobPlans.length}', detail: '$startedJobs started loaders'),
                _MetricCard(label: 'Reports', value: '${reportLibraryItems.length}', detail: 'Reusable terminal templates'),
                _MetricCard(label: 'Saved Views', value: '${savedViewItems.length}', detail: 'Workspace presets'),
                _MetricCard(label: 'Alert Rules', value: '${alertRuleItems.length}', detail: 'Future monitoring layer'),
                const _MetricCard(label: 'Data Policy', value: 'Real', detail: 'No fake sports records'),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _TerminalPanel(
          title: 'Current Product Direction',
          lines: [
            '1. Build NBA first and treat every future sport as an extension of the same data operating model.',
            '2. Use stable local JSON assets now, then replace or augment them with approved source imports later.',
            '3. Keep missing values blank. Never convert unknown statistics into fake zeros.',
            '4. Separate source data, user analysis, reports, saved views, alerts, and Build Lab governance.',
            '5. Prioritize player identity, player season statistics, team season statistics, standings, games, rosters, awards, draft, and transactions before live feeds.',
          ],
        ),
        const SizedBox(height: 24),
        _CoveragePanel(items: coverageItems),
        const SizedBox(height: 24),
        _OperationsPanel(
          connectedSources: connectedSources,
          targetSources: targetSources,
          startedJobs: startedJobs,
        ),
        const SizedBox(height: 24),
        const _TerminalPanel(
          title: 'Near-Term Build Priority',
          lines: [
            '1. Connect the central Stats workspace and Data Coverage workspace into the sidebar navigation.',
            '2. Keep converting static planning pages into asset-backed workspaces with loaders and empty source-pending states.',
            '3. Add source-ready schemas for contracts, scouting notes, media references, and team/franchise relationships.',
            '4. Build a compact navigation system so the sidebar does not become permanently overloaded.',
            '5. Begin selecting lawful player identity and historical statistics sources before importing real player rows.',
          ],
        ),
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

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: const TextStyle(color: terminalTextSoft, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Data Coverage Snapshot', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columnSpacing: 30,
              columns: const [
                DataColumn(label: Text('Priority')),
                DataColumn(label: Text('Dataset')),
                DataColumn(label: Text('Domain')),
                DataColumn(label: Text('Rows')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Next Step')),
              ],
              rows: [
                for (final item in items)
                  DataRow(cells: [
                    DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                    DataCell(SizedBox(width: 220, child: Text(item.dataset, style: const TextStyle(fontWeight: FontWeight.w800)))),
                    DataCell(Text(item.domain)),
                    DataCell(Text('${item.recordCount}')),
                    DataCell(InfoPill(label: item.status)),
                    DataCell(SizedBox(width: 520, child: Text(item.nextStep))),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({required this.connectedSources, required this.targetSources, required this.startedJobs});

  final int connectedSources;
  final int targetSources;
  final int startedJobs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(
          crossAxisCount: isWide ? 3 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: isWide ? 2.2 : 2.8,
          children: [
            _MetricCard(label: 'Connected Sources', value: '$connectedSources', detail: 'Reference layers live'),
            _MetricCard(label: 'Target Sources', value: '$targetSources', detail: 'Near-term source work'),
            _MetricCard(label: 'Started Jobs', value: '$startedJobs', detail: 'Repository loaders ready'),
          ],
        );
      },
    );
  }
}
