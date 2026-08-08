import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_terminal_command_engine.dart';

void main() {
  const engine = NbaTerminalCommandEngine();

  test('exact shortcuts and command IDs resolve deterministically', () {
    expect(engine.resolve('STAT')?.id, 'stats');
    expect(engine.resolve('history')?.id, 'history');
    expect(engine.resolve('PY')?.id, 'python');
    expect(engine.resolve('TRD')?.id, 'trade');
  });

  test('natural language searches surface relevant terminal functions', () {
    final allTime = engine.search('all time records');
    expect(allTime, isNotEmpty);
    expect(allTime.first.command.id, 'history');

    final salary = engine.search('salary matching apron');
    expect(salary, isNotEmpty);
    expect(salary.first.command.id, 'trade');

    final spreadsheet = engine.search('spreadsheet model');
    expect(spreadsheet, isNotEmpty);
    expect(spreadsheet.first.command.id, 'workspace');
  });

  test('organization-only commands are permission filtered', () {
    expect(
      engine.search('organization', organizationMode: false)
          .where((item) => item.command.id == 'organization'),
      isEmpty,
    );
    expect(
      engine.search('organization', organizationMode: true)
          .where((item) => item.command.id == 'organization'),
      isNotEmpty,
    );
  });

  test('empty search returns the core catalog without restricted commands', () {
    final matches = engine.search('', organizationMode: false, limit: 100);
    expect(matches.any((item) => item.command.id == 'terminal'), isTrue);
    expect(matches.any((item) => item.command.id == 'stats'), isTrue);
    expect(matches.any((item) => item.command.id == 'organization'), isFalse);
  });
}
