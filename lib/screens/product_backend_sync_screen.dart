import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/product_api_client.dart';
import '../services/product_local_store.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF6F8FC);
const _green = Color(0xFF059669);

class ProductBackendSyncScreen extends StatefulWidget {
  const ProductBackendSyncScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductBackendSyncScreen> createState() => _ProductBackendSyncScreenState();
}

class _ProductBackendSyncScreenState extends State<ProductBackendSyncScreen> {
  final ProductLocalStore localStore = const ProductLocalStore();
  late final TextEditingController baseUrlController;

  String baseUrl = 'http://127.0.0.1:8000';
  String backendUserId = '';
  String lastSync = '';
  String status = 'Backend not checked yet';
  bool busy = false;
  Map<String, dynamic>? health;
  Map<String, dynamic>? readiness;
  Map<String, dynamic>? personalization;
  Map<String, dynamic>? backendProfile;
  Map<String, dynamic>? backendSettings;
  Map<String, dynamic>? featureFlags;
  List<dynamic> plans = const [];
  List<dynamic> posts = const [];
  List<dynamic> articles = const [];
  List<dynamic> conversations = const [];
  List<String> activity = const ['Open this while the backend is running, then click Run full sync.'];

  @override
  void initState() {
    super.initState();
    baseUrlController = TextEditingController(text: baseUrl);
    _loadLocalState();
  }

  @override
  void dispose() {
    baseUrlController.dispose();
    super.dispose();
  }

  ProductApiClient get api => ProductApiClient(baseUrl: baseUrl);

  Future<void> _loadLocalState() async {
    final savedBaseUrl = await localStore.loadString(ProductLocalStore.backendBaseUrlKey, fallback: baseUrl);
    final savedUserId = await localStore.loadString(ProductLocalStore.backendUserIdKey);
    final savedLastSync = await localStore.loadString(ProductLocalStore.backendLastSyncKey);
    if (!mounted) return;
    setState(() {
      baseUrl = savedBaseUrl.isEmpty ? baseUrl : savedBaseUrl;
      baseUrlController.text = baseUrl;
      backendUserId = savedUserId;
      lastSync = savedLastSync;
    });
  }

  Future<void> _saveBaseUrl() async {
    final value = baseUrlController.text.trim().isEmpty ? 'http://127.0.0.1:8000' : baseUrlController.text.trim();
    setState(() => baseUrl = value);
    await localStore.saveString(ProductLocalStore.backendBaseUrlKey, value);
  }

  Future<void> _checkBackend() async {
    await _run('Checking backend connection', () async {
      await _saveBaseUrl();
      final nextHealth = await api.health();
      final nextReadiness = await api.readiness();
      final nextFlags = await api.featureFlags();
      final nextPlans = await api.listPlans();
      setState(() {
        health = nextHealth;
        readiness = nextReadiness;
        featureFlags = nextFlags;
        plans = nextPlans;
        status = 'Connected to ${nextHealth['service'] ?? 'backend'}';
      });
      _addActivity('Connected: ${nextReadiness['status'] ?? 'ready'}');
    });
  }

  Future<void> _runFullSync() async {
    await _run('Running full backend sync', () async {
      await _saveBaseUrl();
      final nextHealth = await api.health();
      final nextReadiness = await api.readiness();
      final userId = await _ensureBackendUser();
      await _syncProfileSettings(userId);
      await _syncPersonalization(userId);
      await _syncWorkspace(userId);
      await _syncCommunityCmsMessagingAndAdmin(userId);
      final timestamp = DateTime.now().toIso8601String();
      await localStore.saveString(ProductLocalStore.backendLastSyncKey, timestamp);
      final nextPersonalization = await api.getPersonalization(userId);
      final nextFlags = await api.featureFlags();
      final nextPlans = await api.listPlans();
      final nextPosts = await api.listCommunityPosts();
      final nextArticles = await api.listArticles();
      final nextConversations = await api.listUserConversations(userId);
      final nextProfile = await api.getProfile(userId);
      final nextSettings = await api.getSettings(userId);
      setState(() {
        health = nextHealth;
        readiness = nextReadiness;
        personalization = nextPersonalization;
        featureFlags = nextFlags;
        plans = nextPlans;
        posts = nextPosts;
        articles = nextArticles;
        conversations = nextConversations;
        backendProfile = nextProfile;
        backendSettings = nextSettings;
        backendUserId = userId;
        lastSync = timestamp;
        status = 'Synced local prototype state to backend';
      });
      _addActivity('Full sync completed at $timestamp');
    });
  }

