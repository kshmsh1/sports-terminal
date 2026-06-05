import 'package:flutter/material.dart';

import '../data/immediate_release_items.dart';
import '../widgets/first_release_payload_preview.dart';
import '../widgets/first_release_route_engine.dart';
import '../widgets/first_release_route_outputs.dart';
import '../widgets/immediate_release_panel.dart';
import '../widgets/pre_data_readiness_gate_panel.dart';
import '../widgets/terminal_primitives.dart';
import 'source_backed_data_wave_screen.dart';

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
        subtitle: 'First working route payloads for connected Teams, Seasons, operations, Workspace, Compare, Reports, Saved Views, Export, Alerts, Dashboard, Search, and Action Center.',
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
      const PreDataReadinessGatePanel(compact: true),
      const SizedBox(height: 22),
      const _ReleasePrincipleCard(),
      const SizedBox(height: 22),
      const FirstReleaseRouteEngine(),
      const SizedBox(height: 22),
      const FirstReleasePayloadPreview(rowLimit: 8, showImmediatePanel: false),
      const SizedBox(height: 22),
      const FirstReleaseRouteOutputs(),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(title: 'All Immediate Workflow Payloads'),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(target: 'Workspace', title: 'Workspace Activation Targets'),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(target: 'Compare', title: 'Compare Activation Targets'),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(target: 'Reports', title: 'Report Activation Targets'),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(target: 'Exports', title: 'Export Preview Targets'),
      const SizedBox(height: 22),
      const ImmediateReleasePanel(target: 'Alerts', title: 'Alert Preview Targets'),
      const SizedBox(height: 28),
      const SourceBackedDataWaveScreen(),
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
      Text('Teams, Seasons, and operations rows should now become selectable route payloads before player identity or stat rows are imported.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
      SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        InfoPill(label: 'Teams to Workspace'),
        InfoPill(label: 'Seasons to Compare'),
        InfoPill(label: 'Sources to Reports'),
        InfoPill(label: 'Imports to Exports'),
        InfoPill(label: 'Coverage to Dashboard'),
        InfoPill(label: 'QA to Release Gate'),
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
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
    Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
  ]));
}
