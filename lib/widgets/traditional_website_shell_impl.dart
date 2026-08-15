import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/institutional_research_hub_screen.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_community_v2_screen.dart';
import '../screens/product_connected_network_screens.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_fantasy_community_screens.dart';
import '../screens/product_front_office_registry_screen.dart';
import '../screens/product_nba_awards_v2_screen.dart';
import '../screens/product_nba_public_pages_screen.dart';
import '../screens/product_profile_v3_screen.dart';
import '../screens/product_trade_machine_v2_screen.dart';
import '../screens/product_transaction_command_center_screen.dart';
import '../screens/website_nba_stats_screen.dart';
import '../services/product_local_store.dart';
import 'website_nba_data_gate.dart';

const _brandBlue = Color(0xFF2563EB);

/// Website-first Sports Terminal shell.
///
/// The product deliberately uses conventional responsive website navigation.
/// Python Lab and spreadsheet workspaces are preserved internally but are
/// deliberately detached from the primary customer navigation.
class TraditionalWebsiteShell extends StatefulWidget {
  const TraditionalWebsiteShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<TraditionalWebsiteShell> createState() => _TraditionalWebsiteShellState();
}

class _TraditionalWebsiteShellState extends State<TraditionalWebsiteShell> {
  final ProductLocalStore _store = const ProductLocalStore();
  String _selectedId = 'home';
  bool _darkMode = true;

  bool get _organizationMode => widget.session.role.canManageOrganization;

