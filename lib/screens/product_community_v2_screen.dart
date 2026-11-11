import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/community_network_service.dart';
import '../services/trust_safety_service.dart';

const _cBg = Color(0xFF0D0F12);
const _cPanel = Color(0xFF11151A);
const _cPanel2 = Color(0xFF1E242B);
const _cLine = Color(0xFF2B3037);
const _cText = Color(0xFFE8EDF3);
const _cMuted = Color(0xFF8895A5);
const _cBlue = Color(0xFF63A9FF);
const _cGreen = Color(0xFF69C99A);
const _cAmber = Color(0xFFE2B866);
const _cRed = Color(0xFFE87979);

class ProductCommunityV2Screen extends StatefulWidget {
  const ProductCommunityV2Screen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductCommunityV2Screen> createState() =>
      _ProductCommunityV2ScreenState();
}

class _ProductCommunityV2ScreenState extends State<ProductCommunityV2Screen> {
  final CommunityNetworkService network = const CommunityNetworkService();
  final TrustSafetyService trust = const TrustSafetyService();
  final TextEditingController searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> boardsFuture;
  late Future<List<Map<String, dynamic>>> feedFuture;
  late Future<Map<String, dynamic>?> profileFuture;
  String selectedCommunity = '';
  String sort = 'hot';
  bool followedOnly = false;
  bool savedOnly = false;
  String search = '';

