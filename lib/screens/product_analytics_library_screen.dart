import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/analytics_library_service.dart';

const _libraryBg = Color(0xFF151C29);
const _libraryPanel = Color(0xFF1D2636);
const _libraryPanel2 = Color(0xFF252F41);
const _libraryLine = Color(0xFF364256);
const _libraryText = Color(0xFFF3F6FB);
const _libraryMuted = Color(0xFFA2ACBD);
const _libraryGold = Color(0xFFFFCB45);
const _libraryCyan = Color(0xFF65D5FF);
const _libraryGreen = Color(0xFF65E3A5);

class ProductAnalyticsLibraryScreen extends StatefulWidget {
  const ProductAnalyticsLibraryScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductAnalyticsLibraryScreen> createState() =>
      _ProductAnalyticsLibraryScreenState();
}

class _ProductAnalyticsLibraryScreenState
    extends State<ProductAnalyticsLibraryScreen> {
  final AnalyticsLibraryService _service = const AnalyticsLibraryService();
  final TextEditingController _searchController = TextEditingController();
  late Future<_AnalyticsLibrarySnapshot> _future;
  String _type = 'All';
  int _tab = 0;

  bool get organizationMode =>
      widget.session.role.canManageOrganization &&
      widget.session.organizationId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_AnalyticsLibrarySnapshot> _load() async {
    final summary = await _service.summary(widget.session);
    final assets = await _service.assets(
      widget.session,
      assetType: _type == 'All' ? '' : _type,
      query: _searchController.text.trim(),
    );
    final recent = await _service.recent(widget.session);
    return _AnalyticsLibrarySnapshot(
      summary: summary,
      assets: assets,
      recent: recent,
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _createAsset() async {
    final result = await showDialog<_NewAnalyticsAsset>(
      context: context,
      builder: (context) => _CreateAnalyticsAssetDialog(
        organizationMode: organizationMode,
      ),
    );
    if (result == null) return;
    final id = 'analytics-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(9999)}';
    await _service.saveAsset(
      session: widget.session,
      id: id,
      assetType: result.assetType,
      title: result.title,
      description: result.description,
      visibility: organizationMode ? 'organization' : 'private',
      configuration: result.configuration,
      sourceSnapshot: {
        'season': '2025-26',
        'createdFrom': 'analytics-library',
      },
      tags: result.tags,
      pinned: result.pinned,
      expectedVersion: 0,
    );
    _refresh();
  }

  Future<void> _togglePinned(Map<String, dynamic> asset) async {
    await _service.saveAsset(
      session: widget.session,
      id: asset['id']?.toString() ?? '',
      assetType: asset['asset_type']?.toString() ?? 'dashboard',
      title: asset['title']?.toString() ?? 'Untitled analytics asset',
      description: asset['description']?.toString() ?? '',
      visibility: asset['visibility']?.toString() ??
          (organizationMode ? 'organization' : 'private'),
      configuration: _map(asset['configuration']),
      sourceSnapshot: _map(asset['source_snapshot']),
      tags: _strings(asset['tags']),
      pinned: asset['pinned'] != true,
      expectedVersion: (asset['version'] as num?)?.toInt(),
    );
    _refresh();
  }

  Future<void> _clone(Map<String, dynamic> asset) async {
    await _service.cloneAsset(
      session: widget.session,
      id: asset['id']?.toString() ?? '',
      title: '${asset['title'] ?? 'Analytics asset'} copy',
    );
    _refresh();
  }

  Future<void> _delete(Map<String, dynamic> asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete analytics asset?'),
        content: Text(
          'This will remove “${asset['title'] ?? 'Untitled'}” and its saved versions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteAsset(
      widget.session,
      asset['id']?.toString() ?? '',
    );
    _refresh();
  }

  Future<void> _showVersions(Map<String, dynamic> asset) async {
    final versions = await _service.versions(asset['id']?.toString() ?? '');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${asset['title'] ?? 'Analytics asset'} versions'),
        content: SizedBox(
          width: 620,
          child: versions.isEmpty
              ? const Text('No versions are available.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: versions.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final version = versions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${version['version'] ?? '?'}'),
                      ),
                      title: Text('Version ${version['version'] ?? '?'}'),
                      subtitle: Text(
                        '${version['actor_user_id'] ?? 'Unknown user'} · ${version['created_at'] ?? 'Unknown time'}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _libraryBg,
      constraints: const BoxConstraints(minHeight: 720),
      child: FutureBuilder<_AnalyticsLibrarySnapshot>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LibraryHeader(
                organizationMode: organizationMode,
                onCreate: _createAsset,
                onRefresh: _refresh,
              ),
              _LibraryTabs(
                selected: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              Expanded(
                child: snapshot.connectionState != ConnectionState.done
                    ? const Center(
                        child: CircularProgressIndicator(color: _libraryGold),
                      )
                    : snapshot.hasError || data == null
                        ? Center(
                            child: Text(
                              'Analytics Library unavailable: ${snapshot.error}',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          )
                        : _tab == 0
                            ? _OverviewTab(
                                snapshot: data,
                                organizationMode: organizationMode,
                              )
                            : _tab == 1
                                ? _AssetsTab(
                                    snapshot: data,
                                    type: _type,
                                    searchController: _searchController,
                                    onType: (value) {
                                      setState(() => _type = value);
                                      _refresh();
                                    },
                                    onSearch: _refresh,
                                    onPinned: _togglePinned,
                                    onClone: _clone,
                                    onVersions: _showVersions,
                                    onDelete: _delete,
                                  )
                                : _RecentTab(events: data.recent),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.organizationMode,
    required this.onCreate,
    required this.onRefresh,
  });

  final bool organizationMode;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: _libraryPanel,
          border: Border(bottom: BorderSide(color: _libraryLine)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bookmarks_rounded, color: _libraryGold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organizationMode
                        ? 'Organization Analytics Library'
                        : 'My Analytics Library',
                    style: const TextStyle(
                      color: _libraryText,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    organizationMode
                        ? 'Shared stat views, comparison sets, dashboards and research packages.'
                        : 'Your saved views, comparisons, charts and research packages across devices.',
                    style: const TextStyle(color: _libraryMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: _libraryMuted),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New asset'),
              style: FilledButton.styleFrom(
                backgroundColor: _libraryGold,
                foregroundColor: _libraryBg,
              ),
            ),
          ],
        ),
      );
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        color: _libraryPanel,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: Row(
          children: [
            for (final entry in const [
              (0, 'Overview', Icons.space_dashboard_rounded),
              (1, 'Saved assets', Icons.inventory_2_rounded),
              (2, 'Recent', Icons.history_rounded),
            ]) ...[
              _LibraryTab(
                label: entry.$2,
                icon: entry.$3,
                selected: selected == entry.$1,
                onTap: () => onChanged(entry.$1),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.snapshot,
    required this.organizationMode,
  });

  final _AnalyticsLibrarySnapshot snapshot;
  final bool organizationMode;

  @override
  Widget build(BuildContext context) {
    final byType = _map(snapshot.summary['assets_by_type']);
    final metrics = <String, Object>{
      'Saved assets': snapshot.summary['total_assets'] ?? snapshot.assets.length,
      'Pinned': snapshot.summary['pinned_assets'] ?? 0,
      'Recent opens': snapshot.summary['recent_events'] ?? snapshot.recent.length,
      'Shared scope': organizationMode ? 'Organization' : 'Personal',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in metrics.entries)
                _MetricCard(label: entry.key, value: '${entry.value}'),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Library composition',
            style: TextStyle(
              color: _libraryText,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final type in _assetTypes)
                _CompositionCard(
                  type: type,
                  count: (byType[type] as num?)?.toInt() ?? 0,
                ),
            ],
          ),
          const SizedBox(height: 18),
          _BoundaryCard(
            organizationMode
                ? 'Organization assets are versioned and shared inside the organization scope. Personal libraries remain private unless explicitly copied into an organization-owned asset.'
                : 'Personal assets remain private to your account. Organization users can maintain a separate shared library without overwriting personal work.',
          ),
        ],
      ),
    );
  }
}

