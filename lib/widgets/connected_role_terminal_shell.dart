import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_backend_sync_screen.dart';
import '../screens/product_connected_data_studio_screen.dart';
import '../screens/product_connected_network_screens.dart';
import '../screens/product_connected_transaction_screens.dart';
import '../screens/product_connected_workspace_screen.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_fantasy_community_screens.dart';
import '../screens/product_front_office_registry_screen.dart';
import '../screens/product_nba_entity_hub_screen.dart';
import '../screens/product_nba_stats_center_screen.dart';
import '../screens/product_profile_persisted_screen.dart';
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
  final ProductLocalStore store = const ProductLocalStore();
  final TextEditingController searchController = TextEditingController();
  int selectedIndex = 0;
  bool darkMode = false;
  String search = '';

  bool get organizationMode => widget.session.role.canManageOrganization;

  List<_TerminalDestination> get destinations => [
        _TerminalDestination(
          label: organizationMode ? 'Organization' : 'My Work',
          group: organizationMode ? 'Organization' : 'Personal',
          icon: organizationMode
              ? Icons.corporate_fare_rounded
              : Icons.space_dashboard_rounded,
          description: organizationMode
              ? 'Shared case queue, approvals and operating activity.'
              : 'Personal case queue, assignments and saved work.',
          screen: ProductTransactionCommandCenterScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        _TerminalDestination(
          label: 'Home',
          group: 'Product',
          icon: Icons.home_rounded,
          description: 'Your launch dashboard and active NBA operating context.',
          screen: ProductRoleHomeScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        const _TerminalDestination(
          label: 'Stats',
          group: 'NBA',
          icon: Icons.leaderboard_rounded,
          description: 'Search, rank and compare connected NBA statistics.',
          screen: ProductNbaStatsCenterScreen(),
        ),
        const _TerminalDestination(
          label: 'NBA Hub',
          group: 'NBA',
          icon: Icons.sports_basketball_rounded,
          description: 'Players, teams, games and linked NBA entities.',
          screen: ProductNbaEntityHubScreen(),
        ),
        const _TerminalDestination(
          label: 'Advanced',
          group: 'NBA',
          icon: Icons.analytics_rounded,
          description: 'Advanced metrics, lineup and decision-support tools.',
          screen: ProductAdvancedNbaToolsScreen(),
        ),
        _TerminalDestination(
          label: 'Trade Machine',
          group: 'Front Office',
          icon: Icons.swap_horiz_rounded,
          description: 'Model multi-team salary, apron and approval scenarios.',
          screen: ProductConnectedTradeMachineScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        _TerminalDestination(
          label: 'Front Office',
          group: 'Front Office',
          icon: Icons.account_tree_rounded,
          description: 'Build cap and roster scenarios from connected cases.',
          screen: ProductConnectedFrontOfficeScreen(
            session: widget.session,
            organizationMode: organizationMode,
          ),
        ),
        _TerminalDestination(
          label: 'Contracts & Assets',
          group: 'Front Office',
          icon: Icons.inventory_2_rounded,
          description: 'Versioned contracts, cap positions, picks and ledger.',
          screen: ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        _TerminalDestination(
          label: 'Workspace',
          group: 'Tools',
          icon: Icons.grid_on_rounded,
          description: 'Multi-sheet modeling, formulas, imports and versions.',
          screen: ProductConnectedWorkspaceScreen(session: widget.session),
        ),
        _TerminalDestination(
          label: 'Python Lab',
          group: 'Tools',
          icon: Icons.code_rounded,
          description: 'Run routed datasets in the bounded Python runtime.',
          screen: ProductConnectedDataStudioScreen(session: widget.session),
        ),
        if (organizationMode)
          _TerminalDestination(
            label: 'Organization Admin',
            group: 'Organization',
            icon: Icons.admin_panel_settings_rounded,
            description: 'Manage organization members and operating controls.',
            screen: ProductAdminOpsCenterScreen(session: widget.session),
          ),
        if (organizationMode)
          _TerminalDestination(
            label: 'Trust & Safety',
            group: 'Organization',
            icon: Icons.shield_rounded,
            description: 'Review reports, apply actions and inspect audit events.',
            screen: ProductTrustSafetyConsoleScreen(session: widget.session),
          ),
        const _TerminalDestination(
          label: 'Strategy',
          group: 'Product',
          icon: Icons.radar_rounded,
          description: 'Product priorities, launch dependencies and roadmap.',
          screen: ProductStrategyMapScreen(),
        ),
        const _TerminalDestination(
          label: 'Fantasy',
          group: 'Product',
          icon: Icons.bolt_rounded,
          description: 'Fantasy watchlists and connected NBA target analysis.',
          screen: ProductFantasyWarRoomScreen(),
        ),
        const _TerminalDestination(
          label: 'Team Blogs',
          group: 'Content',
          icon: Icons.newspaper_rounded,
          description: 'Team-focused editorial and data context.',
          screen: ProductTeamBlogsScreen(),
        ),
        _TerminalDestination(
          label: 'Community',
          group: 'Network',
          icon: Icons.forum_rounded,
          description: 'Moderated threads, replies, reports, blocks and mutes.',
          screen: ProductConnectedCommunityScreen(session: widget.session),
        ),
        const _TerminalDestination(
          label: 'Articles',
          group: 'Network',
          icon: Icons.article_rounded,
          description: 'Long-form sports analysis and publishing surfaces.',
          screen: ProductArticlesArenaScreen(),
        ),
        _TerminalDestination(
          label: 'Messages',
          group: 'Network',
          icon: Icons.chat_bubble_rounded,
          description: 'Membership-protected, block-aware conversations.',
          screen: ProductConnectedMessagesScreen(session: widget.session),
        ),
        if (organizationMode)
          _TerminalDestination(
            label: 'Backend',
            group: 'Organization',
            icon: Icons.cloud_sync_rounded,
            description: 'Backend connectivity, state and synchronization tools.',
            screen: ProductBackendSyncScreen(session: widget.session),
          ),
        if (organizationMode)
          const _TerminalDestination(
            label: 'Internal Lab',
            group: 'Organization',
            icon: Icons.science_rounded,
            description: 'Internal product experiments and operating diagnostics.',
            screen: ProductInternalLabScreen(),
          ),
        _TerminalDestination(
          label: 'Profile',
          group: 'Account',
          icon: Icons.person_rounded,
          description: 'Account, identity and saved preference controls.',
          screen: ProductPersistedProfileScreen(session: widget.session),
        ),
        const _TerminalDestination(
          label: 'About Us',
          group: 'Legal',
          icon: Icons.info_outline_rounded,
          description: 'Sports Terminal mission and product information.',
          screen: ProductLegalScreen(kind: 'about'),
        ),
        const _TerminalDestination(
          label: 'Contact',
          group: 'Legal',
          icon: Icons.mail_outline_rounded,
          description: 'Contact and customer support information.',
          screen: ProductLegalScreen(kind: 'contact'),
        ),
        const _TerminalDestination(
          label: 'Privacy Policy',
          group: 'Legal',
          icon: Icons.privacy_tip_outlined,
          description: 'Privacy disclosures and data-use boundaries.',
          screen: ProductLegalScreen(kind: 'privacy'),
        ),
        const _TerminalDestination(
          label: 'Terms & Conditions',
          group: 'Legal',
          icon: Icons.description_outlined,
          description: 'Platform terms and customer responsibilities.',
          screen: ProductLegalScreen(kind: 'terms'),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
    setState(() {
      selectedIndex = index;
      search = '';
      searchController.clear();
    });
    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _selectDestination(_TerminalDestination destination) {
    final index = destinations.indexOf(destination);
    if (index >= 0) _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _TerminalPalette(darkMode);
    final items = destinations;
    if (selectedIndex >= items.length) selectedIndex = 0;
    final selected = items[selectedIndex];
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: darkMode ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _blue,
          brightness: darkMode ? Brightness.dark : Brightness.light,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1020;
          return Scaffold(
            backgroundColor: palette.background,
            appBar: compact
                ? AppBar(
                    backgroundColor: palette.panel,
                    foregroundColor: palette.text,
                    title: Row(
                      children: [
                        const _TerminalLogo(size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            organizationMode
                                ? widget.session.organizationName
                                : 'Sports Terminal',
                            maxLines: 1,
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
                      child: _TerminalNavigation(
                        session: widget.session,
                        destinations: items,
                        selectedIndex: selectedIndex,
                        palette: palette,
                        search: search,
                        searchController: searchController,
                        onSearch: (value) => setState(() => search = value),
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
                    width: 288,
                    child: ColoredBox(
                      color: palette.panel,
                      child: SafeArea(
                        child: _TerminalNavigation(
                          session: widget.session,
                          destinations: items,
                          selectedIndex: selectedIndex,
                          palette: palette,
                          search: search,
                          searchController: searchController,
                          onSearch: (value) => setState(() => search = value),
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
                          constraints: const BoxConstraints(maxWidth: 1420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TerminalPageHeader(
                                destination: selected,
                                palette: palette,
                                organizationMode: organizationMode,
                                onQuickOpen: _selectDestination,
                                destinations: items,
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

class _TerminalDestination {
  const _TerminalDestination({
    required this.label,
    required this.group,
    required this.icon,
    required this.description,
    required this.screen,
  });

  final String label;
  final String group;
  final IconData icon;
  final String description;
  final Widget screen;
}

class _TerminalNavigation extends StatelessWidget {
  const _TerminalNavigation({
    required this.session,
    required this.destinations,
    required this.selectedIndex,
    required this.palette,
    required this.search,
    required this.searchController,
    required this.onSearch,
    required this.onSelected,
    required this.onToggleTheme,
    required this.onSignOut,
    required this.darkMode,
  });

  final AppSession session;
  final List<_TerminalDestination> destinations;
  final int selectedIndex;
  final _TerminalPalette palette;
  final String search;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onSelected;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final normalized = search.trim().toLowerCase();
    final visible = <MapEntry<int, _TerminalDestination>>[
      for (var index = 0; index < destinations.length; index++)
        if (normalized.isEmpty ||
            '${destinations[index].label} ${destinations[index].group} ${destinations[index].description}'
                .toLowerCase()
                .contains(normalized))
          MapEntry(index, destinations[index]),
    ];
    String? lastGroup;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const _TerminalLogo(size: 44),
              const SizedBox(width: 11),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            style: TextStyle(color: palette.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Find a terminal function...',
              hintStyle: TextStyle(color: palette.muted),
              prefixIcon: Icon(Icons.search_rounded, color: palette.muted),
              suffixIcon: search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        onSearch('');
                      },
                      icon: Icon(Icons.close_rounded, color: palette.muted),
                    ),
              filled: true,
              fillColor: palette.search,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No terminal function matches “$search”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.muted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                  children: [
                    for (final entry in visible) ...[
                      if (lastGroup != entry.value.group)
                        Builder(
                          builder: (context) {
                            lastGroup = entry.value.group;
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(10, 14, 10, 5),
                              child: Text(
                                entry.value.group.toUpperCase(),
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            );
                          },
                        ),
                      _NavigationItem(
                        destination: entry.value,
                        selected: entry.key == selectedIndex,
                        palette: palette,
                        onTap: () => onSelected(entry.key),
                      ),
                    ],
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.line)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _blue,
                    child: Text(
                      session.displayName.isEmpty
                          ? 'ST'
                          : session.displayName
                              .split(' ')
                              .take(2)
                              .map((part) => part.isEmpty ? '' : part[0])
                              .join()
                              .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
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
                  IconButton(
                    tooltip: darkMode ? 'Use light mode' : 'Use dark mode',
                    onPressed: onToggleTheme,
                    icon: Icon(
                      darkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: palette.muted,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: onSignOut,
                    icon: Icon(Icons.logout_rounded, color: palette.muted),
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

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final _TerminalDestination destination;
  final bool selected;
  final _TerminalPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Material(
          color: selected ? palette.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    size: 20,
                    color: selected ? _blue : palette.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: TextStyle(
                        color: selected ? palette.text : palette.muted,
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: _blue,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TerminalPageHeader extends StatelessWidget {
  const _TerminalPageHeader({
    required this.destination,
    required this.palette,
    required this.organizationMode,
    required this.onQuickOpen,
    required this.destinations,
  });

  final _TerminalDestination destination;
  final _TerminalPalette palette;
  final bool organizationMode;
  final ValueChanged<_TerminalDestination> onQuickOpen;
  final List<_TerminalDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final quick = destinations.where((item) {
      return const {
        'Trade Machine',
        'Contracts & Assets',
        'Workspace',
        'Python Lab',
      }.contains(item.label);
    }).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(destination.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.label,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  destination.description,
                  style: TextStyle(color: palette.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<_TerminalDestination>(
            tooltip: 'Quick open',
            onSelected: onQuickOpen,
            itemBuilder: (context) => [
              for (final item in quick)
                PopupMenuItem(
                  value: item,
                  child: ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    subtitle: Text(item.description),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: palette.selected,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: _blue, size: 18),
                  const SizedBox(width: 7),
                  Text(
                    organizationMode ? 'Organization tools' : 'Quick open',
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, color: _blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalLogo extends StatelessWidget {
  const _TerminalLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_blue, _orange],
          ),
          borderRadius: BorderRadius.circular(size * .28),
        ),
        alignment: Alignment.center,
        child: Text(
          'ST',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * .34,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _TerminalPalette {
  const _TerminalPalette(this.dark);
  final bool dark;

  Color get background => dark ? _darkBackground : _lightBackground;
  Color get panel => dark ? const Color(0xFF0C1727) : Colors.white;
  Color get card => dark ? const Color(0xFF101D2E) : Colors.white;
  Color get search => dark ? const Color(0xFF142338) : const Color(0xFFF1F4F8);
  Color get selected => dark ? const Color(0xFF172B46) : const Color(0xFFEFF6FF);
  Color get text => dark ? const Color(0xFFF3F6FA) : const Color(0xFF102033);
  Color get muted => dark ? const Color(0xFFA8B3C3) : const Color(0xFF667085);
  Color get line => dark ? const Color(0xFF24364F) : const Color(0xFFE3E8F0);
}