  @override
  void initState() {
    super.initState();
    boardsFuture = network.boards(widget.session);
    feedFuture = _loadFeed();
    profileFuture = network.userProfile(widget.session.userId);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadFeed() => network.feed(
        widget.session,
        communitySlug: selectedCommunity,
        sort: sort,
        followedOnly: followedOnly,
        savedOnly: savedOnly,
      );

  Future<void> _refresh() async {
    setState(() {
      boardsFuture = network.boards(widget.session);
      feedFuture = _loadFeed();
      profileFuture = network.userProfile(widget.session.userId);
    });
    await Future.wait([boardsFuture, feedFuture, profileFuture]);
  }

  void _changeFeed() {
    setState(() => feedFuture = _loadFeed());
  }

  Future<void> _createThread(List<Map<String, dynamic>> boards) async {
    final result = await showDialog<_ThreadDraft>(
      context: context,
      builder: (context) => _CreateThreadDialog(
        boards: boards,
        initialCommunity: selectedCommunity,
      ),
    );
    if (result == null) return;
    final created = await network.createThread(
      session: widget.session,
      communitySlug: result.communitySlug,
      title: result.title,
      body: result.body,
      flair: result.flair,
    );
    if (!mounted) return;
    _show(created == null
        ? 'Thread could not be published. Check the backend or moderation response.'
        : created['status'] == 'published'
            ? 'Thread published.'
            : 'Thread submitted for moderation review.');
    await _refresh();
  }

  Future<void> _vote(Map<String, dynamic> post, int direction) async {
    final current = _int(post['viewer_vote']);
    final next = current == direction ? 0 : direction;
    final updated = await network.vote(
      session: widget.session,
      postId: '${post['id']}',
      direction: next,
    );
    if (!mounted) return;
    if (updated == null) {
      _show('Vote could not be saved.');
      return;
    }
    _changeFeed();
  }

  Future<void> _save(Map<String, dynamic> post) async {
    final next = post['saved_by_viewer'] != true;
    final ok = await network.save(
      session: widget.session,
      postId: '${post['id']}',
      saved: next,
    );
    if (!mounted) return;
    if (!ok) _show('Saved-post state could not be updated.');
    _changeFeed();
  }

  Future<void> _follow(Map<String, dynamic> board) async {
    final next = board['following'] != true;
    final ok = await network.follow(
      session: widget.session,
      communitySlug: '${board['slug']}',
      followed: next,
    );
    if (!mounted) return;
    if (!ok) _show('Community follow state could not be updated.');
    await _refresh();
  }

  Future<void> _report(Map<String, dynamic> post) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report thread'),
        content: TextField(
          controller: reasonController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Reason and relevant context',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.trim().isEmpty) return;
    final result = await trust.report(
      session: widget.session,
      targetType: 'post',
      targetId: '${post['id']}',
      reason: reason.trim(),
    );
    if (!mounted) return;
    _show(result == null
        ? 'Report service unavailable.'
        : 'Report entered the moderation queue.');
  }

  Future<void> _relationship(Map<String, dynamic> post, bool block) async {
    final author = '${post['author_user_id'] ?? ''}';
    if (author.isEmpty || author == widget.session.userId) return;
    final ok = block
        ? await trust.block(
            session: widget.session,
            targetUserId: author,
            reason: 'Community user action',
          )
        : await trust.mute(
            session: widget.session,
            targetUserId: author,
            reason: 'Community user action',
          );
    if (!mounted) return;
    _show(ok ? (block ? 'User blocked.' : 'User muted.') : 'Action unavailable.');
    await _refresh();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _cBg,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: boardsFuture,
          builder: (context, boardsSnapshot) {
            final boards = boardsSnapshot.data ?? const <Map<String, dynamic>>[];
            final selectedBoard = boards.cast<Map<String, dynamic>?>().firstWhere(
                  (item) => '${item?['slug'] ?? ''}' == selectedCommunity,
                  orElse: () => null,
                );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CommunityHero(
                  profileFuture: profileFuture,
                  onCreate: boards.isEmpty ? null : () => _createThread(boards),
                ),
                const SizedBox(height: 12),

                LayoutBuilder(builder: (context, bounds) {
                  final communities = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                _CommunityPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: _SectionLabel('COMMUNITIES'),
                          ),
                          Text(
                            '${boards.length} available',
                            style: const TextStyle(color: _cMuted, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CommunityChoice(
                            label: 'All communities',
                            selected: selectedCommunity.isEmpty,
                            onTap: () {
                              selectedCommunity = '';
                              _changeFeed();
                            },
                          ),
                          const SizedBox(height: 6),
                          for (final board in boards) ...[
                            _CommunityChoice(
                              label: '${board['name'] ?? board['slug']}',
                              badge: board['following'] == true ? 'FOLLOWING' : '',
                              selected: selectedCommunity == '${board['slug']}',
                              onTap: () {
                                selectedCommunity = '${board['slug']}';
                                _changeFeed();
                              },
                            ),
                            const SizedBox(height: 5),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                    ],
                  );
                  final feed = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                if (selectedBoard != null) ...[
                  const SizedBox(height: 10),
                  _BoardProfile(
                    board: selectedBoard,
                    onFollow: () => _follow(selectedBoard),
                  ),
                ],
                const SizedBox(height: 12),
                _CommunityPanel(
                  child: Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 270,
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) => setState(() => search = value),
                          style: const TextStyle(color: _cText),
                          decoration: const InputDecoration(
                            hintText: 'Search visible threads…',
                            prefixIcon: Icon(Icons.search_rounded),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      for (final item in const [
                        ('hot', 'Hot'),
                        ('new', 'New'),
                        ('top', 'Top'),
                        ('controversial', 'Controversial'),
                      ])
                        ChoiceChip(
                          label: Text(item.$2),
                          selected: sort == item.$1,
                          onSelected: (_) {
                            sort = item.$1;
                            _changeFeed();
                          },
                        ),
                      FilterChip(
                        label: const Text('Following'),
                        selected: followedOnly,
                        onSelected: (value) {
                          followedOnly = value;
                          if (value) savedOnly = false;
                          _changeFeed();
                        },
                      ),
                      FilterChip(
                        label: const Text('Saved'),
                        selected: savedOnly,
                        onSelected: (value) {
                          savedOnly = value;
                          if (value) followedOnly = false;
                          _changeFeed();
                        },
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: feedFuture,
                  builder: (context, feedSnapshot) {
                    if (feedSnapshot.connectionState != ConnectionState.done) {
                      return const _CommunityPanel(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (feedSnapshot.hasError) {
                      return _CommunityPanel(
                        child: Text(
                          'Community feed unavailable: ${feedSnapshot.error}',
                          style: const TextStyle(color: _cMuted),
                        ),
                      );
                    }
                    final query = search.trim().toLowerCase();
                    final rows = (feedSnapshot.data ?? const [])
                        .where(
                          (post) => query.isEmpty ||
                              '${post['title']} ${post['body']} ${post['author_display_name']} ${post['flair']} ${post['community_slug']}'
                                  .toLowerCase()
                                  .contains(query),
                        )
                        .toList();
                    if (rows.isEmpty) {
                      return const _CommunityPanel(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No threads match this feed. Follow a community, change the sort, clear the filter or start a discussion.',
                            style: TextStyle(color: _cMuted),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final post in rows) ...[
                          _ThreadCard(
                            session: widget.session,
                            post: post,
                            onVote: (direction) => _vote(post, direction),
                            onSave: () => _save(post),
                            onReport: () => _report(post),
                            onBlock: () => _relationship(post, true),
                            onMute: () => _relationship(post, false),
                            onOpen: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                settings: RouteSettings(
                                  name: '/community/thread/${post['id']}',
                                ),
                                builder: (_) => CommunityThreadPage(
                                  session: widget.session,
                                  initialPost: post,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),

                    ],
                  );
                  if (bounds.maxWidth < 1180) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [communities, const SizedBox(height: 12), feed],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 226, child: communities),
                      const SizedBox(width: 15),
                      Expanded(child: feed),
                      const SizedBox(width: 15),
                      SizedBox(width: 238,
                        child: _CommunityRightRail(
                          profileFuture: profileFuture,
                          boardCount: boards.length,
                        )),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                const _NetworkPrinciples(),
              ],
            );
          },
        ),
      );
}

class CommunityThreadPage extends StatefulWidget {
  const CommunityThreadPage({
    super.key,
    required this.session,
    required this.initialPost,
  });

  final AppSession session;
  final Map<String, dynamic> initialPost;

  @override
  State<CommunityThreadPage> createState() => _CommunityThreadPageState();
}

class _CommunityThreadPageState extends State<CommunityThreadPage> {
  final CommunityNetworkService network = const CommunityNetworkService();
  final TextEditingController replyController = TextEditingController();
  late Future<List<Map<String, dynamic>>> commentsFuture;
  String parentCommentId = '';
  String parentLabel = '';

  @override
  void initState() {
    super.initState();
    commentsFuture = network.comments(
      session: widget.session,
      postId: '${widget.initialPost['id']}',
    );
  }

  @override
  void dispose() {
    replyController.dispose();
    super.dispose();
  }

  Future<void> _reply() async {
    final body = replyController.text.trim();
    if (body.isEmpty) return;
    final result = await network.reply(
      session: widget.session,
      postId: '${widget.initialPost['id']}',
      body: body,
      parentCommentId: parentCommentId,
    );
    if (!mounted) return;
    if (result != null) {
      replyController.clear();
      setState(() {
        parentCommentId = '';
        parentLabel = '';
        commentsFuture = network.comments(
          session: widget.session,
          postId: '${widget.initialPost['id']}',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _cBg,
        appBar: AppBar(
          backgroundColor: _cPanel,
          foregroundColor: _cText,
          title: Text('${widget.initialPost['community_slug']} / thread'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ThreadCard(
                      session: widget.session,
                      post: widget.initialPost,
                      detailed: true,
                    ),
                    const SizedBox(height: 12),
                    _CommunityPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel('JOIN THE DISCUSSION'),
                          if (parentCommentId.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Replying to $parentLabel',
                                    style: const TextStyle(
                                      color: _cBlue,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    parentCommentId = '';
                                    parentLabel = '';
                                  }),
                                  child: const Text('Cancel reply'),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            controller: replyController,
                            minLines: 3,
                            maxLines: 10,
                            style: const TextStyle(color: _cText),
                            decoration: const InputDecoration(
                              hintText: 'Add evidence, analysis, context or a question…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _reply,
                            icon: const Icon(Icons.reply_rounded),
                            label: const Text('Post reply'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: commentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const _CommunityPanel(
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                        return _CommunityPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel('${rows.length} COMMENTS'),
                              const SizedBox(height: 8),
                              if (rows.isEmpty)
                                const Text(
                                  'No replies yet. Start the thread.',
                                  style: TextStyle(color: _cMuted),
                                ),
                              for (final comment in rows)
                                _ThreadedComment(
                                  comment: comment,
                                  onReply: () => setState(() {
                                    parentCommentId = '${comment['id']}';
                                    parentLabel =
                                        '${comment['display_name'] ?? comment['author_user_id']}';
                                  }),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _CommunityHero extends StatelessWidget {
  const _CommunityHero({required this.profileFuture, required this.onCreate});
  final Future<Map<String, dynamic>?> profileFuture;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 13, 12, 15),
    child: Row(children: [
      const Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Arcside Community', style: TextStyle(
            fontSize: 25, fontWeight: FontWeight.w900, color: _cText)),
          SizedBox(height: 5),
          Text('Basketball discussions, research, and the people behind the numbers.',
            style: TextStyle(fontSize: 12, color: _cMuted)),
        ],
      )),
      const SizedBox(width: 10),
      FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded, size: 17),
        label: const Text('Create post')),
    ]),
  );
}

class _CommunityRightRail extends StatelessWidget {
  const _CommunityRightRail({required this.profileFuture, required this.boardCount});
  final Future<Map<String, dynamic>?> profileFuture;
  final int boardCount;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _CommunityPanel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('ABOUT ARCSIDE'),
          const SizedBox(height: 11),
          const Text('Basketball news, thoughtful analysis and conversation in one community.',
              style: TextStyle(color: _cText, height: 1.45)),
          const Divider(height: 26, color: _cLine),
          Text('$boardCount communities', style: const TextStyle(
              color: _cText, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Upvote useful posts, save research, and join team discussions.',
              style: TextStyle(color: _cMuted, fontSize: 12, height: 1.5)),
        ],
      )),
      const SizedBox(height: 12),
      _CommunityPanel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('YOUR ACTIVITY'),
          const SizedBox(height: 11),
          FutureBuilder<Map<String, dynamic>?>(
            future: profileFuture,
            builder: (context, snapshot) {
              final reputation = snapshot.data?['reputation'];
              final info = reputation is Map ? reputation : const {};
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${info['reputation'] ?? 0} reputation',
                    style: const TextStyle(color: _cText,
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text('${info['posts'] ?? 0} posts · ${info['comments'] ?? 0} comments',
                    style: const TextStyle(color: _cMuted, fontSize: 12)),
              ]);
            },
          ),
        ],
      )),
      const SizedBox(height: 12),
      const _CommunityPanel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('COMMUNITY GUIDELINES'),
          SizedBox(height: 10),
          Text('• Use credible sources\n• Be respectful\n• No spam or harassment\n• Keep posts on topic',
              style: TextStyle(color: _cMuted, fontSize: 12, height: 1.7)),
          SizedBox(height: 12),
          Text('ARCSIDE', style: TextStyle(
              color: _cBlue, fontWeight: FontWeight.w900)),
        ],
      )),
    ],
  );
}

