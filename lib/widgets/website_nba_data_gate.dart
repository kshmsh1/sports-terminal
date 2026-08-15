import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';

/// Keeps local-source setup details out of normal customer pages.
///
/// The gate never fabricates a fallback dataset. When the validated NBA seed
/// is absent, it presents an ordinary website empty state instead of exposing
/// Flutter asset-loader exceptions to the user.
class WebsiteNbaDataGate extends StatefulWidget {
  const WebsiteNbaDataGate({
    super.key,
    required this.builder,
    this.repository = const NbaTerminalSeedRepository(),
  });

  final Widget Function(BuildContext context, NbaTerminalSeedSnapshot data)
      builder;
  final NbaTerminalSeedRepository repository;

  @override
  State<WebsiteNbaDataGate> createState() => _WebsiteNbaDataGateState();
}

class _WebsiteNbaDataGateState extends State<WebsiteNbaDataGate> {
  late Future<NbaTerminalSeedSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _retry() {
    setState(() => _future = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _WebsiteLoadingCard();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return WebsiteNbaDataUnavailable(onRetry: _retry);
        }
        return widget.builder(context, snapshot.data!);
      },
    );
  }
}

class WebsiteNbaDataUnavailable extends StatelessWidget {
  const WebsiteNbaDataUnavailable({
    super.key,
    this.onRetry,
  });

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.storage_outlined,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'NBA data is not installed yet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 9),
              Text(
                'This local checkout does not currently have a validated NBA source dataset. Sports Terminal will not invent player statistics just to fill the page.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Restart with scripts/open_terminal.sh after a local source catalog, warehouse or exported seed is available. The launcher will detect it and prepare the website data automatically.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WebsiteLoadingCard extends StatelessWidget {
  const _WebsiteLoadingCard();

  @override
  Widget build(BuildContext context) => const Card(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}
