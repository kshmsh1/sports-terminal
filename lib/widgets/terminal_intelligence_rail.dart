import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';
import '../models/terminal_action.dart';

class TerminalIntelligenceItem {
  const TerminalIntelligenceItem({
    required this.kind,
    required this.title,
    required this.body,
    this.timestamp = '',
    this.severity = 'info',
    this.onTap,
  });

  final String kind;
  final String title;
  final String body;
  final String timestamp;
  final String severity;
  final VoidCallback? onTap;
}

class TerminalIntelligenceRail extends StatelessWidget {
  const TerminalIntelligenceRail({
    super.key,
    required this.items,
    this.actions = const [],
    this.onAction,
  });

  final List<TerminalIntelligenceItem> items;
  final List<TerminalAction> actions;
  final ValueChanged<TerminalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      child: ListView(
        padding: EdgeInsets.all(tokens.space3),
        children: [
          Text('INTELLIGENCE', style: tokens.captionStyle.copyWith(letterSpacing: 1.1)),
          if (actions.isNotEmpty) ...[
            SizedBox(height: tokens.space2),
            Wrap(
              spacing: tokens.space1,
              runSpacing: tokens.space1,
              children: [
                for (final action in actions.take(6))
                  ActionChip(
                    label: Text(action.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                    onPressed: action.enabled && onAction != null ? () => onAction!(action) : null,
                  ),
              ],
            ),
          ],
          SizedBox(height: tokens.space3),
          if (items.isEmpty)
            Text(
              'No contextual alerts, watched-object updates, research, or source notices for this view.',
              style: tokens.captionStyle,
            )
          else
            for (final item in items) ...[
              _IntelligenceCard(item: item),
              SizedBox(height: tokens.space2),
            ],
        ],
      ),
    );
  }
}

class _IntelligenceCard extends StatelessWidget {
  const _IntelligenceCard({required this.item});
  final TerminalIntelligenceItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    final color = switch (item.severity) {
      'warning' => tokens.warning,
      'critical' => tokens.negative,
      'positive' => tokens.positive,
      _ => tokens.accent,
    };
    return Material(
      color: tokens.panelRaised,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        child: Container(
          padding: EdgeInsets.all(tokens.space2),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.line),
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  SizedBox(width: tokens.space1),
                  Expanded(child: Text(item.kind.toUpperCase(), style: tokens.captionStyle)),
                  if (item.timestamp.isNotEmpty) Text(item.timestamp, style: tokens.captionStyle),
                ],
              ),
              SizedBox(height: tokens.space1),
              Text(item.title, style: tokens.bodyStyle.copyWith(fontWeight: FontWeight.w800)),
              SizedBox(height: tokens.space1),
              Text(item.body, style: tokens.captionStyle),
            ],
          ),
        ),
      ),
    );
  }
}
