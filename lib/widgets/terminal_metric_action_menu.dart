import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';
import '../models/terminal_action.dart';

class TerminalMetricEvidence {
  const TerminalMetricEvidence({
    required this.metricId,
    required this.label,
    required this.valueLabel,
    this.definition = '',
    this.source = '',
    this.method = '',
    this.release = '',
    this.coverage = '',
  });

  final String metricId;
  final String label;
  final String valueLabel;
  final String definition;
  final String source;
  final String method;
  final String release;
  final String coverage;
}

/// A metric is never a decorative dead end. Selecting it exposes evidence and
/// the standard Terminal action grammar.
class TerminalActionableMetric extends StatelessWidget {
  const TerminalActionableMetric({
    super.key,
    required this.evidence,
    this.actions = TerminalAction.standard,
    this.onAction,
  });

  final TerminalMetricEvidence evidence;
  final List<TerminalAction> actions;
  final ValueChanged<TerminalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    return Semantics(
      button: true,
      label: '${evidence.label}: ${evidence.valueLabel}. Open metric evidence and actions.',
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _MetricSheet(
            evidence: evidence,
            actions: actions,
            onAction: onAction,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space2,
            vertical: tokens.space1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(evidence.label.toUpperCase(), style: tokens.captionStyle),
              Text(
                evidence.valueLabel,
                style: tokens.metricStyle.copyWith(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricSheet extends StatelessWidget {
  const _MetricSheet({
    required this.evidence,
    required this.actions,
    this.onAction,
  });

  final TerminalMetricEvidence evidence;
  final List<TerminalAction> actions;
  final ValueChanged<TerminalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    final evidenceRows = <(String, String)>[
      ('Definition', evidence.definition),
      ('Source', evidence.source),
      ('Method', evidence.method),
      ('Release', evidence.release),
      ('Coverage', evidence.coverage),
      ('Metric ID', evidence.metricId),
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.space5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(evidence.label, style: tokens.titleStyle),
              SizedBox(height: tokens.space1),
              Text(evidence.valueLabel, style: tokens.metricStyle),
              SizedBox(height: tokens.space4),
              for (final row in evidenceRows)
                if (row.$2.trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.space2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(row.$1.toUpperCase(), style: tokens.captionStyle),
                        ),
                        Expanded(child: SelectableText(row.$2, style: tokens.bodyStyle)),
                      ],
                    ),
                  ),
              SizedBox(height: tokens.space3),
              Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space2,
                children: [
                  for (final action in actions)
                    OutlinedButton(
                      onPressed: action.enabled && onAction != null
                          ? () {
                              Navigator.of(context).pop();
                              onAction!(action);
                            }
                          : null,
                      child: Text(action.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
