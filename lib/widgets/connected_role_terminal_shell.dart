import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_backend_sync_screen.dart';
import '../screens/product_connected_data_studio_screen.dart';
import '../screens/product_connected_network_screens.dart';
import '../screens/product_community_v2_screen.dart';
import '../screens/product_articles_v2_screen.dart';
import '../screens/product_community_v2_screen.dart';
import '../screens/product_articles_v2_screen.dart';
import '../screens/product_connected_transaction_screens.dart';
import '../screens/product_connected_workspace_screen.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_fantasy_community_screens.dart';
import '../screens/product_front_office_registry_screen.dart';
import '../screens/product_legal_information_v2.dart';
import '../screens/product_nba_awards_screen.dart';
import '../screens/product_nba_hub_v2_screen.dart';
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
  State<ConnectedRoleTerminalShell> createState() => _ConnectedRoleTerminalShellState();
}

class _ConnectedRoleTerminalShellState extends State<ConnectedRoleTerminalShell> {
  final ProductLocalStore store = const ProductLocalStore();
  final TextEditingController searchController = TextEditingController();
  int selectedIndex = 0;
  bool darkMode = true;
  String search = '';

  bool get organizationMode => widget.session.role.canManageOrganization;

  List<_TerminalDestination> get destinations => [
        _TerminalDestination(
          label: organizationMode ? 'Organization' : 'My Work',
          group: organizationMode ? 'Organization' : 'Personal',
          icon: organizationMode ? Icons.corporate_fare_rounded : Icons.space_dashboard_rounded,
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
          description: 'Basic NBA player statistics with linked player and team pages.',
          screen: ProductNbaStatsCenterScreen(),
        ),
        const _TerminalDestination(
          label: 'Advanced Stats',
          group: 'NBA',
          icon: Icons.analytics_rounded,
          description: 'The complete source-aware metric workstation and analytics suite.',
          screen: ProductAdvancedNbaToolsScreen(),
        ),
        const _TerminalDestination(
          label: 'NBA Hub',
          group: 'NBA',
          icon: Icons.sports_basketball_rounded,
          description: 'Players, teams, standings, schedule, leaders, awards and league data.',
          screen: ProductNbaHubV2Screen(),
        ),
        const _TerminalDestination(
          label: 'Awards & Voting',
          group: 'NBA',
          icon: Icons.workspace_premium_rounded,
          description: 'Annual NBA awards, All-League honors, ballots and historical voting.',
          screen: ProductNbaAwardsScreen(),
        ),
        _TerminalDestination(
          label: 'Trade Machine',
          group: 'Front Office',
          icon: Icons.swap_horiz_rounded,
          description: 'Model multi-team salary, apron, pick, exception and approval scenarios.',
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
          description: 'A bounded notebook environment with routed NBA datasets and inline output.',
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
          description: 'Team-specific news, analysis, writers and discussion.',
          screen: ProductTeamBlogsScreen(),
        ),
        _TerminalDestination(
          label: 'Community',
          group: 'Network',
          icon: Icons.forum_rounded,
          description: 'Moderated communities, threads, comments, voting, saves and reputation.',
          screen: ProductCommunityV2Screen(session: widget.session),
        ),
        const _TerminalDestination(
          label: 'Articles',
          group: 'Content',
          icon: Icons.article_rounded,
          description: 'Multi-sport long-form reporting, analysis and editorial discovery.',
          screen: ProductArticlesV2Screen(),
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
          description: 'Identity, profile, teams, preferences, badges, security and visibility.',
          screen: ProductPersistedProfileScreen(session: widget.session),
        ),
        const _TerminalDestination(
          label: 'About Us',
          group: 'Company',
          icon: Icons.info_outline_rounded,
          description: 'Sports Terminal mission, product philosophy and company information.',
          screen: ProductLegalInformationScreen(kind: 'about'),
        ),
        const _TerminalDestination(
          label: 'Contact',
          group: 'Company',
          icon: Icons.mail_outline_rounded,
          description: 'Support, data, legal, privacy, safety, press and partnerships.',
          screen: ProductLegalInformationScreen(kind: 'contact'),
        ),
        const _TerminalDestination(
          label: 'Privacy Policy',
          group: 'Legal',
          icon: Icons.privacy_tip_outlined,
          description: 'Comprehensive privacy disclosures, rights and data-use boundaries.',
          screen: ProductLegalInformationScreen(kind: 'privacy'),
        ),
        const _TerminalDestination(
          label: 'Terms & Conditions',
          group: 'Legal',
          icon: Icons.description_outlined,
          description: 'Comprehensive platform terms, IP protection and user obligations.',
          screen: ProductLegalInformationScreen(kind: 'terms'),
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
    final saved = await store.loadBool(ProductLocalStore.darkModeKey, fallback: true);
    if (!mounted) return;
    setState(() => darkMode = saved);
  }

  Future<void> _toggleTheme() async {
    final next = !darkMode;
    setState(() => darkMode = next);
    await store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(int index) {
    if (index < 0 || index >= destinations.length) return;
    setState(() {
      selectedIndex = index;
      search = '';
      searchController.clear();
    });
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
          final compact = constraints.maxWidth < 820;
          return Scaffold(
            backgroundColor: palette.background,
            body: SafeArea(
              child: Column(
                children: [
                  _TerminalTopNavigation(
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
                  Expanded(
                    child: ColoredBox(
                      color: palette.background,
                      // The platform shell owns the vertical scroll. Product pages
                      // are expected to render document-flow content rather than
                      // independent vertically scrolling panes.
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 20,
                          compact ? 14 : 20,
                          compact ? 12 : 20,
                          48,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1680),
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
                                const SizedBox(height: 16),
                                selected.screen,
                                const SizedBox(height: 28),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

class _TerminalTopNavigation extends StatelessWidget {
  const _TerminalTopNavigation({
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
            '${destinations[index].label} ${destinations[index].group} ${destinations[index].description}'.toLowerCase().contains(normalized))
          MapEntry(index, destinations[index]),
    ];
    return Material(
      color: palette.panel,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.line))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LayoutBuilder(builder: (context, constraints) {
            final showSearch = constraints.maxWidth >= 720;
            final showIdentity = constraints.maxWidth >= 1080;
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
              child: Row(children: [
                const _TerminalLogo(size: 36),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      session.role.canManageOrganization ? session.organizationName : 'Sports Terminal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.text, fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      session.role.canManageOrganization ? 'ORGANIZATION TERMINAL' : 'SPORTS INTELLIGENCE TERMINAL',
                      style: TextStyle(color: palette.muted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .7),
                    ),
                  ]),
                ),
                if (showSearch) ...[
                  const SizedBox(width: 18),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearch,
                          style: TextStyle(color: palette.text, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Find terminal function…',
                            hintStyle: TextStyle(color: palette.muted),
                            prefixIcon: Icon(Icons.search_rounded, color: palette.muted, size: 17),
                            suffixIcon: search.isEmpty
                                ? null
                                : IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      searchController.clear();
                                      onSearch('');
                                    },
                                    icon: Icon(Icons.close_rounded, color: palette.muted, size: 16),
                                  ),
                            filled: true,
                            fillColor: palette.search,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: palette.line)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: palette.line)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (showIdentity) ...[
                  const Spacer(),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _blue,
                    child: Text(_initials(session.displayName), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(session.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.text, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
                const SizedBox(width: 6),
                IconButton(
                  tooltip: darkMode ? 'Use light mode' : 'Use dark mode',
                  onPressed: onToggleTheme,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: palette.muted, size: 18),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: onSignOut,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.logout_rounded, color: palette.muted, size: 18),
                ),
              ]),
            );
          }),
          Container(
            height: 51,
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.dark ? const Color(0xFF0A1320) : const Color(0xFFF7F9FC),
              border: Border(top: BorderSide(color: palette.line)),
            ),
            child: visible.isEmpty
                ? Center(child: Text('No terminal function matches “$search”.', style: TextStyle(color: palette.muted, fontSize: 11)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 3),
                    itemBuilder: (context, index) {
                      final entry = visible[index];
                      return _TopNavigationItem(
                        destination: entry.value,
                        selected: entry.key == selectedIndex,
                        palette: palette,
                        onTap: () => onSelected(entry.key),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _TopNavigationItem extends StatelessWidget {
  const _TopNavigationItem({required this.destination, required this.selected, required this.palette, required this.onTap});
  final _TerminalDestination destination;
  final bool selected;
  final _TerminalPalette palette;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? palette.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? _blue : Colors.transparent, width: 2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(destination.icon, size: 16, color: selected ? _blue : palette.muted),
              const SizedBox(width: 7),
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(destination.group.toUpperCase(), style: TextStyle(color: selected ? _blue : palette.muted, fontSize: 6.5, fontWeight: FontWeight.w900, letterSpacing: .55)),
                Text(destination.label, style: TextStyle(color: selected ? palette.text : palette.muted, fontSize: 10.5, fontWeight: selected ? FontWeight.w900 : FontWeight.w700)),
              ]),
            ]),
          ),
        ),
      );
}

