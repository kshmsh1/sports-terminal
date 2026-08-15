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
import '../services/product_local_store.dart';

const _siteBlue = Color(0xFF2563EB);
const _siteOrange = Color(0xFFFF7A1A);

/// The default authenticated Sports Terminal experience.
///
/// This shell intentionally behaves like a conventional responsive website.
/// The terminal command frame, density controls, floating research launchers,
/// Python Lab and spreadsheet workspace remain available as product code, but
/// they are deliberately detached from the primary customer navigation.
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

  static const _primaryIds = <String>{
    'home',
    'nba',
    'stats',
    'analytics',
    'trade',
    'front-office',
  };

  List<_SiteDestination> get _destinations => [
        _SiteDestination(
          id: 'home',
          label: 'Home',
          icon: Icons.home_rounded,
          builder: () => _WebsiteHome(
            session: widget.session,
            organizationMode: _organizationMode,
            onNavigate: _select,
          ),
        ),
        const _SiteDestination(
          id: 'nba',
          label: 'NBA',
          icon: Icons.sports_basketball_rounded,
          builder: _nbaHub,
        ),
        const _SiteDestination(
          id: 'stats',
          label: 'Stats',
          icon: Icons.leaderboard_rounded,
          builder: _stats,
        ),
        const _SiteDestination(
          id: 'analytics',
          label: 'Analytics',
          icon: Icons.analytics_rounded,
          builder: _analytics,
        ),
        _SiteDestination(
          id: 'trade',
          label: 'Trade Machine',
          icon: Icons.swap_horiz_rounded,
          builder: () => ProductTradeMachineV2Screen(session: widget.session),
        ),
        _SiteDestination(
          id: 'front-office',
          label: 'Front Office',
          icon: Icons.account_tree_rounded,
          builder: () => ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        _SiteDestination(
          id: 'my-work',
          label: _organizationMode ? 'Organization' : 'My Work',
          icon: _organizationMode
              ? Icons.corporate_fare_rounded
              : Icons.work_outline_rounded,
          builder: () => ProductTransactionCommandCenterScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
        ),
        const _SiteDestination(
          id: 'awards',
          label: 'Awards',
          icon: Icons.emoji_events_outlined,
          builder: _awards,
        ),
        _SiteDestination(
          id: 'research',
          label: 'Research',
          icon: Icons.science_outlined,
          builder: () => InstitutionalResearchHubScreen(session: widget.session),
        ),
        const _SiteDestination(
          id: 'fantasy',
          label: 'Fantasy',
          icon: Icons.bolt_outlined,
          builder: _fantasy,
        ),
        const _SiteDestination(
          id: 'articles',
          label: 'Articles',
          icon: Icons.article_outlined,
          builder: _articles,
        ),
        _SiteDestination(
          id: 'community',
          label: 'Community',
          icon: Icons.forum_outlined,
          builder: () => ProductCommunityV2Screen(session: widget.session),
        ),
        _SiteDestination(
          id: 'messages',
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
          builder: () => ProductConnectedMessagesScreen(session: widget.session),
        ),
        _SiteDestination(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          builder: () => ProductProfileV3Screen(session: widget.session),
        ),
      ];

  static Widget _nbaHub() => const ProductNbaHubV2Screen();
  static Widget _stats() => const ProductNbaBasicStatsScreen();
  static Widget _analytics() => const ProductAdvancedNbaToolsScreen();
  static Widget _awards() => const ProductNbaAwardsVotingScreen();
  static Widget _fantasy() => const ProductFantasyWarRoomScreen();
  static Widget _articles() => const ProductEditorialHomeScreen();

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
    if (!mounted) return;
    setState(() => _darkMode = value);
  }

  Future<void> _toggleTheme() async {
    final next = !_darkMode;
    setState(() => _darkMode = next);
    await _store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(String id) {
    if (!_destinations.any((destination) => destination.id == id)) return;
    setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final selected = destinations.firstWhere(
      (destination) => destination.id == _selectedId,
      orElse: () => destinations.first,
    );
    final primary = [
      for (final destination in destinations)
        if (_primaryIds.contains(destination.id)) destination,
    ];
    final secondary = [
      for (final destination in destinations)
        if (!_primaryIds.contains(destination.id)) destination,
    ];

    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _siteBlue,
        brightness: brightness,
      ),
      scaffoldBackgroundColor:
          _darkMode ? const Color(0xFF0A1019) : const Color(0xFFF7F8FA),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor:
          _darkMode ? const Color(0xFF263240) : const Color(0xFFE5E7EB),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _WebsiteHeader(
                session: widget.session,
                selectedId: selected.id,
                primary: primary,
                secondary: secondary,
                darkMode: _darkMode,
                onSelect: _select,
                onToggleTheme: _toggleTheme,
                onSignOut: widget.onSignOut,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 56),
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

class _WebsiteHeader extends StatelessWidget {
  const _WebsiteHeader({
    required this.session,
    required this.selectedId,
    required this.primary,
    required this.secondary,
    required this.darkMode,
    required this.onSelect,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  final AppSession session;
  final String selectedId;
  final List<_SiteDestination> primary;
  final List<_SiteDestination> secondary;
  final bool darkMode;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF0E1724) : Colors.white,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;
            return Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect('home'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'ST',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
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
                  for (final destination in primary)
                    _HeaderLink(
                      destination: destination,
                      selected: selectedId == destination.id,
                      onTap: () => onSelect(destination.id),
                    ),
                  _MoreMenu(
                    destinations: secondary,
                    selectedId: selectedId,
                    onSelect: onSelect,
                  ),
                ] else ...[
                  const Spacer(),
                  _CompactMenu(
                    destinations: [...primary, ...secondary],
                    selectedId: selectedId,
                    onSelect: onSelect,
                  ),
                ],
                if (desktop) const Spacer(),
                IconButton(
                  tooltip: darkMode ? 'Use light mode' : 'Use dark mode',
                  onPressed: onToggleTheme,
                  icon: Icon(
                    darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Account',
                  onSelected: (value) {
                    if (value == 'profile') {
                      onSelect('profile');
                    } else if (value == 'sign-out') {
                      onSignOut();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
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
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_outline_rounded),
                        title: Text('Profile'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sign-out',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.logout_rounded),
                        title: Text('Sign out'),
                      ),
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

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _SiteDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? colors.primary : colors.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 18),
          textStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        child: Text(destination.label),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_SiteDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = destinations.any((item) => item.id == selectedId);
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final destination in destinations)
          PopupMenuItem(
            value: destination.id,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(destination.icon, size: 19),
              title: Text(destination.label),
              trailing: destination.id == selectedId
                  ? const Icon(Icons.check_rounded, size: 18)
                  : null,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'More',
              style: TextStyle(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
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

class _CompactMenu extends StatelessWidget {
  const _CompactMenu({
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_SiteDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Navigation',
        onSelected: onSelect,
        itemBuilder: (context) => [
          for (final destination in destinations)
            PopupMenuItem(
              value: destination.id,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(destination.icon),
                title: Text(destination.label),
                trailing: destination.id == selectedId
                    ? const Icon(Icons.check_rounded)
                    : null,
              ),
            ),
        ],
        icon: const Icon(Icons.menu_rounded),
      );
}

class _WebsiteHome extends StatelessWidget {
  const _WebsiteHome({
    required this.session,
    required this.organizationMode,
    required this.onNavigate,
  });

  final AppSession session;
  final bool organizationMode;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sports, clearly organized.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Explore NBA data, compare performance and use front-office tools without navigating a wall of terminal controls.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 4
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (16 * (columns - 1))) / columns;
            final cards = [
              _HomeCardData(
                title: 'NBA',
                body: 'Players, teams, games, standings and league history.',
                icon: Icons.sports_basketball_rounded,
                target: 'nba',
              ),
              _HomeCardData(
                title: 'Stats',
                body: 'Sortable player statistics with clean filters and drill-downs.',
                icon: Icons.leaderboard_rounded,
                target: 'stats',
              ),
              _HomeCardData(
                title: 'Analytics',
                body: 'Advanced metrics, comparisons and deeper performance analysis.',
                icon: Icons.analytics_rounded,
                target: 'analytics',
              ),
              _HomeCardData(
                title: 'Trade Machine',
                body: 'Build and validate multi-team trade scenarios.',
                icon: Icons.swap_horiz_rounded,
                target: 'trade',
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final card in cards)
                  SizedBox(
                    width: width,
                    child: _HomeCard(
                      data: card,
                      onTap: () => onNavigate(card.target),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 36),
        Text(
          'More to explore',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _HomeRow(
                  icon: Icons.account_tree_outlined,
                  title: 'Front Office',
                  body: 'Contracts, draft assets and team position records.',
                  onTap: () => onNavigate('front-office'),
                ),
                _HomeRow(
                  icon: Icons.emoji_events_outlined,
                  title: 'Awards',
                  body: 'League awards, selections and voting history.',
                  onTap: () => onNavigate('awards'),
                ),
                _HomeRow(
                  icon: Icons.science_outlined,
                  title: 'Research',
                  body:
                      'Saved research, metric definitions and advanced institutional tools live here instead of in the global navigation.',
                  onTap: () => onNavigate('research'),
                ),
                _HomeRow(
                  icon: organizationMode
                      ? Icons.corporate_fare_rounded
                      : Icons.work_outline_rounded,
                  title: organizationMode ? 'Organization' : 'My Work',
                  body: organizationMode
                      ? 'Shared cases and organization workflow.'
                      : 'Your saved cases and personal workflow.',
                  onTap: () => onNavigate('my-work'),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Signed in as ${session.displayName}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
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
              const SizedBox(height: 18),
              Text(
                data.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 7),
              Text(
                data.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 17, color: colors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeRow extends StatelessWidget {
  const _HomeRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            onTap: onTap,
            leading: Icon(icon),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(body),
            trailing: const Icon(Icons.chevron_right_rounded),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          ),
          if (showDivider) const Divider(height: 1),
        ],
      );
}

class _SiteDestination {
  const _SiteDestination({
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
  const _HomeCardData({
    required this.title,
    required this.body,
    required this.icon,
    required this.target,
  });

  final String title;
  final String body;
  final IconData icon;
  final String target;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final letters = [for (final part in parts.take(2)) part.substring(0, 1).toUpperCase()];
  return letters.isEmpty ? 'ST' : letters.join();
}
