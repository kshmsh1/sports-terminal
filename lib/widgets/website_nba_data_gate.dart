import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import '../services/website_nba_api_service.dart';

/// Compatibility wrapper for website surfaces that historically expected a
/// terminal-seed snapshot before they were allowed to render.
///
/// The traditional website now owns its data loading at the individual-screen
/// level. A missing legacy seed, a temporarily unavailable static index, or a
/// failed preflight request must never replace the entire website page with a
/// global "NBA data unavailable" screen.
///
/// We still try to resolve the canonical static snapshot in the background so
/// any older builder that happens to consume the snapshot receives real data
/// when available. While that check is running, or if it fails, the page is
/// rendered with an empty compatibility snapshot. Current website builders do
/// not depend on this value; they read their own immutable static datasets.
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
  static const NbaTerminalSeedSnapshot _emptySnapshot =
      NbaTerminalSeedSnapshot(
    manifest: <String, dynamic>{},
    teams: <Map<String, dynamic>>[],
    players: <Map<String, dynamic>>[],
    games: <Map<String, dynamic>>[],
    teamRecords: <Map<String, dynamic>>[],
    teamGameLogs: <Map<String, dynamic>>[],
    playerSeasonTotals: <Map<String, dynamic>>[],
    playerLeaders: <String, dynamic>{},
    playerGameHighs: <String, dynamic>{},
    playerGameLogsTop: <Map<String, dynamic>>[],
    searchIndex: <Map<String, dynamic>>[],
    dataDictionary: <String, dynamic>{},
    validationReport: null,
    assetManifest: null,
    launchConfig: <String, dynamic>{
      'datasetStatus': 'website-screen-owned',
      'supportedSeason': '2025-26',
    },
    assetPath: 'website://screen-owned',
  );

  late Future<NbaTerminalSeedSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAvailableData();
  }

  Future<NbaTerminalSeedSnapshot> _loadAvailableData() async {
    Object? staticError;

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

    try {
      return await widget.repository.load();
    } catch (legacyError) {
      throw NbaTerminalSeedException(
        'NBA website data preflight failed. Static corpus error: '
        '${staticError ?? 'unknown'}; legacy seed error: $legacyError',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: _future,
      initialData: _emptySnapshot,
      builder: (context, snapshot) {
        // initialData guarantees a non-null compatibility snapshot while the
        // background preflight runs. Never block an entire destination because
        // this shared check is slow or unavailable.
        return widget.builder(context, snapshot.data!);
      },
    );
  }
}

/// Local, opt-in error state for a screen that genuinely cannot render its own
/// required dataset. This is intentionally no longer used as the global NBA
/// navigation gate.
class WebsiteNbaDataUnavailable extends StatelessWidget {
  const WebsiteNbaDataUnavailable({
    super.key,
    this.onRetry,
    this.error,
    this.title = 'NBA data unavailable for this view',
  });

  final VoidCallback? onRetry;
  final Object? error;
  final String title;

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
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 9),
              Text(
                'This specific view could not read the local dataset it needs. '
                'Other Sports Terminal pages remain available.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
