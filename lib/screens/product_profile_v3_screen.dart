import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/product_local_store.dart';
import '../services/profile_service.dart';

const _pBg = Color(0xFF090D12);
const _pPanel = Color(0xFF0F151C);
const _pPanel2 = Color(0xFF141C25);
const _pLine = Color(0xFF263342);
const _pText = Color(0xFFE8EDF3);
const _pMuted = Color(0xFF8895A5);
const _pBlue = Color(0xFF63A9FF);
const _pGreen = Color(0xFF69C99A);
const _pAmber = Color(0xFFE2B866);
const _pRed = Color(0xFFE87979);

class ProductProfileV3Screen extends StatefulWidget {
  const ProductProfileV3Screen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductProfileV3Screen> createState() => _ProductProfileV3ScreenState();
}

class _ProductProfileV3ScreenState extends State<ProductProfileV3Screen> {
  final SportsTerminalProfileService profileService =
      const SportsTerminalProfileService();
  final ProductLocalStore store = const ProductLocalStore();
  final TextEditingController displayName = TextEditingController();
  final TextEditingController handle = TextEditingController();
  final TextEditingController bio = TextEditingController();
  final TextEditingController avatarUrl = TextEditingController();
  final TextEditingController favoritePlayer = TextEditingController();

  bool loading = true;
  bool saving = false;
  bool remoteAvailable = false;
  String error = '';
  bool isPublic = true;
  bool emailDigest = false;
  bool fantasyAlerts = true;
  bool tradeAlerts = true;
  bool editorialNewsletter = true;
  Set<String> favoriteTeams = {};
  List<String> favoritePlayers = [];
  Map<String, dynamic> reputation = {};
  List<Map<String, dynamic>> communities = [];

