import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/website_nba_static_repository.dart';

class WebsiteNbaDataCoverageScreen extends StatefulWidget {
  const WebsiteNbaDataCoverageScreen({super.key});

  @override
  State<WebsiteNbaDataCoverageScreen> createState() => _WebsiteNbaDataCoverageScreenState();
}

class _WebsiteNbaDataCoverageScreenState extends State<WebsiteNbaDataCoverageScreen> {
  late Future<_CoverageSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CoverageSnapshot> _load() async {
    final repository = WebsiteNbaStaticRepository();
    final manifest = await repository.manifest();
    final seasons = await repository.seasons();
    final players = await repository.playerIndex();
    final teams = await repository.teamIndex();
    final games = await repository.gameIndex();

    Map<String, dynamic> lineupManifest = const {};
    try {
      final response = await http
          .get(Uri.base.resolve('data/nba_static/lineups/manifest.json'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          lineupManifest = decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      }
    } catch (_) {
      lineupManifest = const {};
    }

    return _CoverageSnapshot(
      manifest: manifest,
      seasons: seasons,
      players: players.length,
      teams: teams.length,
      games: games.length,
      lineupManifest: lineupManifest,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_CoverageSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
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
    final totalSeasonPlayerRows = seasons.fold<int>(0, (sum, season) => sum + season.playerCount);
    final totalSeasonTeamRows = seasons.fold<int>(0, (sum, season) => sum + season.teamCount);
    final lineupDatasets = _mapList(data.lineupManifest['datasets']);
    final lineupRows = _int(data.lineupManifest['row_count']) ?? 0;
    final lineupCaptures = _int(data.lineupManifest['capture_count']) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NBA Data Coverage',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'What Sports Terminal actually has, where it came from and which surfaces are static. This page reports stored coverage; it does not infer missing records or pretend unavailable sources exist.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth >= 1120 ? 5 : constraints.maxWidth >= 680 ? 3 : 1;
            final width = count == 1 ? constraints.maxWidth : (constraints.maxWidth - (count - 1) * 10) / count;
            final cards = <Widget>[
              _CoverageCard(label: 'Seasons', value: '${seasons.length}', detail: '$oldest → $newest'),
              _CoverageCard(label: 'Canonical players', value: '${data.players}', detail: 'player index objects'),
              _CoverageCard(label: 'Canonical teams', value: '${data.teams}', detail: 'team / franchise objects'),
              _CoverageCard(label: 'Historical games', value: '${data.games}', detail: 'indexed static games'),
              _CoverageCard(label: 'Lineup rows', value: '$lineupRows', detail: '$lineupCaptures NBA.com captures'),
            ];
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final card in cards) SizedBox(width: width, child: card)],
            );
          },
        ),
        const SizedBox(height: 18),
        _PolicyCard(manifest: data.manifest),
        const SizedBox(height: 22),
        Text(
          'Season coverage',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          '$totalSeasonPlayerRows player-season rows and $totalSeasonTeamRows team-season rows are represented across the static catalog below.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _SeasonCoverageTable(seasons: seasons),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Lineup coverage',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (data.lineupManifest.isNotEmpty)
              Text(
                (data.lineupManifest['contract'] ?? '').toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (lineupDatasets.isEmpty)
          _EmptyCoverage(
            title: 'No static lineup manifest found',
            detail: 'Lineup Analysis remains source-disciplined and will show no rows until NBA.com lineup captures are materialized locally.',
          )
        else
          _LineupCoverage(datasets: lineupDatasets),
        const SizedBox(height: 24),
        _MetricLineageNote(),
      ],
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.label, required this.value, required this.detail});

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
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.manifest});

  final Map<String, dynamic> manifest;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final contract = (manifest['contract'] ?? manifest['schema'] ?? 'Static NBA corpus').toString();
    final generated = (manifest['generated_at'] ?? manifest['generatedAt'] ?? manifest['built_at'] ?? '').toString();
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Historical NBA statistics, entity pages and imported NBA.com enrichment are rendered from local static artifacts. The browser should not need a live NBA.com request to display a completed historical sample.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag('Contract: $contract'),
                const _Tag('Static historical delivery'),
                const _Tag('Missing data stays missing'),
                const _Tag('Canonical entity links'),
                if (generated.isNotEmpty) _Tag('Built: $generated'),
              ],
            ),
          ],
        ),
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
      return const _EmptyCoverage(title: 'No season catalog', detail: 'The static season catalog could not be read.');
    }
    final headerStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .018),
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

class _LineupCoverage extends StatelessWidget {
  const _LineupCoverage({required this.datasets});

  final List<Map<String, dynamic>> datasets;

  @override
  Widget build(BuildContext context) {
    final sorted = [...datasets]
      ..sort((a, b) {
        final aq = _int(a['group_quantity']) ?? 5;
        final bq = _int(b['group_quantity']) ?? 5;
        if (aq != bq) return bq.compareTo(aq);
        final season = (b['season'] ?? '').toString().compareTo((a['season'] ?? '').toString());
        if (season != 0) return season;
        return (a['season_type'] ?? '').toString().compareTo((b['season_type'] ?? '').toString());
      });
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final row in sorted)
          _Tag(
            '${_int(row['group_quantity']) ?? 5}-player · ${row['season'] ?? '—'} · ${_labelSeasonType(row['season_type'])} · ${_int(row['rows']) ?? 0} rows',
          ),
      ],
    );
  }
}

class _MetricLineageNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Metric lineage guardrails',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 9),
              const Text(
                'Offensive 3P% and 3P DFG% are distinct measures and remain separate throughout ingestion, storage and display. 3P% describes the shooter’s own makes divided by attempts; 3P DFG% describes an opponent’s percentage on defended three-point attempts while the selected player is the closest defender.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 9),
              Text(
                'The same source-lineage rule applies to every enriched metric: a similarly named field from a different NBA.com surface is not silently substituted just because the table would otherwise contain a dash.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
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
        child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
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
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(detail, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45)),
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
              Text('Coverage report unavailable', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('${error ?? 'Unable to read static NBA manifests.'}'),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _CoverageSnapshot {
  const _CoverageSnapshot({
    required this.manifest,
    required this.seasons,
    required this.players,
    required this.teams,
    required this.games,
    required this.lineupManifest,
  });

  final Map<String, dynamic> manifest;
  final List<WebsiteNbaStaticSeason> seasons;
  final int players;
  final int teams;
  final int games;
  final Map<String, dynamic> lineupManifest;
}

Widget _tableCell(String text, {TextStyle? style, bool numeric = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Align(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(text, style: style),
      ),
    );

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, field) => MapEntry(key.toString(), field)),
  ];
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _labelSeasonType(Object? value) {
  final text = value?.toString() ?? '';
  return text.toLowerCase().contains('play') ? 'Playoffs' : 'Regular Season';
}
