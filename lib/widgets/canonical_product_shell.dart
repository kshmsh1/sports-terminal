import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../screens/product_community_v2_screen.dart';
import '../screens/product_front_office_registry_screen.dart';
import '../screens/product_profile_v3_screen.dart';
import '../screens/product_trade_machine_screen.dart';
import '../screens/website_nba_advanced_stats_screen.dart';
import '../screens/website_nba_box_scores_screen.dart';
import '../screens/website_nba_entity_pages.dart';
import '../screens/website_nba_home_dashboard.dart';
import '../screens/website_nba_live_games_screen.dart';
import '../screens/website_nba_media_feed_screen.dart';
import '../screens/website_nba_player_comparison_screen.dart';
import '../screens/website_nba_research_screen.dart';
import '../screens/website_nba_stats_screen.dart';
import '../screens/website_nba_team_comparison_screen.dart';
import '../screens/website_sports_home_screen.dart';
import '../services/product_local_store.dart';
import '../services/website_nba_api_service.dart';

const _brandBlue = Color(0xFF6674C7);

/// Sole customer-facing Sports Terminal shell.
///
/// Historical NBA data is served from the local static corpus. Live scores and
/// public social embeds are isolated to the explicitly live product surfaces.
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
  final _store = const ProductLocalStore();
  String _selected = 'sports';
  bool _darkMode = true;

  List<_Destination> get _items => [
        _Destination(
          id: 'sports',
          label: 'Sports',
          icon: Icons.public_rounded,
          builder: () => WebsiteSportsHomeScreen(
            onOpenNba: () => _select('nba-home'),
          ),
        ),
        _Destination(
          id: 'nba-home',
          label: 'NBA Home',
          icon: Icons.sports_basketball_rounded,
          builder: () => WebsiteNbaHomeDashboard(session: widget.session),
        ),
        _Destination(
          id: 'stats',
          label: 'Stats',
          icon: Icons.leaderboard_rounded,
          builder: () => WebsiteNbaStatsScreen(session: widget.session),
        ),
        _Destination(
          id: 'advanced',
          label: 'Advanced Stats',
          icon: Icons.analytics_rounded,
          builder: () => WebsiteNbaAdvancedStatsScreen(session: widget.session),
        ),
        _Destination(
          id: 'player-compare',
          label: 'Player Compare',
          icon: Icons.people_alt_outlined,
          builder: () => WebsiteNbaPlayerComparisonScreen(session: widget.session),
          showInMainNav: false,
        ),
        _Destination(
          id: 'team-compare',
          label: 'Team Compare',
          icon: Icons.groups_2_outlined,
          builder: () => WebsiteNbaTeamComparisonScreen(session: widget.session),
          showInMainNav: false,
        ),
        const _Destination(
          id: 'trade',
          label: 'Trade Machine',
          icon: Icons.swap_horiz_rounded,
          builder: ProductTradeMachineScreen.new,
        ),
        const _Destination(
          id: 'live-games',
          label: 'Live Games',
          icon: Icons.sports_score_rounded,
          builder: WebsiteNbaLiveGamesScreen.new,
        ),
        const _Destination(
          id: 'box-scores',
          label: 'Box Scores',
          icon: Icons.table_rows_rounded,
          builder: WebsiteNbaBoxScoresScreen.new,
        ),
        const _Destination(
          id: 'media-feed',
          label: 'Media Feed',
          icon: Icons.dynamic_feed_rounded,
          builder: WebsiteNbaMediaFeedScreen.new,
        ),
        _Destination(
          id: 'front-office',
          label: 'Front Office',
          icon: Icons.account_tree_rounded,
          builder: () => ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        const _Destination(
          id: 'research',
          label: 'Research',
          icon: Icons.science_outlined,
          builder: WebsiteNbaResearchScreen.new,
        ),
        _Destination(
          id: 'community',
          label: 'Community',
          icon: Icons.forum_rounded,
          builder: () => ProductCommunityV2Screen(session: widget.session),
        ),
        const _Destination(
          id: 'python-lab',
          label: 'Python Lab',
          icon: Icons.code_rounded,
          enabled: false,
        ),
        const _Destination(
          id: 'excel-workspace',
          label: 'Excel Workspace',
          icon: Icons.table_chart_outlined,
          enabled: false,
        ),
        _Destination(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          builder: () => ProductProfileV3Screen(session: widget.session),
          showInMainNav: false,
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
    final next = !_darkMode;
    setState(() => _darkMode = next);
    await _store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(String id) {
    _Destination? match;
    for (final item in _items) {
      if (item.id == id) {
        match = item;
        break;
      }
    }
    if (match == null || !match.enabled || match.builder == null) return;
    setState(() => _selected = id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _items.firstWhere(
      (item) => item.id == _selected,
      orElse: () => _items.first,
    );
    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brandBlue,
        brightness: brightness,
      ),
      scaffoldBackgroundColor:
          _darkMode ? const Color(0xFF0B111A) : const Color(0xFFF7F8FA),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkMode ? const Color(0xFF141B25) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: _darkMode ? const Color(0xFF263241) : const Color(0xFFE5E7EB),
          ),
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
              _TopNav(
                session: widget.session,
                items: _items,
                selected: _selected,
                dark: _darkMode,
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
                      child: selected.builder!(),
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

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.session,
    required this.items,
    required this.selected,
    required this.dark,
    required this.onSelect,
    required this.onTheme,
    required this.onSignOut,
  });

  final AppSession session;
  final List<_Destination> items;
  final String selected;
  final bool dark;
  final ValueChanged<String> onSelect;
  final VoidCallback onTheme;
  final VoidCallback onSignOut;

  bool get _compareSelected =>
      selected == 'player-compare' || selected == 'team-compare';

  _Destination _item(String id) => items.firstWhere((item) => item.id == id);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final moreIds = <String>[
      'live-games',
      'box-scores',
      'media-feed',
      'front-office',
      'research',
      'community',
      'python-lab',
      'excel-workspace',
    ];
    final primaryIds = <String>['sports', 'nba-home', 'stats', 'advanced', 'trade'];

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            return Row(
              children: [
                InkWell(
                  onTap: () => onSelect('sports'),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'ST',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (constraints.maxWidth >= 680) ...[
                        const SizedBox(width: 10),
                        const Text(
                          'Sports Terminal',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 18),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final id in primaryIds.take(4))
                          _NavButton(
                            item: _item(id),
                            selected: selected == id,
                            onSelect: onSelect,
                          ),
                        _CompareMenu(
                          selected: _compareSelected,
                          onSelect: onSelect,
                        ),
                        _NavButton(
                          item: _item('trade'),
                          selected: selected == 'trade',
                          onSelect: onSelect,
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: onSelect,
                          itemBuilder: (_) => [
                            for (final id in moreIds)
                              PopupMenuItem<String>(
                                value: id,
                                enabled: _item(id).enabled,
                                child: ListTile(
                                  enabled: _item(id).enabled,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(_item(id).icon),
                                  title: Text(_item(id).label),
                                  subtitle: _item(id).enabled
                                      ? null
                                      : const Text('Display only — not connected'),
                                  trailing: selected == id
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                ),
                              ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('More'),
                                SizedBox(width: 2),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 220,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () => _openSearchDialog(context, session),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Search players & teams'),
                      ),
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                  IconButton(
                    tooltip: 'Search NBA players and teams',
                    onPressed: () => _openSearchDialog(context, session),
                    icon: const Icon(Icons.search_rounded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Navigation',
                    onSelected: onSelect,
                    itemBuilder: (_) => [
                      for (final id in ['sports', 'nba-home', 'stats', 'advanced'])
                        _mobileMenuItem(_item(id), selected),
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text(
                          'COMPARE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                      _mobileMenuItem(_item('player-compare'), selected),
                      _mobileMenuItem(_item('team-compare'), selected),
                      const PopupMenuDivider(),
                      _mobileMenuItem(_item('trade'), selected),
                      for (final id in moreIds) _mobileMenuItem(_item(id), selected),
                    ],
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ],
                IconButton(
                  tooltip: dark ? 'Light mode' : 'Dark mode',
                  onPressed: onTheme,
                  icon: Icon(
                    dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: session.displayName,
                  onSelected: (value) {
                    if (value == 'profile') onSelect('profile');
                    if (value == 'sign-out') onSignOut();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'profile', child: Text('Profile')),
                    PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
                  ],
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      _initials(session.displayName),
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  PopupMenuItem<String> _mobileMenuItem(
    _Destination item,
    String selectedId,
  ) =>
      PopupMenuItem<String>(
        value: item.id,
        enabled: item.enabled,
        child: ListTile(
          enabled: item.enabled,
          contentPadding: EdgeInsets.zero,
          leading: Icon(item.icon),
          title: Text(item.label),
          subtitle: item.enabled ? null : const Text('Display only — not connected'),
          trailing: selectedId == item.id
              ? const Icon(Icons.check_rounded)
              : null,
        ),
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onSelect,
  });

  final _Destination item;
  final bool selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: TextButton(
        onPressed: item.enabled ? () => onSelect(item.id) : null,
        style: TextButton.styleFrom(
          foregroundColor: selected ? colors.primary : colors.onSurfaceVariant,
          textStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        child: Text(item.label),
      ),
    );
  }
}

class _CompareMenu extends StatelessWidget {
  const _CompareMenu({required this.selected, required this.onSelect});

  final bool selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Compare',
      onSelected: onSelect,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'player-compare',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.people_alt_outlined),
            title: Text('Player Compare'),
            subtitle: Text('2–5 players · cross-era · custom metrics'),
          ),
        ),
        PopupMenuItem(
          value: 'team-compare',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.groups_2_outlined),
            title: Text('Team Compare'),
            subtitle: Text('2–5 teams · season and playoff comparisons'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Compare',
              style: TextStyle(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
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
  final _data = const WebsiteNbaApiService();
  final _controller = TextEditingController();
  Future<Map<String, dynamic>>? _future;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    final query = value.trim();
    setState(() {
      _future = query.length < 2 ? null : _data.searchEntities(query);
    });
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
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Jayson Tatum, Boston Celtics…',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _future == null
                    ? const Center(child: Text('Type at least two characters.'))
                    : FutureBuilder<Map<String, dynamic>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          if (snapshot.hasError || snapshot.data == null) {
                            return Center(
                              child: Text('Static search unavailable: ${snapshot.error}'),
                            );
                          }
                          final groups = _map(snapshot.data!['groups']);
                          final players = _maps(groups['players']);
                          final teams = _maps(groups['teams']);
                          if (players.isEmpty && teams.isEmpty) {
                            return const Center(child: Text('No matches found.'));
                          }
                          return ListView(
                            children: [
                              if (players.isNotEmpty) const _SearchSection('Players'),
                              for (final player in players)
                                ListTile(
                                  leading: const Icon(Icons.person_outline_rounded),
                                  title: Text(_text(player['canonical_name'], 'Player')),
                                  subtitle: Text(
                                    [
                                      _text(player['primary_position']),
                                      _text(player['last_season']),
                                    ].where((item) => item.isNotEmpty).join(' · '),
                                  ),
                                  onTap: () {
                                    final playerKey = _text(player['player_key']);
                                    final playerName = _text(
                                      player['canonical_name'],
                                      'Player',
                                    );
                                    Navigator.of(context).pop();
                                    openWebsiteNbaPlayerPage(
                                      context,
                                      session: widget.session,
                                      playerKey: playerKey,
                                      playerName: playerName,
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
                                    final teamKey = _text(team['team_key']);
                                    final teamName = _text(
                                      team['canonical_name'],
                                      'Team',
                                    );
                                    Navigator.of(context).pop();
                                    openWebsiteNbaTeamPage(
                                      context,
                                      session: widget.session,
                                      teamKey: teamKey,
                                      teamName: teamName,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
}

class _SearchSection extends StatelessWidget {
  const _SearchSection(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      );
}

class _Destination {
  const _Destination({
    required this.id,
    required this.label,
    required this.icon,
    this.builder,
    this.enabled = true,
    this.showInMainNav = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget Function()? builder;
  final bool enabled;
  final bool showInMainNav;
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final result = parts.map((part) => part.substring(0, 1).toUpperCase()).join();
  return result.isEmpty ? 'ST' : result;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _map(item),
  ];
}

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}