  static const nbaTeams = [
    'ATL','BOS','BKN','CHA','CHI','CLE','DAL','DEN','DET','GSW','HOU','IND','LAC','LAL','MEM','MIA','MIL','MIN','NOP','NYK','OKC','ORL','PHI','PHX','POR','SAC','SAS','TOR','UTA','WAS'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    displayName.dispose();
    handle.dispose();
    bio.dispose();
    avatarUrl.dispose();
    favoritePlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = '';
    });
    final remote = await profileService.load(widget.session);
    if (!mounted) return;
    if (remote.profile != null) {
      _apply(remote.profile!);
      setState(() {
        remoteAvailable = true;
        loading = false;
      });
      await _cache();
      return;
    }
    final identity = await store.loadStringMap('sports_terminal.profile.identity.v3');
    final preferences = await store.loadStringMap('sports_terminal.profile.preferences.v3');
    final teams = await store.loadStringList(ProductLocalStore.favoriteTeamsKey);
    final players = await store.loadStringList(ProductLocalStore.playerWatchlistKey);
    if (!mounted) return;
    setState(() {
      displayName.text = identity['display_name'] ?? widget.session.displayName;
      handle.text = identity['handle'] ?? _defaultHandle(widget.session.displayName);
      bio.text = identity['bio'] ?? '';
      avatarUrl.text = identity['avatar_url'] ?? '';
      isPublic = identity['is_public'] != 'false';
      emailDigest = preferences['email_digest'] == 'true';
      fantasyAlerts = preferences['fantasy_alerts'] != 'false';
      tradeAlerts = preferences['trade_alerts'] != 'false';
      editorialNewsletter = preferences['editorial_newsletter'] != 'false';
      favoriteTeams = teams.toSet();
      favoritePlayers = players;
      remoteAvailable = false;
      error = remote.error.isEmpty
          ? 'Profile backend unavailable. Editing continues in local resilience mode.'
          : remote.error;
      loading = false;
    });
  }

  void _apply(Map<String, dynamic> payload) {
    final prefsRaw = payload['preferences'];
    final prefs = prefsRaw is Map
        ? prefsRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final teamsRaw = payload['favorite_teams'];
    final playersRaw = payload['favorite_players'];
    final reputationRaw = payload['reputation'];
    final communitiesRaw = payload['communities'];
    displayName.text = '${payload['display_name'] ?? widget.session.displayName}';
    handle.text = '${payload['handle'] ?? _defaultHandle(widget.session.displayName)}';
    bio.text = '${payload['bio'] ?? ''}';
    avatarUrl.text = '${payload['avatar_url'] ?? ''}';
    isPublic = payload['is_public'] != false;
    emailDigest = prefs['email_digest'] == true;
    fantasyAlerts = prefs['fantasy_alerts'] != false;
    tradeAlerts = prefs['trade_alerts'] != false;
    editorialNewsletter = prefs['editorial_newsletter'] != false;
    favoriteTeams = teamsRaw is List
        ? teamsRaw.map((item) => '$item').toSet()
        : <String>{};
    favoritePlayers = playersRaw is List
        ? [for (final item in playersRaw) '$item']
        : <String>[];
    reputation = reputationRaw is Map
        ? reputationRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    communities = communitiesRaw is List
        ? [
            for (final item in communitiesRaw)
              if (item is Map)
                item.map((key, value) => MapEntry(key.toString(), value)),
          ]
        : <Map<String, dynamic>>[];
  }

  Future<void> _cache() async {
    await Future.wait([
      store.saveStringMap('sports_terminal.profile.identity.v3', {
        'display_name': displayName.text.trim(),
        'handle': handle.text.trim(),
        'bio': bio.text.trim(),
        'avatar_url': avatarUrl.text.trim(),
        'is_public': '$isPublic',
      }),
      store.saveStringMap('sports_terminal.profile.preferences.v3', {
        'email_digest': '$emailDigest',
        'fantasy_alerts': '$fantasyAlerts',
        'trade_alerts': '$tradeAlerts',
        'editorial_newsletter': '$editorialNewsletter',
      }),
      store.saveStringList(
        ProductLocalStore.favoriteTeamsKey,
        favoriteTeams.toList()..sort(),
      ),
      store.saveStringList(
        ProductLocalStore.playerWatchlistKey,
        favoritePlayers,
      ),
    ]);
  }

  Future<void> _save() async {
    final cleanDisplay = displayName.text.trim();
    final cleanHandle = handle.text.trim().toLowerCase();
    if (cleanDisplay.isEmpty || cleanHandle.length < 3) {
      _message('Display name and a username of at least three characters are required.');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    final remote = await profileService.save(
      session: widget.session,
      displayName: cleanDisplay,
      handle: cleanHandle,
      bio: bio.text,
      avatarUrl: avatarUrl.text,
      isPublic: isPublic,
      favoriteTeams: favoriteTeams.toList()..sort(),
      favoritePlayers: favoritePlayers,
      emailDigest: emailDigest,
      fantasyAlerts: fantasyAlerts,
      tradeAlerts: tradeAlerts,
      editorialNewsletter: editorialNewsletter,
    );
    if (!mounted) return;
    if (remote.profile != null) {
      _apply(remote.profile!);
      remoteAvailable = true;
      error = '';
      await _cache();
      if (!mounted) return;
      setState(() => saving = false);
      _message('Profile saved to your Sports Terminal account.');
      return;
    }
    await _cache();
    if (!mounted) return;
    setState(() {
      saving = false;
      remoteAvailable = false;
      error = remote.error.isEmpty
          ? 'Account backend unavailable; changes were saved locally.'
          : '${remote.error} Changes were saved locally.';
    });
    _message('Saved locally. The account service can synchronize this later.');
  }

  void _addFavoritePlayer() {
    final value = favoritePlayer.text.trim();
    if (value.isEmpty || favoritePlayers.contains(value)) return;
    setState(() {
      favoritePlayers = [...favoritePlayers, value];
      favoritePlayer.clear();
    });
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _ProfilePanel(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final avatar = avatarUrl.text.trim();
    final badgesRaw = reputation['badges'];
    final badges = badgesRaw is List ? badgesRaw.map((item) => '$item').toList() : <String>[];
    return ColoredBox(
      color: _pBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfilePanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 43,
                  backgroundColor: _pPanel2,
                  foregroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                  child: avatar.isEmpty
                      ? Text(
                          _initials(displayName.text),
                          style: const TextStyle(
                            color: _pBlue,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            displayName.text,
                            style: const TextStyle(
                              color: _pText,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          _Tag(
                            remoteAvailable ? 'ACCOUNT SYNCED' : 'LOCAL RESILIENCE',
                            remoteAvailable ? _pGreen : _pAmber,
                          ),
                          if (!isPublic) const _Tag('PRIVATE', _pMuted),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${handle.text} · ${widget.session.role.label}',
                        style: const TextStyle(
                          color: _pBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (bio.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          bio.text.trim(),
                          style: const TextStyle(color: _pMuted, height: 1.45),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Metric('${reputation['reputation'] ?? 0}', 'Reputation'),
                          _Metric('${reputation['posts'] ?? 0}', 'Threads'),
                          _Metric('${reputation['comments'] ?? 0}', 'Comments'),
                          _Metric('${reputation['received_upvotes'] ?? 0}', 'Upvotes earned'),
                        ],
                      ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [for (final badge in badges) _Tag(badge.toUpperCase(), _pGreen)],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ProfilePanel(
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: _pAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(error, style: const TextStyle(color: _pMuted)),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final identity = _IdentityEditor(
                displayName: displayName,
                handle: handle,
                bio: bio,
                avatarUrl: avatarUrl,
                isPublic: isPublic,
                onPublic: (value) => setState(() => isPublic = value),
                onChanged: () => setState(() {}),
              );
              final preferences = _PreferencesEditor(
                emailDigest: emailDigest,
                fantasyAlerts: fantasyAlerts,
                tradeAlerts: tradeAlerts,
                editorialNewsletter: editorialNewsletter,
                onEmailDigest: (value) => setState(() => emailDigest = value),
                onFantasyAlerts: (value) => setState(() => fantasyAlerts = value),
                onTradeAlerts: (value) => setState(() => tradeAlerts = value),
                onEditorialNewsletter: (value) => setState(() => editorialNewsletter = value),
              );
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [identity, const SizedBox(height: 12), preferences],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  Expanded(child: preferences),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _ProfilePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Heading('TEAMS YOU ROOT FOR'),
                const SizedBox(height: 5),
                const Text(
                  'Favorite teams can drive your home feed, team publications, community shortcuts and alert preferences.',
                  style: TextStyle(color: _pMuted, height: 1.4),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final team in nbaTeams)
                      FilterChip(
                        label: Text(team),
                        selected: favoriteTeams.contains(team),
                        onSelected: (_) => setState(() {
                          if (!favoriteTeams.add(team)) favoriteTeams.remove(team);
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ProfilePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Heading('FAVORITE PLAYERS / WATCHLIST'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: favoritePlayer,
                        onSubmitted: (_) => _addFavoritePlayer(),
                        style: const TextStyle(color: _pText),
                        decoration: const InputDecoration(
                          hintText: 'Player name or canonical ID…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addFavoritePlayer,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (favoritePlayers.isEmpty)
                  const Text(
                    'No favorite players yet.',
                    style: TextStyle(color: _pMuted),
                  ),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final player in favoritePlayers)
                      InputChip(
                        label: Text(player),
                        onDeleted: () => setState(() {
                          favoritePlayers = favoritePlayers
                              .where((item) => item != player)
                              .toList();
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (communities.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ProfilePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Heading('COMMUNITIES'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final community in communities.take(30))
                        _Tag(
                          '${community['name'] ?? community['slug']}',
                          '${community['role'] ?? 'member'}' == 'member'
                              ? _pBlue
                              : _pAmber,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_rounded),
              label: Text(saving ? 'Saving…' : 'Save account profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityEditor extends StatelessWidget {
  const _IdentityEditor({
    required this.displayName,
    required this.handle,
    required this.bio,
    required this.avatarUrl,
    required this.isPublic,
    required this.onPublic,
    required this.onChanged,
  });

  final TextEditingController displayName;
  final TextEditingController handle;
  final TextEditingController bio;
  final TextEditingController avatarUrl;
  final bool isPublic;
  final ValueChanged<bool> onPublic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => _ProfilePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Heading('IDENTITY'),
            const SizedBox(height: 10),
            TextField(
              controller: displayName,
              onChanged: (_) => onChanged(),
              style: const TextStyle(color: _pText),
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: handle,
              onChanged: (_) => onChanged(),
              style: const TextStyle(color: _pText),
              decoration: const InputDecoration(
                labelText: 'Username / handle',
                prefixText: '@',
                helperText: '3–30 lowercase letters, numbers, _, . or -',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bio,
              onChanged: (_) => onChanged(),
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(color: _pText),
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: avatarUrl,
              onChanged: (_) => onChanged(),
              style: const TextStyle(color: _pText),
              decoration: const InputDecoration(
                labelText: 'Profile image URL',
                helperText:
                    'Direct image uploads can move to object storage at production deployment.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _ToggleRow(
              title: 'Public profile',
              subtitle:
                  'Allow other users to view your bio, favorite teams and public contribution reputation.',
              value: isPublic,
              onChanged: onPublic,
            ),
          ],
        ),
      );
}

class _PreferencesEditor extends StatelessWidget {
  const _PreferencesEditor({
    required this.emailDigest,
    required this.fantasyAlerts,
    required this.tradeAlerts,
    required this.editorialNewsletter,
    required this.onEmailDigest,
    required this.onFantasyAlerts,
    required this.onTradeAlerts,
    required this.onEditorialNewsletter,
  });

  final bool emailDigest;
  final bool fantasyAlerts;
  final bool tradeAlerts;
  final bool editorialNewsletter;
  final ValueChanged<bool> onEmailDigest;
  final ValueChanged<bool> onFantasyAlerts;
  final ValueChanged<bool> onTradeAlerts;
  final ValueChanged<bool> onEditorialNewsletter;

  @override
  Widget build(BuildContext context) => _ProfilePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Heading('PREFERENCES & NOTIFICATIONS'),
            const SizedBox(height: 6),
            _ToggleRow(
              title: 'Weekly sports digest',
              subtitle: 'Research, watched entities and major platform activity.',
              value: emailDigest,
              onChanged: onEmailDigest,
            ),
            _ToggleRow(
              title: 'Fantasy / player alerts',
              subtitle: 'Player-watch and fantasy-relevant movement.',
              value: fantasyAlerts,
              onChanged: onFantasyAlerts,
            ),
            _ToggleRow(
              title: 'Trade & transaction alerts',
              subtitle: 'Roster moves, trade cases and relevant front-office changes.',
              value: tradeAlerts,
              onChanged: onTradeAlerts,
            ),
            _ToggleRow(
              title: 'Editorial newsletter',
              subtitle: 'Articles, team publications and major analysis.',
              value: editorialNewsletter,
              onChanged: onEditorialNewsletter,
            ),
          ],
        ),
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _pText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _pMuted, fontSize: 11, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _pPanel, border: Border.all(color: _pLine)),
        child: child,
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _pText,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: .7,
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _pPanel2,
          border: Border.all(color: color.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: _pPanel2, border: Border.all(color: _pLine)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(color: _pText, fontWeight: FontWeight.w900),
            ),
            Text(
              label.toUpperCase(),
              style: const TextStyle(color: _pMuted, fontSize: 7, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

String _defaultHandle(String name) {
  final clean = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  if (clean.length >= 3) return clean.substring(0, clean.length.clamp(0, 24));
  return 'user${DateTime.now().millisecondsSinceEpoch % 100000}';
}

String _initials(String name) {
  final value = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .take(2)
      .map((item) => item[0])
      .join()
      .toUpperCase();
  return value.isEmpty ? 'ST' : value;
}
