import 'package:flutter/material.dart';

class NbaWorkspaceLink {
  const NbaWorkspaceLink({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.group,
    required this.mode,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final String group;
  final String mode;
}

const nbaWorkspaceLinks = <NbaWorkspaceLink>[
  NbaWorkspaceLink(
    id: 'player-compare',
    label: 'Player Compare',
    subtitle: '2–5 players, cross-era views and custom metrics',
    icon: Icons.people_alt_outlined,
    group: 'Compare',
    mode: 'Static historical data',
  ),
  NbaWorkspaceLink(
    id: 'team-compare',
    label: 'Team Compare',
    subtitle: 'Compare team seasons and playoff runs',
    icon: Icons.groups_2_outlined,
    group: 'Compare',
    mode: 'Static historical data',
  ),
  NbaWorkspaceLink(
    id: 'live-games',
    label: 'Live Games',
    subtitle: '2026–27 schedule with live scoreboard overlay',
    icon: Icons.sports_score_rounded,
    group: 'Games',
    mode: 'Local schedule + live overlay',
  ),
  NbaWorkspaceLink(
    id: 'box-scores',
    label: 'Box Scores',
    subtitle: 'Search the historical game and box-score archive',
    icon: Icons.table_rows_rounded,
    group: 'Games',
    mode: 'Static historical data',
  ),
  NbaWorkspaceLink(
    id: 'media-feed',
    label: 'Media Feed',
    subtitle: 'Public NBA insider timelines in one desk',
    icon: Icons.dynamic_feed_rounded,
    group: 'Games',
    mode: 'Live public embeds',
  ),
  NbaWorkspaceLink(
    id: 'visualizations',
    label: 'Visualizations',
    subtitle: 'Build charts, regressions and saved analytical views',
    icon: Icons.auto_graph_rounded,
    group: 'Analysis',
    mode: 'Static historical data + local presets',
  ),
  NbaWorkspaceLink(
    id: 'with-without',
    label: 'With / Without',
    subtitle: 'Teammate split analysis with explicit source boundaries',
    icon: Icons.compare_arrows_rounded,
    group: 'Analysis',
    mode: 'Static lineup data when available',
  ),
  NbaWorkspaceLink(
    id: 'rankings',
    label: 'Rankings',
    subtitle: 'Drag-and-drop ordered tier boards with saved views',
    icon: Icons.format_list_numbered_rounded,
    group: 'Analysis',
    mode: 'Static historical data + local boards',
  ),
  NbaWorkspaceLink(
    id: 'trade',
    label: 'Trade Machine',
    subtitle: 'Multi-team transaction construction and validation',
    icon: Icons.swap_horiz_rounded,
    group: 'Front Office',
    mode: 'Local CBA and contract rules',
  ),
  NbaWorkspaceLink(
    id: 'front-office',
    label: 'Front Office',
    subtitle: 'Team cap, contract, exception and draft-asset workspace',
    icon: Icons.account_tree_rounded,
    group: 'Front Office',
    mode: 'Static snapshot + local rules',
  ),
  NbaWorkspaceLink(
    id: 'research',
    label: 'Research',
    subtitle: 'Historical exploration and research-oriented tools',
    icon: Icons.science_outlined,
    group: 'Research',
    mode: 'Static historical data',
  ),
];

NbaWorkspaceLink? nbaWorkspaceLinkFor(String id) {
  for (final item in nbaWorkspaceLinks) {
    if (item.id == id) return item;
  }
  return null;
}

List<NbaWorkspaceLink> nbaWorkspaceGroup(String group) => [
      for (final item in nbaWorkspaceLinks)
        if (item.group == group) item,
    ];

class NbaWorkspaceLauncher extends StatelessWidget {
  const NbaWorkspaceLauncher({
    super.key,
    required this.onSelect,
  });

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const featuredGroups = ['Compare', 'Games', 'Analysis', 'Front Office'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view_rounded, color: colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'NBA Workspaces',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.apps_rounded, size: 16),
                  label: Text('${nbaWorkspaceLinks.length} tools'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Jump directly into the comparison, games, analysis and front-office workspaces built into Sports Terminal.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final group in featuredGroups) ...[
              Text(
                group.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1050
                      ? 3
                      : constraints.maxWidth >= 680
                          ? 2
                          : 1;
                  final gap = 10.0;
                  final width =
                      (constraints.maxWidth - (columns - 1) * gap) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final item in nbaWorkspaceGroup(group))
                        SizedBox(
                          width: width,
                          child: _WorkspaceTile(
                            item: item,
                            onTap: () => onSelect(item.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class NbaWorkspaceContextBar extends StatelessWidget {
  const NbaWorkspaceContextBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final current = nbaWorkspaceLinkFor(selected);
    if (current == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final siblings = nbaWorkspaceGroup(current.group);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(current.icon, size: 18, color: colors.primary),
            Text(
              current.group,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Chip(
              avatar: const Icon(Icons.storage_rounded, size: 15),
              label: Text(current.mode),
            ),
            const SizedBox(width: 2),
            for (final item in siblings)
              ChoiceChip(
                selected: item.id == selected,
                label: Text(item.label),
                avatar: Icon(item.icon, size: 16),
                onSelected: (_) => onSelect(item.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.item,
    required this.onTap,
  });

  final NbaWorkspaceLink item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
