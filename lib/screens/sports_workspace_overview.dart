import 'package:flutter/material.dart';

import '../services/website_nba_api_service.dart';
import '../widgets/sports_workspace_design.dart';
import 'website_sports_home_screen.dart';

/// The starting point is now a working dashboard, not twelve equal-size
/// league placeholders. All entry points open existing, source-backed routes.
class SportsWorkspaceOverview extends StatelessWidget {
  const SportsWorkspaceOverview({
    super.key,
    required this.onOpenRoute,
    required this.onOpenNba,
  });

  final ValueChanged<String> onOpenRoute;
  final VoidCallback onOpenNba;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 950;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WorkspaceSectionLabel('Sports Terminal / Overview'),
        const SizedBox(height: 16),
        if (desktop)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: _lead(context)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _archivePanel(context)),
          ])
        else ...[
          _lead(context),
          const SizedBox(height: 14),
          _archivePanel(context),
        ],
        const SizedBox(height: 38),
        Row(children: [
          Text('Your workspaces',
            style: Theme.of(context).textTheme.headlineMedium),
          const Spacer(),
          Text('NBA', style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colors.onSurfaceVariant,
          )),
        ]),
        const SizedBox(height: 14),
        _workspaceGrid(context, constraints.maxWidth),
        const SizedBox(height: 38),
        WorkspaceSurface(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.public_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Leagues and coverage',
                style: Theme.of(context).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 9),
            Text('NBA is the currently enabled historical research corpus. '
              'Other league homes are available to explore but do not yet '
              'contain verified statistical datasets.',
              style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 10),
            ExpansionTile(
              title: const Text('View all supported and planned leagues'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 12),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                // Keep the canonical cross-sport league-home behavior.
                WebsiteSportsHomeScreen(onOpenNba: onOpenNba),
              ],
            ),
          ],
        )),
      ]);
    });
  }

  Widget _lead(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 326),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline),
        color: colors.primary.withValues(alpha: .075),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const WorkspaceSectionLabel('Research / Analysis / Decisions'),
        const SizedBox(height: 18),
        Text('Sports Terminal',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            height: 1.02,
          )),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Explore historical NBA data, compare players and teams, '
            'build visualizations, and analyze trades—all in one workspace.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: () => onOpenRoute('research'),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Open research'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 17),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onOpenNba,
            icon: const Icon(Icons.sports_basketball_outlined),
            label: const Text('NBA overview'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 17),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _archivePanel(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return WorkspaceSurface(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const WorkspaceSectionLabel('Data availability'),
        const SizedBox(height: 20),
        Row(children: [
          Icon(Icons.verified_outlined, color: colors.primary),
          const SizedBox(width: 9),
          Text('NBA historical archive',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )),
        ]),
        const SizedBox(height: 12),
        Text('Completed season data is compiled into local static datasets. '
          'Coverage varies by statistic and season.',
          style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 15),
        FutureBuilder<List<WebsiteNbaSeason>>(
          future: const WebsiteNbaApiService().seasons(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('Archive index not available locally.');
            }
            return Row(children: [
              Text('${snapshot.data!.length}',
                style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(width: 12),
              Expanded(child: Text('season entries indexed',
                style: TextStyle(color: colors.onSurfaceVariant))),
            ]);
          },
        ),
        const SizedBox(height: 18),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Examine data coverage',
            style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Sources and limitations'),
          trailing: const Icon(Icons.arrow_outward_rounded),
          onTap: () => onOpenRoute('research'),
        ),
      ]),
    );
  }

  Widget _workspaceGrid(BuildContext context, double width) {
    final count = width < 590 ? 1 : width < 1080 ? 2 : 3;
    const spacing = 14.0;
    final cardWidth = (width - (count - 1) * spacing) / count;
    const entries = <_WorkspaceLink>[
      _WorkspaceLink('Research', 'research', '01',
        'Start from the indexed historical NBA corpus.',
        Icons.manage_search_rounded),
      _WorkspaceLink('Statistics', 'stats', '02',
        'Filter, rank, and inspect players and teams.',
        Icons.view_list_rounded),
      _WorkspaceLink('Visualization Studio', 'visualizations', '03',
        'Build and interrogate statistical charts.',
        Icons.insights_rounded),
      _WorkspaceLink('Player Compare', 'player-compare', '04',
        'Compare production, efficiency, and seasons.',
        Icons.compare_arrows_rounded),
      _WorkspaceLink('Trade Machine', 'trade', '05',
        'Build transactions against the NBA CBA.',
        Icons.swap_horiz_rounded),
      _WorkspaceLink('NBA Financials', 'financials', '06',
        'Review cap, tax, aprons, and roster charges.',
        Icons.account_balance_wallet_outlined),
    ];
    return Wrap(spacing: spacing, runSpacing: spacing,
      children: [
        for (final entry in entries)
          SizedBox(
            width: cardWidth,
            child: _WorkspaceLaunchCard(
              item: entry, onTap: () => onOpenRoute(entry.route),
            ),
          ),
      ],
    );
  }
}

class _WorkspaceLink {
  const _WorkspaceLink(
      this.label, this.route, this.number, this.description, this.icon);
  final String label;
  final String route;
  final String number;
  final String description;
  final IconData icon;
}

class _WorkspaceLaunchCard extends StatelessWidget {
  const _WorkspaceLaunchCard({required this.item, required this.onTap});
  final _WorkspaceLink item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(item.icon, size: 24, color: colors.primary),
                const Spacer(),
                Text(item.number, style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 24),
              Text(item.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(item.description,
                maxLines: 3,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                )),
              const SizedBox(height: 16),
              Row(children: [
                Text('Open workspace', style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                )),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                  size: 16, color: colors.primary),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
