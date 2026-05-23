import 'package:flutter/material.dart';

import '../data/immediate_release_items.dart';
import '../widgets/immediate_release_panel.dart';
import '../widgets/terminal_primitives.dart';

class CoreMvpGapsScreen extends StatelessWidget {
  const CoreMvpGapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = immediateReleaseItems.where((item) => item.category == 'Workspace').length;
    final compare = immediateReleaseItems.where((item) => item.category == 'Compare').length;
    final reports = immediateReleaseItems.where((item) => item.category == 'Reports').length;
    final exports = immediateReleaseItems.where((item) => item.category == 'Exports').length;
    final alerts = immediateReleaseItems.where((item) => item.category == 'Alerts').length;
    final command = immediateReleaseItems.length - workspace - compare - reports - exports - alerts;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(
        title: 'Immediate Release Payloads',
        subtitle: 'First working route payloads for connected Teams, Seasons, Source Registry, Import Jobs, Data Coverage, QA, Workspace, Compare, Reports, Saved Views, Export, Alerts, Dashboard, Search, and Action Center.',
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
          childAspectRatio: isWide ? 1.95 : 1.45,
          children: [
            _Metric(label: 'Immediate Payloads', value: '${immediateReleaseItems.length}', detail: 'Visible route targets'),
            _Metric(label: 'Workspace / Compare', value: '$workspace / $compare', detail: 'First table + side-by-side'),
            _Metric(label: 'Reports / Exports', value: '$reports / $exports', detail: 'First output shells'),
            _Metric(label: 'Alerts / Command', value: '$alerts / $command', detail: 'Monitoring + routing'),
          ],
        );
      }),
      const SizedBox(height: 22),
      const _ReleasePrincipleCard(),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(
        title: 'All Immediate Workflow Payloads',
        subtitle: 'This is the execution map for moving from architecture into visible payload previews. These rows should become the first real route outputs before player/stat imports.',
      ),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(
        target: 'Workspace',
        title: 'Workspace Activation Targets',
        subtitle: 'First non-empty Workspace Studio payloads should come from connected team rows, season rows, and operations rows.',
      ),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(
        target: 'Compare',
        title: 'Compare Activation Targets',
        subtitle: 'First Compare outputs should be Team vs Team, Season vs Season, Source vs Source, and Import Job vs Import Job.',
      ),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(
        target: 'Reports',
        title: 'Report Activation Targets',
        subtitle: 'First report shells should be Team Brief, Season Brief, Source Audit, Import Monitor, Data Coverage, and QA Readiness.',
      ),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(
        target: 'Exports',
        title: 'Export Preview Targets',
        subtitle: 'First export manifests should preview row count, selected columns, source notes, missing-data flags, and disabled download copy.',
      ),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(
        target: 'Alerts',
        title: 'Alert Preview Targets',
        subtitle: 'First alert previews should monitor team directory changes, season catalog changes, source status movement, and import job movement.',
      ),
    ]);
  }
}

class _ReleasePrincipleCard extends StatelessWidget {
  const _ReleasePrincipleCard();

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('First Workflow Release Principle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      SizedBox(height: 12),
      Text('The app should now prove terminal behavior with rows that already exist. Teams, Seasons, and operational registries should route into Workspace Studio, Compare, Reports, Saved Views, Export previews, Alerts, Dashboard cards, Search results, and Action Center routes before we import player identity or NBA stat rows.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        InfoPill(label: 'Teams → Workspace'),
        InfoPill(label: 'Seasons → Compare'),
        InfoPill(label: 'Sources → Reports'),
        InfoPill(label: 'Imports → Exports'),
        InfoPill(label: 'Coverage → Dashboard'),
        InfoPill(label: 'QA → Release Gate'),
      ]),
    ]));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
      Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
    ]));
  }
}
