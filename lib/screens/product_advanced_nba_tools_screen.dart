import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/launch_auth_client.dart';
import 'product_analytics_library_screen.dart';
import 'product_analytics_suite_screen.dart';

class ProductAdvancedNbaToolsScreen extends StatefulWidget {
  const ProductAdvancedNbaToolsScreen({super.key});

  @override
  State<ProductAdvancedNbaToolsScreen> createState() =>
      _ProductAdvancedNbaToolsScreenState();
}

class _ProductAdvancedNbaToolsScreenState
    extends State<ProductAdvancedNbaToolsScreen> {
  late final Future<AppSession?> _sessionFuture;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _sessionFuture = const LaunchAuthClient().restore().then(
          (result) => result.session,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF111827),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              _AnalyticsModeTab(
                label: 'Analytics Suite',
                icon: Icons.analytics_rounded,
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 6),
              _AnalyticsModeTab(
                label: 'Saved Library',
                icon: Icons.bookmarks_rounded,
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: _tab == 0
              ? const ProductAnalyticsSuiteScreen()
              : FutureBuilder<AppSession?>(
                  future: _sessionFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final session = snapshot.data;
                    if (session == null) {
                      return const _AnalyticsLibraryUnavailable();
                    }
                    return ProductAnalyticsLibraryScreen(session: session);
                  },
                ),
        ),
      ],
    );
  }
}

class _AnalyticsModeTab extends StatelessWidget {
  const _AnalyticsModeTab({
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
        color: selected
            ? const Color(0xFFFFCB45)
            : const Color(0xFF252F41),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? const Color(0xFF111827)
                      : const Color(0xFFA2ACBD),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF111827)
                        : const Color(0xFFF3F6FB),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _AnalyticsLibraryUnavailable extends StatelessWidget {
  const _AnalyticsLibraryUnavailable();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF151C29),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: Color(0xFFFFCB45), size: 42),
            SizedBox(height: 12),
            Text(
              'Saved Analytics Library requires a customer session',
              style: TextStyle(
                color: Color(0xFFF3F6FB),
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Development demo roles can use the Analytics Suite, but cross-device saved views and organization libraries require a backend-authenticated account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA2ACBD)),
            ),
          ],
        ),
      );
}
