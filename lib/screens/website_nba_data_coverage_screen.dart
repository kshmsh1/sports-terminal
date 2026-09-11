import 'package:flutter/material.dart';

import '../services/website_nba_static_repository.dart';

class WebsiteNbaDataCoverageScreen extends StatefulWidget {
  const WebsiteNbaDataCoverageScreen({super.key});

  @override
  State<WebsiteNbaDataCoverageScreen> createState() =>
      _WebsiteNbaDataCoverageScreenState();
}

class _WebsiteNbaDataCoverageScreenState
    extends State<WebsiteNbaDataCoverageScreen> {
  late Future<_CoverageSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CoverageSnapshot> _load() async {
    final repository = WebsiteNbaStaticRepository();
    final values = await Future.wait<dynamic>([
      repository.manifest(),
      repository.dataFoundation(),
      repository.researchCatalog(),
      repository.seasons(),
      repository.playerIndex(),
      repository.teamIndex(),
      repository.gameIndex(),
    ]);
    return _CoverageSnapshot(
      manifest: values[0] as Map<String, dynamic>,
      foundation: values[1] as Map<String, dynamic>,
      catalog: values[2] as Map<String, dynamic>,
      seasons: values[3] as List<WebsiteNbaStaticSeason>,
      players: (values[4] as List).length,
      teams: (values[5] as List).length,
      games: (values[6] as List).length,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_CoverageSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _CoverageError(
              error: snapshot.error,
              onRetry: () => setState(() => _future = _load()),
            );
          }
          return _CoverageBody(data: snapshot.data!);
        },
      );
}

class _CoverageBody extends StatelessWidget {
  const _CoverageBody({required this.data});

  final _CoverageSnapshot data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final seasons = data.seasons;
    final newest = seasons.isEmpty ? '—' : seasons.first.id;
    final oldest = seasons.isEmpty ? '—' : seasons.last.id;
    final providers = _mapList(data.foundation['providers']);
    final datasets = _mapList(data.catalog['datasets']);
    final catalogSummary = _map(data.catalog['summary']);
    final totalSeasonPlayerRows = seasons.fold<int>(
      0,
      (sum, season) => sum + season.playerCount,
    );
    final totalSeasonTeamRows = seasons.fold<int>(
      0,
      (sum, season) => sum + season.teamCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NBA Data Coverage',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A transparent inventory of the local historical corpus, provider inputs and research datasets. Historical pages render from static files; acquisition is separate from browsing.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            const _StaticBadge(),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth >= 1160
                ? 6
                : constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 460
                        ? 2
                        : 1;
            final width = count == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (count - 1) * 10) / count;
            final cards = <Widget>[
              _CoverageCard(
                label: 'Seasons',
                value: '${seasons.length}',
                detail: '$oldest → $newest',
              ),
              _CoverageCard(
                label: 'Players',
                value: '${data.players}',
                detail: 'canonical player objects',
              ),
              _CoverageCard(
                label: 'Teams',
                value: '${data.teams}',
                detail: 'team / franchise objects',
              ),
              _CoverageCard(
                label: 'Games',
                value: '${data.games}',
                detail: 'indexed static games',
              ),
              _CoverageCard(
                label: 'Providers',
                value:
                    '${_int(data.foundation['available_provider_count']) ?? providers.where((row) => row['available'] == true).length}/${_int(data.foundation['provider_count']) ?? providers.length}',
                detail: 'available locally',
              ),
              _CoverageCard(
                label: 'Research families',
                value: '${_int(catalogSummary['dataset_families']) ?? datasets.length}',
                detail:
                    '${_int(catalogSummary['available']) ?? 0} ready · ${_int(catalogSummary['partial']) ?? 0} partial',
              ),
            ];
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _PolicyCard(
          manifest: data.manifest,
          foundation: data.foundation,
          catalog: data.catalog,
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Provider foundation',
          detail:
              'Each provider has an explicit role. Availability means files are present locally; it does not imply every metric exists for every season.',
        ),
        const SizedBox(height: 12),
        _ProviderGrid(providers: providers),
        const SizedBox(height: 30),
        _SectionHeader(
          title: 'Research dataset families',
          detail:
              'The catalog distinguishes ready, partial and missing families so the UI can expose capability without fabricating rows.',
        ),
        const SizedBox(height: 12),
        _DatasetTable(datasets: datasets),
        const SizedBox(height: 30),
        _SectionHeader(
          title: 'Season coverage',
          detail:
              '$totalSeasonPlayerRows player-season rows and $totalSeasonTeamRows team-season rows are represented across the static catalog.',
        ),
        const SizedBox(height: 12),
        _SeasonCoverageTable(seasons: seasons),
        const SizedBox(height: 28),
        const _LineageCard(),
      ],
    );
  }
}

