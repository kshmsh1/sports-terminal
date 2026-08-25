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
                  padding: const EdgeInsets.fromLTRB(12, 34, 12, 72),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1580),
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
    final primary = nbaItems.take(4).toList();
    final moreItems = [...nbaItems.skip(4), ...secondary];
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Text('ST', style: TextStyle(color: colors.onPrimaryContainer, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            const Text('Sports Terminal', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(width: 30),
            for (final item in primary)
              _HeaderButton(
                label: item.label,
                selected: item.id == selectedId,
                onTap: () => onSelect(item.id),
              ),
            const Spacer(),
            SizedBox(
              width: 230,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Align(alignment: Alignment.centerLeft, child: Text('Search players & teams')),
              ),
            ),
            const SizedBox(width: 10),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value.startsWith('future:')) return;
                onSelect(value);
              },
              itemBuilder: (context) => [
                for (final item in moreItems)
                  PopupMenuItem(value: item.id, child: Row(children: [Icon(item.icon, size: 18), const SizedBox(width: 10), Text(item.label)])),
                const PopupMenuDivider(),
                for (final sport in futureSports)
                  PopupMenuItem(value: 'future:$sport', enabled: false, child: Text(sport)),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(children: [Text('More'), SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_rounded, size: 18)]),
              ),
            ),
            IconButton(onPressed: onToggleTheme, icon: Icon(darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined)),
            const SizedBox(width: 4),
            CircleAvatar(radius: 18, child: Text(session.initials)),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
          textStyle: TextStyle(fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
        ),
        child: Text(label),
      );
}

class _Destination {
  const _Destination({required this.id, required this.label, required this.icon, required this.builder});
  final String id;
  final String label;
  final IconData icon;
  final Widget Function() builder;
}