  Future<void> _refreshSnapshot() async {
    if (backendUserId.isEmpty) {
      await _checkBackend();
      return;
    }
    await _run('Refreshing backend snapshot', () async {
      final nextHealth = await api.health();
      final nextReadiness = await api.readiness();
      final nextPersonalization = await api.getPersonalization(backendUserId);
      final nextFlags = await api.featureFlags();
      final nextPlans = await api.listPlans();
      final nextPosts = await api.listCommunityPosts();
      final nextArticles = await api.listArticles();
      final nextConversations = await api.listUserConversations(backendUserId);
      final nextProfile = await api.getProfile(backendUserId);
      final nextSettings = await api.getSettings(backendUserId);
      setState(() {
        health = nextHealth;
        readiness = nextReadiness;
        personalization = nextPersonalization;
        featureFlags = nextFlags;
        plans = nextPlans;
        posts = nextPosts;
        articles = nextArticles;
        conversations = nextConversations;
        backendProfile = nextProfile;
        backendSettings = nextSettings;
        status = 'Snapshot refreshed';
      });
      _addActivity('Snapshot refreshed from backend.');
    });
  }

  Future<String> _ensureBackendUser() async {
    if (backendUserId.isNotEmpty) {
      try {
        await api.getProfile(backendUserId);
        _addActivity('Using existing backend user $backendUserId');
        return backendUserId;
      } catch (_) {
        _addActivity('Saved backend user was missing; creating a new one.');
      }
    }
    final safeName = widget.session.displayName.trim().isEmpty ? 'Sports Terminal User' : widget.session.displayName.trim();
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final user = await api.createUser(
      email: 'demo-$suffix@sportsterminal.local',
      displayName: safeName,
      role: widget.session.role.label.toLowerCase().replaceAll(' ', '_'),
    );
    final userId = '${user['id']}';
    await localStore.saveString(ProductLocalStore.backendUserIdKey, userId);
    setState(() => backendUserId = userId);
    _addActivity('Created backend user $userId');
    return userId;
  }

