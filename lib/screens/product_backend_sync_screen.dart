import 'package:flutter/material.dart';

import '../models/app_session.dart';

class ProductBackendSyncScreen extends StatelessWidget {
  const ProductBackendSyncScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local Data Mode',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sports Terminal no longer connects the customer application to a runtime backend API. User preferences and prototype workspace state are stored locally, while sports datasets are served from reviewed static snapshots.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Static-only policy',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  'Backend sync, remote workbook synchronization, live sports feeds, and remote product API calls are disabled in this build. This screen is retained only so older routes remain source-compatible while the repository is cleaned conservatively.',
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 14),
                Text(
                  'Signed-in prototype user: ${session.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
