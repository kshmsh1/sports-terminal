import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_analytics_suite_screen.dart';
import '../screens/product_backend_sync_screen.dart';
import '../screens/product_community_v2_screen.dart';
import '../screens/product_connected_data_studio_screen.dart';
import '../screens/product_connected_network_screens.dart';
import '../screens/product_connected_transaction_screens.dart';
import '../screens/product_connected_workspace_screen.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_fantasy_community_screens.dart';
import '../screens/product_front_office_registry_screen.dart';
import '../screens/product_nba_awards_v2_screen.dart';
import '../screens/product_nba_public_pages_screen.dart';
import '../screens/product_platform_content_legal_screen.dart';
import '../screens/product_profile_v3_screen.dart';
import '../screens/product_role_home_screen.dart';
import '../screens/product_shell_screens.dart';
import '../screens/product_strategy_map_screen.dart';
import '../screens/product_team_blogs_screen.dart';
import '../screens/product_transaction_command_center_screen.dart';
import '../services/product_local_store.dart';

const _navBackground = Color(0xFF0A101A);
const _darkBackground = Color(0xFF080F18);
const _lightBackground = Color(0xFFF5F7FB);
const _darkPanel = Color(0xFF111A27);
const _lightPanel = Colors.white;
const _darkLine = Color(0xFF283243);
const _lightLine = Color(0xFFDDE3EC);
const _darkText = Color(0xFFF2F4FA);
const _lightText = Color(0xFF172033);
const _darkMuted = Color(0xFFAAB2C1);
const _lightMuted = Color(0xFF657084);
const _accent = Color(0xFFAFB8FF);
const _logo = Color(0xFF424B83);

/// Canonical Sports Terminal product chrome.
///
/// Keep the primary product navigation intentionally small. New product surfaces
/// belong under More unless they replace one of the five canonical destinations.
class CanonicalProductShell extends StatefulWidget {
  const CanonicalProductShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<CanonicalProductShell> createState() => _CanonicalProductShellState();
}

class _CanonicalProductShellState extends State<CanonicalProductShell> {
  final ProductLocalStore _store = const ProductLocalStore();
  int _selectedIndex = 0;
  bool _darkMode = true;

  bool get _organizationMode => widget.session.role.canManageOrganization;

