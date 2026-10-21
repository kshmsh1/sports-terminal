import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../screens/product_community_v2_screen.dart';
import '../screens/product_front_office_registry_screen.dart';
import '../screens/product_platform_content_legal_screen.dart';
import '../screens/product_profile_v3_screen.dart';
import '../screens/product_trade_machine_screen.dart';
import '../screens/website_nba_advanced_stats_screen.dart';
import '../screens/website_nba_box_scores_screen.dart';
import '../screens/website_nba_entity_pages.dart';
import '../screens/website_nba_financials_screen.dart';
import '../screens/website_nba_home_dashboard.dart';
import '../screens/website_nba_live_games_screen.dart';
import '../screens/website_nba_media_feed_screen.dart';
import '../screens/website_nba_player_comparison_screen.dart';
import '../screens/website_nba_rankings_screen.dart';
import '../screens/website_nba_research_screen.dart';
import '../screens/website_nba_stats_screen.dart';
import '../screens/website_nba_team_comparison_screen.dart';
import '../screens/website_nba_visualizations_screen.dart';
import '../screens/website_nba_with_without_screen.dart';
import '../screens/sports_workspace_overview.dart';
import '../services/product_local_store.dart';
import '../services/website_nba_api_service.dart';
import 'sports_workspace_chrome.dart';
import 'sports_workspace_design.dart';

/// Sole customer-facing Sports Terminal shell.
///
/// Customer-facing sports data is served from the local static corpus.
/// Remote sports/social/product API calls are disabled at runtime.
class CanonicalProductShell extends StatefulWidget {
  const CanonicalProductShell({
    super.key,
    required this.session,
    required this.onSignOut,
  });

  final AppSession session;
  final VoidCallback onSignOut;

  @override
  State<CanonicalProductShell> createState() => _CanonicalProductShellState();
}

class _CanonicalProductShellState extends State<CanonicalProductShell> {
  final _store = const ProductLocalStore();
  String _selected = 'sports';
  bool _darkMode = true;

