import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';
import '../models/terminal_board.dart';

class TerminalBoardWorkspace extends StatelessWidget {
  const TerminalBoardWorkspace({
    super.key,
    required this.board,
    this.panelBuilders = const {},
    this.onRemovePanel,
    this.onToggleLiveRefresh,
  });

  final TerminalBoard board;
  final Map<String, Widget Function(TerminalBoardPanel)> panelBuilders;
  final ValueChanged<String>? onRemovePanel;
  final ValueChanged<bool>? onToggleLiveRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(board.title, style: tokens.titleStyle),
                  if (board.description.isNotEmpty)
                    Text(board.description, style: tokens.captionStyle),
                ],
              ),
            ),
            FilterChip(
              label: const Text('LIVE REFRESH'),
              selected: board.liveRefresh,
              onSelected: onToggleLiveRefresh,
            ),
          ],
        ),
        SizedBox(height: tokens.space3),
        if (board.panels.isEmpty)
          TerminalPanel(
            child: Padding(
              padding: EdgeInsets.all(tokens.space5),
              child: Column(
                children: [
                  Icon(Icons.dashboard_customize_outlined, color: tokens.muted, size: 34),
                  SizedBox(height: tokens.space2),
                  Text('This Board has no panels yet.', style: tokens.bodyStyle),
                  SizedBox(height: tokens.space1),
                  Text(
                    'Send an object, query, chart, comparison or research object to BOARD.',
                    style: tokens.captionStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1200
                  ? 3
                  : constraints.maxWidth >= 720
                      ? 2
                      : 1;
              final width = (constraints.maxWidth - (columns - 1) * tokens.space3) / columns;
              return Wrap(
                spacing: tokens.space3,
                runSpacing: tokens.space3,
                children: [
                  for (final panel in board.panels)
                    SizedBox(
                      width: width * panel.width.clamp(1, columns) +
                          tokens.space3 * (panel.width.clamp(1, columns) - 1),
                      child: TerminalPanel(
                        title: panel.title,
                        trailing: onRemovePanel == null
                            ? null
                            : IconButton(
                                tooltip: 'Remove panel',
                                onPressed: () => onRemovePanel!(panel.id),
                                icon: const Icon(Icons.close_rounded, size: 17),
                              ),
                        child: _buildPanel(panel, tokens),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildPanel(TerminalBoardPanel panel, TerminalDesignTokens tokens) {
    final builder = panelBuilders[panel.kind];
    if (builder != null) return builder(panel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(panel.kind.toUpperCase(), style: tokens.captionStyle),
        SizedBox(height: tokens.space2),
        for (final entry in panel.payload.entries.take(8))
          Padding(
            padding: EdgeInsets.only(bottom: tokens.space1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(entry.key, style: tokens.captionStyle),
                ),
                Expanded(child: Text('${entry.value}', style: tokens.bodyStyle)),
              ],
            ),
          ),
      ],
    );
  }
}
