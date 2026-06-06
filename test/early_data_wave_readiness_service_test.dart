import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/early_data_wave_readiness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('early data wave readiness evaluates source-pending stat and context waves', () async {
    final summary = await const EarlyDataWaveReadinessService().evaluate();
    final waves = summary.rows.map((row) => row.wave);

    expect(summary.totalBlockers, 0);
    expect(waves, contains('Reference teams'));
    expect(waves, contains('Reference seasons'));
    expect(waves, contains('Player identity'));
    expect(waves, contains('Player season stats'));
    expect(waves, contains('Team season stats'));
    expect(waves, contains('Standings'));
    expect(waves, contains('Playoff series'));
    expect(waves, contains('Awards and MVP voting'));
    expect(summary.rows.firstWhere((row) => row.wave == 'Player season stats').status, 'Source pending');
    expect(summary.rows.firstWhere((row) => row.wave == 'Team season stats').status, 'Source pending');
    expect(summary.rows.firstWhere((row) => row.wave == 'Standings').status, 'Source pending');
    expect(summary.rows.firstWhere((row) => row.wave == 'Playoff series').status, 'Source pending');
    expect(summary.rows.firstWhere((row) => row.wave == 'Awards and MVP voting').status, 'Source pending');
  });
}
