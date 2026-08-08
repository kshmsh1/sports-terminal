import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_metric_catalog.dart';

void main() {
  test('defensive DREB expands only into contested and uncontested defensive rebounds', () {
    final defense = nbaTerminalFamily('defense_hustle');
    final keys = nbaVisibleMetricKeys(defense, {'dreb'});
    final index = keys.indexOf('dreb');

    expect(index, greaterThanOrEqualTo(0));
    expect(
      keys.sublist(index, index + 3),
      ['dreb', 'contested_dreb_pg', 'uncontested_dreb_pg'],
    );
    expect(keys, isNot(contains('drb_pct')));
  });

  test('usage remains source-backed rather than relabeling scoring load', () {
    final usage = nbaTerminalMetricByKey['usage'];
    expect(usage, isNotNull);
    expect(usage!.engineKey, isNull);
    expect(usage.providerNative, isTrue);
    expect(usage.rawAliases, containsAll(['usage', 'usage_pct', 'usg_pct']));
  });
}