  List<_Destination> get _primary => [
        _Destination(
          id: 'home',
          label: 'Home',
          icon: Icons.home_rounded,
          builder: () => _WebsiteHome(onNavigate: _select),
        ),
        _Destination(
          id: 'nba',
          label: 'NBA',
          icon: Icons.sports_basketball_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductNbaHubV2Screen(),
          ),
        ),
        const _Destination(
          id: 'stats',
          label: 'Stats',
          icon: Icons.leaderboard_rounded,
          builder: _statsPage,
        ),
        _Destination(
          id: 'analytics',
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductAdvancedNbaToolsScreen(),
          ),
        ),
        _Destination(
          id: 'trade',
          label: 'Trade Machine',
          icon: Icons.swap_horiz_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => ProductTradeMachineV2Screen(
              session: widget.session,
            ),
          ),
        ),
        _Destination(
          id: 'front-office',
          label: 'Front Office',
          icon: Icons.account_tree_outlined,
          builder: () => ProductFrontOfficeRegistryScreen(
            session: widget.session,
          ),
        ),
      ];

  List<_Destination> get _secondary => [
        _Destination(
          id: 'my-work',
          label: _organizationMode ? 'Organization' : 'My Work',
          icon: _organizationMode
              ? Icons.corporate_fare_outlined
              : Icons.work_outline_rounded,
          builder: () => ProductTransactionCommandCenterScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
        ),
        _Destination(
          id: 'awards',
          label: 'Awards',
          icon: Icons.emoji_events_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductNbaAwardsVotingScreen(),
          ),
        ),
        _Destination(
          id: 'research',
          label: 'Research',
          icon: Icons.science_outlined,
          builder: () => InstitutionalResearchHubScreen(session: widget.session),
        ),
        _Destination(
          id: 'fantasy',
          label: 'Fantasy',
          icon: Icons.bolt_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductFantasyWarRoomScreen(),
          ),
        ),
        _Destination(
          id: 'articles',
          label: 'Articles',
          icon: Icons.article_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductArticlesArenaScreen(),
          ),
        ),
        _Destination(
          id: 'community',
          label: 'Community',
          icon: Icons.forum_outlined,
          builder: () => ProductCommunityV2Screen(session: widget.session),
        ),
        _Destination(
          id: 'messages',
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
          builder: () => ProductConnectedMessagesScreen(session: widget.session),
        ),
        _Destination(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          builder: () => ProductProfileV3Screen(session: widget.session),
        ),
      ];

  static Widget _statsPage() => const WebsiteNbaStatsScreen();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final dark = await _store.loadBool(
      ProductLocalStore.darkModeKey,
      fallback: true,
    );
    if (mounted) setState(() => _darkMode = dark);
  }

  Future<void> _toggleTheme() async {
    final next = !_darkMode;
    setState(() => _darkMode = next);
    await _store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(String id) {
    final all = [..._primary, ..._secondary];
    if (all.any((item) => item.id == id)) {
      setState(() => _selectedId = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primary;
    final secondary = _secondary;
    final all = [...primary, ...secondary];
    final selected = all.firstWhere(
      (item) => item.id == _selectedId,
      orElse: () => primary.first,
    );
    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brandBlue,
        brightness: brightness,
      ),
      scaffoldBackgroundColor:
          _darkMode ? const Color(0xFF0B111A) : const Color(0xFFF7F8FA),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor:
          _darkMode ? const Color(0xFF273241) : const Color(0xFFE5E7EB),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _SiteHeader(
                session: widget.session,
                primary: primary,
                secondary: secondary,
                selectedId: selected.id,
                darkMode: _darkMode,
                onSelect: _select,
                onToggleTheme: _toggleTheme,
                onSignOut: widget.onSignOut,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 64),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: selected.builder(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({
    required this.session,
    required this.primary,
    required this.secondary,
    required this.selectedId,
    required this.darkMode,
    required this.onSelect,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  final AppSession session;
  final List<_Destination> primary;
  final List<_Destination> secondary;
  final String selectedId;
  final bool darkMode;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF101925) : Colors.white,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1000;
            return Row(
              children: [
                InkWell(
                  onTap: () => onSelect('home'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Text(
                            'ST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Sports Terminal',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (desktop) ...[
                  const SizedBox(width: 28),
                  for (final item in primary)
                    _NavLink(
                      item: item,
                      active: selectedId == item.id,
                      onTap: () => onSelect(item.id),
                    ),
                  _MoreMenu(
                    items: secondary,
                    selectedId: selectedId,
                    onSelect: onSelect,
                  ),
                  const Spacer(),
                ] else ...[
                  const Spacer(),
                  _MobileMenu(
                    items: [...primary, ...secondary],
                    selectedId: selectedId,
                    onSelect: onSelect,
                  ),
                ],
                IconButton(
                  tooltip: darkMode ? 'Light mode' : 'Dark mode',
                  onPressed: onToggleTheme,
                  icon: Icon(
                    darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Account',
                  onSelected: (value) {
                    if (value == 'profile') onSelect('profile');
                    if (value == 'sign-out') onSignOut();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: SizedBox(
                        width: 210,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              session.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'profile',
                      child: Text('Profile'),
                    ),
                    const PopupMenuItem(
                      value: 'sign-out',
                      child: Text('Sign out'),
                    ),
                  ],
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(
                      _initials(session.displayName),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.item, required this.active, required this.onTap});

  final _Destination item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? colors.primary : colors.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        textStyle: TextStyle(
          fontSize: 13,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      child: Text(item.label),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.items, required this.selectedId, required this.onSelect});

  final List<_Destination> items;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = items.any((item) => item.id == selectedId);
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem(
            value: item.id,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.icon, size: 19),
              title: Text(item.label),
              trailing: item.id == selectedId
                  ? const Icon(Icons.check_rounded, size: 18)
                  : null,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'More',
              style: TextStyle(
                color: active ? colors.primary : colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more_rounded, size: 17),
          ],
        ),
      ),
    );
  }
}

class _MobileMenu extends StatelessWidget {
  const _MobileMenu({required this.items, required this.selectedId, required this.onSelect});

  final List<_Destination> items;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Navigation',
        onSelected: onSelect,
        itemBuilder: (_) => [
          for (final item in items)
            PopupMenuItem(
              value: item.id,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon),
                title: Text(item.label),
                trailing: item.id == selectedId
                    ? const Icon(Icons.check_rounded)
                    : null,
              ),
            ),
        ],
        icon: const Icon(Icons.menu_rounded),
      );
}

class _WebsiteHome extends StatelessWidget {
  const _WebsiteHome({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cards = const [
      _HomeCardData(
        'NBA',
        'Players, teams, games, schedules and league context.',
        Icons.sports_basketball_rounded,
        'nba',
      ),
      _HomeCardData(
        'Stats',
        'Simple sortable player statistics with familiar filters.',
        Icons.leaderboard_rounded,
        'stats',
      ),
      _HomeCardData(
        'Analytics',
        'Deeper metrics and comparison tools when you need them.',
        Icons.analytics_outlined,
        'analytics',
      ),
      _HomeCardData(
        'Trade Machine',
        'Build and validate multi-team trade scenarios.',
        Icons.swap_horiz_rounded,
        'trade',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sports, clearly organized.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
              ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Explore NBA data and front-office tools through a normal website experience. Advanced research features stay available without taking over every screen.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 640
                    ? 2
                    : 1;
            final cardWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - 16 * (columns - 1)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: cardWidth,
                    child: _HomeCard(
                      data: card,
                      onTap: () => onNavigate(card.target),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 34),
        Text(
          'Explore more',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _ExploreRow(
                icon: Icons.account_tree_outlined,
                title: 'Front Office',
                body: 'Contracts, cap context and draft assets.',
                onTap: () => onNavigate('front-office'),
              ),
              _ExploreRow(
                icon: Icons.emoji_events_outlined,
                title: 'Awards',
                body: 'Awards, selections and voting history.',
                onTap: () => onNavigate('awards'),
              ),
              _ExploreRow(
                icon: Icons.science_outlined,
                title: 'Research',
                body: 'Saved work, metric definitions and institutional tools.',
                onTap: () => onNavigate('research'),
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.data, required this.onTap});

  final _HomeCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text(
                data.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                data.body,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 16),
              Text(
                'Open →',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreRow extends StatelessWidget {
  const _ExploreRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            leading: Icon(icon),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(body),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          if (!last) const Divider(height: 1),
        ],
      );
}

class _Destination {
  const _Destination({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget Function() builder;
}

class _HomeCardData {
  const _HomeCardData(this.title, this.body, this.icon, this.target);

  final String title;
  final String body;
  final IconData icon;
  final String target;
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final letters = [
    for (final part in parts.take(2)) part.substring(0, 1).toUpperCase(),
  ];
  return letters.isEmpty ? 'ST' : letters.join();
}
