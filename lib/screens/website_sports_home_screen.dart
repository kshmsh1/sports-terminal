import 'package:flutter/material.dart';

class WebsiteSportsHomeScreen extends StatelessWidget {
  const WebsiteSportsHomeScreen({
    super.key,
    required this.onOpenNba,
  });

  final VoidCallback onOpenNba;

  static const _leagues = <_LeagueCardData>[
    _LeagueCardData('NBA', 'Basketball', Icons.sports_basketball_rounded, true),
    _LeagueCardData('NFL', 'American football', Icons.sports_football_rounded, false),
    _LeagueCardData('NHL', 'Ice hockey', Icons.sports_hockey_rounded, false),
    _LeagueCardData('MLB', 'Baseball', Icons.sports_baseball_rounded, false),
    _LeagueCardData('MLS', 'Soccer', Icons.sports_soccer_rounded, false),
    _LeagueCardData('F1', 'Auto racing', Icons.sports_motorsports_rounded, false),
    _LeagueCardData('Premier League', 'Association football', Icons.sports_soccer_rounded, false),
    _LeagueCardData('WNBA', 'Basketball', Icons.sports_basketball_rounded, false),
    _LeagueCardData('ATP', 'Tennis', Icons.sports_tennis_rounded, false),
    _LeagueCardData('WTA', 'Tennis', Icons.sports_tennis_rounded, false),
    _LeagueCardData('PGA', 'Golf', Icons.sports_golf_rounded, false),
    _LeagueCardData('IPL', 'Cricket', Icons.sports_cricket_rounded, false),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sports Terminal',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a league. NBA is the first fully enabled data product; the remaining league homes stay explicit until their source-backed datasets are added.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1120
                ? 4
                : constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 500
                        ? 2
                        : 1;
            final gap = 14.0;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final league in _leagues)
                  SizedBox(
                    width: width,
                    child: _LeagueCard(
                      league: league,
                      onTap: league.enabled ? onOpenNba : null,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 30),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Data rule: unavailable leagues remain unavailable. Sports Terminal does not synthesize standings, players, schedules, or statistics for a league before a real dataset is connected.',
          ),
        ),
      ],
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.league, required this.onTap});

  final _LeagueCardData league;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: enabled
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      league.icon,
                      color: enabled ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: enabled
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      enabled ? 'OPEN' : 'COMING SOON',
                      style: TextStyle(
                        color: enabled ? colors.primary : colors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                league.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                league.sport,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Text(
                enabled
                    ? 'Players, teams, historical stats, advanced stats, contracts and transaction tools.'
                    : 'League data surface not enabled yet.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueCardData {
  const _LeagueCardData(this.name, this.sport, this.icon, this.enabled);

  final String name;
  final String sport;
  final IconData icon;
  final bool enabled;
}
