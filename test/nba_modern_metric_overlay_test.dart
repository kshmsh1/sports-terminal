import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_modern_metric_overlay_repository.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';

void main() {
  const resolver = NbaTerminalMetricResolver();

  NbaStatsRow fixtureRow() => const NbaStatsRow(
        playerId: '2544',
        player: 'Fixture Star',
        team: 'AAA',
        position: 'SF',
        values: {
          'gp': 10,
          'pts': 25,
          'reb': 8,
          'ast': 6,
        },
        percentiles: {},
        raw: {},
        possessionsEstimated: false,
      );

  test('modern NBA API overlay populates source-aware metric aliases', () {
    const overlay = NbaModernMetricOverlay(
      season: '2025-26',
      seasonType: 'regular',
      byPlayerId: {
        '2544': {
          'deflections_pg': 3.4,
          'charges_drawn_pg': 0.6,
          'ftr': 0.31,
        },
      },
      byCanonicalPlayerKey: {},
      byPlayerName: {},
      metricKeys: {'deflections_pg', 'charges_drawn_pg', 'ftr'},
    );

    final row = overlay.enrich(fixtureRow());
    expect(resolver.value(row, 'deflections_pg'), 3.4);
    expect(resolver.value(row, 'charges_drawn_pg'), 0.6);
    expect(resolver.value(row, 'ftr'), 0.31);
    expect(resolver.format(row, 'deflections_pg'), '3.4');
  });

  test('overlay can match canonical player identity when NBA id differs', () {
    const overlay = NbaModernMetricOverlay(
      season: '2025-26',
      seasonType: 'regular',
      byPlayerId: {},
      byCanonicalPlayerKey: {
        'canonical-fixture-star': {'dfg_pct': 0.421},
      },
      byPlayerName: {},
      metricKeys: {'dfg_pct'},
    );

    final row = NbaStatsRow(
      playerId: 'canonical-fixture-star',
      player: 'Fixture Star',
      team: 'AAA',
      position: 'SF',
      values: const {'gp': 10},
      percentiles: const {},
      raw: const {},
      possessionsEstimated: false,
    );
    final enriched = overlay.enrich(row);
    expect(resolver.value(enriched, 'dfg_pct'), closeTo(0.421, 1e-9));
  });

  test('empty overlay leaves existing stats row unchanged', () {
    final row = fixtureRow();
    final enriched = NbaModernMetricOverlay.empty.enrich(row);
    expect(identical(enriched, row), isTrue);
  });
}