class _BoardProfile extends StatelessWidget {
  const _BoardProfile({required this.board, required this.onFollow});

  final Map<String, dynamic> board;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final rules = board['rules'] is List ? board['rules'] as List : const [];
    return _CommunityPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${board['name'] ?? board['slug']}',
                      style: const TextStyle(
                        color: _cText,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${board['description'] ?? ''}',
                      style: const TextStyle(color: _cMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onFollow,
                icon: Icon(
                  board['following'] == true
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                ),
                label: Text(board['following'] == true ? 'Following' : 'Follow'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill('MEMBERS', '${board['member_count'] ?? 0}'),
              _MetricPill('THREADS', '${board['post_count'] ?? 0}'),
              _MetricPill('CATEGORY', '${board['category'] ?? 'Community'}'),
              if ('${board['team_abbreviation'] ?? ''}'.isNotEmpty)
                _MetricPill('TEAM', '${board['team_abbreviation']}'),
            ],
          ),
          if (rules.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionLabel('COMMUNITY RULES'),
            const SizedBox(height: 6),
            for (var index = 0; index < rules.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${index + 1}. ${rules[index]}',
                  style: const TextStyle(color: _cMuted, fontSize: 11, height: 1.4),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.session,
    required this.post,
    this.onVote, this.onSave, this.onReport, this.onBlock,
    this.onMute, this.onOpen, this.detailed = false,
  });

  final AppSession session;
  final Map<String, dynamic> post;
  final ValueChanged<int>? onVote;
  final VoidCallback? onSave;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onMute;
  final VoidCallback? onOpen;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final viewerVote = _int(post['viewer_vote']);
    final own = '${post['author_user_id']}' == session.userId;
    final author = post['author_handle']?.toString().isNotEmpty == true
        ? 'u/${post['author_handle']}'
        : '${post['author_display_name'] ?? 'member'}';
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 14),
        decoration: const BoxDecoration(border:
          Border(bottom: BorderSide(color: _cLine))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
              CircleAvatar(radius: 14, backgroundColor: _cPanel2,
                child: Text(('${post['community_slug'] ?? 'A'}').isEmpty
                    ? 'A' : '${post['community_slug'] ?? 'A'}'[0].toUpperCase(),
                  style: const TextStyle(color: _cBlue,
                    fontWeight: FontWeight.w900, fontSize: 12))),
              Text('r/${post['community_slug'] ?? 'arcside'}',
                style: const TextStyle(color: _cText,
                  fontWeight: FontWeight.w900, fontSize: 12)),
              Text('· ${_relative('${post['created_at'] ?? ''}')}',
                style: const TextStyle(color: _cMuted, fontSize: 11)),
              Text('· $author', style: const TextStyle(
                color: _cMuted, fontSize: 11)),
              if (post['pinned'] == true)
                const Icon(Icons.push_pin_rounded, color: _cGreen, size: 14),
              if (post['flair'] != null) _Badge('${post['flair']}'),
            ]),
            const SizedBox(height: 10),
            InkWell(onTap: onOpen, child: Text(
              '${post['title'] ?? ''}',
              style: const TextStyle(color: _cText,
                fontSize: 18, fontWeight: FontWeight.w800,
                height: 1.28))),
            const SizedBox(height: 9),
            Text('${post['body'] ?? ''}',
              maxLines: detailed ? null : 5,
              overflow: detailed ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(color: _cMuted, height: 1.47,
                fontSize: 13)),
            const SizedBox(height: 14),
            Wrap(spacing: 7, runSpacing: 7, children: [
              Container(
                decoration: BoxDecoration(color: _cPanel2,
                    borderRadius: BorderRadius.circular(30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Upvote',
                    onPressed: onVote == null ? null : () => onVote!(1),
                    icon: Icon(Icons.arrow_upward_rounded, size: 18,
                      color: viewerVote == 1 ? _cGreen : _cText)),
                  Text('${post['score'] ?? 0}',
                    style: const TextStyle(color: _cText,
                      fontWeight: FontWeight.w800, fontSize: 12)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Downvote',
                    onPressed: onVote == null || own ? null : () => onVote!(-1),
                    icon: Icon(Icons.arrow_downward_rounded, size: 18,
                      color: viewerVote == -1 ? _cRed : _cText)),
                ]),
              ),
              _PostAction(icon: Icons.chat_bubble_outline_rounded,
                label: '${post['comment_count'] ?? 0} comments', onPressed: onOpen),
              _PostAction(
                icon: post['saved_by_viewer'] == true
                    ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                label: post['saved_by_viewer'] == true ? 'Saved' : 'Save',
                onPressed: onSave),
              if (onReport != null)
                _PostAction(icon: Icons.flag_outlined,
                  label: 'Report', onPressed: onReport),
              if (!own && onMute != null)
                _PostAction(icon: Icons.volume_off_outlined,
                  label: 'Mute', onPressed: onMute),
              if (!own && onBlock != null)
                _PostAction(icon: Icons.block_rounded,
                  label: 'Block', onPressed: onBlock),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({required this.icon, required this.label,
    required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      backgroundColor: _cPanel2,
      foregroundColor: _cText,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    onPressed: onPressed,
    icon: Icon(icon, size: 15),
    label: Text(label, style: const TextStyle(fontSize: 12)),
  );
}

class _ThreadedComment extends StatelessWidget {
  const _ThreadedComment({required this.comment, required this.onReply});

  final Map<String, dynamic> comment;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final depth = _int(comment['depth']).clamp(0, 8);
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: depth == 0 ? _cLine : _cBlue)),
          color: depth == 0 ? Colors.transparent : _cPanel2.withValues(alpha: .35),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${comment['handle']?.toString().isNotEmpty == true ? '@${comment['handle']}' : comment['display_name'] ?? comment['author_user_id']} · ${_relative('${comment['created_at'] ?? ''}')}',
              style: const TextStyle(
                color: _cBlue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${comment['body'] ?? ''}',
              style: const TextStyle(color: _cText, height: 1.45),
            ),
            TextButton.icon(
              onPressed: onReply,
              icon: const Icon(Icons.reply_rounded, size: 14),
              label: const Text('Reply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateThreadDialog extends StatefulWidget {
  const _CreateThreadDialog({required this.boards, required this.initialCommunity});

  final List<Map<String, dynamic>> boards;
  final String initialCommunity;

  @override
  State<_CreateThreadDialog> createState() => _CreateThreadDialogState();
}

class _CreateThreadDialogState extends State<_CreateThreadDialog> {
  final title = TextEditingController();
  final body = TextEditingController();
  late String community;
  String flair = 'Discussion';

  @override
  void initState() {
    super.initState();
    title.addListener(_refreshValidity);
    body.addListener(_refreshValidity);
    final slugs = widget.boards.map((item) => '${item['slug']}').toSet();
    community = slugs.contains(widget.initialCommunity)
        ? widget.initialCommunity
        : slugs.first;
  }

  void _refreshValidity() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    title.removeListener(_refreshValidity);
    body.removeListener(_refreshValidity);
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create community thread'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: community,
                decoration: const InputDecoration(labelText: 'Community'),
                items: [
                  for (final item in widget.boards)
                    DropdownMenuItem(
                      value: '${item['slug']}',
                      child: Text('${item['name']}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => community = value);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: flair,
                decoration: const InputDecoration(labelText: 'Flair'),
                items: [
                  for (final item in const [
                    'Discussion',
                    'Analysis',
                    'News',
                    'Question',
                    'Trade Idea',
                    'Film',
                    'Historical',
                    'OC',
                  ])
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => flair = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: title,
                maxLength: 220,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: body,
                minLines: 6,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: title.text.trim().isEmpty || body.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _ThreadDraft(
                        communitySlug: community,
                        title: title.text.trim(),
                        body: body.text.trim(),
                        flair: flair,
                      ),
                    ),
            child: const Text('Publish thread'),
          ),
        ],
      );
}

class _ThreadDraft {
  const _ThreadDraft({
    required this.communitySlug,
    required this.title,
    required this.body,
    required this.flair,
  });

  final String communitySlug;
  final String title;
  final String body;
  final String flair;
}

class _CommunityChoice extends StatelessWidget {
  const _CommunityChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = '',
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String badge;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFF17273A) : _cPanel2,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? _cBlue : _cLine),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _cText : _cMuted,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                )),
                if (badge.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded, size: 12, color: _cGreen),
                ],
              ],
            ),
          ),
        ),
      );
}