class _TerminalPageHeader extends StatelessWidget {
  const _TerminalPageHeader({required this.destination, required this.palette, required this.organizationMode, required this.onQuickOpen, required this.destinations});
  final _TerminalDestination destination;
  final _TerminalPalette palette;
  final bool organizationMode;
  final ValueChanged<_TerminalDestination> onQuickOpen;
  final List<_TerminalDestination> destinations;
  @override
  Widget build(BuildContext context) {
    final quick = destinations.where((item) => const {'Stats', 'Advanced Stats', 'NBA Hub', 'Trade Machine', 'Workspace', 'Python Lab'}.contains(item.label)).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: palette.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_navy, _blue, _orange]), borderRadius: BorderRadius.circular(14)), child: Icon(destination.icon, color: Colors.white)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(destination.label, style: TextStyle(color: palette.text, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 5),
          Text(destination.description, style: TextStyle(color: palette.muted, height: 1.4)),
        ])),
        const SizedBox(width: 12),
        PopupMenuButton<_TerminalDestination>(
          tooltip: 'Quick open',
          onSelected: onQuickOpen,
          itemBuilder: (context) => [for (final item in quick) PopupMenuItem(value: item, child: ListTile(leading: Icon(item.icon), title: Text(item.label), subtitle: Text(item.description), contentPadding: EdgeInsets.zero))],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: palette.selected, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt_rounded, color: _blue, size: 18),
              const SizedBox(width: 7),
              Text(organizationMode ? 'Organization tools' : 'Quick open', style: TextStyle(color: palette.text, fontWeight: FontWeight.w900)),
              const Icon(Icons.arrow_drop_down_rounded, color: _blue),
            ]),
          ),
        ),
      ]),
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
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_blue, _orange]), borderRadius: BorderRadius.circular(size * .28)),
        alignment: Alignment.center,
        child: Text('ST', style: TextStyle(color: Colors.white, fontSize: size * .34, fontWeight: FontWeight.w900)),
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

String _initials(String value) => value.isEmpty ? 'ST' : value.split(' ').where((part) => part.isNotEmpty).take(2).map((part) => part[0].toUpperCase()).join();
