import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/product_local_store.dart';
import '../services/website_nba_api_service.dart';
import 'website_nba_entity_pages.dart';

class WebsiteNbaWatchlistScreen extends StatefulWidget {
  const WebsiteNbaWatchlistScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteNbaWatchlistScreen> createState() =>
      _WebsiteNbaWatchlistScreenState();
}

class _WebsiteNbaWatchlistScreenState extends State<WebsiteNbaWatchlistScreen> {
  static const _playersKey = 'sports_terminal.website.watchlist.players.v1';
  static const _teamsKey = 'sports_terminal.website.watchlist.teams.v1';

  final _store = const ProductLocalStore();
  final _api = const WebsiteNbaApiService();
  final _search = TextEditingController();

  Map<String, String> _players = const {};
  Map<String, String> _teams = const {};
  List<_WatchSuggestion> _suggestions = const [];
  bool _loading = true;
  bool _searching = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final players = await _store.loadStringMap(_playersKey);
    final teams = await _store.loadStringMap(_teamsKey);
    if (!mounted) return;
    setState(() {
      _players = players;
      _teams = teams;
      _loading = false;
    });
  }

  Future<void> _searchEntities(String value) async {
    final query = value.trim();
    final request = ++_request;
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await _api.searchEntities(query, limitPerKind: 8);
      if (!mounted || request != _request) return;
      final groups = result['groups'];
      final map = groups is Map ? groups : const {};
      final suggestions = <_WatchSuggestion>[];
      final players = map['players'];
      if (players is List) {
        for (final item in players) {
          if (item is! Map) continue;
          final key = (item['player_key'] ?? '').toString();
          if (key.isEmpty || _players.containsKey(key)) continue;
          suggestions.add(
            _WatchSuggestion(
              kind: 'player',
              keyValue: key,
              name: (item['canonical_name'] ?? 'Player').toString(),
              detail: (item['primary_position'] ?? '').toString(),
            ),
          );
        }
      }
      final teams = map['teams'];
      if (teams is List) {
        for (final item in teams) {
          if (item is! Map) continue;
          final key = (item['team_key'] ?? '').toString();
          if (key.isEmpty || _teams.containsKey(key)) continue;
          suggestions.add(
            _WatchSuggestion(
              kind: 'team',
              keyValue: key,
              name: (item['canonical_name'] ?? 'Team').toString(),
              detail: (item['abbreviation'] ?? '').toString(),
            ),
          );
        }
      }
      setState(() {
        _suggestions = suggestions;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
    }
  }

  Future<void> _add(_WatchSuggestion suggestion) async {
    if (suggestion.kind == 'player') {
      final next = Map<String, String>.from(_players)
        ..[suggestion.keyValue] = suggestion.name;
      setState(() => _players = next);
      await _store.saveStringMap(_playersKey, next);
    } else {
      final next = Map<String, String>.from(_teams)
        ..[suggestion.keyValue] = suggestion.name;
      setState(() => _teams = next);
      await _store.saveStringMap(_teamsKey, next);
    }
    _search.clear();
    if (mounted) setState(() => _suggestions = const []);
  }

  Future<void> _removePlayer(String key) async {
    final next = Map<String, String>.from(_players)..remove(key);
    setState(() => _players = next);
    await _store.saveStringMap(_playersKey, next);
  }

  Future<void> _removeTeam(String key) async {
    final next = Map<String, String>.from(_teams)..remove(key);
    setState(() => _teams = next);
    await _store.saveStringMap(_teamsKey, next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_loading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final playerEntries = _players.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final teamEntries = _teams.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Watchlist',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep a lightweight personal list of NBA players and teams you want to revisit. Saved entities stay local to this browser and open directly into canonical Sports Terminal pages.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _search,
                  onChanged: _searchEntities,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search a player or team to watch',
                  ),
                ),
                if (_searching) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _suggestions)
                        ActionChip(
                          avatar: Icon(
                            suggestion.kind == 'player'
                                ? Icons.person_add_alt_1_outlined
                                : Icons.add_rounded,
                            size: 17,
                          ),
                          label: Text(
                            suggestion.detail.isEmpty
                                ? suggestion.name
                                : '${suggestion.name} · ${suggestion.detail}',
                          ),
                          onPressed: () => _add(suggestion),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 920;
            final width = twoColumns
                ? (constraints.maxWidth - 14) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: width,
                  child: _WatchSection(
                    title: 'Players',
                    icon: Icons.person_outline_rounded,
                    emptyText: 'No watched players yet.',
                    children: [
                      for (final entry in playerEntries)
                        _WatchRow(
                          name: entry.value,
                          subtitle: 'Player',
                          onOpen: () => openWebsiteNbaPlayerPage(
                            context,
                            session: widget.session,
                            playerKey: entry.key,
                            playerName: entry.value,
                          ),
                          onRemove: () => _removePlayer(entry.key),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _WatchSection(
                    title: 'Teams',
                    icon: Icons.shield_outlined,
                    emptyText: 'No watched teams yet.',
                    children: [
                      for (final entry in teamEntries)
                        _WatchRow(
                          name: entry.value,
                          subtitle: 'Team',
                          onOpen: () => openWebsiteNbaTeamPage(
                            context,
                            session: widget.session,
                            teamKey: entry.key,
                            teamName: entry.value,
                          ),
                          onRemove: () => _removeTeam(entry.key),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          'This first traditional-web watchlist is intentionally simple: it preserves the useful “Watch” workflow from the original Sports Terminal concept without reintroducing terminal-style UI complexity. Alert rules and live monitoring can layer on later.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}

class _WatchSection extends StatelessWidget {
  const _WatchSection({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const Spacer(),
                  Text('${children.length}'),
                ],
              ),
              const SizedBox(height: 12),
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(emptyText),
                )
              else
                ...children,
            ],
          ),
        ),
      );
}

class _WatchRow extends StatelessWidget {
  const _WatchRow({
    required this.name,
    required this.subtitle,
    required this.onOpen,
    required this.onRemove,
  });

  final String name;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove from watchlist',
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      );
}

class _WatchSuggestion {
  const _WatchSuggestion({
    required this.kind,
    required this.keyValue,
    required this.name,
    required this.detail,
  });

  final String kind;
  final String keyValue;
  final String name;
  final String detail;
}