  List<_Destination> get _items => [
        _Destination(
          id: 'sports',
          label: 'Overview',
          icon: Icons.public_rounded,
          builder: () => SportsWorkspaceOverview(
            onOpenRoute: _select,
            onOpenNba: () => _select('nba-home'),
          ),
        ),
        _Destination(
          id: 'nba-home',
          label: 'NBA Home',
          icon: Icons.sports_basketball_rounded,
          builder: () => WebsiteNbaHomeDashboard(session: widget.session),
        ),
        _Destination(
          id: 'stats',
          label: 'Stats',
          icon: Icons.leaderboard_rounded,
          builder: () => WebsiteNbaStatsScreen(session: widget.session),
        ),
        _Destination(
          id: 'advanced',
          label: 'Advanced Stats',
          icon: Icons.analytics_rounded,
          builder: () => WebsiteNbaAdvancedStatsScreen(session: widget.session),
        ),
        _Destination(
          id: 'player-compare',
          label: 'Player Compare',
          icon: Icons.people_alt_outlined,
          builder: () => WebsiteNbaPlayerComparisonScreen(session: widget.session),
        ),
        _Destination(
          id: 'team-compare',
          label: 'Team Compare',
          icon: Icons.groups_2_outlined,
          builder: () => WebsiteNbaTeamComparisonScreen(session: widget.session),
        ),
        const _Destination(
          id: 'trade',
          label: 'Trade Machine',
          icon: Icons.swap_horiz_rounded,
          builder: ProductTradeMachineScreen.new,
        ),
        const _Destination(
          id: 'financials',
          label: 'Financials',
          icon: Icons.account_balance_wallet_outlined,
          builder: WebsiteNbaFinancialsScreen.new,
        ),
        const _Destination(
          id: 'live-games',
          label: 'Schedule',
          icon: Icons.sports_score_rounded,
          builder: WebsiteNbaLiveGamesScreen.new,
        ),
        const _Destination(
          id: 'box-scores',
          label: 'Box Scores',
          icon: Icons.table_rows_rounded,
          builder: WebsiteNbaBoxScoresScreen.new,
        ),
        const _Destination(
          id: 'media-feed',
          label: 'Media Sources',
          icon: Icons.dynamic_feed_rounded,
          builder: WebsiteNbaMediaFeedScreen.new,
        ),
        const _Destination(
          id: 'visualizations',
          label: 'Visualizations',
          icon: Icons.auto_graph_rounded,
          builder: WebsiteNbaVisualizationsScreen.new,
        ),
        const _Destination(
          id: 'with-without',
          label: 'With / Without',
          icon: Icons.compare_arrows_rounded,
          builder: WebsiteNbaWithWithoutScreen.new,
        ),
        const _Destination(
          id: 'rankings',
          label: 'Rankings',
          icon: Icons.format_list_numbered_rounded,
          builder: WebsiteNbaRankingsScreen.new,
        ),
        _Destination(
          id: 'front-office',
          label: 'Front Office',
          icon: Icons.account_tree_rounded,
          builder: () => ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        const _Destination(
          id: 'research',
          label: 'Research',
          icon: Icons.science_outlined,
          builder: WebsiteNbaResearchScreen.new,
        ),
        _Destination(
          id: 'community',
          label: 'Community',
          icon: Icons.forum_rounded,
          builder: () => ProductCommunityV2Screen(session: widget.session),
        ),
        const _Destination(
          id: 'python-lab',
          label: 'Python Lab',
          icon: Icons.code_rounded,
          enabled: false,
        ),
        const _Destination(
          id: 'excel-workspace',
          label: 'Excel Workspace',
          icon: Icons.table_chart_outlined,
          enabled: false,
        ),
        _Destination(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          builder: () => ProductProfileV3Screen(session: widget.session),
        ),
        const _Destination(
          id: 'about',
          label: 'About',
          icon: Icons.info_outline_rounded,
          builder: _AboutRoute.new,
        ),
        const _Destination(
          id: 'contact',
          label: 'Contact',
          icon: Icons.mail_outline_rounded,
          builder: _ContactRoute.new,
        ),
        const _Destination(
          id: 'privacy',
          label: 'Privacy',
          icon: Icons.privacy_tip_outlined,
          builder: _PrivacyRoute.new,
        ),
        const _Destination(
          id: 'terms',
          label: 'Terms',
          icon: Icons.gavel_outlined,
          builder: _TermsRoute.new,
        ),
        const _Destination(
          id: 'sitemap',
          label: 'Sitemap',
          icon: Icons.account_tree_outlined,
          builder: _SitemapRoute.new,
        ),
        const _Destination(
          id: 'accessibility',
          label: 'Accessibility',
          icon: Icons.accessibility_new_rounded,
          builder: _AccessibilityRoute.new,
        ),
        const _Destination(
          id: 'data-policy',
          label: 'Data & Methodology',
          icon: Icons.dataset_outlined,
          builder: _DataPolicyRoute.new,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final value = await _store.loadBool(
      ProductLocalStore.darkModeKey,
      fallback: true,
    );
    if (mounted) setState(() => _darkMode = value);
  }

  Future<void> _toggleTheme() async {
    final value = !_darkMode;
    setState(() => _darkMode = value);
    await _store.saveBool(ProductLocalStore.darkModeKey, value);
  }

  void _select(String id) {
    _Destination? match;
    for (final item in _items) {
      if (item.id == id) {
        match = item;
        break;
      }
    }
    if (match == null || !match.enabled || match.builder == null) return;
    setState(() => _selected = id);
  }

  String _navigationGroup(String id) {
    const sections = <String, List<String>>{
      'Start': ['sports'],
      'Basketball': [
        'nba-home', 'live-games', 'box-scores', 'media-feed',
      ],
      'Research & analysis': [
        'research', 'stats', 'advanced', 'visualizations',
        'player-compare', 'team-compare', 'with-without', 'rankings',
      ],
      'Front office': ['trade', 'financials', 'front-office'],
      'Community': ['community', 'profile'],
      'More': [
        'python-lab', 'excel-workspace', 'about', 'contact',
        'privacy', 'terms', 'sitemap', 'accessibility', 'data-policy',
      ],
    };
    for (final group in sections.entries) {
      if (group.value.contains(id)) return group.key;
    }
    return 'More';
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _items;
    final selected = destinations.firstWhere(
      (item) => item.id == _selected,
      orElse: () => destinations.first,
    );

    return Theme(
      data: SportsWorkspaceDesign.theme(_darkMode),
      child: Builder(builder: (context) => SportsWorkspaceChrome(
        session: widget.session,
        selected: _selected,
        darkMode: _darkMode,
        items: [
          for (final item in destinations)
            WorkspaceNavItem(
              id: item.id,
              label: item.label,
              icon: item.icon,
              group: _navigationGroup(item.id),
              enabled: item.enabled,
            ),
        ],
        onSelect: _select,
        onTheme: _toggleTheme,
        onSearchPeople: () => _openSearchDialog(context, widget.session),
        onSignOut: widget.onSignOut,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: ValueKey('workspace-scroll-$_selected'),
            padding: SportsWorkspaceDesign.gutters(
              constraints.maxWidth, _selected),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: SportsWorkspaceDesign.maxContentWidth(_selected),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selected == 'trade')
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (MediaQuery.sizeOf(context).height - 110)
                              .clamp(0.0, double.infinity).toDouble(),
                        ),
                        child: selected.builder!(),
                      )
                    else
                      selected.builder!(),
                    if (_selected != 'trade') ...[
                      const SizedBox(height: 54),
                      _SiteFooter(onSelect: _select),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      )),
    );
  }
}

