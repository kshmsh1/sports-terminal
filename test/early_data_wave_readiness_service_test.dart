import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/early_data_wave_readiness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('early data wave readiness evaluates source-pending stat waves', () async {
    final summary = await const EarlyDataWaveReadinessService().evaluate();

    expect(summary.totalBlockers, 0);
    expect(summary.rows.map((row) => row.wave), contains('Reference teams'));
    expect(summary.rows.map((row) => row.wave), contains('Reference seasons'));
    expect(summary.rows.map((row) => row.wave), contains('Player identity'));
    expect(summary.rows.map((row) => row.wave), contains('Player season stats'));
    expect(summary.rows.map((row) => row.wave), contains('Team season stats'));
    expect(summary.rows.firstWhere((row) => row.wave == 'Player season stats').status, 'Source pending');
    expect(summary.rows.firstWhere((row) => row.wave == 'Team season stats').status, 'Source pending');
  });
}
