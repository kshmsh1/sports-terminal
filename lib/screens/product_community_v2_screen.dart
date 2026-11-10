import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/community_network_service.dart';
import '../services/trust_safety_service.dart';

const _cBg = Color(0xFF090D12);
const _cPanel = Color(0xFF0F151C);
const _cPanel2 = Color(0xFF141C25);
const _cLine = Color(0xFF263342);
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
      builder: (context, snapshot) {
        final boards = snapshot.data ?? const <Map<String, dynamic>>[];
        final selectedBoard = boards.cast<Map<String, dynamic>?>().firstWhere(
          (board) => '${board?['slug'] ?? ''}' == selectedCommunity,
          orElse: () => null,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                const Icon(Icons.forum_outlined, color: _cBlue, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Text('Community',
                  style: TextStyle(color: _cText, fontSize: 23,
                    fontWeight: FontWeight.w900))),
                OutlinedButton.icon(
                  onPressed: boards.isEmpty
                      ? null : () => _createThread(boards),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create post'),
                ),
              ]),
            ),
            LayoutBuilder(builder: (context, bounds) {
              final desktop = bounds.maxWidth >= 1070;
              final middle = _communityFeed(boards, selectedBoard);
              if (!desktop) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _communityMobileNav(boards),
                    const SizedBox(height: 14),
                    middle,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 210, child: _communitySidebar(boards)),
                  const SizedBox(width: 28),
                  Expanded(child: middle),
                  const SizedBox(width: 28),
                  SizedBox(width: 250, child: _CommunityRightRail(
                    profileFuture: profileFuture,
                    boardCount: boards.length,
                  )),
                ],
              );
            }),
          ],
        );
      },
    ),
  );

  Widget _communitySidebar(List<Map<String, dynamic>> boards) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CommunityChoice(
          label: 'Home', selected: selectedCommunity.isEmpty &&
              !followedOnly && !savedOnly,
          icon: Icons.home_outlined,
          onTap: () {
            selectedCommunity = '';
            followedOnly = false;
            savedOnly = false;
            _changeFeed();
          },
        ),
        _CommunityChoice(
          label: 'Following', icon: Icons.people_outline,
          selected: followedOnly,
          onTap: () {
            selectedCommunity = '';
            followedOnly = true;
            savedOnly = false;
            _changeFeed();
          },
        ),
        _CommunityChoice(
          label: 'Saved', icon: Icons.bookmark_outline,
          selected: savedOnly,
          onTap: () {
            selectedCommunity = '';
            followedOnly = false;
            savedOnly = true;
            _changeFeed();
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 27, 0, 10),
          child: _SectionLabel('COMMUNITIES'),
        ),
        for (final board in boards)
          _CommunityChoice(
            label: '${board['name'] ?? board['slug']}',
            icon: Icons.tag_rounded,
            selected: selectedCommunity == '${board['slug']}',
            badge: board['following'] == true ? 'Following' : '',
            onTap: () {
              selectedCommunity = '${board['slug']}';
              followedOnly = false;
              savedOnly = false;
              _changeFeed();
            },
          ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('ARCSIDE · Basketball discussion',
            style: TextStyle(color: _cMuted, fontSize: 10)),
        ),
      ]);

  Widget _communityMobileNav(List<Map<String, dynamic>> boards) =>
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _CommunityChoice(
          label: 'Home', icon: Icons.home_outlined,
          selected: selectedCommunity.isEmpty,
          onTap: () {
            selectedCommunity = '';
            _changeFeed();
          },
        ),
        for (final board in boards)
          SizedBox(width: 145, child: _CommunityChoice(
            label: '${board['name'] ?? board['slug']}',
            icon: Icons.tag_rounded,
            selected: selectedCommunity == '${board['slug']}',
            onTap: () {
              selectedCommunity = '${board['slug']}';
              _changeFeed();
            },
          )),
      ]),
    );

  Widget _communityFeed(
      List<Map<String, dynamic>> boards, Map<String, dynamic>? selectedBoard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedBoard != null) ...[
          _BoardProfile(
            board: selectedBoard,
            onFollow: () => _follow(selectedBoard),
          ),
          const SizedBox(height: 14),
        ],
        Row(children: [
          TextButton(
            onPressed: () {
              followedOnly = false;
              savedOnly = false;
              _changeFeed();
            },
            child: Text('For you', style: TextStyle(
              fontWeight: FontWeight.w900,
              color: followedOnly ? _cMuted : _cText)),
          ),
          const SizedBox(width: 13),
          TextButton(
            onPressed: () {
              followedOnly = true;
              savedOnly = false;
              _changeFeed();
            },
            child: Text('Following', style: TextStyle(
              fontWeight: FontWeight.w900,
              color: followedOnly ? _cText : _cMuted)),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh feed', onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: _cMuted),
          ),
        ]),
        const Divider(height: 1, color: _cLine),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          onChanged: (value) => setState(() => search = value),
          style: const TextStyle(color: _cText),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search community posts',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true, fillColor: _cPanel2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
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
            label: const Text('Saved'),
            selected: savedOnly,
            onSelected: (value) {
              savedOnly = value;
              if (value) followedOnly = false;
              _changeFeed();
            },
          ),
        ]),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: feedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Community feed unavailable: ${snapshot.error}',
                  style: const TextStyle(color: _cMuted)),
              );
            }
            final query = search.toLowerCase().trim();
            final posts = (snapshot.data ?? const <Map<String, dynamic>>[])
                .where((post) => query.isEmpty ||
                  '${post['title']} ${post['body']} '
                  '${post['author_display_name']} ${post['flair']} '
                  '${post['community_slug']}'.toLowerCase().contains(query))
                .toList();
            if (posts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No posts match this feed. Try another sort or community.',
                  style: TextStyle(color: _cMuted)),
              );
            }
            return Column(children: [
              for (final post in posts)
                _ThreadCard(
                  session: widget.session, post: post,
                  onVote: (direction) => _vote(post, direction),
                  onSave: () => _save(post),
                  onReport: () => _report(post),
                  onBlock: () => _relationship(post, true),
                  onMute: () => _relationship(post, false),
                  onOpen: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      settings: RouteSettings(
                        name: '/community/thread/${post['id']}'),
                      builder: (_) => CommunityThreadPage(
                        session: widget.session, initialPost: post),
                    ),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
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

/// Flat Reddit-style discussion post. Existing vote, save and moderation
/// callbacks are preserved; this only changes the layout.
class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.session,
    required this.post,
    this.onVote,
    this.onSave,
    this.onReport,
    this.onBlock,
    this.onMute,
    this.onOpen,
    this.detailed = false,
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
    final slug = '${post['community_slug'] ?? 'basketball'}';
    final user = post['author_handle']?.toString().isNotEmpty == true
        ? 'u/${post['author_handle']}'
        : '${post['author_display_name'] ?? 'member'}';
    final saved = post['saved_by_viewer'] == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _cLine)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 14, backgroundColor: const Color(0xFF243853),
            child: Text(slug.isEmpty ? 'a' : slug[0].toUpperCase(),
              style: const TextStyle(color: _cText,
                fontSize: 12, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text('r/$slug', maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _cText,
              fontSize: 12, fontWeight: FontWeight.w900))),
          const SizedBox(width: 7),
          Expanded(child: Text('· $user · ${_relative('${post['created_at'] ?? ''}')}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _cMuted, fontSize: 11))),
          PopupMenuButton<String>(
            tooltip: 'Post options',
            icon: const Icon(Icons.more_horiz_rounded, color: _cMuted),
            onSelected: (action) {
              switch (action) {
                case 'save': onSave?.call();
                case 'report': onReport?.call();
                case 'mute': onMute?.call();
                case 'block': onBlock?.call();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'save',
                child: Text(saved ? 'Unsave' : 'Save post')),
              if (onReport != null)
                const PopupMenuItem(value: 'report',
                  child: Text('Report')),
              if (!own && onMute != null)
                const PopupMenuItem(value: 'mute',
                  child: Text('Mute author')),
              if (!own && onBlock != null)
                const PopupMenuItem(value: 'block',
                  child: Text('Block author')),
            ],
          ),
        ]),
        const SizedBox(height: 6),
        InkWell(
          onTap: onOpen,
          child: Text('${post['title'] ?? ''}',
            style: const TextStyle(fontSize: 18,
              fontWeight: FontWeight.w800, color: _cText, height: 1.24)),
        ),
        if ('${post['body'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 9),
          Text('${post['body'] ?? ''}',
            maxLines: detailed ? null : 4,
            overflow: detailed ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(color: _cMuted,
              fontSize: 13, height: 1.45)),
        ],
        if ('${post['flair'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text('${post['flair']}',
            style: const TextStyle(color: _cBlue,
              fontSize: 11, fontWeight: FontWeight.w800)),
        ],
        if (post['pinned'] == true) ...[
          const SizedBox(height: 4),
          const Text('Pinned by moderators',
            style: TextStyle(color: _cGreen, fontSize: 10)),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 9, runSpacing: 7, children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: _cPanel2,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Upvote',
                visualDensity: VisualDensity.compact,
                onPressed: onVote == null || own ? null : () => onVote!(1),
                icon: Icon(Icons.arrow_upward_rounded, size: 18,
                  color: viewerVote == 1 ? _cGreen : _cMuted),
              ),
              Text('${post['score'] ?? 0}',
                style: const TextStyle(color: _cText,
                  fontSize: 12, fontWeight: FontWeight.w800)),
              IconButton(
                tooltip: 'Downvote',
                visualDensity: VisualDensity.compact,
                onPressed: onVote == null || own ? null : () => onVote!(-1),
                icon: Icon(Icons.arrow_downward_rounded, size: 18,
                  color: viewerVote == -1 ? _cRed : _cMuted),
              ),
            ]),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(backgroundColor: _cPanel2),
            onPressed: onOpen,
            icon: const Icon(Icons.mode_comment_outlined, size: 16),
            label: Text('${post['comment_count'] ?? 0} comments'),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(backgroundColor: _cPanel2),
            onPressed: onSave,
            icon: Icon(saved ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded, size: 16),
            label: Text(saved ? 'Saved' : 'Save'),
          ),
        ]),
      ]),
    );
  }
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
    this.icon = Icons.tag_rounded,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String badge;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF202E3E) : Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        child: Row(children: [
          Icon(icon, color: selected ? _cText : _cMuted, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
            overflow: TextOverflow.ellipsis, maxLines: 1,
            style: TextStyle(
              color: selected ? _cText : _cMuted,
              fontSize: 12, fontWeight: selected
                  ? FontWeight.w800 : FontWeight.w600))),
          if (badge.isNotEmpty)
            const Icon(Icons.check_circle_outline_rounded,
              size: 13, color: _cGreen),
        ]),
      ),
    ),
  );
}

class _CommunityPanel extends StatelessWidget {
  const _CommunityPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: _cPanel,
          border: Border.all(color: _cLine),
        ),
        child: child,
      );
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