class _AboutRoute extends StatelessWidget {
  const _AboutRoute();
  @override
  Widget build(BuildContext context) =>
      const ProductPlatformLegalScreen(kind: 'about');
}

class _ContactRoute extends StatelessWidget {
  const _ContactRoute();
  @override
  Widget build(BuildContext context) =>
      const ProductPlatformLegalScreen(kind: 'contact');
}

class _PrivacyRoute extends StatelessWidget {
  const _PrivacyRoute();
  @override
  Widget build(BuildContext context) =>
      const ProductPlatformLegalScreen(kind: 'privacy');
}

class _TermsRoute extends StatelessWidget {
  const _TermsRoute();
  @override
  Widget build(BuildContext context) =>
      const ProductPlatformLegalScreen(kind: 'terms');
}

class _SitemapRoute extends StatelessWidget {
  const _SitemapRoute();
  @override
  Widget build(BuildContext context) =>
      const ProductPlatformLegalScreen(kind: 'sitemap');
}

class _AccessibilityRoute extends StatelessWidget {
  const _AccessibilityRoute();
  @override
  Widget build(BuildContext context) =>
      const ProductPlatformLegalScreen(kind: 'accessibility');
}

class _DataPolicyRoute extends StatelessWidget {
  const _DataPolicyRoute();
  @override
  Widget build(BuildContext context) =>
      const ProductPlatformLegalScreen(kind: 'data');
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final divider = Theme.of(context).dividerColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divider)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final links = Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _FooterLink('About', 'about', onSelect),
              _FooterLink('Contact', 'contact', onSelect),
              _FooterLink('Privacy Policy', 'privacy', onSelect),
              _FooterLink('Terms & Conditions', 'terms', onSelect),
              _FooterLink('Sitemap', 'sitemap', onSelect),
              _FooterLink('Accessibility', 'accessibility', onSelect),
              _FooterLink('Data & Methodology', 'data-policy', onSelect),
            ],
          );
          final brand = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SPORTS TERMINAL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Static, source-aware sports intelligence and research tooling.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '© 2026 Sports Terminal. Independent product; not affiliated with or endorsed by the NBA or other leagues unless expressly stated.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [brand, const SizedBox(height: 16), links],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: brand),
              const SizedBox(width: 24),
              Flexible(child: links),
            ],
          );
        },
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.id, this.onSelect);

  final String label;
  final String id;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => onSelect(id),
        child: Text(label),
      );
}

