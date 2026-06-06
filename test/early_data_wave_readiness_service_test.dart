import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/early_data_wave_readiness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('early data wave readiness evaluates every source-pending NBA wave', () async {
    final summary = await const EarlyDataWaveReadinessService().evaluate();
    final waves = summary.rows.map((row) => row.wave);

    expect(summary.totalBlockers, 0);
    for (final expected in const [
      'Reference teams',
      'Reference seasons',
      'Player identity',
      'Player season stats',
      'Team season stats',
      'Standings',
      'Playoff series',
      'Awards and MVP voting',
      'Games',
      'Rosters',
      'Draft picks',
      'Transactions',
    ]) {
      expect(waves, contains(expected));
    }
    for (final expectedPending in const [
      'Player season stats',
      'Team season stats',
      'Standings',
      'Playoff series',
      'Awards and MVP voting',
      'Games',
      'Rosters',
      'Draft picks',
      'Transactions',
    ]) {
      expect(summary.rows.firstWhere((row) => row.wave == expectedPending).status, 'Source pending');
    }
  });
}
