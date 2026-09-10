import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';

/// Protects NBA pages from genuinely missing local data without tying the
/// website to the legacy bundled terminal-seed transport.
///
/// Historical/current website pages now read the immutable static corpus under
/// `web/data/nba_static`. The old bundled seed remains a compatibility fallback
/// for development surfaces that still consume [NbaTerminalSeedSnapshot]
/// directly.
///
/// This distinction matters because the local launcher materializes the static
/// website corpus before Flutter starts. Checking only the old asset bundle can
/// therefore report "NBA data is not installed" even when the website data was
/// successfully built and is available over the local web server.
class WebsiteNbaDataGate extends StatefulWidget {
  const WebsiteNbaDataGate({
    super.key,
    required this.builder,
    this.repository = const NbaTerminalSeedRepository(),
    this.websiteApi = const WebsiteNbaApiService(),
  });

  final Widget Function(BuildContext context, NbaTerminalSeedSnapshot data)
      builder;
  final NbaTerminalSeedRepository repository;
  final WebsiteNbaApiService websiteApi;

  @override
  State<WebsiteNbaDataGate> createState() => _WebsiteNbaDataGateState();
}

class _WebsiteNbaDataGateState extends State<WebsiteNbaDataGate> {
  late Future<NbaTerminalSeedSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAvailableData();
  }

  Future<NbaTerminalSeedSnapshot> _loadAvailableData() async {
    Object? staticError;

    // The website static corpus is the canonical transport for the current
    // browser experience. Check it first so a valid local build is never
    // rejected merely because the deprecated terminal-seed assets are absent.
    try {
      final seasons = await widget.websiteApi.seasons();
      if (seasons.isNotEmpty) {
        final preferred = seasons.firstWhere(
          (season) => season.id == '2025-26',
          orElse: () => seasons.first,
        );
        return await widget.websiteApi.seasonSnapshot(
          preferred.id,
          seasonType: 'regular',
        );
      }
      staticError = const NbaTerminalSeedException(
        'Static NBA season catalog is empty.',
      );
    } catch (error) {
      staticError = error;
    }

    // Compatibility path for older tests/checkouts and any remaining surfaces
    // that still ship the bundled terminal seed.
    try {
      return await widget.repository.load();
    } catch (legacyError) {
      throw NbaTerminalSeedException(
        'NBA website data is unavailable. Static corpus error: '
        '${staticError ?? 'unknown'}; legacy seed error: $legacyError',
      );
    }
  }

  void _retry() {
    setState(() => _future = _loadAvailableData());
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
          return WebsiteNbaDataUnavailable(
            onRetry: _retry,
            error: snapshot.error,
          );
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
    this.error,
  });

  final VoidCallback? onRetry;
  final Object? error;

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
                'NBA data is unavailable',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 9),
              Text(
                'Sports Terminal could not read either the precompiled NBA website corpus or the legacy bundled seed. Player statistics will not be invented to fill the page.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Restart with scripts/open_terminal.sh so the launcher can prepare and validate web/data/nba_static before Flutter starts.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
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
