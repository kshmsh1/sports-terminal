import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/product_local_store.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF4F7FB);

class ProductPersistedProfileScreen extends StatefulWidget {
  const ProductPersistedProfileScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductPersistedProfileScreen> createState() => _ProductPersistedProfileScreenState();
}

class _ProductPersistedProfileScreenState extends State<ProductPersistedProfileScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  bool publicProfile = true;
  bool emailDigest = false;
  bool fantasyAlerts = true;
  Set<String> favoriteTeams = {'OKC', 'BOS'};
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final settings = await localStore.loadStringMap(ProductLocalStore.profileSettingsKey);
    final teams = await localStore.loadStringSet(ProductLocalStore.favoriteTeamsKey, fallback: {'OKC', 'BOS'});
    if (!mounted) return;
    setState(() {
      publicProfile = settings['publicProfile'] != 'false';
      emailDigest = settings['emailDigest'] == 'true';
      fantasyAlerts = settings['fantasyAlerts'] != 'false';
      favoriteTeams = teams;
      loaded = true;
    });
  }

  Future<void> _saveSettings() async {
    await localStore.saveStringMap(ProductLocalStore.profileSettingsKey, {
      'publicProfile': '$publicProfile',
      'emailDigest': '$emailDigest',
      'fantasyAlerts': '$fantasyAlerts',
    });
    await localStore.saveStringSet(ProductLocalStore.favoriteTeamsKey, favoriteTeams);
  }

  Future<void> _setPublicProfile(bool value) async {
    setState(() => publicProfile = value);
    await _saveSettings();
  }

  Future<void> _setEmailDigest(bool value) async {
    setState(() => emailDigest = value);
    await _saveSettings();
  }

  Future<void> _setFantasyAlerts(bool value) async {
    setState(() => fantasyAlerts = value);
    await _saveSettings();
  }

  Future<void> _toggleTeam(String team) async {
    setState(() => favoriteTeams.contains(team) ? favoriteTeams.remove(team) : favoriteTeams.add(team));
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const _Surface(child: Text('Loading profile settings...', style: TextStyle(color: _muted)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _HeroBand(
        eyebrow: 'Profile / Settings',
        title: '${widget.session.displayName}’s clubhouse',
        body: 'Profiles should become the user’s sports identity: favorites, watchlists, posts, workspaces, privacy, notifications, subscription, and public activity.',
        chips: [widget.session.role.label, widget.session.organizationName, 'Settings saved locally'],
      ),
      const SizedBox(height: 18),
      _TwoColumn(
        left: _Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 34, backgroundColor: const Color(0xFFFFEFE1), child: Text(_initial(widget.session.displayName), style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 28))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.session.displayName, style: const TextStyle(color: _ink, fontSize: 27, fontWeight: FontWeight.w900)),
                Text('${widget.session.organizationName} • ${widget.session.role.label}', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
              ])),
            ]),
            const SizedBox(height: 18),
            _MiniStats(items: [
              _MiniStat('Favorite teams', '${favoriteTeams.length}'),
              const _MiniStat('Watchlist', 'Shared'),
              const _MiniStat('Settings', 'Local save'),
            ]),
            const SizedBox(height: 18),
            const _RoadmapTable(title: 'Profile data to persist in backend later', rows: [
              ['Identity', 'Avatar, bio, handle, favorite teams, favorite players.'],
              ['Activity', 'Posts, comments, saved threads, public workspaces.'],
              ['Account', 'Email, password/provider, privacy, export/delete.'],
            ]),
          ]),
        ),
        right: _Surface(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _PanelHeader('Settings', 'Saved locally on this device until the backend account system exists.'),
            _SettingsSwitch('Public profile', 'Let other users see your bio, posts, favorites, and public workspaces.', publicProfile, _setPublicProfile),
            _SettingsSwitch('Weekly email digest', 'Send a recap of your favorite teams, watchlists, and community replies.', emailDigest, _setEmailDigest),
            _SettingsSwitch('Fantasy alerts', 'Notify me when watchlist players cross role/stat thresholds.', fantasyAlerts, _setFantasyAlerts),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                for (final team in ['OKC', 'BOS', 'NYK', 'DEN', 'LAL', 'GSW', 'DAL', 'MIN', 'PHI', 'MIA'])
                  FilterChip(
                    selected: favoriteTeams.contains(team),
                    selectedColor: const Color(0xFFEFF6FF),
                    checkmarkColor: _blue,
                    label: Text(team, style: const TextStyle(fontWeight: FontWeight.w900)),
                    onSelected: (_) => _toggleTeam(team),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.eyebrow, required this.title, required this.body, required this.chips});
  final String eyebrow;
  final String title;
  final String body;
  final List<String> chips;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _blue, _orange]), borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: Color(0x26071A33), blurRadius: 32, offset: Offset(0, 16))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 38, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -0.8))),
          const SizedBox(height: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: Text(body, style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
          const SizedBox(height: 18),
          Wrap(spacing: 9, runSpacing: 9, children: [for (final chip in chips) _GlassChip(chip)]),
        ]),
      );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.25))), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)));
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch(this.title, this.body, this.value, this.onChanged);
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(body, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600))])), Switch(value: value, onChanged: onChanged)]));
}

class _MiniStats extends StatelessWidget {
  const _MiniStats({required this.items});
  final List<_MiniStat> items;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [for (final item in items) Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(item.value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 20))]))]);
}

class _MiniStat {
  const _MiniStat(this.label, this.value);
  final String label;
  final String value;
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontWeight: FontWeight.w600))]));
}

class _RoadmapTable extends StatelessWidget {
  const _RoadmapTable({required this.title, required this.rows});
  final String title;
  final List<List<String>> rows;
  @override
  Widget build(BuildContext context) => _Surface(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_PanelHeader(title, 'Launch checklist'), for (final row in rows) Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 180, child: Text(row[0], style: const TextStyle(color: _ink, fontWeight: FontWeight.w900))), Expanded(child: Text(row[1], style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600)))]))]));
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 920) return Column(children: [left, const SizedBox(height: 18), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 18), Expanded(child: right)]);
      });
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x0A071A33), blurRadius: 24, offset: Offset(0, 12))]), child: child);
}

String _initial(String value) => value.trim().isEmpty ? 'U' : value.trim()[0].toUpperCase();