class _AssetsTab extends StatelessWidget {
  const _AssetsTab({
    required this.snapshot,
    required this.type,
    required this.searchController,
    required this.onType,
    required this.onSearch,
    required this.onPinned,
    required this.onClone,
    required this.onVersions,
    required this.onDelete,
  });

  final _AnalyticsLibrarySnapshot snapshot;
  final String type;
  final TextEditingController searchController;
  final ValueChanged<String> onType;
  final VoidCallback onSearch;
  final ValueChanged<Map<String, dynamic>> onPinned;
  final ValueChanged<Map<String, dynamic>> onClone;
  final ValueChanged<Map<String, dynamic>> onVersions;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            color: _libraryPanel,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: searchController,
                    onSubmitted: (_) => onSearch(),
                    style: const TextStyle(color: _libraryText),
                    decoration: InputDecoration(
                      hintText: 'Search title, description or tags',
                      hintStyle: const TextStyle(color: _libraryMuted),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: onSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                      filled: true,
                      fillColor: _libraryPanel2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _libraryLine),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: type,
                  dropdownColor: _libraryPanel2,
                  style: const TextStyle(color: _libraryText),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All types')),
                    for (final item in _assetTypes)
                      DropdownMenuItem(value: item, child: Text(_label(item))),
                  ],
                  onChanged: (value) {
                    if (value != null) onType(value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: snapshot.assets.isEmpty
                ? const _EmptyLibrary()
                : GridView.builder(
                    padding: const EdgeInsets.all(18),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 220,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: snapshot.assets.length,
                    itemBuilder: (context, index) {
                      final asset = snapshot.assets[index];
                      return _AssetCard(
                        asset: asset,
                        onPinned: () => onPinned(asset),
                        onClone: () => onClone(asset),
                        onVersions: () => onVersions(asset),
                        onDelete: () => onDelete(asset),
                      );
                    },
                  ),
          ),
        ],
      );
}

