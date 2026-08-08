import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/trust_safety_service.dart';

const _networkNavy = Color(0xFF071A33);
const _networkBlue = Color(0xFF2563EB);
const _networkOrange = Color(0xFFFF7A1A);
const _networkGreen = Color(0xFF059669);
const _networkInk = Color(0xFF102033);
const _networkMuted = Color(0xFF667085);
const _networkLine = Color(0xFFE3E8F0);
const _networkSoft = Color(0xFFF6F8FC);

const _communityBoards = [
  'All',
  'NBA General',
  'Team Rooms',
  'Fantasy',
  'Product Feedback',
  'Organization',
];

class ProductConnectedCommunityScreen extends StatefulWidget {
  const ProductConnectedCommunityScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductConnectedCommunityScreen> createState() =>
      _ProductConnectedCommunityScreenState();
}

class _ProductConnectedCommunityScreenState
    extends State<ProductConnectedCommunityScreen> {
  final TrustSafetyService service = const TrustSafetyService();
  String board = 'All';
  late Future<TrustSafetySnapshot> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<TrustSafetySnapshot> _load() {
    return service.loadCommunity(session: widget.session, board: board);
  }

  Future<void> _refresh() async {
    setState(() {
      future = _load();
    });
    await future;
  }

  Future<void> _createPost() async {
    final value = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _NewPostDialog(initialBoard: board),
    );
    if (value == null) return;
    final post = await service.createPost(
      session: widget.session,
      board: value['board'] ?? 'NBA General',
      title: value['title'] ?? '',
      body: value['body'] ?? '',
    );
    if (!mounted) return;
    _show(post == null
        ? 'Community service is offline. The post was not published.'
        : post['status'] == 'published'
            ? 'Post published.'
            : 'Post submitted for moderation review.');
    await _refresh();
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final result = await service.toggleLike(
      session: widget.session,
      postId: post['id']?.toString() ?? '',
    );
    if (!mounted) return;
    if (result == null) {
      _show('Community service is offline.');
      return;
    }
    await _refresh();
  }

  Future<void> _comments(Map<String, dynamic> post) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CommentsDialog(
        session: widget.session,
        post: post,
        service: service,
      ),
    );
    await _refresh();
  }

  Future<void> _report(Map<String, dynamic> post) async {
    final reason = await _textDialog(
      title: 'Report thread',
      label: 'Why should this thread be reviewed?',
    );
    if (reason == null || reason.trim().isEmpty) return;
    final result = await service.report(
      session: widget.session,
      targetType: 'post',
      targetId: post['id']?.toString() ?? '',
      reason: reason,
    );
    if (!mounted) return;
    _show(result == null
        ? 'Report service is offline.'
        : 'Report submitted to the moderation queue.');
  }

  Future<void> _relationship(
    Map<String, dynamic> post,
    String action,
  ) async {
    final author = post['author_user_id']?.toString() ?? '';
    if (author.isEmpty || author == widget.session.userId) return;
    final success = action == 'block'
        ? await service.block(
            session: widget.session,
            targetUserId: author,
            reason: 'Community user action',
          )
        : await service.mute(
            session: widget.session,
            targetUserId: author,
            reason: 'Community user action',
          );
    if (!mounted) return;
    _show(success
        ? '${action == 'block' ? 'Blocked' : 'Muted'} $author.'
        : 'Trust service is offline.');
    await _refresh();
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TrustSafetySnapshot>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _NetworkSurface(
              child: Text(
                'Loading moderated community...',
                style: TextStyle(color: _networkMuted),
              ),
            );
          }
          if (snapshot.hasError) {
            return _NetworkSurface(
              child: Text('Community unavailable: ${snapshot.error}'),
            );
          }
          final data = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NetworkHero(
                eyebrow: 'MODERATED SPORTS NETWORK',
                title: 'Community with real safety controls.',
                body:
                    'Authenticated threads, comments, reactions, reports, blocks, mutes, sanctions and immutable moderation audit events now share one backend contract.',
                status: data.remoteAvailable ? 'LIVE SERVICE' : 'CACHED READ',
              ),
              const SizedBox(height: 18),
              _NetworkMetrics(
                items: [
                  _NetworkMetric('Visible threads', '${data.posts.length}', board),
                  _NetworkMetric('Blocked users', '${data.blocks.length}', 'hidden both ways'),
                  _NetworkMetric('Muted users', '${data.mutes.length}', 'feed filtering'),
                  _NetworkMetric('Sanctions', '${data.sanctions.length}', 'account history'),
                ],
              ),
              const SizedBox(height: 18),
              _NetworkSurface(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final item in _communityBoards)
                      ChoiceChip(
                        label: Text(item),
                        selected: board == item,
                        selectedColor: _networkNavy,
                        labelStyle: TextStyle(
                          color: board == item ? Colors.white : _networkInk,
                          fontWeight: FontWeight.w900,
                        ),
                        onSelected: (_) {
                          setState(() {
                            board = item;
                            future = _load();
                          });
                        },
                      ),
                    IconButton(
                      tooltip: 'Refresh community',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    FilledButton.icon(
                      onPressed: _createPost,
                      icon: const Icon(Icons.add_comment_rounded),
                      label: const Text('Create thread'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _NetworkSurface(
                padding: EdgeInsets.zero,
                child: data.posts.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No published threads are visible in this board. Create the first thread or refresh when the shared backend is online.',
                          style: TextStyle(color: _networkMuted),
                        ),
                      )
                    : Column(
                        children: [
                          for (final post in data.posts)
                            _CommunityPostCard(
                              post: post,
                              currentUserId: widget.session.userId,
                              onLike: () => _toggleLike(post),
                              onComments: () => _comments(post),
                              onReport: () => _report(post),
                              onBlock: () => _relationship(post, 'block'),
                              onMute: () => _relationship(post, 'mute'),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              const _SafetyBoundary(),
            ],
          );
        },
      );
}

