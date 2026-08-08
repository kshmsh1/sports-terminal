import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/product_local_store.dart';
import '../services/trust_safety_service.dart';

const _cmPanel = Color(0xFF0F151C);
const _cmPanel2 = Color(0xFF141C25);
const _cmLine = Color(0xFF263342);
const _cmText = Color(0xFFE8EDF3);
const _cmMuted = Color(0xFF8895A5);
const _cmBlue = Color(0xFF63A9FF);
const _cmGreen = Color(0xFF69C99A);
const _cmAmber = Color(0xFFE2B866);
const _cmRed = Color(0xFFE57D7D);

const _boards = <String>[
  'All',
  'NBA General',
  'Team Rooms',
  'Breaking News',
  'Analysis',
  'Trade Ideas',
  'Draft',
  'Salary Cap',
  'Fantasy',
  'Statistics',
  'Memes',
  'Off Topic',
  'Product Feedback',
  'Organization',
];

const _boardDescriptions = <String, String>{
  'NBA General': 'League-wide discussion, news, games and analysis.',
  'Team Rooms': 'Team-specific communities and game threads.',
  'Breaking News': 'Fast-moving sourced developments and official announcements.',
  'Analysis': 'Film, statistics, tactics, roster construction and long-form argument.',
  'Trade Ideas': 'Trade-machine proposals, valuation debates and transaction concepts.',
  'Draft': 'Prospects, boards, scouting, pick value and draft strategy.',
  'Salary Cap': 'CBA, contracts, exceptions, aprons and cap mechanics.',
  'Fantasy': 'Fantasy basketball strategy, player value and league discussion.',
  'Statistics': 'Metrics, models, datasets, methodology and research questions.',
  'Memes': 'Basketball humor and lightweight fan content.',
  'Off Topic': 'Community discussion that is not primarily about basketball.',
  'Product Feedback': 'Ideas, bugs and Sports Terminal product discussion.',
  'Organization': 'Organization-only operating discussion when access permits.',
};

enum _CommunitySort { hot, newPosts, top, discussed, rising }

extension on _CommunitySort {
  String get label => switch (this) {
    _CommunitySort.hot => 'Hot',
    _CommunitySort.newPosts => 'New',
    _CommunitySort.top => 'Top',
    _CommunitySort.discussed => 'Most Discussed',
    _CommunitySort.rising => 'Rising',
  };
}

class ProductCommunityV2Screen extends StatefulWidget {
  const ProductCommunityV2Screen({super.key, required this.session});
  final AppSession session;

  @override
  State<ProductCommunityV2Screen> createState() => _ProductCommunityV2ScreenState();
}

