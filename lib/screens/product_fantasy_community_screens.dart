import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF4F7FB);

class ProductFantasyWarRoomScreen extends StatefulWidget {
  const ProductFantasyWarRoomScreen({super.key});

  @override
  State<ProductFantasyWarRoomScreen> createState() => _ProductFantasyWarRoomScreenState();
}

class _ProductFantasyWarRoomScreenState extends State<ProductFantasyWarRoomScreen> {
  String query = '';
  final Set<String> watchlist = {'gilgesh01', 'jokicni01'};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _Surface(child: Text('Loading fantasy board...', style: TextStyle(color: _muted)));
        if (snapshot.hasError) return _Surface(child: Text('Fantasy data unavailable: ${snapshot.error}', style: const TextStyle(color: _muted)));
        final data = snapshot.data!;
        final rows = data.playerSeasonTotals.where((row) {
          final text = '${_txt(row['player_label'])} ${_txt(row['team_ids'])}'.toLowerCase();
          return query.trim().isEmpty || text.contains(query.trim().toLowerCase());
        }).toList()
          ..sort((a, b) => _fantasyScore(b).compareTo(_fantasyScore(a)));
        final watched = rows.where((row) => watchlist.contains(_txt(row['player_id']))).toList();
        final top = rows.isEmpty ? null : rows.first;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Hero('Fantasy War Room', 'Build a watchlist, triage players by simple fantasy score, and turn raw NBA data into a user-friendly fantasy workflow.'),
          const SizedBox(height: 18),
          _MetricGrid(items: [
            _Metric('Watchlist', '${watchlist.length}', 'local prototype'),
            _Metric('Visible players', '${rows.length}', query.trim().isEmpty ? 'all active summaries' : 'query filtered'),
            _Metric('Top target', _txt(top?['player_label']), top == null ? 'No rows' : '${_d(_fantasyScore(top))} score'),
            _Metric('Backend need', 'High', 'save rosters + leagues'),
          ]),
          const SizedBox(height: 18),
          _Search(value: query, hint: 'Search fantasy targets by player or team...', onChanged: (value) => setState(() => query = value)),
          const SizedBox(height: 18),
          _TwoColumn(
            left: _Surface(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Header('Fantasy target board', 'Click the bookmark to add/remove a player from the local watchlist.'),
                for (final row in rows.take(80))
                  _PlayerTargetRow(
                    player: _txt(row['player_label']),
                    team: _txt(row['team_ids']),
                    score: _fantasyScore(row),
                    line: '${_d(row['points_per_game'])} PPG • ${_d(row['rebounds_per_game'])} RPG • ${_d(row['assists_per_game'])} APG',
                    watched: watchlist.contains(_txt(row['player_id'])),
                    onTap: () => setState(() => watchlist.contains(_txt(row['player_id'])) ? watchlist.remove(_txt(row['player_id'])) : watchlist.add(_txt(row['player_id']))),
                  ),
              ]),
            ),
            right: _Surface(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Header('My watchlist', 'Local state only for now; this should become backend-backed favorites/watchlists.'),
                if (watched.isEmpty)
                  const Padding(padding: EdgeInsets.all(18), child: Text('No watched players match the current search.', style: TextStyle(color: _muted)))
                else
                  for (final row in watched)
                    _PlayerTargetRow(
                      player: _txt(row['player_label']),
                      team: _txt(row['team_ids']),
                      score: _fantasyScore(row),
                      line: '${_d(row['minutes_per_game'])} MPG • ${_d(row['avg_bpm'])} BPM',
                      watched: true,
                      onTap: () => setState(() => watchlist.remove(_txt(row['player_id']))),
                    ),
                const _LaunchChecklist(title: 'Fantasy launch needs', rows: [
                  ['League import', 'Connect ESPN/Yahoo/Sleeper or upload rosters.'],
                  ['Scoring settings', 'Custom points, categories, or roto profiles.'],
                  ['Alerts', 'Notify on injuries, role changes, and stat thresholds.'],
                  ['Persistence', 'Save watchlists, rosters, notes, and templates.'],
                ]),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class ProductCommunityArenaScreen extends StatefulWidget {
  const ProductCommunityArenaScreen({super.key});

  @override
  State<ProductCommunityArenaScreen> createState() => _ProductCommunityArenaScreenState();
}

class _ProductCommunityArenaScreenState extends State<ProductCommunityArenaScreen> {
  String board = 'All';
  final List<_Post> posts = [
    _Post('NBA General', 'OKC looks like the cleanest title profile in the loaded data', 'Margin, depth, and top-end creation all show up in the terminal pages.', 128, 34),
    _Post('Fantasy', 'Who are the safest first-round fantasy anchors?', 'SGA and Jokic are the obvious starting point, but the role board can surface second-tier value.', 84, 19),
    _Post('Product Feedback', 'The NBA hub should link directly from every player row into a full player URL', 'This is the next product step after the current in-page entity hub.', 47, 12),
    _Post('Team Rooms', 'Boston roster changes need a dedicated team page thread', 'Team pages should combine data, articles, and fan discussion in one place.', 62, 21),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = posts.where((post) => board == 'All' || post.board == board).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Hero('Community Arena', 'A cleaner social surface for forums, team rooms, fantasy discussion, product feedback, and eventually comments under player/team/game pages.'),
      const SizedBox(height: 18),
      _MetricGrid(items: [
        _Metric('Boards', '5', 'launch structure'),
        _Metric('Visible threads', '${visible.length}', board),
        _Metric('Moderation', 'Needed', 'reports + bans'),
        _Metric('Backend', 'Needed', 'posts + comments'),
      ]),
      const SizedBox(height: 18),
      _BoardTabs(board: board, onChanged: (value) => setState(() => board = value)),
      const SizedBox(height: 18),
      _TwoColumn(
        left: _Surface(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Header('Featured threads', 'Static prototype threads showing the final community shape.'),
            for (final post in visible) _PostCard(post: post, onLike: () => setState(() => post.likes += 1)),
          ]),
        ),
        right: const _Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Community launch checklist', style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900)),
            SizedBox(height: 12),
            _ChecklistItem('Real auth + public profiles'),
            _ChecklistItem('Create post, reply, edit, delete'),
            _ChecklistItem('Likes, saves, follows, reputation'),
            _ChecklistItem('Report queue and moderation console'),
            _ChecklistItem('Team/player/game page comment modules'),
            SizedBox(height: 16),
            _Notice('This screen is intentionally frontend-only right now. The next major unlock is a backend for persistence and safety.'),
          ]),
        ),
      ),
    ]);
  }
}