Future<void> _openSearchDialog(BuildContext context, AppSession session) {
  return showDialog<void>(
    context: context,
    builder: (_) => _NbaSearchDialog(session: session),
  );
}

class _NbaSearchDialog extends StatefulWidget {
  const _NbaSearchDialog({required this.session});

  final AppSession session;

  @override
  State<_NbaSearchDialog> createState() => _NbaSearchDialogState();
}

class _NbaSearchDialogState extends State<_NbaSearchDialog> {
  final _data = const WebsiteNbaApiService();
  final _controller = TextEditingController();
  Future<Map<String, dynamic>>? _future;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    final query = value.trim();
    setState(() {
      _future = query.length < 2 ? null : _data.searchEntities(query);
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Search NBA players and teams'),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 72).clamp(0.0, 620.0).toDouble(),
          height: (MediaQuery.sizeOf(context).height - 170).clamp(180.0, 470.0).toDouble(),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Jayson Tatum, Boston Celtics…',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _future == null
                    ? const Center(child: Text('Type at least two characters.'))
                    : FutureBuilder<Map<String, dynamic>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          if (snapshot.hasError || snapshot.data == null) {
                            return Center(
                              child: Text('Static search unavailable: ${snapshot.error}'),
                            );
                          }
                          final groups = _map(snapshot.data!['groups']);
                          final players = _maps(groups['players']);
                          final teams = _maps(groups['teams']);
                          if (players.isEmpty && teams.isEmpty) {
                            return const Center(child: Text('No matches found.'));
                          }
                          return ListView(
                            children: [
                              if (players.isNotEmpty) const _SearchSection('Players'),
                              for (final player in players)
                                ListTile(
                                  leading: const Icon(Icons.person_outline_rounded),
                                  title: Text(_text(player['canonical_name'], 'Player')),
                                  subtitle: Text(
                                    [
                                      _text(player['primary_position']),
                                      _text(player['last_season']),
                                    ].where((item) => item.isNotEmpty).join(' · '),
                                  ),
                                  onTap: () {
                                    final playerKey = _text(player['player_key']);
                                    final playerName = _text(
                                      player['canonical_name'],
                                      'Player',
                                    );
                                    Navigator.of(context).pop();
                                    openWebsiteNbaPlayerPage(
                                      context,
                                      session: widget.session,
                                      playerKey: playerKey,
                                      playerName: playerName,
                                    );
                                  },
                                ),
                              if (teams.isNotEmpty) const _SearchSection('Teams'),
                              for (final team in teams)
                                ListTile(
                                  leading: const Icon(Icons.groups_outlined),
                                  title: Text(_text(team['canonical_name'], 'Team')),
                                  subtitle: Text(_text(team['abbreviation'])),
                                  onTap: () {
                                    final teamKey = _text(team['team_key']);
                                    final teamName = _text(
                                      team['canonical_name'],
                                      'Team',
                                    );
                                    Navigator.of(context).pop();
                                    openWebsiteNbaTeamPage(
                                      context,
                                      session: widget.session,
                                      teamKey: teamKey,
                                      teamName: teamName,
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
}

class _SearchSection extends StatelessWidget {
  const _SearchSection(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      );
}

class _Destination {
  const _Destination({
    required this.id,
    required this.label,
    required this.icon,
    this.builder,
    this.enabled = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget Function()? builder;
  final bool enabled;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _map(item),
  ];
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}