class _ProductCommunityV2ScreenState extends State<ProductCommunityV2Screen> {
  static const _savedKey = 'sports_terminal.community.saved_posts.v2';
  static const _hiddenKey = 'sports_terminal.community.hidden_posts.v2';
  static const _joinedKey = 'sports_terminal.community.joined_boards.v2';
  final TrustSafetyService _service = const TrustSafetyService();
  final ProductLocalStore _store = const ProductLocalStore();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _comment = TextEditingController();
  late Future<TrustSafetySnapshot> _future;
  String _board = 'All';
  _CommunitySort _sort = _CommunitySort.hot;
  Set<String> _saved = {};
  Set<String> _hidden = {};
  Set<String> _joined = {'NBA General'};
  String _selectedPostId = '';
  List<Map<String, dynamic>> _comments = const [];
  bool _commentsLoading = false;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadPrefs();
  }

  @override
  void dispose() {
    _search.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final saved = await _store.loadStringSet(_savedKey);
    final hidden = await _store.loadStringSet(_hiddenKey);
    final joined = await _store.loadStringSet(_joinedKey, fallback: {'NBA General'});
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _hidden = hidden;
      _joined = joined;
      _prefsLoaded = true;
    });
  }

  Future<TrustSafetySnapshot> _load() => _service.loadCommunity(session: widget.session, board: _board);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
    if (_selectedPostId.isNotEmpty) await _loadComments(_selectedPostId);
  }

  Future<void> _changeBoard(String board) async {
    setState(() {
      _board = board;
      _selectedPostId = '';
      _comments = const [];
      _future = _load();
    });
    await _future;
  }

  Future<void> _toggleJoined(String board) async {
    if (board == 'All') return;
    setState(() {
      if (!_joined.add(board)) _joined.remove(board);
    });
    await _store.saveStringSet(_joinedKey, _joined);
  }

  Future<void> _toggleSaved(String id) async {
    setState(() {
      if (!_saved.add(id)) _saved.remove(id);
    });
    await _store.saveStringSet(_savedKey, _saved);
  }

  Future<void> _hide(String id) async {
    setState(() => _hidden.add(id));
    await _store.saveStringSet(_hiddenKey, _hidden);
  }

  Future<void> _createPost() async {
    final value = await showDialog<_PostDraft>(
      context: context,
      builder: (context) => _CreatePostDialog(initialBoard: _board == 'All' ? 'NBA General' : _board),
    );
    if (value == null) return;
    final post = await _service.createPost(
      session: widget.session,
      board: value.board,
      title: value.title,
      body: value.body,
      entityType: value.entityType,
      entityId: value.entityId,
    );
    if (!mounted) return;
    _toast(post == null
        ? 'Community service is offline. Post was not published.'
        : post['status'] == 'published'
            ? 'Post published.'
            : 'Post submitted for moderation review.');
    await _refresh();
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final id = _text(post['id']);
    if (id == '—') return;
    final result = await _service.toggleLike(session: widget.session, postId: id);
    if (!mounted) return;
    if (result == null) {
      _toast('Community service is offline.');
      return;
    }
    await _refresh();
  }

  Future<void> _loadComments(String postId) async {
    setState(() {
      _selectedPostId = postId;
      _commentsLoading = true;
    });
    final rows = await _service.comments(session: widget.session, postId: postId);
    if (!mounted || _selectedPostId != postId) return;
    setState(() {
      _comments = rows;
      _commentsLoading = false;
    });
  }

  Future<void> _addComment() async {
    final body = _comment.text.trim();
    if (_selectedPostId.isEmpty || body.isEmpty) return;
    final result = await _service.createComment(session: widget.session, postId: _selectedPostId, body: body);
    if (!mounted) return;
    if (result == null) {
      _toast('Comment service is unavailable.');
      return;
    }
    _comment.clear();
    await _loadComments(_selectedPostId);
    await _refresh();
  }

  Future<void> _report(Map<String, dynamic> post) async {
    final reason = await showDialog<String>(context: context, builder: (context) => const _ReportDialog());
    if (reason == null || reason.isEmpty) return;
    final result = await _service.report(
      session: widget.session,
      targetType: 'post',
      targetId: _text(post['id']),
      reason: reason,
      details: 'Submitted from Community v2',
    );
    if (!mounted) return;
    _toast(result == null ? 'Report service is unavailable.' : 'Report submitted to moderation.');
  }

  Future<void> _relationship(Map<String, dynamic> post, {required bool block}) async {
    final author = _text(post['author_user_id']);
    if (author == '—' || author == widget.session.userId) return;
    final success = block
        ? await _service.block(session: widget.session, targetUserId: author, reason: 'Community user action')
        : await _service.mute(session: widget.session, targetUserId: author, reason: 'Community user action');
    if (!mounted) return;
    _toast(success ? '${block ? 'Blocked' : 'Muted'} $author.' : 'Trust service is unavailable.');
    await _refresh();
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  List<Map<String, dynamic>> _visiblePosts(List<Map<String, dynamic>> source) {
    final query = _search.text.trim().toLowerCase();
    final rows = source.where((post) {
      final id = _text(post['id']);
      if (_hidden.contains(id)) return false;
      if (query.isEmpty) return true;
      return '${post['title']} ${post['body']} ${post['board']} ${post['author_display_name'] ?? post['author_user_id']}'.toLowerCase().contains(query);
    }).toList();
    rows.sort((a, b) {
      final likesA = _int(a['like_count'] ?? a['likes'] ?? a['reaction_count']);
      final likesB = _int(b['like_count'] ?? b['likes'] ?? b['reaction_count']);
      final commentsA = _int(a['comment_count'] ?? a['comments']);
      final commentsB = _int(b['comment_count'] ?? b['comments']);
      final timeA = _date(a['created_at'] ?? a['createdAt']);
      final timeB = _date(b['created_at'] ?? b['createdAt']);
      final ageA = DateTime.now().difference(timeA).inHours.clamp(0, 24000);
      final ageB = DateTime.now().difference(timeB).inHours.clamp(0, 24000);
      final hotA = likesA * 3 + commentsA * 2 - ageA / 4;
      final hotB = likesB * 3 + commentsB * 2 - ageB / 4;
      return switch (_sort) {
        _CommunitySort.newPosts => timeB.compareTo(timeA),
        _CommunitySort.top => likesB.compareTo(likesA),
        _CommunitySort.discussed => commentsB.compareTo(commentsA),
        _CommunitySort.rising => (likesB + commentsB - ageB / 8).compareTo(likesA + commentsA - ageA / 8),
        _CommunitySort.hot => hotB.compareTo(hotA),
      };
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) return const _CommunityPanel(child: Center(child: CircularProgressIndicator()));
    return FutureBuilder<TrustSafetySnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _CommunityPanel(child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _CommunityPanel(child: Text('Community unavailable: ${snapshot.error}', style: const TextStyle(color: _cmRed)));
        }
        final data = snapshot.data!;
        final posts = _visiblePosts(data.posts);
        final selected = posts.where((post) => _text(post['id']) == _selectedPostId).firstOrNull;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CommunityHero(data: data, joined: _joined.length, saved: _saved.length),
          const SizedBox(height: 12),
          _CommunityToolbar(
            board: _board,
            sort: _sort,
            search: _search,
            onBoard: _changeBoard,
            onSort: (value) => setState(() => _sort = value),
            onSearch: (_) => setState(() {}),
            onCreate: _createPost,
            onRefresh: _refresh,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1080;
            final feed = Column(children: [
              _FeedHeader(board: _board, count: posts.length, sort: _sort),
              for (final post in posts)
                _PostCard(
                  post: post,
                  saved: _saved.contains(_text(post['id'])),
                  selected: _selectedPostId == _text(post['id']),
                  onVote: () => _toggleLike(post),
                  onComments: () => _loadComments(_text(post['id'])),
                  onSave: () => _toggleSaved(_text(post['id'])),
                  onHide: () => _hide(_text(post['id'])),
                  onReport: () => _report(post),
                  onBlock: () => _relationship(post, block: true),
                  onMute: () => _relationship(post, block: false),
                ),
              if (posts.isEmpty)
                const _CommunityPanel(child: Text('No visible posts match this community/filter. Create a thread or change boards.', style: TextStyle(color: _cmMuted))),
            ]);
            final rail = Column(children: [
              _BoardCard(board: _board, joined: _joined.contains(_board), onJoin: () => _toggleJoined(_board)),
              const SizedBox(height: 12),
              _JoinedCard(joined: _joined, onOpen: _changeBoard),
              const SizedBox(height: 12),
              _SafetyCard(blocks: data.blocks.length, mutes: data.mutes.length, sanctions: data.sanctions.length),
              const SizedBox(height: 12),
              const _CommunityPrinciples(),
            ]);
            if (!wide) return Column(children: [rail, const SizedBox(height: 12), feed]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: feed), const SizedBox(width: 12), Expanded(flex: 3, child: rail)]);
          }),
          if (selected != null) ...[
            const SizedBox(height: 12),
            _InlineThread(
              post: selected,
              comments: _comments,
              loading: _commentsLoading,
              controller: _comment,
              onReply: _addComment,
              onClose: () => setState(() {
                _selectedPostId = '';
                _comments = const [];
              }),
            ),
          ],
        ]);
      },
    );
  }
}

