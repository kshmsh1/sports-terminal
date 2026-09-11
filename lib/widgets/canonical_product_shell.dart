import 'package:flutter/material.dart';

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
import '../screens/product_trade_machine_screen.dart';
import '../screens/product_transaction_command_center_screen.dart';
import '../services/product_local_store.dart';

const _darkBg = Color(0xFF080F18);
const _lightBg = Color(0xFFF5F7FB);
const _darkNav = Color(0xFF0A101A);
const _darkPanel = Color(0xFF111A27);
const _darkLine = Color(0xFF283243);
const _lightLine = Color(0xFFDDE3EC);
const _darkText = Color(0xFFF2F4FA);
const _lightText = Color(0xFF172033);
const _darkMuted = Color(0xFFAAB2C1);
const _lightMuted = Color(0xFF657084);
const _active = Color(0xFFB8C0FF);
const _logo = Color(0xFF424B83);

/// The canonical Sports Terminal product shell.
///
/// The five primary destinations intentionally match the approved product UI:
/// Home, Stats, Advanced Stats, Lineup Analysis, and Trade Machine. Everything
/// else remains available through More rather than expanding the top bar.
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
  final ProductLocalStore _store = const ProductLocalStore();
  int _selectedIndex = 0;
  bool _darkMode = true;

  bool get _organizationMode => widget.session.role.canManageOrganization;

  List<_Destination> get _items => [
        _Destination(
          'Home',
          Icons.home_rounded,
          ProductRoleHomeScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
          primary: true,
        ),
        const _Destination(
          'Stats',
          Icons.leaderboard_rounded,
          ProductNbaBasicStatsScreen(),
          primary: true,
        ),
        const _Destination(
          'Advanced Stats',
          Icons.analytics_rounded,
          ProductAdvancedNbaToolsScreen(),
          primary: true,
        ),
        const _Destination(
          'Lineup Analysis',
          Icons.groups_rounded,
          ProductAnalyticsSuiteScreen(),
          primary: true,
        ),
        const _Destination(
          'Trade Machine',
          Icons.swap_horiz_rounded,
          ProductTradeMachineScreen(),
          primary: true,
        ),
        const _Destination(
          'NBA Hub',
          Icons.sports_basketball_rounded,
          ProductNbaHubV2Screen(),
        ),
        const _Destination(
          'Awards',
          Icons.emoji_events_rounded,
          ProductNbaAwardsVotingScreen(),
        ),
        _Destination(
          _organizationMode ? 'Organization' : 'My Work',
          _organizationMode
              ? Icons.corporate_fare_rounded
              : Icons.space_dashboard_rounded,
          ProductTransactionCommandCenterScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
        ),
        _Destination(
          'Front Office',
          Icons.account_tree_rounded,
          ProductConnectedFrontOfficeScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
        ),
        _Destination(
          'Contracts & Assets',
          Icons.inventory_2_rounded,
          ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        _Destination(
          'Workspace',
          Icons.grid_on_rounded,
          ProductConnectedWorkspaceScreen(session: widget.session),
        ),
        _Destination(
          'Python Lab',
          Icons.code_rounded,
          ProductConnectedDataStudioScreen(session: widget.session),
        ),
        const _Destination('Strategy', Icons.radar_rounded, ProductStrategyMapScreen()),
        const _Destination('Fantasy', Icons.bolt_rounded, ProductFantasyWarRoomScreen()),
        const _Destination('Team Blogs', Icons.newspaper_rounded, ProductTeamBlogsScreen()),
        _Destination(
          'Community',
          Icons.forum_rounded,
          ProductCommunityV2Screen(session: widget.session),
        ),
        const _Destination('Articles', Icons.article_rounded, ProductEditorialHomeScreen()),
        _Destination(
          'Messages',
          Icons.chat_bubble_rounded,
          ProductConnectedMessagesScreen(session: widget.session),
        ),
        _Destination(
          'Profile',
          Icons.person_rounded,
          ProductProfileV3Screen(session: widget.session),
        ),
        if (_organizationMode || widget.session.role.canAccessPlatformAdmin)
          _Destination(
            'Admin',
            Icons.admin_panel_settings_rounded,
            ProductAdminOpsCenterScreen(session: widget.session),
          ),
        if (_organizationMode || widget.session.role.canAccessPlatformAdmin)
          _Destination(
            'Backend',
            Icons.cloud_sync_rounded,
            ProductBackendSyncScreen(session: widget.session),
          ),
        if (_organizationMode || widget.session.role.canAccessPlatformAdmin)
          const _Destination('Internal Lab', Icons.science_rounded, ProductInternalLabScreen()),
        const _Destination(
          'About Us',
          Icons.info_outline_rounded,
          ProductPlatformLegalScreen(kind: 'about'),
        ),
        const _Destination(
          'Contact',
          Icons.mail_outline_rounded,
          ProductPlatformLegalScreen(kind: 'contact'),
        ),
        const _Destination(
          'Privacy Policy',
          Icons.privacy_tip_outlined,
          ProductPlatformLegalScreen(kind: 'privacy'),
        ),
        const _Destination(
          'Terms & Conditions',
          Icons.description_outlined,
          ProductPlatformLegalScreen(kind: 'terms'),
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

  void _select(int index) {
    if (index < 0 || index >= _items.length) return;
    setState(() => _selectedIndex = index);
  }

  void _selectLabel(String label) {
    final index = _items.indexWhere((item) => item.label == label);
    if (index >= 0) _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_selectedIndex >= items.length) _selectedIndex = 0;
    final palette = _Palette(_darkMode);
    final selected = items[_selectedIndex];

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: _darkMode ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _active,
          brightness: _darkMode ? Brightness.dark : Brightness.light,
        ),
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
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _Brand(compact: true),
                            ),
                          ),
                          Divider(color: palette.line, height: 1),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: items.length,
                              itemBuilder: (context, index) => ListTile(
                                selected: index == _selectedIndex,
                                selectedColor: _active,
                                leading: Icon(items[index].icon),
                                title: Text(items[index].label),
                                onTap: () {
                                  _select(index);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout_rounded),
                            title: const Text('Sign out'),
                            onTap: widget.onSignOut,
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
            body: Column(
              children: [
                if (!compact)
                  _TopNav(
                    items: items,
                    selectedIndex: _selectedIndex,
                    session: widget.session,
                    palette: palette,
                    darkMode: _darkMode,
                    onSelected: _select,
                    onSearch: () => _selectLabel('NBA Hub'),
                    onToggleTheme: _toggleTheme,
                    onProfile: () => _selectLabel('Profile'),
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
  const _Destination(this.label, this.icon, this.screen, {this.primary = false});

  final String label;
  final IconData icon;
  final Widget screen;
  final bool primary;
}

class _TopNav extends StatelessWidget {
  const _TopNav({
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
      for (var i = 0; i < items.length; i++)
        if (items[i].primary) MapEntry(i, items[i]),
    ];
    final more = <MapEntry<int, _Destination>>[
      for (var i = 0; i < items.length; i++)
        if (!items[i].primary) MapEntry(i, items[i]),
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
            const SizedBox(width: 24),
            for (final entry in primary)
              TextButton(
                onPressed: () => onSelected(entry.key),
                style: TextButton.styleFrom(
                  foregroundColor:
                      entry.key == selectedIndex ? _active : palette.text,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 22,
                  ),
                  textStyle: TextStyle(
                    fontWeight: entry.key == selectedIndex
                        ? FontWeight.w800
                        : FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(entry.value.label),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search players & teams'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.text,
                side: BorderSide(color: palette.searchLine),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                    const SizedBox(width: 3),
                    Icon(Icons.keyboard_arrow_down_rounded, color: palette.text),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: darkMode ? 'Light mode' : 'Dark mode',
              onPressed: onToggleTheme,
              icon: Icon(
                darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: palette.text,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: session.displayName,
              color: palette.panel,
              onSelected: (value) {
                if (value == 'profile') onProfile();
                if (value == 'signout') onSignOut();
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

class _Palette {
  const _Palette(this.dark);

  final bool dark;

  Color get nav => dark ? _darkNav : Colors.white;
  Color get background => dark ? _darkBg : _lightBg;
  Color get panel => dark ? _darkPanel : Colors.white;
  Color get line => dark ? _darkLine : _lightLine;
  Color get text => dark ? _darkText : _lightText;
  Color get muted => dark ? _darkMuted : _lightMuted;
  Color get searchLine =>
      dark ? const Color(0xFF747E92) : const Color(0xFF9BA6B8);
}
