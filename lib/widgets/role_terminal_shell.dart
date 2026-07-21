import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/excel_like_workspace_screen.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_arena_home_screen.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_front_office_scenario_screen.dart';
import '../screens/product_nba_entity_hub_screen.dart';
import '../screens/product_nba_stats_center_screen.dart';
import '../screens/product_profile_persisted_screen.dart';
import '../screens/product_python_dev_lab_screen.dart';
import '../screens/product_role_operations_screen.dart';
import '../screens/product_shell_screens.dart';
import '../screens/product_trade_machine_screen.dart';
import '../services/product_local_store.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _light = Color(0xFFF5F7FB);
const _dark = Color(0xFF07111F);

class RoleTerminalShell extends StatefulWidget {
  const RoleTerminalShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<RoleTerminalShell> createState() => _RoleTerminalShellState();
}

class _RoleTerminalShellState extends State<RoleTerminalShell> {
  final ProductLocalStore store = const ProductLocalStore();
  int selectedIndex = 0;
  bool darkMode = false;

  bool get organizationMode => widget.session.role.canManageOrganization;

  List<_Destination> get destinations => [
        _Destination(
          label: organizationMode ? 'Organization' : 'My Work',
          group: organizationMode ? 'Organization' : 'Personal',
          icon: organizationMode
              ? Icons.corporate_fare_rounded
              : Icons.space_dashboard_rounded,
          screen: ProductRoleOperationsScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        _Destination(
          label: 'Home',
          group: 'Product',
          icon: Icons.home_rounded,
          screen: ProductArenaHomeScreen(session: widget.session),
        ),
        const _Destination(
          label: 'Stats',
          group: 'NBA',
          icon: Icons.leaderboard_rounded,
          screen: ProductNbaStatsCenterScreen(),
        ),
        const _Destination(
          label: 'NBA Hub',
          group: 'NBA',
          icon: Icons.sports_basketball_rounded,
          screen: ProductNbaEntityHubScreen(),
        ),
        const _Destination(
          label: 'Advanced',
          group: 'NBA',
          icon: Icons.analytics_rounded,
          screen: ProductAdvancedNbaToolsScreen(),
        ),
        const _Destination(
          label: 'Trade Machine',
          group: 'Transactions',
          icon: Icons.swap_horiz_rounded,
          screen: ProductTradeMachineScreen(),
        ),
        const _Destination(
          label: 'Front Office',
          group: 'Transactions',
          icon: Icons.account_tree_rounded,
          screen: ProductFrontOfficeScenarioScreen(),
        ),
        const _Destination(
          label: 'Workspace',
          group: 'Tools',
          icon: Icons.grid_on_rounded,
          screen: ProductWorkspaceHubScreen(
            workspace: ExcelLikeWorkspaceScreen(),
          ),
        ),
        const _Destination(
          label: 'Python Lab',
          group: 'Tools',
          icon: Icons.code_rounded,
          screen: ProductPythonDevLabScreen(),
        ),
        if (organizationMode)
          _Destination(
            label: 'Organization Admin',
            group: 'Organization',
            icon: Icons.admin_panel_settings_rounded,
            screen: ProductAdminOpsCenterScreen(session: widget.session),
          ),
        const _Destination(
          label: 'Articles',
          group: 'Network',
          icon: Icons.article_rounded,
          screen: ProductArticlesArenaScreen(),
        ),
        const _Destination(
          label: 'Messages',
          group: 'Network',
          icon: Icons.chat_bubble_rounded,
          screen: ProductMessagesArenaScreen(),
        ),
        _Destination(
          label: 'Profile',
          group: 'Account',
          icon: Icons.person_rounded,
          screen: ProductPersistedProfileScreen(session: widget.session),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final value = await store.loadBool(ProductLocalStore.darkModeKey);
    if (!mounted) return;
    setState(() => darkMode = value);
  }

  Future<void> _toggleTheme() async {
    final value = !darkMode;
    setState(() => darkMode = value);
    await store.saveBool(ProductLocalStore.darkModeKey, value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Palette(darkMode);
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
                    title: Text(
                      organizationMode
                          ? widget.session.organizationName
                          : 'Sports Terminal',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    actions: [
                      IconButton(
                        onPressed: _toggleTheme,
                        icon: Icon(darkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded),
                      ),
                      IconButton(
                        onPressed: widget.onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ],
                  )
                : null,
            drawer: compact
                ? Drawer(
                    child: SafeArea(
                      child: _Navigation(
                        session: widget.session,
                        destinations: items,
                        selectedIndex: selectedIndex,
                        palette: palette,
                        onSelected: (index) {
                          setState(() => selectedIndex = index);
                          Navigator.of(context).pop();
                        },
                        onToggleTheme: _toggleTheme,
                        onSignOut: widget.onSignOut,
                      ),
                    ),
                  )
                : null,
            body: Row(
              children: [
                if (!compact)
                  SizedBox(
                    width: 270,
                    child: ColoredBox(
                      color: palette.panel,
                      child: SafeArea(
                        child: _Navigation(
                          session: widget.session,
                          destinations: items,
                          selectedIndex: selectedIndex,
                          palette: palette,
                          onSelected: (index) =>
                              setState(() => selectedIndex = index),
                          onToggleTheme: _toggleTheme,
                          onSignOut: widget.onSignOut,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(compact ? 16 : 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1380),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PageHeader(
                              destination: selected,
                              palette: palette,
                              organizationMode: organizationMode,
                            ),
                            const SizedBox(height: 18),
                            selected.screen,
                            const SizedBox(height: 30),
                          ],
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
    required this.group,
    required this.icon,
    required this.screen,
  });

  final String label;
  final String group;
  final IconData icon;
  final Widget screen;
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.session,
    required this.destinations,
    required this.selectedIndex,
    required this.palette,
    required this.onSelected,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  final AppSession session;
  final List<_Destination> destinations;
  final int selectedIndex;
  final _Palette palette;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_orange, _blue]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sports_basketball_rounded,
                  color: Colors.white,
                ),
              ),
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
                          ? 'Organization terminal'
                          : 'Individual terminal',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                      ),
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
              final item = destinations[index];
              final showGroup = index == 0 ||
                  destinations[index - 1].group != item.group;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showGroup)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                      child: Text(
                        item.group.toUpperCase(),
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
                              item.icon,
                              size: 19,
                              color: selectedIndex == index
                                  ? _blue
                                  : palette.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.label,
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
                    child: Text(session.displayName.isEmpty
                        ? 'U'
                        : session.displayName[0].toUpperCase()),
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
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 11,
                          ),
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
                      icon: const Icon(Icons.contrast_rounded),
                      label: const Text('Theme'),
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

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.destination,
    required this.palette,
    required this.organizationMode,
  });

  final _Destination destination;
  final _Palette palette;
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line),
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

class _Palette {
  const _Palette(this.darkMode);
  final bool darkMode;

  Color get background => darkMode ? _dark : _light;
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
