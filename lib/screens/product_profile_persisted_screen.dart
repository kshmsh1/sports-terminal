import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/product_local_store.dart';

const _bg = Color(0xFF090D12);
const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _amber = Color(0xFFE2B866);
const _green = Color(0xFF69C99A);

class ProductPersistedProfileScreen extends StatefulWidget {
  const ProductPersistedProfileScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<ProductPersistedProfileScreen> createState() => _ProductPersistedProfileScreenState();
}

class _ProductPersistedProfileScreenState extends State<ProductPersistedProfileScreen> {
  final store = const ProductLocalStore();
  final username = TextEditingController();
  final bio = TextEditingController();
  final avatarUrl = TextEditingController();
  final favoritePlayer = TextEditingController();
  bool loaded = false;
  bool publicProfile = true;
  bool emailDigest = false;
  bool fantasyAlerts = true;
  bool tradeAlerts = true;
  bool articleDigest = true;
  Set<String> favoriteTeams = {};
  Set<String> favoritePlayers = {};

  static const teams = ['ATL','BOS','BKN','CHA','CHI','CLE','DAL','DEN','DET','GSW','HOU','IND','LAC','LAL','MEM','MIA','MIL','MIN','NOP','NYK','OKC','ORL','PHI','PHX','POR','SAC','SAS','TOR','UTA','WAS'];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { username.dispose(); bio.dispose(); avatarUrl.dispose(); favoritePlayer.dispose(); super.dispose(); }

  Future<void> _load() async {
    final settings = await store.loadStringMap(ProductLocalStore.profileSettingsKey);
    final teams = await store.loadStringSet(ProductLocalStore.favoriteTeamsKey);
    final players = await store.loadStringSet(ProductLocalStore.playerWatchlistKey);
    if (!mounted) return;
    setState(() {
      username.text = settings['username'] ?? widget.session.displayName.replaceAll(' ', '').toLowerCase();
      bio.text = settings['bio'] ?? '';
      avatarUrl.text = settings['avatarUrl'] ?? '';
      publicProfile = settings['publicProfile'] != 'false';
      emailDigest = settings['emailDigest'] == 'true';
      fantasyAlerts = settings['fantasyAlerts'] != 'false';
      tradeAlerts = settings['tradeAlerts'] != 'false';
      articleDigest = settings['articleDigest'] != 'false';
      favoriteTeams = teams;
      favoritePlayers = players;
      loaded = true;
    });
  }

