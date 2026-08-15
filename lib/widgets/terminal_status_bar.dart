import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';
import '../services/terminal_density_service.dart';

class TerminalStatusBar extends StatelessWidget {
  const TerminalStatusBar({
    super.key,
    required this.sourceLabel,
    required this.releaseLabel,
    required this.connectionLabel,
    required this.density,
    this.activeFilters = 0,
    this.backgroundTasks = 0,
  });

  final String sourceLabel;
  final String releaseLabel;
  final String connectionLabel;
  final TerminalDensity density;
  final int activeFilters;
  final int backgroundTasks;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context, density: density);
    return Container(
      height: 30,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: Row(
        children: [
          _StatusItem(label: 'DATA', value: sourceLabel),
          _divider(tokens),
          _StatusItem(label: 'RELEASE', value: releaseLabel),
          _divider(tokens),
          _StatusItem(label: 'CONNECTION', value: connectionLabel),
          _divider(tokens),
          _StatusItem(label: 'DENSITY', value: density.label),
          if (activeFilters > 0) ...[
            _divider(tokens),
            _StatusItem(label: 'FILTERS', value: '$activeFilters'),
          ],
          const Spacer(),
          if (backgroundTasks > 0)
            _StatusItem(label: 'TASKS', value: '$backgroundTasks'),
          SizedBox(width: tokens.space2),
          Container(width: 7, height: 7, decoration: BoxDecoration(color: tokens.positive, shape: BoxShape.circle)),
        ],
      ),
    );
  }

  Widget _divider(TerminalDesignTokens tokens) => Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.space2),
        child: SizedBox(width: 1, height: 12, child: ColoredBox(color: tokens.line)),
      );
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context, density: TerminalDensity.terminal);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label ', style: tokens.captionStyle.copyWith(fontWeight: FontWeight.w900)),
        TextSpan(text: value, style: tokens.captionStyle),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
