import 'package:flutter/material.dart';

import '../services/terminal_density_service.dart';

class TerminalDesignTokens {
  const TerminalDesignTokens({
    required this.background,
    required this.canvas,
    required this.panel,
    required this.panelRaised,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.positive,
    required this.warning,
    required this.negative,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.canvasPadding,
    required this.rowHeight,
    required this.titleStyle,
    required this.sectionStyle,
    required this.bodyStyle,
    required this.captionStyle,
    required this.metricStyle,
  });

  final Color background;
  final Color canvas;
  final Color panel;
  final Color panelRaised;
  final Color line;
  final Color text;
  final Color muted;
  final Color accent;
  final Color positive;
  final Color warning;
  final Color negative;
  final double space1;
  final double space2;
  final double space3;
  final double space4;
  final double space5;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double canvasPadding;
  final double rowHeight;
  final TextStyle titleStyle;
  final TextStyle sectionStyle;
  final TextStyle bodyStyle;
  final TextStyle captionStyle;
  final TextStyle metricStyle;

  static TerminalDesignTokens of(
    BuildContext context, {
    TerminalDensity density = TerminalDensity.analyst,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scale = switch (density) {
      TerminalDensity.summary => 1.12,
      TerminalDensity.analyst => 1.0,
      TerminalDensity.terminal => 0.88,
    };
    final text = dark ? const Color(0xFFE8EDF3) : const Color(0xFF152033);
    final muted = dark ? const Color(0xFF95A4B8) : const Color(0xFF64748B);
    return TerminalDesignTokens(
      background: dark ? const Color(0xFF07111F) : const Color(0xFFF5F7FB),
      canvas: dark ? const Color(0xFF0B1523) : Colors.white,
      panel: dark ? const Color(0xFF101B2A) : const Color(0xFFF8FAFC),
      panelRaised: dark ? const Color(0xFF142235) : const Color(0xFFFFFFFF),
      line: dark ? const Color(0xFF26374C) : const Color(0xFFDCE3EC),
      text: text,
      muted: muted,
      accent: const Color(0xFF4F8CFF),
      positive: const Color(0xFF20B26B),
      warning: const Color(0xFFF0A429),
      negative: const Color(0xFFE05252),
      space1: 4 * scale,
      space2: 8 * scale,
      space3: 12 * scale,
      space4: 16 * scale,
      space5: 24 * scale,
      radiusSmall: 6,
      radiusMedium: 10,
      radiusLarge: 14,
      canvasPadding: 16 * scale,
      rowHeight: 42 * scale,
      titleStyle: TextStyle(
        color: text,
        fontSize: 20 * scale,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      sectionStyle: TextStyle(
        color: text,
        fontSize: 13 * scale,
        fontWeight: FontWeight.w800,
        letterSpacing: .35,
      ),
      bodyStyle: TextStyle(
        color: text,
        fontSize: 12 * scale,
        fontWeight: FontWeight.w500,
      ),
      captionStyle: TextStyle(
        color: muted,
        fontSize: 10.5 * scale,
        fontWeight: FontWeight.w600,
      ),
      metricStyle: TextStyle(
        color: text,
        fontSize: 18 * scale,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class TerminalPanel extends StatelessWidget {
  const TerminalPanel({
    super.key,
    required this.child,
    this.padding,
    this.title,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(child: Text(title!, style: tokens.sectionStyle)),
                  if (trailing != null) trailing!,
                ],
              ),
              SizedBox(height: tokens.space3),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