class _StaticBadge extends StatelessWidget {
  const _StaticBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.offline_bolt_outlined,
              size: 17,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 7),
            Text(
              'Static historical delivery',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 5),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.manifest,
    required this.foundation,
    required this.catalog,
  });

  final Map<String, dynamic> manifest;
  final Map<String, dynamic> foundation;
  final Map<String, dynamic> catalog;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final contract =
        (manifest['contract'] ?? manifest['schema'] ?? 'Static NBA corpus')
            .toString();
    final foundationContract = (foundation['contract'] ?? '').toString();
    final catalogContract = (catalog['contract'] ?? '').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Historical delivery policy',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Historical statistics, entity pages, awards, games and imported enrichment are compiled into local static artifacts. NBA.com, SportsDataverse, pbpstats and Basketball-Reference are acquisition or enrichment sources—not browser-time dependencies.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag('Corpus: $contract'),
                if (foundationContract.isNotEmpty)
                  _Tag('Foundation: $foundationContract'),
                if (catalogContract.isNotEmpty)
                  _Tag('Catalog: $catalogContract'),
                const _Tag('Missing data stays missing'),
                const _Tag('Canonical entity graph'),
                const _Tag('Live season = overlay + snapshot'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      );
}

class _ProviderGrid extends StatelessWidget {
  const _ProviderGrid({required this.providers});

