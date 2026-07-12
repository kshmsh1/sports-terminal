import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_terminal_seed_repository.dart';

const _navy = Color(0xFF071A33);
const _navy2 = Color(0xFF102A56);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _lime = Color(0xFF8BEA7A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF4F7FB);

class ProductArticlesArenaScreen extends StatelessWidget {
  const ProductArticlesArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final leaders = data == null ? const <Map<String, dynamic>>[] : _rows(data.playerLeaders['points_per_game']);
        final leader = leaders.isEmpty ? null : leaders.first;
        final game = data == null || data.games.isEmpty ? null : data.games.last;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _HeroBand(
            eyebrow: 'Articles / Blogs',
            title: 'Sports writing that feels attached to the data, not bolted on later.',
            body: 'Editorial, user posts, release notes, fantasy explainers, team breakdowns, and player-page analysis should all live inside the same product system.',
            chips: ['Editorial', 'User blogs', 'CMS planned', 'Comments planned'],
          ),
          const SizedBox(height: 18),
          _TwoColumn(
            left: _FeatureStory(
              title: 'Featured template',
              headline: leader == null ? 'How to read a Sports Terminal player page' : 'Why ${_txt(leader['player_label'])} jumps off the 2024-25 scoring board',
              kicker: 'NBA DATA EXPLAINER',
              body: 'A launch-ready content layer should let the team turn live product data into readable analysis, then attach that writing to player, team, fantasy, and community pages.',
            ),
            right: _Surface(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _PanelHeader('Editorial queue', 'Static prototype of the CMS pipeline.'),
                const _ArticleRow('Platform', 'What is Sports Terminal?', 'Founder post', 'Draft'),
                const _ArticleRow('NBA', 'How to use player pages without drowning in tables', 'Explainer', 'Ready'),
                const _ArticleRow('Fantasy', 'Building a first watchlist from 2024-25 data', 'Fantasy', 'Draft'),
                _ArticleRow('Game', 'What a game page should show after final buzzer', 'Product', game == null ? 'Planned' : _txt(game['game_id'])),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          const _RoadmapTable(
            title: 'Content system launch needs',
            rows: [
              ['CMS editor', 'Create drafts, tag posts, preview pages, publish/unpublish.'],
              ['Author profiles', 'Connect posts to public user/team/staff profiles.'],
              ['Entity embeds', 'Attach article modules to player, team, game, fantasy, and community pages.'],
              ['Moderation', 'Review user blogs before featuring or distributing them.'],
            ],
          ),
        ]);
      },
    );
  }
}

class ProductMessagesArenaScreen extends StatefulWidget {
  const ProductMessagesArenaScreen({super.key});

  @override
  State<ProductMessagesArenaScreen> createState() => _ProductMessagesArenaScreenState();
}

class _ProductMessagesArenaScreenState extends State<ProductMessagesArenaScreen> {
  int selected = 0;
  final List<_Thread> threads = const [
    _Thread('Fantasy group chat', 'Can someone sanity-check my SGA/Jokic build?', '3 unread', 'Group'),
    _Thread('Product feedback', 'The NBA Hub should deep-link into player pages next.', '12 replies', 'Internal'),
    _Thread('OKC team room', 'Rotation depth board makes them look terrifying.', 'Live', 'Team'),
    _Thread('Data issue report', 'Need a clear path for reporting bad stats.', 'Open', 'Support'),
  ];

  @override
  Widget build(BuildContext context) {
    final thread = threads[selected];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _HeroBand(
        eyebrow: 'Messages',
        title: 'Chats should feel like part of the sports workflow, not a separate inbox app.',
        body: 'DMs, group rooms, team rooms, fantasy chats, mentions, reports, and notifications should eventually be backend-backed and moderation-aware.',
        chips: ['DMs planned', 'Group rooms planned', 'Safety required', 'Notifications planned'],
      ),
      const SizedBox(height: 18),
      _TwoColumn(
        left: _Surface(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _PanelHeader('Inbox prototype', 'Static/local state until messaging backend exists.'),
            for (var i = 0; i < threads.length; i++)
              _MessageThreadRow(thread: threads[i], selected: i == selected, onTap: () => setState(() => selected = i)),
          ]),
        ),
        right: _Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _RoomHeader(thread: thread),
            const SizedBox(height: 18),
            _Bubble(author: 'Keshav', text: thread.preview, self: true),
            const _Bubble(author: 'Sports Terminal', text: 'This is the right shape for the UI, but launch needs a real messaging backend, read state, block/report controls, and notification delivery.', self: false),
            const _Bubble(author: 'Moderator note', text: 'Every messaging surface should connect to safety tooling from day one.', self: false),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
              child: const Row(children: [Expanded(child: Text('Write a message...')), Icon(Icons.send_rounded, color: _blue)]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      const _RoadmapTable(
        title: 'Messaging launch needs',
        rows: [
          ['Persistence', 'Messages, read receipts, threads, group membership, and attachments.'],
          ['Safety', 'Block, report, mute, spam controls, moderation queue, audit trails.'],
          ['Notifications', 'Unread counts, mentions, push/email preferences, digest controls.'],
          ['Permissions', 'DM privacy, private rooms, org/team/admin-only conversations.'],
        ],
      ),
    ]);
  }
}