class ProductConnectedMessagesScreen extends StatefulWidget {
  const ProductConnectedMessagesScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductConnectedMessagesScreen> createState() =>
      _ProductConnectedMessagesScreenState();
}

class _ProductConnectedMessagesScreenState
    extends State<ProductConnectedMessagesScreen> {
  final TrustSafetyService service = const TrustSafetyService();
  final TextEditingController messageController = TextEditingController();
  late Future<List<Map<String, dynamic>>> conversationsFuture;
  List<Map<String, dynamic>> messages = const [];
  Map<String, dynamic>? selectedConversation;
  bool loadingMessages = false;

  @override
  void initState() {
    super.initState();
    conversationsFuture = service.conversations(widget.session);
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      conversationsFuture = service.conversations(widget.session);
    });
    await conversationsFuture;
    if (selectedConversation != null) {
      await _selectConversation(selectedConversation!);
    }
  }

  Future<void> _newConversation() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _ConversationDialog(),
    );
    if (result == null) return;
    final members = [
      for (final value in (result['members'] ?? '').split(','))
        if (value.trim().isNotEmpty) value.trim(),
    ];
    final conversation = await service.createConversation(
      session: widget.session,
      memberUserIds: members,
      title: result['title'] ?? 'Direct message',
    );
    if (!mounted) return;
    _show(conversation == null
        ? 'Messaging service is offline or a block prevents this conversation.'
        : 'Conversation created.');
    await _refresh();
  }

  Future<void> _selectConversation(Map<String, dynamic> conversation) async {
    setState(() {
      selectedConversation = conversation;
      loadingMessages = true;
    });
    final rows = await service.messages(
      session: widget.session,
      conversationId: conversation['id']?.toString() ?? '',
    );
    if (!mounted) return;
    setState(() {
      messages = rows;
      loadingMessages = false;
    });
  }

  Future<void> _send() async {
    final conversation = selectedConversation;
    final body = messageController.text.trim();
    if (conversation == null || body.isEmpty) return;
    final result = await service.sendMessage(
      session: widget.session,
      conversationId: conversation['id']?.toString() ?? '',
      body: body,
    );
    if (!mounted) return;
    if (result == null) {
      _show('Message rejected, blocked, or the messaging service is offline.');
      return;
    }
    messageController.clear();
    await _selectConversation(conversation);
  }

  Future<void> _reportMessage(Map<String, dynamic> message) async {
    final result = await service.report(
      session: widget.session,
      targetType: 'message',
      targetId: message['id']?.toString() ?? '',
      reason: 'Message reported by conversation member',
      priority: 'high',
    );
    if (!mounted) return;
    _show(result == null
        ? 'Report service is offline.'
        : 'Message submitted to the moderation queue.');
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: conversationsFuture,
        builder: (context, snapshot) {
          final conversations = snapshot.data ?? const <Map<String, dynamic>>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _NetworkHero(
                eyebrow: 'PROTECTED COMMUNICATIONS',
                title: 'Messages that honor membership and blocks.',
                body:
                    'Conversations require explicit membership, messages are bounded and scanned, bilateral blocks stop delivery, reports enter the same moderation queue and every action is auditable.',
                status: 'REMOTE FIRST',
              ),
              const SizedBox(height: 18),
              _NetworkSurface(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${conversations.length} conversations',
                        style: const TextStyle(
                          color: _networkInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh messages',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    FilledButton.icon(
                      onPressed: _newConversation,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New conversation'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 860;
                  final conversationList = _ConversationList(
                    rows: conversations,
                    selectedId: selectedConversation?['id']?.toString() ?? '',
                    onSelected: _selectConversation,
                  );
                  final thread = _MessageThread(
                    conversation: selectedConversation,
                    messages: messages,
                    currentUserId: widget.session.userId,
                    loading: loadingMessages,
                    controller: messageController,
                    onSend: _send,
                    onReport: _reportMessage,
                  );
                  if (compact) {
                    return Column(
                      children: [
                        conversationList,
                        const SizedBox(height: 14),
                        thread,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 330, child: conversationList),
                      const SizedBox(width: 14),
                      Expanded(child: thread),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              const _SafetyBoundary(),
            ],
          );
        },
      );
}

class ProductTrustSafetyConsoleScreen extends StatefulWidget {
  const ProductTrustSafetyConsoleScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductTrustSafetyConsoleScreen> createState() =>
      _ProductTrustSafetyConsoleScreenState();
}

class _ProductTrustSafetyConsoleScreenState
    extends State<ProductTrustSafetyConsoleScreen> {
  final TrustSafetyService service = const TrustSafetyService();
  String tab = 'Queue';
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = service.moderationQueue();
  }

  Future<void> _load() async {
    setState(() {
      future = tab == 'Queue'
          ? service.moderationQueue()
          : service.moderationAudit();
    });
    await future;
  }

  Future<void> _act(Map<String, dynamic> item, String action) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ModerationReasonDialog(action: action),
    );
    if (reason == null || reason.trim().isEmpty) return;
    final result = await service.moderate(
      session: widget.session,
      caseId: item['id']?.toString() ?? '',
      action: action,
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result == null
            ? 'Moderation service is offline.'
            : 'Action ${action.toUpperCase()} recorded in the audit log.'),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _NetworkHero(
                eyebrow: 'ORGANIZATION TRUST & SAFETY',
                title: 'Review, act and audit.',
                body:
                    'Reports, automated-review submissions, sanctions and moderator decisions are centralized. Actions update content state and create immutable audit events instead of silently changing rows.',
                status: 'ADMIN CONTROL',
              ),
              const SizedBox(height: 18),
              _NetworkSurface(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in const ['Queue', 'Audit'])
                      ChoiceChip(
                        label: Text(item),
                        selected: tab == item,
                        selectedColor: _networkNavy,
                        labelStyle: TextStyle(
                          color: tab == item ? Colors.white : _networkInk,
                          fontWeight: FontWeight.w900,
                        ),
                        onSelected: (_) {
                          setState(() => tab = item);
                          _load();
                        },
                      ),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _NetworkSurface(
                padding: EdgeInsets.zero,
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tab == 'Queue'
                              ? 'No open moderation cases.'
                              : 'No audit events have been recorded.',
                          style: const TextStyle(color: _networkMuted),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in rows)
                            tab == 'Queue'
                                ? _ModerationCaseRow(
                                    item: item,
                                    onAction: (action) => _act(item, action),
                                  )
                                : _AuditRow(item: item),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              const _SafetyBoundary(),
            ],
          );
        },
      );
}