class _RecentTab extends StatelessWidget {
  const _RecentTab({required this.events});

  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) => events.isEmpty
      ? const _EmptyLibrary(message: 'No analytics activity has been recorded yet.')
      : ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final event = events[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _libraryPanel,
                border: Border.all(color: _libraryLine),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: _libraryCyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['label']?.toString() ?? 'Analytics activity',
                          style: const TextStyle(
                            color: _libraryText,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${event['route'] ?? 'unknown route'} · ${event['created_at'] ?? 'unknown time'}',
                          style: const TextStyle(
                            color: _libraryMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onPinned,
    required this.onClone,
    required this.onVersions,
    required this.onDelete,
  });

  final Map<String, dynamic> asset;
  final VoidCallback onPinned;
  final VoidCallback onClone;
  final VoidCallback onVersions;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tags = _strings(asset['tags']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _libraryPanel,
        border: Border.all(
          color: asset['pinned'] == true ? _libraryGold : _libraryLine,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(asset['asset_type']?.toString() ?? ''),
                  color: _libraryGold),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  asset['title']?.toString() ?? 'Untitled analytics asset',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _libraryText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: asset['pinned'] == true ? 'Unpin' : 'Pin',
                onPressed: onPinned,
                icon: Icon(
                  asset['pinned'] == true
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: _libraryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            asset['description']?.toString().isNotEmpty == true
                ? asset['description'].toString()
                : 'Saved ${_label(asset['asset_type']?.toString() ?? 'dashboard').toLowerCase()} configuration.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _libraryMuted, height: 1.35),
          ),
          const Spacer(),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _MiniPill(_label(asset['asset_type']?.toString() ?? 'dashboard')),
              _MiniPill('v${asset['version'] ?? 1}'),
              _MiniPill(asset['visibility']?.toString() ?? 'private'),
              for (final tag in tags.take(2)) _MiniPill(tag),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onVersions,
                icon: const Icon(Icons.history_rounded, size: 17),
                label: const Text('Versions'),
              ),
              TextButton.icon(
                onPressed: onClone,
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Clone'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateAnalyticsAssetDialog extends StatefulWidget {
  const _CreateAnalyticsAssetDialog({required this.organizationMode});

  final bool organizationMode;

  @override
  State<_CreateAnalyticsAssetDialog> createState() =>
      _CreateAnalyticsAssetDialogState();
}

class _CreateAnalyticsAssetDialogState
    extends State<_CreateAnalyticsAssetDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  String _type = 'stats_view';
  bool _pinned = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create analytics asset'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Asset type'),
                items: [
                  for (final type in _assetTypes)
                    DropdownMenuItem(value: type, child: Text(_label(type))),
                ],
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'comma, separated, tags',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _pinned,
                title: const Text('Pin to top'),
                onChanged: (value) => setState(() => _pinned = value),
              ),
              Text(
                widget.organizationMode
                    ? 'This asset will belong to the organization analytics library.'
                    : 'This asset will remain private to your account.',
                style: Theme.of(context).textTheme.bodySmall,
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
            onPressed: _title.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      _NewAnalyticsAsset(
                        assetType: _type,
                        title: _title.text.trim(),
                        description: _description.text.trim(),
                        tags: _tags.text
                            .split(',')
                            .map((item) => item.trim())
                            .where((item) => item.isNotEmpty)
                            .toList(),
                        pinned: _pinned,
                        configuration: const {
                          'season': '2025-26',
                          'basis': 'per_game',
                          'view': 'Overview',
                        },
                      ),
                    ),
            child: const Text('Create'),
          ),
        ],
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _libraryPanel,
          border: Border.all(color: _libraryLine),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _libraryGold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(color: _libraryMuted, fontSize: 11)),
          ],
        ),
      );
}