class ProductProfileArenaScreen extends StatefulWidget {
  const ProductProfileArenaScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductProfileArenaScreen> createState() => _ProductProfileArenaScreenState();
}

class _ProductProfileArenaScreenState extends State<ProductProfileArenaScreen> {
  bool publicProfile = true;
  bool emailDigest = false;
  bool fantasyAlerts = true;
  final Set<String> teams = {'OKC', 'BOS'};

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _HeroBand(
        eyebrow: 'Profile / Settings',
        title: '${widget.session.displayName}’s clubhouse',
        body: 'Profiles should become the user’s sports identity: favorites, watchlists, posts, workspaces, privacy, notifications, subscription, and public activity.',
        chips: [widget.session.role.label, widget.session.organizationName, 'Local settings prototype'],
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
            _MiniStats(items: const [
              _MiniStat('Favorite teams', '2'),
              _MiniStat('Watchlist', 'Prototype'),
              _MiniStat('Workspaces', 'Local'),
            ]),
            const SizedBox(height: 18),
            const _RoadmapTable(title: 'Profile data to persist', rows: [
              ['Identity', 'Avatar, bio, handle, favorite teams, favorite players.'],
              ['Activity', 'Posts, comments, saved threads, public workspaces.'],
              ['Account', 'Email, password/provider, privacy, export/delete.'],
            ]),
          ]),
        ),
        right: _Surface(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _PanelHeader('Settings prototype', 'Local switches only until account persistence exists.'),
            _SettingsSwitch('Public profile', 'Let other users see your bio, posts, favorites, and public workspaces.', publicProfile, (value) => setState(() => publicProfile = value)),
            _SettingsSwitch('Weekly email digest', 'Send a recap of your favorite teams, watchlists, and community replies.', emailDigest, (value) => setState(() => emailDigest = value)),
            _SettingsSwitch('Fantasy alerts', 'Notify me when watchlist players cross role/stat thresholds.', fantasyAlerts, (value) => setState(() => fantasyAlerts = value)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                for (final team in ['OKC', 'BOS', 'NYK', 'DEN', 'LAL', 'GSW'])
                  FilterChip(
                    selected: teams.contains(team),
                    selectedColor: const Color(0xFFEFF6FF),
                    checkmarkColor: _blue,
                    label: Text(team, style: const TextStyle(fontWeight: FontWeight.w900)),
                    onSelected: (_) => setState(() => teams.contains(team) ? teams.remove(team) : teams.add(team)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class ProductAdminOpsCenterScreen extends StatelessWidget {
  const ProductAdminOpsCenterScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeroBand(
            eyebrow: 'Admin / Operator',
            title: 'A real control room for data, content, community, users, billing, and launch readiness.',
            body: 'The admin area should be separate from the consumer product and should become the place where you operate the platform.',
            chips: ['Signed in: ${session.role.label}', 'Data ops', 'Moderation', 'CMS', 'Billing'],
          ),
          const SizedBox(height: 18),
          _MetricGrid(items: [
            _Metric('Seed health', data == null ? 'Loading' : data.validationStatus.toUpperCase(), 'pipeline gate'),
            _Metric('Games', data == null ? '—' : '${data.games.length}', 'generated asset'),
            _Metric('PBP events', data == null ? '—' : _compact(data.playByPlayEvents), 'warehouse depth'),
            _Metric('Asset files', data == null ? '—' : '${data.copiedAssetFiles}', 'Flutter mirror'),
          ]),
          const SizedBox(height: 18),
          _AdminKanban(),
          const SizedBox(height: 18),
          const _RoadmapTable(title: 'Admin console buildout', rows: [
            ['Data operations', 'Pipeline runs, validation, season imports, current-season refreshes.'],
            ['CMS', 'Article drafts, publishing, featured cards, tags, author tools.'],
            ['Moderation', 'Reports, bans, appeals, audit logs, unsafe content review.'],
            ['Users / billing', 'Plans, entitlements, orgs, support status, invoices.'],
          ]),
        ]);
      },
    );
  }
}