  final List<Map<String, dynamic>> providers;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return const _EmptyCoverage(
        title: 'No provider foundation found',
        detail:
            'Rebuild the static corpus to generate data_foundation.json.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 650
                ? 2
                : 1;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final provider in providers)
              SizedBox(
                width: width,
                child: _ProviderCard(provider: provider),
              ),
          ],
        );
      },
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider});

  final Map<String, dynamic> provider;

  @override
  Widget build(BuildContext context) {
    final available = provider['available'] == true;
    final colors = Theme.of(context).colorScheme;
    final capabilities = _stringList(provider['capabilities']);
    final inventory = _map(provider['inventory']);
    final files = _int(inventory['file_count']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  available
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 19,
                  color: available ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (provider['label'] ?? provider['key'] ?? 'Provider')
                        .toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              (provider['role'] ?? '').toString().replaceAll('_', ' '),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (files != null) ...[
              const SizedBox(height: 4),
              Text(
                '$files local files',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
            if (capabilities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                capabilities.take(4).join(' · '),
                style: const TextStyle(height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DatasetTable extends StatelessWidget {
  const _DatasetTable({required this.datasets});

  final List<Map<String, dynamic>> datasets;

  @override
  Widget build(BuildContext context) {
    if (datasets.isEmpty) {
      return const _EmptyCoverage(
        title: 'No research catalog found',
        detail:
            'Rebuild the static corpus to generate research_catalog.json.',
      );
    }
    final colors = Theme.of(context).colorScheme;
    final sorted = [...datasets]
      ..sort((a, b) {
        final status = _statusRank(a['status']).compareTo(_statusRank(b['status']));
        if (status != 0) return status;
        return (a['label'] ?? '').toString().compareTo((b['label'] ?? '').toString());
      });
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1040),
          child: DataTable(
            headingRowHeight: 46,
            dataRowMinHeight: 54,
            dataRowMaxHeight: 76,
            columns: const [
              DataColumn(label: Text('Dataset')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Grain')),
              DataColumn(label: Text('Providers')),
              DataColumn(label: Text('Product surfaces')),
            ],
            rows: [
              for (final row in sorted)
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 210,
                        child: Text(
                          (row['label'] ?? row['key'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    DataCell(_StatusPill(status: (row['status'] ?? 'partial').toString())),
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Text((row['grain'] ?? '').toString()),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: Text(
                          _stringList(row['providers'])
                              .map((item) => item.replaceAll('_', ' '))
                              .join(' · '),
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 270,
                        child: Text(_stringList(row['surfaces']).join(' · ')),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalized = status.toLowerCase();
    final color = normalized == 'available'
        ? colors.primary
        : normalized == 'missing'
            ? colors.error
            : colors.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        normalized,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SeasonCoverageTable extends StatelessWidget {
  const _SeasonCoverageTable({required this.seasons});

  final List<WebsiteNbaStaticSeason> seasons;

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) {
      return const _EmptyCoverage(
        title: 'No season catalog',
        detail: 'The static season catalog could not be read.',
      );
    }
    final headerStyle = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(fontWeight: FontWeight.w900);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              children: [
                _tableCell('Season', style: headerStyle),
                _tableCell('Players', style: headerStyle, numeric: true),
                _tableCell('Teams', style: headerStyle, numeric: true),
                _tableCell('Games', style: headerStyle, numeric: true),
              ],
            ),
            for (var index = 0; index < seasons.length; index++)
              TableRow(
                decoration: index.isOdd
                    ? BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .018),
                      )
                    : null,
                children: [
                  _tableCell(seasons[index].id),
                  _tableCell('${seasons[index].playerCount}', numeric: true),
                  _tableCell('${seasons[index].teamCount}', numeric: true),
                  _tableCell('${seasons[index].gameCount}', numeric: true),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LineageCard extends StatelessWidget {
  const _LineageCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Metric lineage guardrails',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 9),
              const Text(
                'Sports Terminal never substitutes a similarly named metric from a different definition just to remove a dash. Offensive 3P%, defended 3P%, team pace, player pace, box-score usage and tracking-derived usage remain distinct fields with their own source lineage.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                'The research catalog is intentionally capability-oriented: a dataset family may be partial even when the main Stats page is complete. That makes future acquisition work visible without destabilizing the existing historical site.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
}

class _EmptyCoverage extends StatelessWidget {
  const _EmptyCoverage({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                detail,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CoverageError extends StatelessWidget {
  const _CoverageError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coverage report unavailable',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('${error ?? 'Unable to read static NBA manifests.'}'),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

class _CoverageSnapshot {
  const _CoverageSnapshot({
    required this.manifest,
    required this.foundation,
    required this.catalog,
    required this.seasons,
    required this.players,
    required this.teams,
    required this.games,
  });

  final Map<String, dynamic> manifest;
  final Map<String, dynamic> foundation;
  final Map<String, dynamic> catalog;
  final List<WebsiteNbaStaticSeason> seasons;
  final int players;
  final int teams;
  final int games;
}

Widget _tableCell(
  String text, {
  TextStyle? style,
  bool numeric = false,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Align(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(text, style: style),
      ),
    );

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, field) => MapEntry(key.toString(), field));
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, field) => MapEntry(key.toString(), field)),
  ];
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

int _statusRank(Object? value) {
  switch ((value ?? '').toString().toLowerCase()) {
    case 'available':
      return 0;
    case 'partial':
      return 1;
    case 'missing':
      return 2;
    default:
      return 3;
  }
}
