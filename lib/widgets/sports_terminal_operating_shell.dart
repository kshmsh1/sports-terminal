import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';
import '../models/terminal_action.dart';
import '../services/terminal_density_service.dart';
import 'terminal_command_bar.dart';
import 'terminal_context_rail.dart';
import 'terminal_intelligence_rail.dart';
import 'terminal_status_bar.dart';

/// Blueprint-level application chrome shared by every Sports Terminal surface.
///
/// The shell deliberately separates context navigation, the working canvas,
/// intelligence, and status so product pages do not invent their own chrome.
class SportsTerminalOperatingShell extends StatelessWidget {
  const SportsTerminalOperatingShell({
    super.key,
    required this.title,
    required this.body,
    required this.contextItems,
    required this.onContextSelected,
    required this.commandEntries,
    required this.onCommand,
    required this.density,
    required this.onDensityChanged,
    this.subtitle = '',
    this.sourceLabel = 'LOCAL / DEVELOPMENT',
    this.releaseLabel = 'UNRELEASED',
    this.connectionLabel = 'LOCAL',
    this.intelligenceItems = const [],
    this.actions = const [],
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final List<TerminalContextItem> contextItems;
  final ValueChanged<TerminalContextItem> onContextSelected;
  final List<TerminalCommandEntry> commandEntries;
  final ValueChanged<TerminalCommandResult> onCommand;
  final TerminalDensity density;
  final ValueChanged<TerminalDensity> onDensityChanged;
  final String sourceLabel;
  final String releaseLabel;
  final String connectionLabel;
  final List<TerminalIntelligenceItem> intelligenceItems;
  final List<TerminalAction> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context, density: density);
    final narrow = compact || MediaQuery.sizeOf(context).width < 1050;

    final canvas = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.canvas,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space4,
              tokens.space3,
              tokens.space3,
              tokens.space3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tokens.titleStyle),
                      if (subtitle.trim().isNotEmpty) ...[
                        SizedBox(height: tokens.space1),
                        Text(subtitle, style: tokens.captionStyle),
                      ],
                    ],
                  ),
                ),
                TerminalDensitySelector(
                  value: density,
                  onChanged: onDensityChanged,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.line),
          Padding(
            padding: EdgeInsets.all(tokens.canvasPadding),
            child: body,
          ),
        ],
      ),
    );

    return ColoredBox(
      color: tokens.background,
      child: Column(
        children: [
          TerminalCommandBar(
            entries: commandEntries,
            onResult: onCommand,
            actions: actions,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(tokens.space3),
              child: narrow
                  ? canvas
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TerminalContextRail(
                            items: contextItems,
                            onSelected: onContextSelected,
                          ),
                        ),
                        SizedBox(width: tokens.space3),
                        Expanded(child: canvas),
                        SizedBox(width: tokens.space3),
                        SizedBox(
                          width: 280,
                          child: TerminalIntelligenceRail(
                            items: intelligenceItems,
                            actions: actions,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          TerminalStatusBar(
            sourceLabel: sourceLabel,
            releaseLabel: releaseLabel,
            connectionLabel: connectionLabel,
            density: density,
          ),
        ],
      ),
    );
  }
}
