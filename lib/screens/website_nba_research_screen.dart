import 'package:flutter/material.dart';

import '../services/website_nba_api_service.dart';

class WebsiteNbaResearchScreen extends StatefulWidget {
  const WebsiteNbaResearchScreen({super.key});

  @override
  State<WebsiteNbaResearchScreen> createState() =>
      _WebsiteNbaResearchScreenState();
}

class _WebsiteNbaResearchScreenState extends State<WebsiteNbaResearchScreen> {
  final _data = const WebsiteNbaApiService();
  late final Future<_ResearchCoverage> _future = _load();

  Future<_ResearchCoverage> _load() async {
    final values = await Future.wait<dynamic>([
      _data.manifest(),
      _data.seasons(),
      _data.coverage(),
    ]);
    return _ResearchCoverage(
      manifest: values[0] as Map<String, dynamic>,
      seasons: values[1] as List<WebsiteNbaSeason>,
      coverage: values[2] as List<Map<String, dynamic>>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NBA Research',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Research starts from the same immutable historical NBA corpus used by Home, Stats, Advanced Stats, and canonical player/team pages. Historical facts are not fetched from a runtime NBA API.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<_ResearchCoverage>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _StaticLoadingCard();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _StaticUnavailableCard(error: snapshot.error);
            }
            final data = snapshot.data!;
            final latest = data.manifest['latest_season']?.toString() ?? '—';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 850
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricCard(
                          width: width,
                          label: 'HISTORICAL SEASONS',
                          value: '${data.seasons.length}',
                        ),
                        _MetricCard(
                          width: width,
                          label: 'LATEST STATIC SEASON',
                          value: latest,
                        ),
                        _MetricCard(
                          width: width,
                          label: 'COVERAGE RECORDS',
                          value: '${data.coverage.length}',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Static research foundation',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Completed historical seasons are compiled once into same-origin JSON shards. Player careers, team histories, awards, All-Star context, draft context, historical games, Stats, and Advanced Stats all read those static files. Missing source-backed metrics remain unavailable rather than being reconstructed.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'A future active-season layer can overlay 2026-27 updates while the completed historical corpus stays immutable. At season end, the active season can be frozen into the same static corpus.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _StaticLoadingCard extends StatelessWidget {
  const _StaticLoadingCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Reading local static research index…',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
}

class _StaticUnavailableCard extends StatelessWidget {
  const _StaticUnavailableCard({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Static NBA corpus is not built yet.',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Run scripts/open_terminal.sh so the local historical warehouse is compiled into web/data/nba_static before Flutter starts.',
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _ResearchCoverage {
  const _ResearchCoverage({
    required this.manifest,
    required this.seasons,
    required this.coverage,
  });

  final Map<String, dynamic> manifest;
  final List<WebsiteNbaSeason> seasons;
  final List<Map<String, dynamic>> coverage;
}
