import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';
import '../services/terminal_density_service.dart';

class TerminalObjectFact {
  const TerminalObjectFact({required this.label, required this.value});
  final String label;
  final String value;
}

class TerminalObjectHeader extends StatelessWidget {
  const TerminalObjectHeader({
    super.key,
    required this.objectType,
    required this.title,
    this.subtitle = '',
    this.status = '',
    this.sourceClass = '',
    this.release = '',
    this.facts = const [],
    this.actions = const [],
    this.density = TerminalDensity.analyst,
  });

  final String objectType;
  final String title;
  final String subtitle;
  final String status;
  final String sourceClass;
  final String release;
  final List<TerminalObjectFact> facts;
  final List<Widget> actions;
  final TerminalDensity density;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context, density: density);
    return TerminalPanel(
      padding: EdgeInsets.all(tokens.space4),
      child: Wrap(
        spacing: tokens.space4,
        runSpacing: tokens.space3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  objectType.toUpperCase(),
                  style: tokens.captionStyle.copyWith(
                    color: tokens.accent,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: tokens.space1),
                Text(title, style: tokens.titleStyle),
                if (subtitle.trim().isNotEmpty) ...[
                  SizedBox(height: tokens.space1),
                  Text(subtitle, style: tokens.captionStyle),
                ],
              ],
            ),
          ),
          for (final fact in facts)
            _FactCell(fact: fact, tokens: tokens),
          if (status.trim().isNotEmpty)
            _HeaderBadge(label: status, tokens: tokens, emphasized: true),
          if (sourceClass.trim().isNotEmpty)
            _HeaderBadge(label: sourceClass, tokens: tokens),
          if (release.trim().isNotEmpty)
            _HeaderBadge(label: release, tokens: tokens),
          if (actions.isNotEmpty)
            Wrap(spacing: tokens.space2, runSpacing: tokens.space2, children: actions),
        ],
      ),
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({required this.fact, required this.tokens});
  final TerminalObjectFact fact;
  final TerminalDesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92, maxWidth: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fact.label.toUpperCase(), style: tokens.captionStyle),
          SizedBox(height: tokens.space1),
          Text(
            fact.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tokens.bodyStyle.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.label,
    required this.tokens,
    this.emphasized = false,
  });
  final String label;
  final TerminalDesignTokens tokens;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.space2, vertical: tokens.space1),
      decoration: BoxDecoration(
        color: emphasized
            ? tokens.accent.withValues(alpha: .14)
            : tokens.panelRaised,
        border: Border.all(
          color: emphasized ? tokens.accent.withValues(alpha: .45) : tokens.line,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: tokens.captionStyle.copyWith(
          color: emphasized ? tokens.accent : tokens.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