/// A light structural region: Reddit-style dividers rather than a field of
/// bordered cards. Deliberate surfaces are reserved for controls and actions.
class _CommunityPanel extends StatelessWidget {
  const _CommunityPanel({required this.child,
    this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding, child: child);
}

class _MetricPill extends StatelessWidget {
  const _MetricPill(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _cPanel2,
          border: Border.all(color: _cLine),
        ),
        child: Text(
          '$label  $value',
          style: const TextStyle(
            color: _cMuted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _cPanel2,
          border: Border.all(color: _cLine),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _cAmber,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _cBlue,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      );
}

class _NetworkPrinciples extends StatelessWidget {
  const _NetworkPrinciples();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: _CommunityPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('NETWORK DESIGN'),
              SizedBox(height: 6),
              Text(
                'Arcside community ranking is bounded and auditable rather than an opaque engagement maximizer. Blocks are bilateral for conversation visibility, mutes remove authors from feeds, sanctions can prevent publication, reports enter a moderation queue, and moderation actions are written to the platform audit log.',
                style: TextStyle(color: _cMuted, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _relative(String iso) {
  try {
    final then = DateTime.parse(iso).toUtc();
    final delta = DateTime.now().toUtc().difference(then);
    if (delta.inDays >= 365) return '${(delta.inDays / 365).floor()}y';
    if (delta.inDays >= 1) return '${delta.inDays}d';
    if (delta.inHours >= 1) return '${delta.inHours}h';
    if (delta.inMinutes >= 1) return '${delta.inMinutes}m';
    return 'now';
  } catch (_) {
    return iso;
  }
}
