import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../models/route_payload.dart';
import 'route_payload_generated_report_panel.dart';
import 'terminal_primitives.dart';

class ActiveRoutePayloadPanel extends StatelessWidget {
  const ActiveRoutePayloadPanel({
    super.key,
    required this.consumerName,
    this.description,
    this.compact = false,
  });

  final String consumerName;
  final String? description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      return const TerminalCard(child: Text('RoutePayloadScope is not available for this screen.', style: TextStyle(color: terminalTextSoft)));
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final payload = controller.activePayload;
        if (payload == null) {
          return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('$consumerName RoutePayload Intake', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const InfoPill(label: 'Waiting for payload')]),
            const SizedBox(height: 10),
            Text(description ?? 'Use the Interactive First-Release Route Engine to publish a Team, Season, or Operations object. This consumer will then render the shared payload instead of relying only on local static state.', style: const TextStyle(color: terminalTextSoft, height: 1.4)),
            const SizedBox(height: 14),
            const Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'No active payload'), InfoPill(label: 'Shared state ready'), InfoPill(label: 'Route engine source')]),
          ]));
        }

        final interpretation = _interpretPayload(consumerName, payload);
        final isReportConsumer = consumerName.toLowerCase().contains('report');
        return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text('$consumerName RoutePayload Intake', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            InfoPill(label: payload.targetRoute),
            const SizedBox(width: 8),
            InfoPill(label: payload.readinessState),
          ]),
          const SizedBox(height: 10),
          Text(interpretation, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            InfoPill(label: payload.sourceObjectType),
            InfoPill(label: payload.sourceObjectId),
            InfoPill(label: '${payload.selectedColumns.length} columns'),
            InfoPill(label: '${payload.selectedRows.length} selected row(s)'),
            InfoPill(label: payload.hasBlockers ? 'Blockers visible' : 'No blockers'),
          ]),
          const SizedBox(height: 16),
          _PayloadDetailGrid(payload: payload, origin: controller.lastOrigin, compact: compact),
          if (isReportConsumer) ...[
            const SizedBox(height: 16),
            RoutePayloadGeneratedReportPanel(payload: payload),
          ],
          if (!compact) ...[
            const SizedBox(height: 16),
            _PayloadHistoryStrip(history: controller.history),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final route in immediateRouteTargets)
              OutlinedButton(
                onPressed: () => controller.retargetActivePayload(route, origin: '$consumerName retarget'),
                child: Text(route),
              ),
            OutlinedButton(onPressed: controller.clear, child: const Text('Clear payload')),
          ]),
        ]));
      },
    );
  }
}

String _interpretPayload(String consumerName, RoutePayload payload) {
  final normalized = consumerName.toLowerCase();
  if (normalized.contains('workspace')) {
    return 'Workspace Studio can turn ${payload.displayLabel} into an active table/workspace input using selected rows, selected columns, filters, source snapshot, blockers, and route actions.';
  }
  if (normalized.contains('compare')) {
    return 'Compare can use ${payload.displayLabel} as a comparison slot seed. Identity fields work now, while deeper statistical/contextual scorecards remain gated by source-backed data.';
  }
  if (normalized.contains('report')) {
    return 'Reports generates a source-aware report shell from ${payload.displayLabel}, preserving structured rows, missing values, readiness, blockers, selected fields, and source-as-of state without inventing unsupported sports claims.';
  }
  if (normalized.contains('saved')) {
    return 'Saved Views can serialize this payload into non-persistent view memory: selected rows, selected columns, filters, source snapshot, output route, and blocker state.';
  }
  if (normalized.contains('export')) {
    return 'Export Center can turn ${payload.displayLabel} into a governed export manifest with columns, rows, filters, missing-data flags, source notes, and route intent.';
  }
  if (normalized.contains('alert')) {
    return 'Alerts can convert this payload into a monitor preview for row-count changes, source-state changes, selected field movement, and unresolved blockers.';
  }
  if (normalized.contains('dashboard')) {
    return 'Dashboard can render ${payload.displayLabel} as a command-center card with target route, readiness state, blockers, and next action.';
  }
  if (normalized.contains('search')) {
    return 'Search can treat this payload as an actionable command result that routes directly into open, workspace, compare, report, save, export, alert, and source audit actions.';
  }
  if (normalized.contains('action')) {
    return 'Action Center can treat this as the current universal action ticket: source object, target route, readiness state, blockers, and available actions.';
  }
  return '$consumerName is reading the active RoutePayload for ${payload.displayLabel} and can use its shared route state instead of static local-only UI state.';
}

class _PayloadDetailGrid extends StatelessWidget {
  const _PayloadDetailGrid({required this.payload, required this.origin, required this.compact});
  final RoutePayload payload;
  final String origin;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = <_PayloadField>[
      _PayloadField('Origin', origin),
      _PayloadField('Object', '${payload.sourceObjectType} · ${payload.displayLabel}'),
      _PayloadField('Object ID', payload.sourceObjectId),
      _PayloadField('Route Key', payload.routeKey),
      _PayloadField('Filters', payload.filterSummary),
      _PayloadField('Source', payload.sourceSnapshot),
      _PayloadField('Columns', payload.selectedColumnsLabel),
      _PayloadField('Rows', payload.selectedRowsLabel),
      _PayloadField('Blockers', payload.blockersLabel),
      _PayloadField('Actions', payload.actionsLabel),
    ];
    final shown = compact ? rows.take(6).toList() : rows;
    return Column(children: [for (final row in shown) _DetailLine(label: row.label, value: row.value)]);
  }
}

class _PayloadField {
  const _PayloadField(this.label, this.value);
  final String label;
  final String value;
}

class _PayloadHistoryStrip extends StatelessWidget {
  const _PayloadHistoryStrip({required this.history});
  final List<RoutePayload> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recent RoutePayload History', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final item in history.take(8)) InfoPill(label: item.conciseDebugLabel)]),
    ]);
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 125, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))),
          Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3))),
        ]),
      );
}
