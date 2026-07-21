import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/excel_like_workspace_screen.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_backend_sync_screen.dart';
import '../screens/product_connected_transaction_screens.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_fantasy_community_screens.dart';
import '../screens/product_nba_entity_hub_screen.dart';
import '../screens/product_nba_stats_center_screen.dart';
import '../screens/product_profile_persisted_screen.dart';
import '../screens/product_python_dev_lab_screen.dart';
import '../screens/product_role_home_screen.dart';
import '../screens/product_shell_screens.dart';
import '../screens/product_strategy_map_screen.dart';
import '../screens/product_team_blogs_screen.dart';
import '../screens/product_transaction_command_center_screen.dart';
import '../services/product_local_store.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _lightBackground = Color(0xFFF5F7FB);
const _darkBackground = Color(0xFF07111F);

class ConnectedRoleTerminalShell extends StatefulWidget {
  const ConnectedRoleTerminalShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<ConnectedRoleTerminalShell> createState() =>
      _ConnectedRoleTerminalShellState();
}

class _ConnectedRoleTerminalShellState
    extends State<ConnectedRoleTerminalShell> {
  final store = const ProductLocalStore();
  int selectedIndex = 0;
  bool darkMode = false;

  bool get organizationMode => widget.session.role.canManageOrganization;

  List<_ConnectedDestination> get destinations => [
        _ConnectedDestination(
          label: organizationMode ? 'Organization' : 'My Work',
          group: organizationMode ? 'Organization' : 'Personal',
          icon: organizationMode
              ? Icons.corporate_fare_rounded
              : Icons.space_dashboard_rounded,
          screen: ProductTransactionCommandCenterScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        _ConnectedDestination(
          label: 'Home',
          group: 'Product',
          icon: Icons.home_rounded,
          screen: ProductRoleHomeScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        const _ConnectedDestination(
          label: 'Stats',
          group: 'NBA',
          icon: Icons.leaderboard_rounded,
          screen: ProductNbaStatsCenterScreen(),
        ),
        const _ConnectedDestination(
          label: 'NBA Hub',
          group: 'NBA',
          icon: Icons.sports_basketball_rounded,
          screen: ProductNbaEntityHubScreen(),
        ),
        const _ConnectedDestination(
          label: 'Advanced',
          group: 'NBA',
          icon: Icons.analytics_rounded,
          screen: ProductAdvancedNbaToolsScreen(),
        ),
        _ConnectedDestination(
          label: 'Trade Machine',
          group: 'Transactions',
          icon: Icons.swap_horiz_rounded,
          screen: ProductConnectedTradeMachineScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        _ConnectedDestination(
          label: 'Front Office',
          group: 'Transactions',
          icon: Icons.account_tree_rounded,
          screen: ProductConnectedFrontOfficeScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        const _ConnectedDestination(
          label: 'Workspace',
          group: 'Tools',
          icon: Icons.grid_on_rounded,
          screen: ProductWorkspaceHubScreen(
            workspace: ExcelLikeWorkspaceScreen(),
          ),
        ),
        const _ConnectedDestination(
          label: 'Python Lab',
          group: 'Tools',
          icon: Icons.code_rounded,
          screen: ProductPythonDevLabScreen(),
        ),
        if (organizationMode)
          _ConnectedDestination(
            label: 'Organization Admin',
            group: 'Organization',
            icon: Icons.admin_panel_settings_rounded,
            screen: ProductAdminOpsCenterScreen(session: widget.session),
          ),
        const _ConnectedDestination(
          label: 'Strategy',
          group: 'Product',
          icon: Icons.radar_rounded,
          screen: ProductStrategyMapScreen(),
        ),
        const _ConnectedDestination(
          label: 'Fantasy',
          group: 'Product',
          icon: Icons.bolt_rounded,
          screen: ProductFantasyWarRoomScreen(),
        ),
        const _ConnectedDestination(
          label: 'Team Blogs',
          group: 'Content',
          icon: Icons.newspaper_rounded,
          screen: ProductTeamBlogsScreen(),
        ),
        const _ConnectedDestination(
          label: 'Community',
          group: 'Network',
          icon: Icons.forum_rounded,
          screen: ProductCommunityArenaScreen(),
        ),
        const _ConnectedDestination(
          label: 'Articles',
          group: 'Network',
          icon: Icons.article_rounded,
          screen: ProductArticlesArenaScreen(),
        ),
        const _ConnectedDestination(
          label: 'Messages',
          group: 'Network',
          icon: Icons.chat_bubble_rounded,
          screen: ProductMessagesArenaScreen(),
        ),
        if (organizationMode)
          _ConnectedDestination(
            label: 'Backend',
            group: 'Organization',
            icon: Icons.cloud_sync_rounded,
            screen: ProductBackendSyncScreen(session: widget.session),
          ),
        if (organizationMode)
          const _ConnectedDestination(
            label: 'Internal Lab',
            group: 'Organization',
            icon: Icons.science_rounded,
            screen: ProductInternalLabScreen(),
          ),
        _ConnectedDestination(
          label: 'Profile',
          group: 'Account',
          icon: Icons.person_rounded,
          screen: ProductPersistedProfileScreen(session: widget.session),
        ),
        const _ConnectedDestination(
          label: 'About Us',
          group: 'Legal',
          icon: Icons.info_outline_rounded,
          screen: ProductLegalScreen(kind: 'about'),
        ),
        const _ConnectedDestination(
          label: 'Contact',
          group: 'Legal',
          icon: Icons.mail_outline_rounded,
          screen: ProductLegalScreen(kind: 'contact'),
        ),
        const _ConnectedDestination(
          label: 'Privacy Policy',
          group: 'Legal',
          icon: Icons.privacy_tip_outlined,
          screen: ProductLegalScreen(kind: 'privacy'),
        ),
        const _ConnectedDestination(
          label: 'Terms & Conditions',
          group: 'Legal',
          icon: Icons.description_outlined,
          screen: ProductLegalScreen(kind: 'terms'),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await store.loadBool(ProductLocalStore.darkModeKey);
    if (!mounted) return;
    setState(() => darkMode = saved);
  }

  Future<void> _toggleTheme() async {
    final next = !darkMode;
    setState(() => darkMode = next);
    await store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(int index, {bool closeDrawer = false}) {
    if (index < 0 || index >= destinations.length) return;
    setState(() => selectedIndex = index);
    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ConnectedPalette(darkMode);
    final items = destinations;
    if (selectedIndex >= items.length) selectedIndex = 0;
    final selected = items[selectedIndex];
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: darkMode ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _navy,
          brightness: darkMode ? Brightness.dark : Brightness.light,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          return Scaffold(
            backgroundColor: palette.background,
            appBar: compact
                ? AppBar(
                    backgroundColor: palette.panel,
                    foregroundColor: palette.text,
                    title: Row(
                      children: [
                        const _ConnectedLogo(size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            organizationMode
                                ? widget.session.organizationName
                                : 'Sports Terminal',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        tooltip: darkMode ? 'Use light mode' : 'Use dark mode',
                        onPressed: _toggleTheme,
                        icon: Icon(
                          darkMode
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sign out',
                        onPressed: widget.onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ],
                  )
                : null,
            drawer: compact
                ? Drawer(
                    backgroundColor: palette.panel,
                    child: SafeArea(
                      child: _ConnectedNavigation(
                        session: widget.session,
                        destinations: items,
                        selectedIndex: selectedIndex,
                        palette: palette,
                        onSelected: (index) => _select(index, closeDrawer: true),
                        onToggleTheme: _toggleTheme,
                        onSignOut: widget.onSignOut,
                        darkMode: darkMode,
                      ),
                    ),
                  )
                : null,
            body: Row(
              children: [
                if (!compact)
                  SizedBox(
                    width: 278,
                    child: ColoredBox(
                      color: palette.panel,
                      child: SafeArea(
                        child: _ConnectedNavigation(
                          session: widget.session,
                          destinations: items,
                          selectedIndex: selectedIndex,
                          palette: palette,
                          onSelected: _select,
                          onToggleTheme: _toggleTheme,
                          onSignOut: widget.onSignOut,
                          darkMode: darkMode,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ColoredBox(
                    color: palette.background,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(compact ? 16 : 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1380),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ConnectedPageHeader(
                                destination: selected,
                                palette: palette,
                                organizationMode: organizationMode,
                              ),
                              const SizedBox(height: 18),
                              selected.screen,
                              const SizedBox(height: 32),
                            ],
                          ),
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

class _ConnectedDestination {
  const _ConnectedDestination({
    required this.label,
    required this.group,
    required this.icon,
    required this.screen,
  });

  final String label;
  final String group;
  final IconData icon;
  final Widget screen;
}

class _ConnectedNavigation extends StatelessWidget {
  const _ConnectedNavigation({
    required this.session,
    required this.destinations,
    required this.selectedIndex,
    required this.palette,
    required this.onSelected,
    required this.onToggleTheme,
    required this.onSignOut,
    required this.darkMode,
  });

  final AppSession session;
  final List<_ConnectedDestination> destinations;
  final int selectedIndex;
  final _ConnectedPalette palette;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const _ConnectedLogo(size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.role.canManageOrganization
                          ? session.organizationName
                          : 'Sports Terminal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      session.role.canManageOrganization
                          ? 'Organization operating terminal'
                          : 'Individual operating terminal',
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: palette.line, height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: destinations.length,
            itemBuilder: (context, index) {
              final destination = destinations[index];
              final showGroup = index == 0 ||
                  destinations[index - 1].group != destination.group;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showGroup)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                      child: Text(
                        destination.group.toUpperCase(),
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  Material(
                    color: selectedIndex == index
                        ? palette.selected
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              destination.icon,
                              size: 19,
                              color: selectedIndex == index
                                  ? _blue
                                  : palette.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                destination.label,
                                style: TextStyle(
                                  color: selectedIndex == index
                                      ? palette.text
                                      : palette.muted,
                                  fontWeight: selectedIndex == index
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Divider(color: palette.line, height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: palette.soft,
                    child: Text(
                      session.displayName.isEmpty
                          ? 'U'
                          : session.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: _orange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          session.role.label,
                          style: TextStyle(color: palette.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onToggleTheme,
                      icon: Icon(
                        darkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                      ),
                      label: Text(darkMode ? 'Light' : 'Dark'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectedPageHeader extends StatelessWidget {
  const _ConnectedPageHeader({
    required this.destination,
    required this.palette,
    required this.organizationMode,
  });

  final _ConnectedDestination destination;
  final _ConnectedPalette palette;
  final bool organizationMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: palette.soft,
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(destination.icon, color: _blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination.label,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                organizationMode
                    ? 'Organization workspace · ${destination.group}'
                    : 'Personal workspace · ${destination.group}',
                style: TextStyle(color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectedLogo extends StatelessWidget {
  const _ConnectedLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_orange, _blue]),
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        child: const Icon(Icons.sports_basketball_rounded, color: Colors.white),
      );
}

class _ConnectedPalette {
  const _ConnectedPalette(this.darkMode);
  final bool darkMode;

  Color get background => darkMode ? _darkBackground : _lightBackground;
  Color get panel => darkMode ? const Color(0xFF0E1A2B) : Colors.white;
  Color get text =>
      darkMode ? const Color(0xFFF7FAFF) : const Color(0xFF102033);
  Color get muted =>
      darkMode ? const Color(0xFFA9B6C8) : const Color(0xFF667085);
  Color get line =>
      darkMode ? const Color(0xFF23324A) : const Color(0xFFE3E8F0);
  Color get soft =>
      darkMode ? const Color(0xFF16253A) : const Color(0xFFF2F6FC);
  Color get selected =>
      darkMode ? const Color(0xFF17335D) : const Color(0xFFEAF2FF);
}
