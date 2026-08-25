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
import '../screens/product_transaction_command_center_screen.dart';
import '../screens/website_nba_advanced_stats_screen.dart';
import '../screens/website_nba_stats_screen.dart';
import '../screens/website_trade_machine_screen.dart';
import '../services/product_local_store.dart';
import 'website_nba_data_gate.dart';

const _brandBlue = Color(0xFF6F8BFF);

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
  String _selectedId = 'nba-home';
  bool _darkMode = true;

  bool get _organizationMode => widget.session.role.canManageOrganization;

  List<_Destination> get _nbaDestinations => [
        _Destination(
          id: 'nba-home',
          label: 'Home',
          icon: Icons.home_rounded,
          builder: () => WebsiteNbaDataGate(builder: (_, _) => const ProductNbaHubV2Screen()),
        ),
        _Destination(
          id: 'nba-stats',
          label: 'Stats',
          icon: Icons.leaderboard_rounded,
          builder: () => WebsiteNbaDataGate(builder: (_, _) => WebsiteNbaStatsScreen(session: widget.session)),
        ),
        _Destination(
          id: 'nba-advanced',
          label: 'Advanced Stats',
          icon: Icons.analytics_outlined,
          builder: () => WebsiteNbaDataGate(builder: (_, _) => WebsiteNbaAdvancedStatsScreen(session: widget.session)),
        ),
        _Destination(
          id: 'nba-trade',
          label: 'Trade Machine',
          icon: Icons.swap_horiz_rounded,
          builder: () => WebsiteNbaDataGate(builder: (_, _) => WebsiteTradeMachineScreen(session: widget.session)),
        ),
        _Destination(
          id: 'nba-front-office',
          label: 'Front Office',
          icon: Icons.account_tree_outlined,
          builder: () => ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        _Destination(
          id: 'nba-awards',
          label: 'Awards',
          icon: Icons.emoji_events_outlined,
          builder: () => WebsiteNbaDataGate(builder: (_, _) => const ProductNbaAwardsVotingScreen()),
        ),
        _Destination(
          id: 'nba-tools',
          label: 'NBA Tools',
          icon: Icons.tune_rounded,
          builder: () => WebsiteNbaDataGate(builder: (_, _) => const ProductAdvancedNbaToolsScreen()),
        ),
      ];

  List<_Destination> get _secondary => [
        _Destination(
          id: 'my-work',
          label: _organizationMode ? 'Organization' : 'My Work',
          icon: _organizationMode ? Icons.corporate_fare_outlined : Icons.work_outline_rounded,
          builder: () => ProductTransactionCommandCenterScreen(session: widget.session, organizationMode: _organizationMode),
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
          builder: () => WebsiteNbaDataGate(builder: (_, _) => const ProductFantasyWarRoomScreen()),
        ),
        _Destination(
          id: 'articles',
          label: 'Articles',
          icon: Icons.article_outlined,
          builder: () => WebsiteNbaDataGate(builder: (_, _) => const ProductArticlesArenaScreen()),
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

  static const _futureSports = [
    'NFL', 'NHL', 'MLB', 'MLS', 'Tennis', 'WNBA', 'NCAAB', 'NCAAF', 'Champions League', 'Premier League',
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final dark = await _store.loadBool(ProductLocalStore.darkModeKey, fallback: true);
    if (mounted) setState(() => _darkMode = dark);
  }

  Future<void> _toggleTheme() async {
    final next = !_darkMode;
    setState(() => _darkMode = next);
    await _store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(String id) {
    final all = [..._nbaDestinations, ..._secondary];
    if (all.any((item) => item.id == id)) setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final nba = _nbaDestinations;
    final secondary = _secondary;
    final all = [...nba, ...secondary];
    final selected = all.firstWhere((item) => item.id == _selectedId, orElse: () => nba.first);
    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: _brandBlue, brightness: brightness),
      scaffoldBackgroundColor: _darkMode ? const Color(0xFF0A1018) : const Color(0xFFF6F8FC),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkMode ? const Color(0xFF121B26) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _darkMode ? const Color(0xFF263241) : const Color(0xFFE4E8F0)),
        ),
      ),
      dividerColor: _darkMode ? const Color(0xFF2B3747) : const Color(0xFFE5E9F0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkMode ? const Color(0xFF101923) : const Color(0xFFF9FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkMode ? const Color(0xFF334155) : const Color(0xFFD7DDE7)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: _darkMode ? const Color(0xFF334155) : const Color(0xFFD7DDE7)),
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
                nbaItems: nba,
                secondary: secondary,
                selectedId: selected.id,
                darkMode: _darkMode,
                futureSports: _futureSports,
                onSelect: _select,
                onToggleTheme: _toggleTheme,
                onSignOut: widget.onSignOut,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 34, 18, 72),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1480),
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
    required this.nbaItems,
    required this.secondary,
    required this.selectedId,
    required this.darkMode,
    required this.futureSports,
    required this.onSelect,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  final AppSession session;
  final List<_Destination> nbaItems;
  final List<_Destination> secondary;
  final String selectedId;
  final bool darkMode;
  final List<String> futureSports;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF0E1722) : Colors.white,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;
            return Row(
              children: [
                InkWell(
                  onTap: () => onSelect('nba-home'),
                  borderRadius: BorderRadius.circular(13),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [colors.primary, colors.tertiary]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ST', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 10),
                      const Text('Sports Terminal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                    ]),
                  ),
                ),
                if (desktop) ...[
                  const SizedBox(width: 26),
                  _SportMenu(nbaItems: nbaItems, futureSports: futureSports, selectedId: selectedId, onSelect: onSelect),
                  const SizedBox(width: 4),
                  _MoreMenu(items: secondary, selectedId: selectedId, onSelect: onSelect),
                  const Spacer(),
                ] else ...[
                  const Spacer(),
                  _MobileMenu(items: [...nbaItems, ...secondary], selectedId: selectedId, onSelect: onSelect),
                ],
                IconButton(
                  tooltip: darkMode ? 'Light mode' : 'Dark mode',
                  onPressed: onToggleTheme,
                  icon: Icon(darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
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
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(session.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(session.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                        ]),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'profile', child: Text('Profile')),
                    const PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
                  ],
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(_initials(session.displayName), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
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

class _SportMenu extends StatelessWidget {
  const _SportMenu({required this.nbaItems, required this.futureSports, required this.selectedId, required this.onSelect});
  final List<_Destination> nbaItems;
  final List<String> futureSports;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Sports',
      onSelected: onSelect,
      itemBuilder: (_) => [
        const PopupMenuItem<String>(enabled: false, child: Text('NBA', style: TextStyle(fontWeight: FontWeight.w900))),
        for (final item in nbaItems)
          PopupMenuItem(
            value: item.id,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.icon, size: 19),
              title: Text(item.label),
              trailing: item.id == selectedId ? const Icon(Icons.check_rounded, size: 18) : null,
            ),
          ),
        const PopupMenuDivider(),
        for (final sport in futureSports)
          PopupMenuItem<String>(
            enabled: false,
            child: Row(children: [
              const Icon(Icons.lock_clock_outlined, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(sport)),
              Text('Coming Later', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ]),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sports_basketball_rounded, size: 19, color: colors.primary),
          const SizedBox(width: 7),
          Text('NBA', style: TextStyle(color: colors.primary, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(width: 3),
          const Icon(Icons.expand_more_rounded, size: 17),
        ]),
      ),
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
              trailing: item.id == selectedId ? const Icon(Icons.check_rounded, size: 18) : null,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('More', style: TextStyle(color: active ? colors.primary : null, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(width: 3),
          Icon(Icons.expand_more_rounded, size: 17, color: active ? colors.primary : null),
        ]),
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
        tooltip: 'Menu',
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
                trailing: item.id == selectedId ? const Icon(Icons.check_rounded, size: 18) : null,
              ),
            ),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Icon(Icons.menu_rounded),
        ),
      );
}

class _Destination {
  const _Destination({required this.id, required this.label, required this.icon, required this.builder});
  final String id;
  final String label;
  final IconData icon;
  final Widget Function() builder;
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
  if (parts.isEmpty) return 'ST';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}