class _CommunityHero extends StatelessWidget {
  const _CommunityHero({required this.data, required this.joined, required this.saved});
  final TrustSafetySnapshot data;
  final int joined;
  final int saved;
  @override
  Widget build(BuildContext context) => _CommunityPanel(
        child: LayoutBuilder(builder: (context, constraints) {
          final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NETWORK / COMMUNITY', style: TextStyle(color: _cmBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 5),
            const Text('Sports discussion with an actual trust layer.', style: TextStyle(color: _cmText, fontSize: 29, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('Communities, ranked feeds, threads, comments, voting, saves, hides, blocks, mutes and reports share the same authenticated identity and moderation backend.', style: TextStyle(color: _cmMuted, height: 1.4)),
          ]);
          final status = Wrap(spacing: 7, runSpacing: 7, children: [
            _Tag(data.remoteAvailable ? 'LIVE SERVICE' : 'CACHED READ', data.remoteAvailable ? _cmGreen : _cmAmber),
            _Tag('$joined JOINED', _cmBlue),
            _Tag('$saved SAVED', _cmAmber),
            _Tag('${data.sanctions.length} SANCTIONS ON ACCOUNT', data.sanctions.isEmpty ? _cmGreen : _cmRed),
          ]);
          if (constraints.maxWidth < 850) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 12), status]);
          return Row(children: [Expanded(child: copy), const SizedBox(width: 20), Flexible(child: status)]);
        }),
      );
}