class _Post {
  _Post(this.board, this.title, this.body, this.likes, this.replies);
  final String board;
  final String title;
  final String body;
  int likes;
  final int replies;
}

class _Hero extends StatelessWidget {
  const _Hero(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_navy, _blue, _orange]), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x22071A33), blurRadius: 30, offset: Offset(0, 14))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 36, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          const SizedBox(height: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: Text(body, style: const TextStyle(color: Color(0xFFEAF2FF), height: 1.45, fontSize: 16, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _BoardTabs extends StatelessWidget {
  const _BoardTabs({required this.board, required this.onChanged});
  final String board;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final item in const ['All', 'NBA General', 'Team Rooms', 'Fantasy', 'Product Feedback'])
            ChoiceChip(
              label: Text(item),
              selected: board == item,
              selectedColor: _navy,
              labelStyle: TextStyle(color: board == item ? Colors.white : _ink, fontWeight: FontWeight.w900),
              onSelected: (_) => onChanged(item),
            ),
        ]),
      );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onLike});
  final _Post post;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)), child: Text(post.board, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 12))),
            Text('${post.replies} replies', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          Text(post.title, style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(post.body, style: const TextStyle(color: _muted, height: 1.4, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, children: [
            OutlinedButton.icon(onPressed: onLike, icon: const Icon(Icons.arrow_upward_rounded, size: 17), label: Text('${post.likes}')),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.mode_comment_outlined, size: 17), label: const Text('Reply soon')),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.bookmark_border_rounded, size: 17), label: const Text('Save soon')),
          ]),
        ]),
      );
}

class _PlayerTargetRow extends StatelessWidget {
  const _PlayerTargetRow({required this.player, required this.team, required this.score, required this.line, required this.watched, required this.onTap});
  final String player;
  final String team;
  final double score;
  final String line;
  final bool watched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
        child: Row(children: [
          IconButton(onPressed: onTap, icon: Icon(watched ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: watched ? _orange : _muted)),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(player, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('$team • $line', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)), child: Text(_d(score), style: const TextStyle(color: _blue, fontWeight: FontWeight.w900))),
        ]),
      );
}

class _LaunchChecklist extends StatelessWidget {
  const _LaunchChecklist({required this.title, required this.rows});
  final String title;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          for (final row in rows) _ChecklistItem('${row[0]} — ${row[1]}'),
        ]),
      );
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, color: _orange, size: 18), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700)))]));
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFD7A8))), child: Text(text, style: const TextStyle(color: Color(0xFF9A3412), height: 1.4, fontWeight: FontWeight.w700)));
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: wide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: wide ? 2.1 : 1.35, children: [for (final item in items) _MetricTile(item)]);
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
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(item.label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w800)), Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 25, fontWeight: FontWeight.w900)), Text(item.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w800))]));
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
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 24, offset: Offset(0, 10))]), child: child);
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 19)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontWeight: FontWeight.w600))]));
}

class _Search extends StatelessWidget {
  const _Search({required this.value, required this.hint, required this.onChanged});
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _Surface(child: TextField(controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length), onChanged: onChanged, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: hint, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line)))));
}

String _txt(Object? value) => value?.toString() ?? '—';

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _d(Object? value) => _num(value).toStringAsFixed(1);

double _fantasyScore(Map<String, dynamic>? row) {
  if (row == null) return 0;
  return _num(row['points_per_game']) + 1.2 * _num(row['rebounds_per_game']) + 1.5 * _num(row['assists_per_game']) + 3.0 * _num(row['steals_per_game']) + 3.0 * _num(row['blocks_per_game']) + 0.5 * _num(row['avg_bpm']);
}