class _NewPostDialog extends StatefulWidget {
  const _NewPostDialog({required this.initialBoard});
  final String initialBoard;

  @override
  State<_NewPostDialog> createState() => _NewPostDialogState();
}

class _NewPostDialogState extends State<_NewPostDialog> {
  final title = TextEditingController();
  final body = TextEditingController();
  late String board;

  @override
  void initState() {
    super.initState();
    board = widget.initialBoard == 'All' ? 'NBA General' : widget.initialBoard;
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create community thread'),
        content: SizedBox(
          width: 650,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: board,
                decoration: const InputDecoration(labelText: 'Board'),
                items: [
                  for (final item in _communityBoards.skip(1))
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) => setState(() => board = value ?? board),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Thread title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Thread body',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'board': board,
              'title': title.text.trim(),
              'body': body.text.trim(),
            }),
            child: const Text('Publish'),
          ),
        ],
      );
}

class _CommentsDialog extends StatefulWidget {
  const _CommentsDialog({
    required this.session,
    required this.post,
    required this.service,
  });

  final AppSession session;
  final Map<String, dynamic> post;
  final TrustSafetyService service;

  @override
  State<_CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<_CommentsDialog> {
  final TextEditingController controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.service.comments(
      session: widget.session,
      postId: widget.post['id']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (controller.text.trim().isEmpty) return;
    final result = await widget.service.createComment(
      session: widget.session,
      postId: widget.post['id']?.toString() ?? '',
      body: controller.text,
    );
    if (!mounted) return;
    if (result != null) controller.clear();
    setState(() {
      future = widget.service.comments(
        session: widget.session,
        postId: widget.post['id']?.toString() ?? '',
      );
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.post['title']?.toString() ?? 'Thread'),
        content: SizedBox(
          width: 720,
          height: 520,
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: future,
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (rows.isEmpty) {
                      return const Center(child: Text('No visible comments yet.'));
                    }
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final comment = rows[index];
                        return ListTile(
                          title: Text(comment['body']?.toString() ?? ''),
                          subtitle: Text(
                            '${comment['author_user_id']} · ${comment['created_at']}',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Write a reply...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: _send, child: const Text('Reply')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      );
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComments,
    required this.onReport,
    required this.onBlock,
    required this.onMute,
  });

  final Map<String, dynamic> post;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onMute;

  @override
  Widget build(BuildContext context) {
    final ownPost = post['author_user_id'] == currentUserId;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _networkLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _NetworkPill(post['board']?.toString() ?? 'Community', _networkBlue),
              Text(
                '${post['author_user_id']} · ${post['created_at']}',
                style: const TextStyle(color: _networkMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post['title']?.toString() ?? 'Untitled thread',
            style: const TextStyle(
              color: _networkInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post['body']?.toString() ?? '',
            style: const TextStyle(color: _networkMuted, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onLike,
                icon: Icon(
                  post['liked_by_viewer'] == true
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                label: Text('${post['like_count'] ?? 0}'),
              ),
              OutlinedButton.icon(
                onPressed: onComments,
                icon: const Icon(Icons.comment_outlined),
                label: Text('${post['comment_count'] ?? 0} replies'),
              ),
              if (!ownPost)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'report') onReport();
                    if (value == 'mute') onMute();
                    if (value == 'block') onBlock();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'report', child: Text('Report thread')),
                    PopupMenuItem(value: 'mute', child: Text('Mute author')),
                    PopupMenuItem(value: 'block', child: Text('Block author')),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversationDialog extends StatefulWidget {
  const _ConversationDialog();

  @override
  State<_ConversationDialog> createState() => _ConversationDialogState();
}

class _ConversationDialogState extends State<_ConversationDialog> {
  final title = TextEditingController();
  final members = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    members.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New protected conversation'),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Conversation title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: members,
                decoration: const InputDecoration(
                  labelText: 'Member user IDs, comma separated',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'title': title.text.trim(),
              'members': members.text.trim(),
            }),
            child: const Text('Create'),
          ),
        ],
      );
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.rows,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> rows;
  final String selectedId;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) => _NetworkSurface(
        padding: EdgeInsets.zero,
        child: rows.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No conversations yet.',
                  style: TextStyle(color: _networkMuted),
                ),
              )
            : Column(
                children: [
                  for (final row in rows)
                    ListTile(
                      selected: selectedId == row['id'],
                      selectedTileColor: const Color(0xFFEFF6FF),
                      leading: const CircleAvatar(
                        child: Icon(Icons.forum_outlined),
                      ),
                      title: Text(
                        row['title']?.toString() ?? 'Conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${row['message_count'] ?? 0} messages · ${row['last_message_at'] ?? 'no messages'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelected(row),
                    ),
                ],
              ),
      );
}

class _MessageThread extends StatelessWidget {
  const _MessageThread({
    required this.conversation,
    required this.messages,
    required this.currentUserId,
    required this.loading,
    required this.controller,
    required this.onSend,
    required this.onReport,
  });

