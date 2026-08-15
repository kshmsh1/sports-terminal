import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/institutional_research_hub_screen.dart';
import '../screens/product_community_v2_screen.dart';
import '../screens/product_front_office_registry_screen.dart';
import '../screens/product_profile_v3_screen.dart';
import '../screens/website_nba_advanced_stats_screen.dart';
import '../screens/website_nba_entity_pages.dart';
import '../screens/website_nba_home_dashboard.dart';
import '../screens/website_nba_stats_screen.dart';
import '../screens/website_trade_machine_screen.dart';
import '../services/product_local_store.dart';
import '../services/website_nba_api_service.dart';

const _brandBlue = Color(0xFF2563EB);

class TraditionalWebsiteShellV2 extends StatefulWidget {
  const TraditionalWebsiteShellV2({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<TraditionalWebsiteShellV2> createState() => _TraditionalWebsiteShellV2State();
}

class _TraditionalWebsiteShellV2State extends State<TraditionalWebsiteShellV2> {
  final _store = const ProductLocalStore();
  String _selected = 'home';
  bool _dark = true;

  List<_WebDestination> get _primary => [
        _WebDestination(
          id: 'home',
          label: 'Home',
          icon: Icons.home_rounded,
          builder: () => WebsiteNbaHomeDashboard(session: widget.session),
        ),
        _WebDestination(
          id: 'stats',
          label: 'Stats',
          icon: Icons.leaderboard_rounded,
          builder: () => WebsiteNbaStatsScreen(session: widget.session),
        ),
        _WebDestination(
          id: 'advanced',
          label: 'Advanced Stats',
          icon: Icons.analytics_outlined,
          builder: () => WebsiteNbaAdvancedStatsScreen(session: widget.session),
        ),
        _WebDestination(
          id: 'trade',
          label: 'Trade Machine',
          icon: Icons.swap_horiz_rounded,
          builder: () => WebsiteTradeMachineScreen(session: widget.session),
        ),
      ];

  List<_WebDestination> get _secondary => [
        _WebDestination(
          id: 'front-office',
          label: 'Front Office',
          icon: Icons.account_tree_outlined,
          builder: () => ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        _WebDestination(
          id: 'research',
          label: 'Research',
          icon: Icons.science_outlined,
          builder: () => InstitutionalResearchHubScreen(session: widget.session),
        ),
        _WebDestination(
          id: 'community',
          label: 'Community',
          icon: Icons.forum_outlined,
          builder: () => ProductCommunityV2Screen(session: widget.session),
        ),
        _WebDestination(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          builder: () => ProductProfileV3Screen(session: widget.session),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final value = await _store.loadBool(ProductLocalStore.darkModeKey, fallback: true);
    if (mounted) setState(() => _dark = value);
  }

  Future<void> _toggleTheme() async {
    final next = !_dark;
    setState(() => _dark = next);
    await _store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(String id) {
    final all = [..._primary, ..._secondary];
    if (all.any((item) => item.id == id)) setState(() => _selected = id);
  }

  @override
  Widget build(BuildContext context) {
    final all = [..._primary, ..._secondary];
    final selected = all.firstWhere((item) => item.id == _selected, orElse: () => all.first);
    final brightness = _dark ? Brightness.dark : Brightness.light;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: _brandBlue, brightness: brightness),
      scaffoldBackgroundColor: _dark ? const Color(0xFF0B111A) : const Color(0xFFF7F8FA),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _dark ? const Color(0xFF141B25) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _dark ? const Color(0xFF263241) : const Color(0xFFE5E7EB)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(fontWeight: FontWeight.w800),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _WebsiteHeader(
                session: widget.session,
                primary: _primary,
                secondary: _secondary,
                selected: _selected,
                dark: _dark,
                onSelect: _select,
                onTheme: _toggleTheme,
                onSignOut: widget.onSignOut,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 64),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
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
    required this.primary,
    required this.secondary,
    required this.selected,
    required this.dark,
    required this.onSelect,
    required this.onTheme,
    required this.onSignOut,
  });

  final AppSession session;
  final List<_WebDestination> primary;
  final List<_WebDestination> secondary;
  final String selected;
  final bool dark;
  final ValueChanged<String> onSelect;
  final VoidCallback onTheme;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1040;
            return Row(
              children: [
                InkWell(
                  onTap: () => onSelect('home'),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
                        child: const Text('ST', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 10),
                      if (constraints.maxWidth >= 620)
                        const Text('Sports Terminal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                    ],
                  ),
                ),
                if (desktop) ...[
                  const SizedBox(width: 26),
                  for (final item in primary)
                    TextButton(
                      onPressed: () => onSelect(item.id),
                      style: TextButton.styleFrom(
                        foregroundColor: selected == item.id ? colors.primary : colors.onSurfaceVariant,
                        textStyle: TextStyle(fontWeight: selected == item.id ? FontWeight.w900 : FontWeight.w600),
                      ),
                      child: Text(item.label),
                    ),
                  const Spacer(),
                  _GlobalNbaSearch(session: session),
                  const SizedBox(width: 10),
                  _MoreMenu(items: secondary, selected: selected, onSelect: onSelect),
                ] else ...[
                  const Spacer(),
                  IconButton(
                    tooltip: 'Search players and teams',
                    onPressed: () => _openSearchDialog(context, session),
                    icon: const Icon(Icons.search_rounded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Navigation',
                    onSelected: onSelect,
                    itemBuilder: (_) => [
                      for (final item in [...primary, ...secondary])
                        PopupMenuItem(
                          value: item.id,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(item.icon),
                            title: Text(item.label),
                            trailing: item.id == selected ? const Icon(Icons.check_rounded) : null,
                          ),
                        ),
                    ],
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ],
                IconButton(
                  tooltip: dark ? 'Light mode' : 'Dark mode',
                  onPressed: onTheme,
                  icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Account',
                  onSelected: (value) {
                    if (value == 'profile') onSelect('profile');
                    if (value == 'sign-out') onSignOut();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'profile', child: Text('Profile')),
                    PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
                  ],
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: colors.primaryContainer,
                    child: Text(_initials(session.displayName), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
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

class _GlobalNbaSearch extends StatelessWidget {
  const _GlobalNbaSearch({required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 225,
        height: 40,
        child: OutlinedButton.icon(
          onPressed: () => _openSearchDialog(context, session),
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Align(alignment: Alignment.centerLeft, child: Text('Search players & teams')),
        ),
      );
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.items, required this.selected, required this.onSelect});
  final List<_WebDestination> items;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: onSelect,
        itemBuilder: (_) => [
          for (final item in items)
            PopupMenuItem(
              value: item.id,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon),
                title: Text(item.label),
                trailing: item.id == selected ? const Icon(Icons.check_rounded) : null,
              ),
            ),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text('More'), SizedBox(width: 3), Icon(Icons.expand_more_rounded, size: 18)]),
        ),
      );
}

Future<void> _openSearchDialog(BuildContext context, AppSession session) {
  return showDialog<void>(
    context: context,
    builder: (_) => _NbaSearchDialog(session: session),
  );
}

class _NbaSearchDialog extends StatefulWidget {
  const _NbaSearchDialog({required this.session});
  final AppSession session;

  @override
  State<_NbaSearchDialog> createState() => _NbaSearchDialogState();
}

class _NbaSearchDialogState extends State<_NbaSearchDialog> {
  final _api = const WebsiteNbaApiService();
  final _controller = TextEditingController();
  Future<Map<String, dynamic>>? _future;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    final query = value.trim();
    setState(() => _future = query.length < 2 ? null : _api.searchEntities(query));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Search NBA players and teams'),
        content: SizedBox(
          width: 620,
          height: 470,
          child: Column(
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Jayson Tatum, Boston Celtics…'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _future == null
                    ? const Center(child: Text('Type at least two characters.'))
                    : FutureBuilder<Map<String, dynamic>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                          if (snapshot.hasError || snapshot.data == null) return Center(child: Text('Search unavailable: ${snapshot.error}'));
                          final groups = _map(snapshot.data!['groups']);
                          final players = _maps(groups['players']);
                          final teams = _maps(groups['teams']);
                          if (players.isEmpty && teams.isEmpty) return const Center(child: Text('No matches found.'));
                          return ListView(
                            children: [
                              if (players.isNotEmpty) const _SearchSection('Players'),
                              for (final player in players)
                                ListTile(
                                  leading: const Icon(Icons.person_outline_rounded),
                                  title: Text(_text(player['canonical_name'], 'Player')),
                                  subtitle: Text([_text(player['primary_position']), _text(player['last_stat_season'])].where((item) => item.isNotEmpty).join(' · ')),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    openWebsiteNbaPlayerPage(
                                      context,
                                      session: widget.session,
                                      playerKey: _text(player['player_key']),
                                      playerName: _text(player['canonical_name'], 'Player'),
                                    );
                                  },
                                ),
                              if (teams.isNotEmpty) const _SearchSection('Teams'),
                              for (final team in teams)
                                ListTile(
                                  leading: const Icon(Icons.groups_outlined),
                                  title: Text(_text(team['canonical_name'], 'Team')),
                                  subtitle: Text(_text(team['abbreviation'])),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    openWebsiteNbaTeamPage(
                                      context,
                                      session: widget.session,
                                      teamKey: _text(team['team_key']),
                                      teamName: _text(team['canonical_name'], 'Team'),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      );
}

class _SearchSection extends StatelessWidget {
  const _SearchSection(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
      );
}

class _WebDestination {
  const _WebDestination({required this.id, required this.label, required this.icon, required this.builder});
  final String id;
  final String label;
  final IconData icon;
  final Widget Function() builder;
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
  final result = parts.map((part) => part.substring(0, 1).toUpperCase()).join();
  return result.isEmpty ? 'ST' : result;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) _map(item)];
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}