class _CommunityToolbar extends StatelessWidget {
  const _CommunityToolbar({required this.board, required this.sort, required this.search, required this.onBoard, required this.onSort, required this.onSearch, required this.onCreate, required this.onRefresh});
  final String board;
  final _CommunitySort sort;
  final TextEditingController search;
  final ValueChanged<String> onBoard;
  final ValueChanged<_CommunitySort> onSort;
  final ValueChanged<String> onSearch;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => _CommunityPanel(
        padding: const EdgeInsets.all(9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final item in _boards)
              ChoiceChip(label: Text(item), selected: board == item, onSelected: (_) => onBoard(item)),
          ]),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SegmentedButton<_CommunitySort>(
              segments: [for (final item in _CommunitySort.values) ButtonSegment(value: item, label: Text(item.label))],
              selected: {sort},
              onSelectionChanged: (values) => onSort(values.first),
              showSelectedIcon: false,
            ),
            SizedBox(width: 260, child: TextField(controller: search, onChanged: onSearch, decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search_rounded), hintText: 'Search posts and users…', border: OutlineInputBorder()))),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('Create post')),
            IconButton(tooltip: 'Refresh', onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
          ]),
        ]),
      );
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.board, required this.count, required this.sort});
  final String board;
  final int count;
  final _CommunitySort sort;
  @override
  Widget build(BuildContext context) => _CommunityPanel(
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(board == 'All' ? 'Home feed' : board, style: const TextStyle(color: _cmText, fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text('$count visible posts · sorted by ${sort.label}', style: const TextStyle(color: _cmMuted, fontSize: 10))])), _Tag(sort.label.toUpperCase(), _cmBlue)]),
      );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.saved, required this.selected, required this.onVote, required this.onComments, required this.onSave, required this.onHide, required this.onReport, required this.onBlock, required this.onMute});
  final Map<String, dynamic> post;
  final bool saved;
  final bool selected;
  final VoidCallback onVote;
  final VoidCallback onComments;
  final VoidCallback onSave;
  final VoidCallback onHide;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onMute;
  @override
  Widget build(BuildContext context) {
    final likes = _int(post['like_count'] ?? post['likes'] ?? post['reaction_count']);
    final comments = _int(post['comment_count'] ?? post['comments']);
    final author = _text(post['author_display_name'] ?? post['author_user_id']);
    final board = _text(post['board']);
    final status = _text(post['status']);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: selected ? const Color(0xFF132238) : _cmPanel, border: Border.all(color: selected ? _cmBlue : _cmLine), borderRadius: BorderRadius.circular(9)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(color: _cmPanel2, borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))),
          child: Column(children: [
            IconButton(tooltip: 'Upvote / toggle like', onPressed: onVote, icon: const Icon(Icons.arrow_upward_rounded, color: _cmBlue, size: 18)),
            Text('$likes', style: const TextStyle(color: _cmText, fontWeight: FontWeight.w900)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
                _Tag(board.toUpperCase(), _cmBlue),
                if (status != '—' && status != 'published') _Tag(status.toUpperCase(), _cmAmber),
                Text('Posted by $author · ${_relative(post['created_at'] ?? post['createdAt'])}', style: const TextStyle(color: _cmMuted, fontSize: 9)),
              ]),
              const SizedBox(height: 7),
              Text(_text(post['title']), style: const TextStyle(color: _cmText, fontSize: 17, fontWeight: FontWeight.w900, height: 1.2)),
              if (_text(post['body']) != '—') ...[
                const SizedBox(height: 7),
                Text(_text(post['body']), maxLines: selected ? 12 : 5, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _cmMuted, height: 1.45)),
              ],
              const SizedBox(height: 9),
              Wrap(spacing: 4, runSpacing: 4, children: [
                TextButton.icon(onPressed: onComments, icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15), label: Text('$comments comments')),
                TextButton.icon(onPressed: onSave, icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 15), label: Text(saved ? 'Saved' : 'Save')),
                TextButton.icon(onPressed: onHide, icon: const Icon(Icons.visibility_off_outlined, size: 15), label: const Text('Hide')),
                PopupMenuButton<String>(
                  tooltip: 'Post actions',
                  onSelected: (value) {
                    if (value == 'report') onReport();
                    if (value == 'mute') onMute();
                    if (value == 'block') onBlock();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'report', child: Text('Report post')),
                    PopupMenuItem(value: 'mute', child: Text('Mute author')),
                    PopupMenuItem(value: 'block', child: Text('Block author')),
                  ],
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Icon(Icons.more_horiz_rounded, color: _cmMuted, size: 18)),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InlineThread extends StatelessWidget {
  const _InlineThread({required this.post, required this.comments, required this.loading, required this.controller, required this.onReply, required this.onClose});
  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> comments;
  final bool loading;
  final TextEditingController controller;
  final VoidCallback onReply;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => _CommunityPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('THREAD DISCUSSION', style: TextStyle(color: _cmBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8))), IconButton(tooltip: 'Close discussion', onPressed: onClose, icon: const Icon(Icons.close_rounded))]),
          Text(_text(post['title']), style: const TextStyle(color: _cmText, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (comments.isEmpty)
            const Text('No comments yet. Start the discussion.', style: TextStyle(color: _cmMuted))
          else
            for (var i = 0; i < comments.length; i++)
              _CommentCard(comment: comments[i], index: i),
          const SizedBox(height: 12),
          TextField(controller: controller, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'Add to the discussion', hintText: 'Contribute substance. Challenge ideas, not people.', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: onReply, icon: const Icon(Icons.reply_rounded), label: const Text('Post comment')),
        ]),
      );
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.index});
  final Map<String, dynamic> comment;
  final int index;
  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: index == 0 ? 0 : 7),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        decoration: BoxDecoration(color: _cmPanel2, border: Border(left: BorderSide(color: index.isEven ? _cmBlue : _cmLine, width: 2)), borderRadius: BorderRadius.circular(5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_text(comment['author_display_name'] ?? comment['author_user_id'])} · ${_relative(comment['created_at'] ?? comment['createdAt'])}', style: const TextStyle(color: _cmBlue, fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(_text(comment['body']), style: const TextStyle(color: _cmText, height: 1.45)),
        ]),
      );
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.board, required this.joined, required this.onJoin});
  final String board;
  final bool joined;
  final VoidCallback onJoin;
  @override
  Widget build(BuildContext context) => _CommunityPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ABOUT COMMUNITY', style: TextStyle(color: _cmBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 6),
          Text(board, style: const TextStyle(color: _cmText, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(board == 'All' ? 'Your combined Sports Terminal community feed.' : _boardDescriptions[board] ?? 'Sports Terminal community board.', style: const TextStyle(color: _cmMuted, height: 1.4)),
          if (board != 'All') ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onJoin, icon: Icon(joined ? Icons.check_rounded : Icons.add_rounded), label: Text(joined ? 'Joined' : 'Join community'))),
          ],
        ]),
      );
}