  Future<void> _save() async {
    await store.saveStringMap(ProductLocalStore.profileSettingsKey, {
      'username': username.text.trim(), 'bio': bio.text.trim(), 'avatarUrl': avatarUrl.text.trim(),
      'publicProfile': '$publicProfile', 'emailDigest': '$emailDigest', 'fantasyAlerts': '$fantasyAlerts', 'tradeAlerts': '$tradeAlerts', 'articleDigest': '$articleDigest',
    });
    await store.saveStringSet(ProductLocalStore.favoriteTeamsKey, favoriteTeams);
    await store.saveStringSet(ProductLocalStore.playerWatchlistKey, favoritePlayers);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile and preferences saved.')));
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const _Card(child: Center(child: CircularProgressIndicator()));
    final handle = username.text.trim().isEmpty ? 'user' : username.text.trim();
    return ColoredBox(color: _bg, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Card(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 42, backgroundColor: _panel2, foregroundImage: avatarUrl.text.trim().isEmpty ? null : NetworkImage(avatarUrl.text.trim()), child: avatarUrl.text.trim().isEmpty ? Text(_initials(widget.session.displayName), style: const TextStyle(color: _blue, fontSize: 24, fontWeight: FontWeight.w900)) : null),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.session.displayName, style: const TextStyle(color: _text, fontSize: 29, fontWeight: FontWeight.w900)),
          Text('@$handle · ${widget.session.role.label}', style: const TextStyle(color: _blue, fontWeight: FontWeight.w800)),
          if (bio.text.trim().isNotEmpty) ...[const SizedBox(height: 7), Text(bio.text.trim(), style: const TextStyle(color: _muted, height: 1.4))],
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: [const _Badge('FOUNDING USER', Icons.workspace_premium_rounded, _amber), if (favoriteTeams.isNotEmpty) const _Badge('TEAM LOYALIST', Icons.favorite_rounded, _green), if (favoritePlayers.length >= 5) const _Badge('SCOUT', Icons.visibility_rounded, _blue), if (publicProfile) const _Badge('PUBLIC PROFILE', Icons.public_rounded, _blue)]),
        ])),
      ])),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final editor = _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Title('IDENTITY'), const SizedBox(height: 10),
          TextField(controller: username, onChanged: (_) => setState(() {}), style: const TextStyle(color: _text), decoration: const InputDecoration(labelText: 'Username / handle', prefixText: '@', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: bio, onChanged: (_) => setState(() {}), minLines: 3, maxLines: 5, style: const TextStyle(color: _text), decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: avatarUrl, onChanged: (_) => setState(() {}), style: const TextStyle(color: _text), decoration: const InputDecoration(labelText: 'Profile picture URL', helperText: 'Image upload/storage can replace this URL field when object storage is connected.', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: publicProfile, onChanged: (v) => setState(() => publicProfile = v), title: const Text('Public profile', style: TextStyle(color: _text, fontWeight: FontWeight.w800)), subtitle: const Text('Allow other users to view your bio, teams, badges and public activity.', style: TextStyle(color: _muted))),
        ]));
        final prefs = _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Title('PREFERENCES & NOTIFICATIONS'), const SizedBox(height: 6),
          _Switch('Weekly sports digest', emailDigest, (v) => setState(() => emailDigest = v)),
          _Switch('Fantasy/player alerts', fantasyAlerts, (v) => setState(() => fantasyAlerts = v)),
          _Switch('Trade & transaction alerts', tradeAlerts, (v) => setState(() => tradeAlerts = v)),
          _Switch('Editorial newsletter', articleDigest, (v) => setState(() => articleDigest = v)),
        ]));
        if (constraints.maxWidth < 900) return Column(children: [editor, const SizedBox(height: 12), prefs]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: editor), const SizedBox(width: 12), Expanded(child: prefs)]);
      }),
      const SizedBox(height: 12),
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Title('TEAMS YOU ROOT FOR'), const SizedBox(height: 5), const Text('Choose any number of NBA teams. These preferences can drive your home feed, notifications, articles and community shortcuts.', style: TextStyle(color: _muted)), const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [for (final team in teams) FilterChip(selected: favoriteTeams.contains(team), label: Text(team), onSelected: (_) => setState(() { if (!favoriteTeams.add(team)) favoriteTeams.remove(team); }))]),
      ])),
      const SizedBox(height: 12),
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Title('FAVORITE PLAYERS / WATCHLIST'), const SizedBox(height: 8),
        Row(children: [Expanded(child: TextField(controller: favoritePlayer, style: const TextStyle(color: _text), decoration: const InputDecoration(hintText: 'Add player name or ID…', border: OutlineInputBorder()))), const SizedBox(width: 8), FilledButton(onPressed: () { final value = favoritePlayer.text.trim(); if (value.isEmpty) return; setState(() { favoritePlayers.add(value); favoritePlayer.clear(); }); }, child: const Text('Add'))]),
        const SizedBox(height: 9),
        Wrap(spacing: 7, runSpacing: 7, children: [for (final player in favoritePlayers) InputChip(label: Text(player), onDeleted: () => setState(() => favoritePlayers.remove(player)))]),
      ])),
      const SizedBox(height: 12),
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Title('PROFILE AWARDS & REPUTATION'), const SizedBox(height: 8),
        const Wrap(spacing: 8, runSpacing: 8, children: [_Badge('FOUNDING USER', Icons.workspace_premium_rounded, _amber), _Badge('QUALITY CONTRIBUTOR', Icons.thumb_up_alt_rounded, _green), _Badge('ANALYTICS', Icons.analytics_rounded, _blue), _Badge('COMMUNITY HELPER', Icons.volunteer_activism_rounded, _green)]),
        const SizedBox(height: 9), const Text('Badges are designed for verified contribution, tenure, community quality, prediction contests, editorial participation and organization credentials. Production award issuance should be server-authoritative rather than user-editable.', style: TextStyle(color: _muted, height: 1.45)),
      ])),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('Save profile & preferences'))),
    ]));
  }
}

class _Card extends StatelessWidget { const _Card({required this.child}); final Widget child; @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)), child: child); }
class _Title extends StatelessWidget { const _Title(this.text); final String text; @override Widget build(BuildContext context) => Text(text, style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .6)); }
class _Badge extends StatelessWidget { const _Badge(this.text, this.icon, this.color); final String text; final IconData icon; final Color color; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: _panel2, border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: color), const SizedBox(width: 5), Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900))])); }
class _Switch extends StatelessWidget { const _Switch(this.label, this.value, this.onChanged); final String label; final bool value; final ValueChanged<bool> onChanged; @override Widget build(BuildContext context) => SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: value, onChanged: onChanged, title: Text(label, style: const TextStyle(color: _text, fontWeight: FontWeight.w800))); }
String _initials(String value) => value.trim().split(RegExp(r'\s+')).take(2).map((part) => part.isEmpty ? '' : part[0]).join().toUpperCase();
