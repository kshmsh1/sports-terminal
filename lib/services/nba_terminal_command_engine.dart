import 'package:flutter/material.dart';

class NbaTerminalCommand {
  const NbaTerminalCommand({
    required this.id,
    required this.label,
    required this.group,
    required this.description,
    required this.icon,
    required this.aliases,
    this.shortcut = '',
    this.requiresOrganization = false,
  });

  final String id;
  final String label;
  final String group;
  final String description;
  final IconData icon;
  final List<String> aliases;
  final String shortcut;
  final bool requiresOrganization;

  String get searchable => [
        id,
        label,
        group,
        description,
        ...aliases,
      ].join(' ').toLowerCase();
}

class NbaTerminalCommandMatch {
  const NbaTerminalCommandMatch({
    required this.command,
    required this.score,
  });

  final NbaTerminalCommand command;
  final int score;
}

class NbaTerminalCommandEngine {
  const NbaTerminalCommandEngine();

  static const catalog = <NbaTerminalCommand>[
    NbaTerminalCommand(
      id: 'terminal',
      label: 'NBA Terminal Home',
      group: 'Core',
      description: 'League-wide operating home, active context, saved work and coverage.',
      icon: Icons.space_dashboard_rounded,
      aliases: ['home', 'dashboard', 'command center', 'nba terminal'],
      shortcut: 'HOME',
    ),
    NbaTerminalCommand(
      id: 'entity',
      label: 'Entity & Season Intelligence',
      group: 'NBA',
      description: 'Canonical player, team, franchise, season and game dossiers.',
      icon: Icons.hub_rounded,
      aliases: ['entity', 'player', 'team', 'franchise', 'season', 'game', 'dossier'],
      shortcut: 'ENT',
    ),
    NbaTerminalCommand(
      id: 'universe',
      label: 'NBA Universe',
      group: 'NBA',
      description: 'Discover the connected NBA entity graph and activate research context.',
      icon: Icons.public_rounded,
      aliases: ['universe', 'directory', 'roster', 'players', 'teams'],
      shortcut: 'NBA',
    ),
    NbaTerminalCommand(
      id: 'stats',
      label: 'Stats Workstation',
      group: 'Research',
      description: 'Dense sortable player statistics, filters, percentiles, compare and exports.',
      icon: Icons.table_chart_rounded,
      aliases: ['stats', 'leaderboard', 'rankings', 'percentile', 'per 36', 'per 100'],
      shortcut: 'STAT',
    ),
    NbaTerminalCommand(
      id: 'analytics',
      label: 'Analytics Suite',
      group: 'Research',
      description: 'Player/team comparison, rankings, last-X, shot profile and lineup tools.',
      icon: Icons.analytics_rounded,
      aliases: ['analytics', 'compare', 'lineup', 'shot profile', 'rank', 'last x'],
      shortcut: 'ANL',
    ),
    NbaTerminalCommand(
      id: 'history',
      label: 'Historical Intelligence',
      group: 'Research',
      description: 'All-time records, cross-era analysis, games, PBP and franchise lineage.',
      icon: Icons.history_edu_rounded,
      aliases: ['history', 'historical', 'all time', 'records', 'era', 'play by play'],
      shortcut: 'HIST',
    ),
    NbaTerminalCommand(
      id: 'research',
      label: 'Research Command Center',
      group: 'Research',
      description: 'Research boards, Stats, Analytics, data coverage and methodology.',
      icon: Icons.query_stats_rounded,
      aliases: ['research', 'boards', 'methodology', 'coverage', 'workspace'],
      shortcut: 'RES',
    ),
    NbaTerminalCommand(
      id: 'trade',
      label: 'Trade Machine',
      group: 'Front Office',
      description: 'Multi-team salary matching, apron checks and transaction scenario modeling.',
      icon: Icons.swap_horiz_rounded,
      aliases: ['trade', 'salary matching', 'apron', 'deal', 'transaction'],
      shortcut: 'TRD',
    ),
    NbaTerminalCommand(
      id: 'front-office',
      label: 'Front Office',
      group: 'Front Office',
      description: 'Roster, cap, contract, draft-asset and transaction decision support.',
      icon: Icons.account_tree_rounded,
      aliases: ['front office', 'cap', 'roster', 'contracts', 'draft assets'],
      shortcut: 'FO',
    ),
    NbaTerminalCommand(
      id: 'contracts',
      label: 'Contracts & Assets',
      group: 'Front Office',
      description: 'Versioned player contracts, cap positions, picks and ledger records.',
      icon: Icons.inventory_2_rounded,
      aliases: ['contracts', 'assets', 'picks', 'ledger', 'salary'],
      shortcut: 'CTR',
    ),
    NbaTerminalCommand(
      id: 'transactions',
      label: 'Transaction Command Center',
      group: 'Operations',
      description: 'Personal or organization case queue, approvals, comments and activity.',
      icon: Icons.workspaces_rounded,
      aliases: ['transactions', 'cases', 'approvals', 'workflow', 'my work'],
      shortcut: 'TXN',
    ),
    NbaTerminalCommand(
      id: 'workspace',
      label: 'Workspace',
      group: 'Tools',
      description: 'Multi-sheet spreadsheet modeling, routed data, formulas and versions.',
      icon: Icons.grid_on_rounded,
      aliases: ['workspace', 'spreadsheet', 'workbook', 'excel', 'model'],
      shortcut: 'WS',
    ),
    NbaTerminalCommand(
      id: 'python',
      label: 'Python Lab',
      group: 'Tools',
      description: 'Analyze routed terminal datasets in the bounded Python runtime.',
      icon: Icons.code_rounded,
      aliases: ['python', 'notebook', 'code', 'dataframe', 'pandas'],
      shortcut: 'PY',
    ),
    NbaTerminalCommand(
      id: 'automation',
      label: 'Automation Center',
      group: 'Operations',
      description: 'Scheduled and governed platform automations and execution policy.',
      icon: Icons.auto_awesome_motion_rounded,
      aliases: ['automation', 'scheduled', 'rules', 'governance'],
      shortcut: 'AUTO',
    ),
    NbaTerminalCommand(
      id: 'organization',
      label: 'Organization Admin',
      group: 'Organization',
      description: 'Members, permissions, governance and organization operating controls.',
      icon: Icons.admin_panel_settings_rounded,
      aliases: ['organization', 'admin', 'members', 'permissions'],
      shortcut: 'ORG',
      requiresOrganization: true,
    ),
    NbaTerminalCommand(
      id: 'trust',
      label: 'Trust & Safety',
      group: 'Organization',
      description: 'Reports, moderation actions and audit state.',
      icon: Icons.shield_rounded,
      aliases: ['trust', 'safety', 'moderation', 'reports', 'audit'],
      shortcut: 'T&S',
      requiresOrganization: true,
    ),
    NbaTerminalCommand(
      id: 'community',
      label: 'Community',
      group: 'Network',
      description: 'Moderated NBA discussion, replies, reports, blocks and mutes.',
      icon: Icons.forum_rounded,
      aliases: ['community', 'forum', 'discussion', 'threads'],
      shortcut: 'COM',
    ),
    NbaTerminalCommand(
      id: 'messages',
      label: 'Messages',
      group: 'Network',
      description: 'Protected direct conversations and organization communication.',
      icon: Icons.chat_bubble_rounded,
      aliases: ['messages', 'chat', 'dm', 'conversation'],
      shortcut: 'MSG',
    ),
    NbaTerminalCommand(
      id: 'fantasy',
      label: 'Fantasy War Room',
      group: 'NBA',
      description: 'Fantasy target watchlists and connected player analysis.',
      icon: Icons.bolt_rounded,
      aliases: ['fantasy', 'watchlist', 'targets'],
      shortcut: 'FAN',
    ),
    NbaTerminalCommand(
      id: 'profile',
      label: 'Profile & Preferences',
      group: 'Account',
      description: 'Identity, account and persistent preference controls.',
      icon: Icons.person_rounded,
      aliases: ['profile', 'account', 'preferences', 'settings'],
      shortcut: 'PROF',
    ),
  ];