class _JoinedCard extends StatelessWidget {
  const _JoinedCard({required this.joined, required this.onOpen});
  final Set<String> joined;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => _CommunityPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR COMMUNITIES', style: TextStyle(color: _cmAmber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 7),
          if (joined.isEmpty)
            const Text('Join communities to build a personalized home feed.', style: TextStyle(color: _cmMuted, fontSize: 10))
          else
            for (final board in joined)
              InkWell(onTap: () => onOpen(board), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [const Icon(Icons.forum_outlined, color: _cmBlue, size: 15), const SizedBox(width: 7), Expanded(child: Text(board, style: const TextStyle(color: _cmText, fontSize: 10, fontWeight: FontWeight.w800))), const Icon(Icons.chevron_right_rounded, color: _cmMuted, size: 15)]))),
        ]),
      );
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.blocks, required this.mutes, required this.sanctions});
  final int blocks;
  final int mutes;
  final int sanctions;
  @override
  Widget build(BuildContext context) => _CommunityPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SAFETY CONTROLS', style: TextStyle(color: _cmGreen, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 7),
          _RailMetric('Blocked users', '$blocks'),
          _RailMetric('Muted users', '$mutes'),
          _RailMetric('Account sanctions', '$sanctions'),
          const SizedBox(height: 6),
          const Text('Reports enter a shared moderation queue. Blocks, mutes and sanctions affect backend visibility and delivery—not just the current screen.', style: TextStyle(color: _cmMuted, fontSize: 9, height: 1.4)),
        ]),
      );
}

