import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/excel_like_workspace_screen.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_arena_home_screen.dart';
import '../screens/product_backend_sync_screen.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_fantasy_community_screens.dart';
import '../screens/product_front_office_scenario_screen.dart';
import '../screens/product_nba_entity_hub_screen.dart';
import '../screens/product_nba_stats_center_screen.dart';
import '../screens/product_profile_persisted_screen.dart';
import '../screens/product_python_dev_lab_screen.dart';
import '../screens/product_shell_screens.dart';
import '../screens/product_strategy_map_screen.dart';
import '../screens/product_team_blogs_screen.dart';
import '../screens/product_trade_machine_screen.dart';
import '../services/product_local_store.dart';

const _lightBackground = Color(0xFFF5F7FB);
const _darkBackground = Color(0xFF07111F);
const _navy = Color(0xFF102A56);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);

class UserTerminalShell extends StatefulWidget {
  const UserTerminalShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<UserTerminalShell> createState() => _UserTerminalShellState();
}

class _UserTerminalShellState extends State<UserTerminalShell> {
  final ProductLocalStore localStore = const ProductLocalStore();

  int selectedIndex = 0;
  bool darkMode = false;

  List<_TerminalDestination> get destinations => [
        _TerminalDestination(
          label: 'Home',
          group: 'Product',
          icon: Icons.home_rounded,
          screen: ProductArenaHomeScreen(session: widget.session),
        ),
        const _TerminalDestination(
          label: 'Stats',
          group: 'NBA',
          icon: Icons.leaderboard_rounded,
          screen: ProductNbaStatsCenterScreen(),
        ),
        const _TerminalDestination(
          label: 'NBA',
          group: 'NBA',
          icon: Icons.sports_basketball_rounded,
          screen: ProductNbaEntityHubScreen(),
        ),
        const _TerminalDestination(
          label: 'Trade Machine',
          group: 'Front Office',
          icon: Icons.swap_horiz_rounded,
          screen: ProductTradeMachineScreen(),
        ),
        const _TerminalDestination(
          label: 'Advanced',
          group: 'NBA',
          icon: Icons.analytics_rounded,
          screen: ProductAdvancedNbaToolsScreen(),
        ),
        const _TerminalDestination(
          label: 'Front Office',
          group: 'Front Office',
          icon: Icons.account_tree_rounded,
          screen: ProductFrontOfficeScenarioScreen(),
        ),
        const _TerminalDestination(
          label: 'Strategy',
          group: 'Product',
          icon: Icons.radar_rounded,
          screen: ProductStrategyMapScreen(),
        ),
        const _TerminalDestination(
          label: 'Fantasy',
          group: 'Product',
          icon: Icons.bolt_rounded,
          screen: ProductFantasyWarRoomScreen(),
        ),
        const _TerminalDestination(
          label: 'Team Blogs',
          group: 'Content',
          icon: Icons.newspaper_rounded,
          screen: ProductTeamBlogsScreen(),
        ),
        const _TerminalDestination(
          label: 'Community',
          group: 'Product',
          icon: Icons.forum_rounded,
          screen: ProductCommunityArenaScreen(),
        ),
        const _TerminalDestination(
          label: 'Articles',
          group: 'Content',
          icon: Icons.article_rounded,
          screen: ProductArticlesArenaScreen(),
        ),
        const _TerminalDestination(
          label: 'Workspace',
          group: 'Tools',
          icon: Icons.grid_on_rounded,
          screen: ProductWorkspaceHubScreen(
            workspace: ExcelLikeWorkspaceScreen(),
          ),
        ),
        const _TerminalDestination(
          label: 'Python Lab',
          group: 'Tools',
          icon: Icons.code_rounded,
          screen: ProductPythonDevLabScreen(),
        ),
        const _TerminalDestination(
          label: 'Messages',
          group: 'Product',
          icon: Icons.chat_bubble_rounded,
          screen: ProductMessagesArenaScreen(),
        ),
        _TerminalDestination(
          label: 'Profile',
          group: 'Product',
          icon: Icons.person_rounded,
          screen: ProductPersistedProfileScreen(session: widget.session),
        ),
        _TerminalDestination(
          label: 'Admin',
          group: 'Operator',
          icon: Icons.admin_panel_settings_rounded,
          screen: ProductAdminOpsCenterScreen(session: widget.session),
        ),
        _TerminalDestination(
          label: 'Backend',
          group: 'Operator',
          icon: Icons.cloud_sync_rounded,
          screen: ProductBackendSyncScreen(session: widget.session),
          primary: false,
        ),
        const _TerminalDestination(
          label: 'Internal Lab',
          group: 'Operator',
          icon: Icons.science_rounded,
          screen: ProductInternalLabScreen(),
          primary: false,
        ),
        const _TerminalDestination(
          label: 'About Us',
          group: 'Legal',
          icon: Icons.info_outline_rounded,
          screen: ProductLegalScreen(kind: 'about'),
          primary: false,
        ),
        const _TerminalDestination(
          label: 'Contact',
          group: 'Legal',
          icon: Icons.mail_outline_rounded,
          screen: ProductLegalScreen(kind: 'contact'),
          primary: false,
        ),
        const _TerminalDestination(
          label: 'Privacy Policy',
          group: 'Legal',
          icon: Icons.privacy_tip_outlined,
          screen: ProductLegalScreen(kind: 'privacy'),
          primary: false,
        ),
        const _TerminalDestination(
          label: 'Terms & Conditions',
          group: 'Legal',
          icon: Icons.description_outlined,
          screen: ProductLegalScreen(kind: 'terms'),
          primary: false,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await localStore.loadBool(ProductLocalStore.darkModeKey);
    if (!mounted) return;
    setState(() => darkMode = saved);
  }

  Future<void> _toggleTheme() async {
    final next = !darkMode;
    setState(() => darkMode = next);
    await localStore.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(int index, {bool closeDrawer = false}) {
    if (index < 0 || index >= destinations.length) return;
    setState(() => selectedIndex = index);
    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _selectLabel(String label) {
    final index = destinations.indexWhere((item) => item.label == label);
    if (index >= 0) _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final items = destinations;
    if (selectedIndex >= items.length) selectedIndex = 0;
    final selected = items[selectedIndex];
    final palette = _ShellPalette(darkMode);

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
                    title: const Row(
                      children: [
                        _LogoMark(size: 34),
                        SizedBox(width: 10),
                        Text(
                          'Sports Terminal',
                          style: TextStyle(fontWeight: FontWeight.w900),
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
                      child: _NavigationList(
                        destinations: items,
                        selectedIndex: selectedIndex,
                        palette: palette,
                        session: widget.session,
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
                    width: 260,
                    child: ColoredBox(
                      color: palette.panel,
                      child: SafeArea(
                        child: _NavigationList(
                          destinations: items,
                          selectedIndex: selectedIndex,
                          palette: palette,
                          session: widget.session,
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
                      padding: EdgeInsets.fromLTRB(
                        compact ? 16 : 28,
                        compact ? 18 : 28,
                        compact ? 16 : 28,
                        0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PageHeader(
                                destination: selected,
                                palette: palette,
                              ),
                              const SizedBox(height: 18),
                              selected.screen,
                              _Footer(
                                palette: palette,
                                onOpenAbout: () => _selectLabel('About Us'),
                                onOpenContact: () => _selectLabel('Contact'),
                                onOpenPrivacy: () => _selectLabel('Privacy Policy'),
                                onOpenTerms: () =>
                                    _selectLabel('Terms & Conditions'),
                              ),
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

class _TerminalDestination {
  const _TerminalDestination({
    required this.label,
    required this.group,
    required this.icon,
    required this.screen,
    this.primary = true,
  });

  final String label;
  final String group;
  final IconData icon;
  final Widget screen;
  final bool primary;
}

class _NavigationList extends StatelessWidget {
  const _NavigationList({
    required this.destinations,
    required this.selectedIndex,
    required this.palette,
    required this.session,
    required this.onSelected,
    required this.onToggleTheme,
    required this.onSignOut,
    required this.darkMode,
  });

  final List<_TerminalDestination> destinations;
  final int selectedIndex;
  final _ShellPalette palette;
  final AppSession session;
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
              const _LogoMark(size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sports Terminal',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'NBA-first intelligence',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            itemCount: destinations.length,
            itemBuilder: (context, index) {
              final item = destinations[index];
              final previousGroup = index == 0
                  ? null
                  : destinations[index - 1].group;
              final showGroup = previousGroup != item.group;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showGroup)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Text(
                        item.group.toUpperCase(),
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  _NavigationTile(
                    destination: item,
                    selected: selectedIndex == index,
                    palette: palette,
                    onTap: () => onSelected(index),
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
                    radius: 17,
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
                            fontSize: 12,
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
                      icon: Icon(
                        darkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 18,
                      ),
                      label: Text(darkMode ? 'Light' : 'Dark'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
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

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.destination,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final _TerminalDestination destination;
  final bool selected;
  final _ShellPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? palette.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 19,
                  color: selected ? _blue : palette.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destination.label,
                    style: TextStyle(
                      color: selected ? palette.text : palette.muted,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
                if (!destination.primary)
                  Icon(
                    Icons.more_horiz_rounded,
                    color: palette.muted,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.destination, required this.palette});

  final _TerminalDestination destination;
  final _ShellPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line),
          ),
          child: Icon(destination.icon, color: _blue, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination.label == 'Home'
                    ? 'Dashboard'
                    : destination.label,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                destination.group,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.palette,
    required this.onOpenAbout,
    required this.onOpenContact,
    required this.onOpenPrivacy,
    required this.onOpenTerms,
  });

  final _ShellPalette palette;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenContact;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 18,
        children: [
          SizedBox(
            width: 480,
            child: Text(
              'Sports Terminal is an NBA-first sports intelligence, fantasy, community, workspace, trade, and development platform under active development.',
              style: TextStyle(
                color: palette.muted,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              TextButton(onPressed: onOpenAbout, child: const Text('About Us')),
              TextButton(
                onPressed: onOpenContact,
                child: const Text('Contact the Team'),
              ),
              TextButton(
                onPressed: onOpenPrivacy,
                child: const Text('Privacy Policy'),
              ),
              TextButton(
                onPressed: onOpenTerms,
                child: const Text('Terms & Conditions'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_orange, _blue]),
        borderRadius: BorderRadius.circular(size * 0.35),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FF7A1A),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: const Icon(Icons.sports_basketball_rounded, color: Colors.white),
    );
  }
}

class _ShellPalette {
  const _ShellPalette(this.darkMode);

  final bool darkMode;

  Color get background => darkMode ? _darkBackground : _lightBackground;
  Color get panel => darkMode ? const Color(0xFF0E1A2B) : Colors.white;
  Color get text => darkMode ? const Color(0xFFF7FAFF) : const Color(0xFF102033);
  Color get muted => darkMode ? const Color(0xFFA9B6C8) : const Color(0xFF667085);
  Color get line => darkMode ? const Color(0xFF23324A) : const Color(0xFFE3E8F0);
  Color get soft => darkMode ? const Color(0xFF16253A) : const Color(0xFFF2F6FC);
  Color get selected => darkMode ? const Color(0xFF17335D) : const Color(0xFFEAF2FF);
}