  Future<void> _syncProfileSettings(String userId) async {
    final settings = await localStore.loadStringMap(ProductLocalStore.profileSettingsKey);
    final isPublic = settings['publicProfile'] != 'false';
    final emailDigest = settings['emailDigest'] == 'true';
    final fantasyAlerts = settings['fantasyAlerts'] != 'false';
    final darkMode = await localStore.loadBool(ProductLocalStore.darkModeKey);
    await api.updateProfile(
      userId,
      handle: widget.session.displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), ''),
      bio: 'Sports Terminal local prototype profile synced from Flutter.',
      isPublic: isPublic,
    );
    await api.updateSettings(
      userId,
      darkMode: darkMode,
      emailDigest: emailDigest,
      fantasyAlerts: fantasyAlerts,
      notificationPreferences: {'source': 'flutter-local-sync', 'last_view': 'backend-sync'},
    );
    _addActivity('Synced profile and settings.');
  }

  Future<void> _syncPersonalization(String userId) async {
    final favorites = await localStore.loadStringSet(ProductLocalStore.favoriteTeamsKey, fallback: {'OKC', 'BOS'});
    final watchlist = await localStore.loadStringSet(ProductLocalStore.playerWatchlistKey, fallback: {'jokicni01', 'gilgesh01'});
    for (final teamId in favorites.take(12)) {
      await api.addFavoriteTeam(userId, teamId);
    }
    for (final playerId in watchlist.take(24)) {
      await api.addWatchlistPlayer(userId, playerId, source: 'flutter-local-sync', notes: 'Synced from local NBA/Fantasy watchlist.');
    }
    _addActivity('Synced ${favorites.length} favorite teams and ${watchlist.length} watchlist players.');
  }

  Future<void> _syncWorkspace(String userId) async {
    var workbookId = await localStore.loadString(ProductLocalStore.backendWorkbookIdKey);
    if (workbookId.isEmpty) {
      final workbook = await api.createWorkbook(ownerUserId: userId, title: 'Sports Terminal Synced Workbook');
      workbookId = '${workbook['id']}';
      await localStore.saveString(ProductLocalStore.backendWorkbookIdKey, workbookId);
      _addActivity('Created backend workbook $workbookId');
    }
    final localCells = await localStore.loadStringMap(ProductLocalStore.workbookCellsKey);
    final entries = localCells.isEmpty
        ? <MapEntry<String, String>>[
            const MapEntry('A1', 'Sports Terminal'),
            const MapEntry('A2', 'Backend sync'),
            const MapEntry('B2', '=SUM(C3:C5)'),
            const MapEntry('C3', '24.5'),
            const MapEntry('C4', '31.2'),
            const MapEntry('C5', '18.7'),
          ]
        : localCells.entries.take(40).toList();
    for (final entry in entries) {
      await api.updateWorkbookCell(workbookId, sheet: 'Sheet 1', cellRef: entry.key, rawValue: entry.value);
    }
    _addActivity('Synced ${entries.length} workbook cells.');
  }

  Future<void> _syncCommunityCmsMessagingAndAdmin(String userId) async {
    final post = await api.createCommunityPost(
      authorUserId: userId,
      board: 'Product Feedback',
      title: 'Backend sync is connected',
      body: 'Flutter local state can now be pushed into the FastAPI + SQLite backend prototype.',
      entityType: 'product',
      entityId: 'backend-sync',
    );
    await api.reactToPost(postId: '${post['id']}', userId: userId);
    await api.reportContent(reporterUserId: userId, targetType: 'post', targetId: '${post['id']}', reason: 'Smoke-test moderation workflow for operator console.');

    final article = await api.createArticle(
      authorUserId: userId,
      title: 'Sports Terminal backend sync milestone',
      body: 'This draft was created through the Flutter backend sync control panel.',
      tags: const ['launch', 'backend', 'sync'],
    );
    await api.updateArticleStatus('${article['id']}', 'published');

    final conversationId = await _ensureConversation(userId);
    await api.sendMessage(
      conversationId: conversationId,
      senderUserId: userId,
      body: 'Backend sync check-in from the Flutter client.',
    );

    await api.updateFeatureFlag('backend_sync', true);
    await api.upsertDataSource(
      sourceId: 'nba-2025-static-assets',
      sourceType: 'historical_nba',
      label: 'NBA 2024-25 generated seed assets',
      enabled: true,
      config: {'mode': 'static_asset', 'owner': 'Sports Terminal'},
    );
    await api.recordPipelineRun({
      'source': 'flutter-backend-sync',
      'season': '2024-25',
      'status': 'recorded',
      'summary': {'event': 'manual sync', 'surface': 'ProductBackendSyncScreen'},
    });
    _addActivity('Synced community, CMS, messaging, moderation, feature flags, data source, and pipeline run.');
  }

  Future<String> _ensureConversation(String userId) async {
    var conversationId = await localStore.loadString(ProductLocalStore.backendConversationIdKey);
    if (conversationId.isNotEmpty) return conversationId;
    final conversation = await api.createConversation(title: 'Sports Terminal Sync Room', memberUserIds: [userId]);
    conversationId = '${conversation['id']}';
    await localStore.saveString(ProductLocalStore.backendConversationIdKey, conversationId);
    return conversationId;
  }

  Future<void> _run(String nextStatus, Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      status = nextStatus;
    });
    try {
      await task();
    } catch (error) {
      _addActivity('Error: $error');
      if (mounted) setState(() => status = 'Backend action failed. Is the API running on $baseUrl?');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _addActivity(String message) {
    if (!mounted) return;
    setState(() {
      activity = [message, ...activity].take(9).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final readyStatus = '${readiness?['status'] ?? 'not checked'}';
    final favoriteCount = _listCount(personalization?['favorite_teams']);
    final watchCount = _listCount(personalization?['watchlist']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _HeroBand(
        title: 'Backend Sync Center',
        body: 'This is the bridge between the polished Flutter prototype and the FastAPI + SQLite backend. Use it to create a backend user, push local favorites/watchlists/settings/workbook state, and exercise community, CMS, messaging, admin, and billing API contracts.',
        chips: ['API: $baseUrl', 'Readiness: $readyStatus', backendUserId.isEmpty ? 'No backend user yet' : backendUserId],
      ),
      const SizedBox(height: 18),
      _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Connection', style: TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: baseUrlController,
                decoration: InputDecoration(
                  labelText: 'Backend base URL',
                  hintText: 'http://127.0.0.1:8000',
                  filled: true,
                  fillColor: _soft,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _ActionButton(label: 'Check', icon: Icons.wifi_tethering_rounded, onPressed: busy ? null : _checkBackend),
            const SizedBox(width: 10),
            _ActionButton(label: 'Run full sync', icon: Icons.sync_rounded, primary: true, onPressed: busy ? null : _runFullSync),
            const SizedBox(width: 10),
            _ActionButton(label: 'Refresh', icon: Icons.refresh_rounded, onPressed: busy ? null : _refreshSnapshot),
          ]),
          if (busy) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator()),
          const SizedBox(height: 12),
          Text(status, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 18),
      _MetricGrid(items: [
        _Metric('Backend', '${health?['status'] ?? '—'}', '${health?['version'] ?? 'not checked'}'),
        _Metric('Readiness', readyStatus, '${readiness?['backend'] ?? 'FastAPI'}'),
        _Metric('Favorite teams', '$favoriteCount', 'backend personalization'),
        _Metric('Watchlist', '$watchCount', 'backend personalization'),
        _Metric('Posts', '${posts.length}', 'community API'),
        _Metric('Articles', '${articles.length}', 'CMS API'),
        _Metric('Conversations', '${conversations.length}', 'messaging API'),
        _Metric('Plans', '${plans.length}', 'billing API'),
      ]),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final left = _SnapshotPanel(
          title: 'Backend snapshot',
          rows: [
            ['User', backendUserId.isEmpty ? 'Not created' : backendUserId],
            ['Last sync', lastSync.isEmpty ? 'Never' : lastSync],
            ['Profile public', '${backendProfile?['is_public'] ?? '—'}'],
            ['Dark mode', '${backendSettings?['dark_mode'] ?? '—'}'],
            ['Feature flags', featureFlags == null ? '—' : '${featureFlags!.length} loaded'],
            ['Database', '${health?['database'] ?? '—'}'],
          ],
        );
        final right = _ActivityPanel(activity: activity);
        if (compact) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 18),
      const _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What this unlocks next', style: TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          _ChecklistItem('Wire Profile, NBA, Fantasy, Workspace, Community, Messages, and Admin screens directly to this API client.'),
          _ChecklistItem('Keep local storage as offline fallback while backend sync becomes the source of truth.'),
          _ChecklistItem('Add auth/session scaffolding so backend users are real accounts instead of local demo identities.'),
          _ChecklistItem('Add hosted Postgres, migrations, secrets, logging, and deployment after the local API contract stabilizes.'),
        ]),
      ),
    ]);
  }

  int _listCount(Object? value) => value is List ? value.length : 0;
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.title, required this.body, required this.chips});
  final String title;
  final String body;
  final List<String> chips;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _blue, _orange]),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [BoxShadow(color: Color(0x26071A33), blurRadius: 32, offset: Offset(0, 16))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('BACKEND CONTROL PLANE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 38, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          const SizedBox(height: 12),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850), child: Text(body, style: const TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
          const SizedBox(height: 18),
          Wrap(spacing: 9, runSpacing: 9, children: [for (final chip in chips) _GlassChip(chip)]),
        ]),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
          boxShadow: const [BoxShadow(color: Color(0x11071A33), blurRadius: 24, offset: Offset(0, 12))],
        ),
        child: child,
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 720 ? constraints.maxWidth : (constraints.maxWidth - 36) / 4;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final item in items) SizedBox(width: width, child: _MetricCard(item))]);
      });
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);
  final _Metric metric;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(metric.label.toUpperCase(), style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(metric.caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _Metric {
  const _Metric(this.label, this.value, this.caption);
  final String label;
  final String value;
  final String caption;
}

class _SnapshotPanel extends StatelessWidget {
  const _SnapshotPanel({required this.title, required this.rows});
  final String title;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final row in rows) _KeyValueRow(label: row[0], value: row[1]),
        ]),
      );
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.activity});
  final List<String> activity;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Activity log', style: TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final item in activity)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, color: _green, size: 8)),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700))),
              ]),
            ),
        ]),
      );
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
        child: Row(children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w800))),
          Expanded(child: Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900))),
        ]),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.onPressed, this.primary = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background = primary ? _navy : Colors.white;
    final foreground = primary ? Colors.white : _navy;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: _line,
        disabledForegroundColor: _muted,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: primary ? _navy : _line)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.13), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.25))),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      );
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle_rounded, color: _green, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700))),
        ]),
      );
}