class _CommunityPrinciples extends StatelessWidget {
  const _CommunityPrinciples();
  @override
  Widget build(BuildContext context) => const _CommunityPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('COMMUNITY PRINCIPLES', style: TextStyle(color: _cmBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          SizedBox(height: 7),
          _Principle('Substance over engagement bait', 'Ranking should reward useful sports discussion rather than rage farming.'),
          _Principle('Transparent moderation', 'Reports, sanctions and moderator actions belong in an auditable trust system.'),
          _Principle('Identity without forced exposure', 'Users can build reputation while retaining profile/privacy controls.'),
          _Principle('Data-native discussion', 'Threads can eventually attach players, teams, games, trades, charts and notebooks as first-class objects.'),
        ]),
      );
}

class _Principle extends StatelessWidget {
  const _Principle(this.title, this.body);
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _cmText, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(body, style: const TextStyle(color: _cmMuted, fontSize: 9, height: 1.35))]));
}

class _RailMetric extends StatelessWidget {
  const _RailMetric(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: _cmMuted, fontSize: 9))), Text(value, style: const TextStyle(color: _cmText, fontSize: 10, fontWeight: FontWeight.w900))]));
}

class _CreatePostDialog extends StatefulWidget {
  const _CreatePostDialog({required this.initialBoard});
  final String initialBoard;
  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _entityId = TextEditingController();
  String _board = 'NBA General';
  String _entityType = '';

  @override
  void initState() {
    super.initState();
    _board = _boards.contains(widget.initialBoard) && widget.initialBoard != 'All' ? widget.initialBoard : 'NBA General';
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _entityId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create community post'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(value: _board, isExpanded: true, decoration: const InputDecoration(labelText: 'Community', border: OutlineInputBorder()), items: [for (final item in _boards.where((item) => item != 'All')) DropdownMenuItem(value: item, child: Text(item))], onChanged: (value) { if (value != null) setState(() => _board = value); }),
              const SizedBox(height: 10),
              TextField(controller: _title, maxLength: 180, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _body, minLines: 6, maxLines: 16, decoration: const InputDecoration(labelText: 'Body', hintText: 'Add context, sourcing, argument or question…', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(value: _entityType, decoration: const InputDecoration(labelText: 'Attach Sports Terminal object', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: '', child: Text('None')), DropdownMenuItem(value: 'player', child: Text('Player')), DropdownMenuItem(value: 'team', child: Text('Team')), DropdownMenuItem(value: 'game', child: Text('Game')), DropdownMenuItem(value: 'trade', child: Text('Trade scenario')), DropdownMenuItem(value: 'article', child: Text('Article'))], onChanged: (value) => setState(() => _entityType = value ?? ''))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _entityId, enabled: _entityType.isNotEmpty, decoration: const InputDecoration(labelText: 'Object ID', border: OutlineInputBorder()))),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _title.text.trim().isEmpty ? () {
            if (_title.text.trim().isEmpty) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A title is required.')));
          } : null, child: const Text('Publish')),
          FilledButton(
            onPressed: () {
              final title = _title.text.trim();
              final body = _body.text.trim();
              if (title.isEmpty || body.isEmpty) return;
              Navigator.of(context).pop(_PostDraft(board: _board, title: title, body: body, entityType: _entityType, entityId: _entityId.text.trim()));
            },
            child: const Text('Submit post'),
          ),
        ],
      );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = 'Spam or manipulation';
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Report post'),
        content: DropdownButtonFormField<String>(value: _reason, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()), items: [for (final item in const ['Spam or manipulation', 'Harassment or abuse', 'Threat or violence', 'Impersonation', 'Privacy / doxxing', 'Sexual or exploitative content', 'Copyright / rights concern', 'Misinformation / deceptive sourcing', 'Other Terms violation']) DropdownMenuItem(value: item, child: Text(item))], onChanged: (value) { if (value != null) setState(() => _reason = value); }),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(context).pop(_reason), child: const Text('Submit report'))],
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .4)));
}

class _CommunityPanel extends StatelessWidget {
  const _CommunityPanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _cmPanel, border: Border.all(color: _cmLine), borderRadius: BorderRadius.circular(9)), child: child);
}

class _PostDraft {
  const _PostDraft({required this.board, required this.title, required this.body, required this.entityType, required this.entityId});
  final String board;
  final String title;
  final String body;
  final String entityType;
  final String entityId;
}

String _text(Object? value) { final text = value?.toString().trim() ?? ''; return text.isEmpty ? '—' : text; }
int _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
DateTime _date(Object? value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
String _relative(Object? value) {
  final date = _date(value);
  if (date.millisecondsSinceEpoch == 0) return 'unknown time';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
