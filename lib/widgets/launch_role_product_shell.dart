import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/product_automation_governance_screen.dart';
import '../services/launch_backend_transport.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import 'connected_role_terminal_shell.dart';

class LaunchRoleProductShell extends StatefulWidget {
  const LaunchRoleProductShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<LaunchRoleProductShell> createState() =>
      _LaunchRoleProductShellState();
}

class _LaunchRoleProductShellState extends State<LaunchRoleProductShell> {
  final ProductLocalStore _store = const ProductLocalStore();
  late Future<_LaunchProductStatus> _statusFuture;
  bool _remoteEnabled = true;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final value = await _store.loadBool(
      ProductLocalStore.launchRemoteSyncEnabledKey,
      fallback: true,
    );
    if (!mounted) return;
    setState(() => _remoteEnabled = value);
  }

  Future<_LaunchProductStatus> _loadStatus() async {
    final seedFuture = const NbaTerminalSeedRepository().load();
    final backendFuture = const LaunchBackendTransport().getJson(
      '/v2/launch/readiness',
    );
    final seed = await seedFuture;
    final backend = await backendFuture;
    final backendData = backend.data is Map
        ? (backend.data! as Map)
            .map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final blockers = backendData['blocking_items'];
    return _LaunchProductStatus(
      supportedSeason: seed.supportedSeason,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      assetPath: seed.assetPath,
      warehouseGeneratedAt: seed.warehouseGeneratedAt,
      usedFallback: seed.usedFallback,
      backendOnline: backend.available,
      backendStatus: backendData['status']?.toString() ?? 'offline',
      blockers: blockers is List
          ? [for (final item in blockers) item.toString()]
          : const [],
    );
  }

  Future<void> _refresh() async {
    setState(() => _statusFuture = _loadStatus());
    await _statusFuture;
  }

  Future<void> _setRemoteEnabled(bool value) async {
    await _store.saveBool(
      ProductLocalStore.launchRemoteSyncEnabledKey,
      value,
    );
    if (!mounted) return;
    setState(() {
      _remoteEnabled = value;
      _statusFuture = _loadStatus();
    });
  }

  Future<void> _showAutomationCenter() {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.session.role.canManageOrganization
                  ? 'Organization Control Plane'
                  : 'My Automation Center',
            ),
            leading: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1420),
                child: ProductAutomationGovernanceScreen(
                  session: widget.session,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(_LaunchProductStatus status) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sports Terminal launch status'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusRow('User platform', widget.session.role.label),
                _StatusRow('Target season', status.supportedSeason),
                _StatusRow('Dataset', status.datasetStatus),
                _StatusRow('Validation', status.validationStatus),
                _StatusRow('Resolved assets', status.assetPath),
                _StatusRow('Warehouse generated', status.warehouseGeneratedAt),
                _StatusRow(
                  'Shared backend',
                  status.backendOnline
                      ? status.backendStatus
                      : 'offline · using local fallback',
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _remoteEnabled,
                  title: const Text('Remote-first collaboration'),
                  subtitle: const Text(
                    'Use the launch backend for cases, activity, notifications, organization members, automation and governance when it is reachable.',
                  ),
                  onChanged: _setRemoteEnabled,
                ),
                if (status.usedFallback) ...[
                  const SizedBox(height: 8),
                  const _Notice(
                    'The certified 2025–26 asset release is not active yet. The app is intentionally using the validated development fallback instead of presenting incomplete data as launch-ready.',
                  ),
                ],
                if (status.blockers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Launch blockers',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  for (final blocker in status.blockers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $blocker'),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _refresh, child: const Text('Refresh')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ConnectedRoleTerminalShell(
          session: widget.session,
          workspaceController: widget.workspaceController,
          onSignOut: widget.onSignOut,
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'automation-center',
                  onPressed: _showAutomationCenter,
                  icon: Icon(
                    widget.session.role.canManageOrganization
                        ? Icons.admin_panel_settings_rounded
                        : Icons.auto_awesome_motion_rounded,
                  ),
                  label: Text(
                    widget.session.role.canManageOrganization
                        ? 'Control Plane'
                        : 'Automation',
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<_LaunchProductStatus>(
                  future: _statusFuture,
                  builder: (context, snapshot) {
                    final status = snapshot.data;
                    final loading = status == null;
                    final backendOnline = status?.backendOnline == true;
                    final fallback = status?.usedFallback == true;
                    final label = loading
                        ? 'Checking launch status'
                        : '${status.supportedSeason} · ${fallback ? 'DEV DATA' : 'CERTIFIED'} · ${backendOnline ? 'SHARED' : 'LOCAL'}';
                    return Material(
                      elevation: 12,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: status == null ? null : () => _showDetails(status),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF071A33),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: fallback
                                  ? const Color(0xFFFFB547)
                                  : const Color(0xFF6EE7B7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (loading)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                Icon(
                                  backendOnline
                                      ? Icons.cloud_done_rounded
                                      : Icons.cloud_off_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LaunchProductStatus {
  const _LaunchProductStatus({
    required this.supportedSeason,
    required this.datasetStatus,
    required this.validationStatus,
    required this.assetPath,
    required this.warehouseGeneratedAt,
    required this.usedFallback,
    required this.backendOnline,
    required this.backendStatus,
    required this.blockers,
  });

  final String supportedSeason;
  final String datasetStatus;
  final String validationStatus;
  final String assetPath;
  final String warehouseGeneratedAt;
  final bool usedFallback;
  final bool backendOnline;
  final String backendStatus;
  final List<String> blockers;
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        border: Border.all(color: const Color(0xFFFFD28A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}