  final Map<String, dynamic>? conversation;
  final List<Map<String, dynamic>> messages;
  final String currentUserId;
  final bool loading;
  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<Map<String, dynamic>> onReport;

  @override
  Widget build(BuildContext context) => _NetworkSurface(
        child: SizedBox(
          height: 560,
          child: conversation == null
              ? const Center(
                  child: Text(
                    'Select or create a conversation.',
                    style: TextStyle(color: _networkMuted),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation!['title']?.toString() ?? 'Conversation',
                      style: const TextStyle(
                        color: _networkInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : messages.isEmpty
                              ? const Center(child: Text('No visible messages yet.'))
                              : ListView.builder(
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    final mine = message['sender_user_id'] == currentUserId;
                                    return Align(
                                      alignment: mine
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: GestureDetector(
                                        onLongPress: mine
                                            ? null
                                            : () => onReport(message),
                                        child: Container(
                                          constraints: const BoxConstraints(maxWidth: 560),
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: mine
                                                ? const Color(0xFFEFF6FF)
                                                : _networkSoft,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: _networkLine),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(message['body']?.toString() ?? ''),
                                              const SizedBox(height: 5),
                                              Text(
                                                '${message['sender_user_id']} · ${message['created_at']}',
                                                style: const TextStyle(
                                                  color: _networkMuted,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Write a protected message...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => onSend(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: onSend,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      );
}

class _ModerationReasonDialog extends StatefulWidget {
  const _ModerationReasonDialog({required this.action});
  final String action;

  @override
  State<_ModerationReasonDialog> createState() => _ModerationReasonDialogState();
}

class _ModerationReasonDialogState extends State<_ModerationReasonDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.action.toUpperCase()} moderation case'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Reason and resolution record',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Record action'),
          ),
        ],
      );
}

class _ModerationCaseRow extends StatelessWidget {
  const _ModerationCaseRow({required this.item, required this.onAction});
  final Map<String, dynamic> item;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _networkLine)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(Icons.report_problem_outlined)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${item['target_type']} · ${item['target_id']}',
                        style: const TextStyle(
                          color: _networkInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _NetworkPill(
                        item['priority']?.toString().toUpperCase() ?? 'NORMAL',
                        item['priority'] == 'high' || item['priority'] == 'urgent'
                            ? Colors.red
                            : _networkOrange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['reason']?.toString() ?? '',
                    style: const TextStyle(color: _networkMuted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Reporter ${item['reporter_user_id']} · target user ${item['target_user_id'] ?? 'unknown'} · ${item['created_at']}',
                    style: const TextStyle(color: _networkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: onAction,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'approve', child: Text('Approve / restore')),
                PopupMenuItem(value: 'hide', child: Text('Hide during review')),
                PopupMenuItem(value: 'remove', child: Text('Remove content')),
                PopupMenuItem(value: 'warn', child: Text('Warn user')),
                PopupMenuItem(value: 'suspend', child: Text('Suspend user')),
                PopupMenuItem(value: 'ban', child: Text('Ban user')),
                PopupMenuItem(value: 'close', child: Text('Close case')),
              ],
            ),
          ],
        ),
      );
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
        title: Text(
          item['event_type']?.toString() ?? 'Audit event',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${item['actor_user_id']} · ${item['target_type']}:${item['target_id']} · ${item['created_at']}',
        ),
      );
}

class _NetworkHero extends StatelessWidget {
  const _NetworkHero({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.status,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String status;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [_networkNavy, _networkBlue, _networkOrange],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24071A33),
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                _NetworkPill(status, _networkGreen),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 37,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 930,
              child: Text(
                body,
                style: const TextStyle(
                  color: Color(0xFFEAF2FF),
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _NetworkMetrics extends StatelessWidget {
  const _NetworkMetrics({required this.items});
  final List<_NetworkMetric> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 760
              ? constraints.maxWidth
              : (constraints.maxWidth - 18) / 4;
          return Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final item in items) SizedBox(width: width, child: item),
            ],
          );
        },
      );
}

class _NetworkMetric extends StatelessWidget {
  const _NetworkMetric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => _NetworkSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _networkMuted, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: _networkInk, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: _networkMuted, fontSize: 12)),
          ],
        ),
      );
}

class _NetworkSurface extends StatelessWidget {
  const _NetworkSurface({required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _networkLine),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 22, offset: Offset(0, 10)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _NetworkPill extends StatelessWidget {
  const _NetworkPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );
}

class _SafetyBoundary extends StatelessWidget {
  const _SafetyBoundary();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          border: Border.all(color: const Color(0xFFFFD28A)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Public enablement still requires staffed moderation, documented escalation and appeals, production abuse monitoring, legal policy review and incident-response ownership. The product now contains the enforcement and audit primitives; it does not replace human operations.',
          style: TextStyle(color: _networkInk, height: 1.45, fontWeight: FontWeight.w600),
        ),
      );
}