  List<NbaTerminalCommandMatch> search(
    String query, {
    bool organizationMode = false,
    int limit = 20,
  }) {
    final normalized = _normalize(query);
    final available = catalog
        .where((command) => organizationMode || !command.requiresOrganization)
        .toList();
    if (normalized.isEmpty) {
      return [
        for (final command in available.take(limit))
          NbaTerminalCommandMatch(command: command, score: 0),
      ];
    }
    final tokens = normalized.split(' ').where((value) => value.isNotEmpty).toList();
    final matches = <NbaTerminalCommandMatch>[];
    for (final command in available) {
      final label = _normalize(command.label);
      final shortcut = _normalize(command.shortcut);
      final searchable = _normalize(command.searchable);
      var score = 0;
      if (command.id == normalized || shortcut == normalized) score += 1000;
      if (label == normalized) score += 900;
      if (label.startsWith(normalized)) score += 450;
      if (searchable.contains(normalized)) score += 220;
      for (final token in tokens) {
        if (label.startsWith(token)) score += 90;
        if (searchable.contains(token)) score += 35;
      }
      if (score > 0) matches.add(NbaTerminalCommandMatch(command: command, score: score));
    }
    matches.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.command.label.compareTo(b.command.label);
    });
    return matches.take(limit).toList();
  }

  NbaTerminalCommand? resolve(String input, {bool organizationMode = false}) {
    final matches = search(input, organizationMode: organizationMode, limit: 1);
    return matches.isEmpty ? null : matches.first.command;
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9&+]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