class _AdminKanban extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final columns = [
          _AdminColumn('Live now', const [('NBA seed assets', 'Validated'), ('Footer pages', 'Static'), ('Product shell', 'Active')]),
          _AdminColumn('Build next', const [('Local persistence', 'Theme/favorites'), ('Routed pages', 'Players/teams/games'), ('Workspace engine', 'Formulas')]),
          _AdminColumn('Backend required', const [('Community', 'Posts/comments'), ('Messaging', 'DMs/groups'), ('Billing', 'Plans/payments')]),
        ];
        if (compact) return Column(children: [for (final column in columns) ...[column, const SizedBox(height: 14)]]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final column in columns) Expanded(child: Padding(padding: const EdgeInsets.only(right: 14), child: column))]);
      });
}

class _AdminColumn extends StatelessWidget {
  const _AdminColumn(this.title, this.items);
  final String title;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => _Surface(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PanelHeader(title, 'Operator lane'),
          for (final item in items)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
              child: Row(children: [Expanded(child: Text(item.$1, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900))), Text(item.$2, style: const TextStyle(color: _blue, fontWeight: FontWeight.w800, fontSize: 12))]),
            ),
        ]),
      );
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
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _navy2, _blue, _orange]), borderRadius: BorderRadius.circular(32), boxShadow: const [BoxShadow(color: Color(0x26071A33), blurRadius: 32, offset: Offset(0, 16))]),
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

class _FeatureStory extends StatelessWidget {
  const _FeatureStory({required this.title, required this.headline, required this.kicker, required this.body});
  final String title;
  final String headline;
  final String kicker;
  final String body;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _muted, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0)),
          const SizedBox(height: 10),
          Container(width: double.infinity, height: 150, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_navy, _blue, _orange]), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 54)),
          const SizedBox(height: 16),
          Text(kicker, style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 6),
          Text(headline, style: const TextStyle(color: _ink, fontSize: 25, height: 1.08, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(color: _muted, height: 1.45, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow(this.section, this.title, this.type, this.status);
  final String section;
  final String title;
  final String type;
  final String status;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.article_rounded, color: _blue)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('$section • $type', style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700))])), Text(status, style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 12))]));
}

class _Thread {
  const _Thread(this.title, this.preview, this.meta, this.kind);
  final String title;
  final String preview;
  final String meta;
  final String kind;
}

class _MessageThreadRow extends StatelessWidget {
  const _MessageThreadRow({required this.thread, required this.selected, required this.onTap});
  final _Thread thread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(color: selected ? const Color(0xFFEFF6FF) : Colors.white, child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [CircleAvatar(backgroundColor: selected ? _blue : const Color(0xFFF2F4F7), child: Text(thread.kind[0], style: TextStyle(color: selected ? Colors.white : _muted, fontWeight: FontWeight.w900))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(thread.title, style: TextStyle(color: selected ? _blue : _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(thread.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12))])), Text(thread.meta, style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 11))]))));
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.thread});
  final _Thread thread;
  @override
  Widget build(BuildContext context) => Row(children: [CircleAvatar(radius: 24, backgroundColor: const Color(0xFFEFF6FF), child: Text(thread.kind[0], style: const TextStyle(color: _blue, fontWeight: FontWeight.w900))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(thread.title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)), Text('${thread.kind} room • ${thread.meta}', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))]))]);
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.author, required this.text, required this.self});
  final String author;
  final String text;
  final bool self;
  @override
  Widget build(BuildContext context) => Align(alignment: self ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 10), constraints: const BoxConstraints(maxWidth: 520), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: self ? _navy : _soft, borderRadius: BorderRadius.circular(18), border: Border.all(color: self ? _navy : _line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(author, style: TextStyle(color: self ? Colors.white70 : _muted, fontSize: 11, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(text, style: TextStyle(color: self ? Colors.white : _ink, height: 1.35, fontWeight: FontWeight.w600))])));
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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: wide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: wide ? 2.0 : 1.35, children: [for (final item in items) _MetricTile(item)]);
      });
}

class _Metric {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.item);
  final _Metric item;
  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(item.label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w800)), Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w900)), Text(item.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w800))]));
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

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) item.cast<String, dynamic>()];
}

String _txt(Object? value) => value?.toString() ?? '—';
String _initial(String value) => value.trim().isEmpty ? 'U' : value.trim()[0].toUpperCase();

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