  List<_Destination> get _destinations => [
        _Destination(
          label: 'Home',
          icon: Icons.home_rounded,
          screen: ProductRoleHomeScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
          primary: true,
        ),
        const _Destination(
          label: 'Stats',
          icon: Icons.leaderboard_rounded,
          screen: ProductNbaBasicStatsScreen(),
          primary: true,
        ),
        const _Destination(
          label: 'Advanced Stats',
          icon: Icons.analytics_rounded,
          screen: ProductAdvancedNbaToolsScreen(),
          primary: true,
        ),
        const _Destination(
          label: 'Lineup Analysis',
          icon: Icons.groups_rounded,
          screen: ProductAnalyticsSuiteScreen(initialTool: 'Lineup Builder'),
          primary: true,
        ),
        _Destination(
          label: 'Trade Machine',
          icon: Icons.swap_horiz_rounded,
          screen: ProductConnectedTradeMachineScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
          primary: true,
        ),
        const _Destination(
          label: 'NBA Hub',
          icon: Icons.sports_basketball_rounded,
          screen: ProductNbaHubV2Screen(),
        ),
        const _Destination(
          label: 'Awards',
          icon: Icons.emoji_events_rounded,
          screen: ProductNbaAwardsVotingScreen(),
        ),
        _Destination(
          label: _organizationMode ? 'Organization' : 'My Work',
          icon: _organizationMode
              ? Icons.corporate_fare_rounded
              : Icons.space_dashboard_rounded,
          screen: ProductTransactionCommandCenterScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
        ),
        _Destination(
          label: 'Front Office',
          icon: Icons.account_tree_rounded,
          screen: ProductConnectedFrontOfficeScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
        ),
        _Destination(
          label: 'Contracts & Assets',
          icon: Icons.inventory_2_rounded,
          screen: ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        _Destination(
          label: 'Workspace',
          icon: Icons.grid_on_rounded,
          screen: ProductConnectedWorkspaceScreen(session: widget.session),
        ),
        _Destination(
          label: 'Python Lab',
          icon: Icons.code_rounded,
          screen: ProductConnectedDataStudioScreen(session: widget.session),
        ),
        const _Destination(
          label: 'Strategy',
          icon: Icons.radar_rounded,
          screen: ProductStrategyMapScreen(),
        ),
        const _Destination(
          label: 'Fantasy',
          icon: Icons.bolt_rounded,
          screen: ProductFantasyWarRoomScreen(),
        ),
        const _Destination(
          label: 'Team Blogs',
          icon: Icons.newspaper_rounded,
          screen: ProductTeamBlogsScreen(),
        ),
        _Destination(
          label: 'Community',
          icon: Icons.forum_rounded,
          screen: ProductCommunityV2Screen(session: widget.session),
        ),
        const _Destination(
          label: 'Articles',
          icon: Icons.article_rounded,
          screen: ProductEditorialHomeScreen(),
        ),
        _Destination(
          label: 'Messages',
          icon: Icons.chat_bubble_rounded,
          screen: ProductConnectedMessagesScreen(session: widget.session),
        ),
        _Destination(
          label: 'Profile',
          icon: Icons.person_rounded,
          screen: ProductProfileV3Screen(session: widget.session),
        ),
        if (_organizationMode || widget.session.role.canAccessPlatformAdmin)
          _Destination(
            label: 'Admin',
            icon: Icons.admin_panel_settings_rounded,
            screen: ProductAdminOpsCenterScreen(session: widget.session),
          ),
        if (_organizationMode || widget.session.role.canAccessPlatformAdmin)
          _Destination(
            label: 'Backend',
            icon: Icons.cloud_sync_rounded,
            screen: ProductBackendSyncScreen(session: widget.session),
          ),
        if (_organizationMode || widget.session.role.canAccessPlatformAdmin)
          const _Destination(
            label: 'Internal Lab',
            icon: Icons.science_rounded,
            screen: ProductInternalLabScreen(),
          ),
        const _Destination(
          label: 'About Us',
          icon: Icons.info_outline_rounded,
          screen: ProductPlatformLegalScreen(kind: 'about'),
        ),
        const _Destination(
          label: 'Contact',
          icon: Icons.mail_outline_rounded,
          screen: ProductPlatformLegalScreen(kind: 'contact'),
        ),
        const _Destination(
          label: 'Privacy Policy',
          icon: Icons.privacy_tip_outlined,
          screen: ProductPlatformLegalScreen(kind: 'privacy'),
        ),
        const _Destination(
          label: 'Terms & Conditions',
          icon: Icons.description_outlined,
          screen: ProductPlatformLegalScreen(kind: 'terms'),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await _store.loadBool(
      ProductLocalStore.darkModeKey,
      fallback: true,
    );
    if (!mounted) return;
    setState(() => _darkMode = saved);
  }

  Future<void> _toggleTheme() async {
    final next = !_darkMode;
    setState(() => _darkMode = next);
    await _store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(int index) {
    final items = _destinations;
    if (index < 0 || index >= items.length) return;
    setState(() => _selectedIndex = index);
  }

  void _selectByLabel(String label) {
    final index = _destinations.indexWhere((item) => item.label == label);
    if (index >= 0) _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final items = _destinations;
    if (_selectedIndex >= items.length) _selectedIndex = 0;
    final selected = items[_selectedIndex];
    final palette = _Palette(_darkMode);

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: _darkMode ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: _darkMode ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: palette.background,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          return Scaffold(
            backgroundColor: palette.background,
            appBar: compact
                ? AppBar(
                    backgroundColor: palette.nav,
                    foregroundColor: palette.text,
                    elevation: 0,
                    titleSpacing: 14,
                    title: const _Brand(compact: true),
                    actions: [
                      IconButton(
                        tooltip: _darkMode ? 'Light mode' : 'Dark mode',
                        onPressed: _toggleTheme,
                        icon: Icon(
                          _darkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ],
                  )
                : null,
            drawer: compact
                ? Drawer(
                    backgroundColor: palette.panel,
                    child: SafeArea(
                      child: _MobileMenu(
                        items: items,
                        selectedIndex: _selectedIndex,
                        palette: palette,
                        onSelected: (index) {
                          _select(index);
                          Navigator.of(context).pop();
                        },
                        onSignOut: widget.onSignOut,
                      ),
                    ),
                  )
                : null,
            body: Column(
              children: [
                if (!compact)
                  _DesktopNav(
                    items: items,
                    selectedIndex: _selectedIndex,
                    session: widget.session,
                    palette: palette,
                    darkMode: _darkMode,
                    onSelected: _select,
                    onSearch: () => _selectByLabel('NBA Hub'),
                    onToggleTheme: _toggleTheme,
                    onProfile: () => _selectByLabel('Profile'),
                    onSignOut: widget.onSignOut,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 12 : 14,
                            compact ? 16 : 24,
                            compact ? 12 : 14,
                            36,
                          ),
                          child: selected.screen,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.screen,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final Widget screen;
  final bool primary;
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({
    required this.items,
    required this.selectedIndex,
    required this.session,
    required this.palette,
    required this.darkMode,
    required this.onSelected,
    required this.onSearch,
    required this.onToggleTheme,
    required this.onProfile,
    required this.onSignOut,
  });

  final List<_Destination> items;
  final int selectedIndex;
  final AppSession session;
  final _Palette palette;
  final bool darkMode;
  final ValueChanged<int> onSelected;
  final VoidCallback onSearch;
  final VoidCallback onToggleTheme;
  final VoidCallback onProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final primary = <MapEntry<int, _Destination>>[
      for (var index = 0; index < items.length; index++)
        if (items[index].primary) MapEntry(index, items[index]),
    ];
    final more = <MapEntry<int, _Destination>>[
      for (var index = 0; index < items.length; index++)
        if (!items[index].primary) MapEntry(index, items[index]),
    ];

    return Material(
      color: palette.nav,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.line)),
        ),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelected(primary.first.key),
              child: const _Brand(),
            ),
            const SizedBox(width: 26),
            for (final entry in primary)
              _PrimaryNavButton(
                label: entry.value.label,
                selected: entry.key == selectedIndex,
                palette: palette,
                onTap: () => onSelected(entry.key),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search players & teams'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.text,
                side: BorderSide(color: palette.searchLine),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                shape: const StadiumBorder(),
              ),
            ),
            const SizedBox(width: 10),
            PopupMenuButton<int>(
              tooltip: 'More',
              color: palette.panel,
              onSelected: onSelected,
              itemBuilder: (context) => [
                for (final entry in more)
                  PopupMenuItem<int>(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value.icon, size: 18, color: palette.muted),
                        const SizedBox(width: 10),
                        Text(entry.value.label),
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'More',
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: palette.text),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: darkMode ? 'Light mode' : 'Dark mode',
              onPressed: onToggleTheme,
              icon: Icon(
                darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: palette.text,
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: session.displayName,
              color: palette.panel,
              onSelected: (value) {
                if (value == 'profile') {
                  onProfile();
                } else if (value == 'signout') {
                  onSignOut();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'profile', child: Text('Profile')),
                PopupMenuItem(value: 'signout', child: Text('Sign out')),
              ],
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _logo,
                child: Text(
                  session.displayName.isEmpty
                      ? 'U'
                      : session.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryNavButton extends StatelessWidget {
  const _PrimaryNavButton({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? _accent : palette.text,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
          textStyle: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 14,
          ),
        ),
        child: Text(label),
      );
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _logo,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'ST',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 13 : 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Sports Terminal',
            style: TextStyle(
              color: _darkText,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ],
      );
}

class _MobileMenu extends StatelessWidget {
  const _MobileMenu({
    required this.items,
    required this.selectedIndex,
    required this.palette,
    required this.onSelected,
    required this.onSignOut,
  });

  final List<_Destination> items;
  final int selectedIndex;
  final _Palette palette;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Brand(compact: true),
            ),
          ),
          Divider(color: palette.line, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  selected: index == selectedIndex,
                  selectedColor: _accent,
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  onTap: () => onSelected(index),
                );
              },
            ),
          ),
          Divider(color: palette.line, height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: onSignOut,
          ),
          const SizedBox(height: 8),
        ],
      );
}

class _Palette {
  const _Palette(this.dark);

  final bool dark;

  Color get nav => dark ? _navBackground : Colors.white;
  Color get background => dark ? _darkBackground : _lightBackground;
  Color get panel => dark ? _darkPanel : _lightPanel;
  Color get line => dark ? _darkLine : _lightLine;
  Color get text => dark ? _darkText : _lightText;
  Color get muted => dark ? _darkMuted : _lightMuted;
  Color get searchLine => dark ? const Color(0xFF747E92) : const Color(0xFF9BA6B8);
}