class _CompositionCard extends StatelessWidget {
  const _CompositionCard({required this.type, required this.count});
  final String type;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        width: 220,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _libraryPanel,
          border: Border.all(color: _libraryLine),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(_icon(type), color: _libraryCyan),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_label(type),
                  style: const TextStyle(
                      color: _libraryText, fontWeight: FontWeight.w800)),
            ),
            Text('$count',
                style: const TextStyle(
                    color: _libraryGold, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF22291F),
          border: Border.all(color: const Color(0xFF4D6A3C)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: _libraryGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: _libraryText, fontSize: 12)),
            ),
          ],
        ),
      );
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _libraryGold : _libraryPanel2,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? _libraryBg : _libraryMuted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _libraryBg : _libraryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _libraryPanel2,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _libraryMuted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({this.message = 'No analytics assets match this view.'});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                color: _libraryMuted, size: 42),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: _libraryMuted)),
          ],
        ),
      );
}

class _AnalyticsLibrarySnapshot {
  const _AnalyticsLibrarySnapshot({
    required this.summary,
    required this.assets,
    required this.recent,
  });
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> recent;
}

class _NewAnalyticsAsset {
  const _NewAnalyticsAsset({
    required this.assetType,
    required this.title,
    required this.description,
    required this.tags,
    required this.pinned,
    required this.configuration,
  });
  final String assetType;
  final String title;
  final String description;
  final List<String> tags;
  final bool pinned;
  final Map<String, dynamic> configuration;
}

const _assetTypes = <String>[
  'stats_view',
  'comparison_set',
  'team_board',
  'dashboard',
  'chart',
  'research_package',
];

String _label(String type) => switch (type) {
      'stats_view' => 'Stats view',
      'comparison_set' => 'Comparison set',
      'team_board' => 'Team board',
      'dashboard' => 'Dashboard',
      'chart' => 'Chart',
      'research_package' => 'Research package',
      _ => type.replaceAll('_', ' '),
    };

IconData _icon(String type) => switch (type) {
      'stats_view' => Icons.table_chart_rounded,
      'comparison_set' => Icons.compare_arrows_rounded,
      'team_board' => Icons.groups_rounded,
      'dashboard' => Icons.space_dashboard_rounded,
      'chart' => Icons.scatter_plot_rounded,
      'research_package' => Icons.inventory_2_rounded,
      _ => Icons.analytics_rounded,
    };

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}
