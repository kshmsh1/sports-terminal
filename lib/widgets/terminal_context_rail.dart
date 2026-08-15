import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';

class TerminalContextItem {
  const TerminalContextItem({
    required this.id,
    required this.label,
    required this.icon,
    this.selected = false,
    this.enabled = true,
    this.badge = '',
  });

  final String id;
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final String badge;

  TerminalContextItem copyWith({bool? selected}) => TerminalContextItem(
        id: id,
        label: label,
        icon: icon,
        selected: selected ?? this.selected,
        enabled: enabled,
        badge: badge,
      );
}

class TerminalContextCatalog {
  const TerminalContextCatalog._();

  static List<TerminalContextItem> forObjectType(String objectType) {
    switch (objectType.trim().toLowerCase()) {
      case 'player':
        return const [
          TerminalContextItem(id: 'overview', label: 'Overview', icon: Icons.dashboard_outlined, selected: true),
          TerminalContextItem(id: 'games', label: 'Games', icon: Icons.calendar_view_day_outlined),
          TerminalContextItem(id: 'splits', label: 'Splits', icon: Icons.call_split_outlined),
          TerminalContextItem(id: 'advanced', label: 'Advanced', icon: Icons.analytics_outlined),
          TerminalContextItem(id: 'career', label: 'Career', icon: Icons.timeline_outlined),
          TerminalContextItem(id: 'compare', label: 'Compare', icon: Icons.compare_arrows_outlined),
          TerminalContextItem(id: 'contracts', label: 'Contracts', icon: Icons.receipt_long_outlined),
          TerminalContextItem(id: 'research', label: 'Research', icon: Icons.science_outlined),
        ];
      case 'game':
        return const [
          TerminalContextItem(id: 'live', label: 'Live', icon: Icons.sports_score_outlined, selected: true),
          TerminalContextItem(id: 'timeline', label: 'Timeline', icon: Icons.view_timeline_outlined),
          TerminalContextItem(id: 'box', label: 'Box', icon: Icons.table_chart_outlined),
          TerminalContextItem(id: 'events', label: 'Events', icon: Icons.bolt_outlined),
          TerminalContextItem(id: 'lineups', label: 'Lineups', icon: Icons.groups_outlined),
          TerminalContextItem(id: 'models', label: 'Models', icon: Icons.model_training_outlined),
          TerminalContextItem(id: 'discussion', label: 'Discussion', icon: Icons.forum_outlined),
        ];
      case 'team':
      case 'franchise':
        return const [
          TerminalContextItem(id: 'overview', label: 'Overview', icon: Icons.dashboard_outlined, selected: true),
          TerminalContextItem(id: 'roster', label: 'Roster', icon: Icons.groups_outlined),
          TerminalContextItem(id: 'games', label: 'Games', icon: Icons.calendar_month_outlined),
          TerminalContextItem(id: 'lineups', label: 'Lineups', icon: Icons.account_tree_outlined),
          TerminalContextItem(id: 'performance', label: 'Performance', icon: Icons.analytics_outlined),
          TerminalContextItem(id: 'cap', label: 'Cap & Assets', icon: Icons.account_balance_wallet_outlined),
          TerminalContextItem(id: 'research', label: 'Research', icon: Icons.science_outlined),
        ];
      case 'season':
        return const [
          TerminalContextItem(id: 'overview', label: 'Overview', icon: Icons.dashboard_outlined, selected: true),
          TerminalContextItem(id: 'standings', label: 'Standings', icon: Icons.format_list_numbered_outlined),
          TerminalContextItem(id: 'schedule', label: 'Schedule', icon: Icons.calendar_month_outlined),
          TerminalContextItem(id: 'leaders', label: 'Leaders', icon: Icons.leaderboard_outlined),
          TerminalContextItem(id: 'playoffs', label: 'Playoffs', icon: Icons.emoji_events_outlined),
          TerminalContextItem(id: 'awards', label: 'Awards', icon: Icons.workspace_premium_outlined),
        ];
      default:
        return const [
          TerminalContextItem(id: 'overview', label: 'Overview', icon: Icons.dashboard_outlined, selected: true),
          TerminalContextItem(id: 'research', label: 'Research', icon: Icons.science_outlined),
          TerminalContextItem(id: 'sources', label: 'Sources', icon: Icons.fact_check_outlined),
        ];
    }
  }
}

class TerminalContextRail extends StatelessWidget {
  const TerminalContextRail({
    super.key,
    required this.items,
    required this.onSelected,
  });

  final List<TerminalContextItem> items;
  final ValueChanged<TerminalContextItem> onSelected;

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
        padding: EdgeInsets.all(tokens.space2),
        children: [
          Padding(
            padding: EdgeInsets.all(tokens.space2),
            child: Text('CONTEXT', style: tokens.captionStyle.copyWith(letterSpacing: 1.1)),
          ),
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.space1),
              child: Material(
                color: item.selected ? tokens.accent.withValues(alpha: .12) : Colors.transparent,
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                child: ListTile(
                  dense: true,
                  enabled: item.enabled,
                  selected: item.selected,
                  leading: Icon(item.icon, size: 18),
                  title: Text(item.label, style: tokens.bodyStyle),
                  trailing: item.badge.isEmpty
                      ? null
                      : Text(item.badge, style: tokens.captionStyle),
                  onTap: item.enabled ? () => onSelected(item) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
