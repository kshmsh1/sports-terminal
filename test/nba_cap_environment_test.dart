import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/nba_cap_environment.dart';

void main() {
  const environment = NbaCapEnvironment(
    season: '2026-27',
    effectiveDate: '2026-07-01',
    salaryCap: 164961000,
    taxLevel: 200428000,
    minimumTeamSalary: 148465000,
    firstApron: 209015000,
    secondApron: 221686000,
    nonTaxpayerMle: 15044000,
    taxpayerMle: 6064000,
    roomMle: 9366000,
    sourceLabel: 'NBA Communications',
    sourceUrl: 'https://www.nba.com/',
  );

  test('classifies modeled salary across cap tiers', () {
    expect(environment.positionFor(140000000).tier, 'Below minimum team salary');
    expect(environment.positionFor(155000000).tier, 'Cap-space team');
    expect(environment.positionFor(180000000).tier, 'Over-cap / below-tax');
    expect(environment.positionFor(205000000).tier, 'Tax team');
    expect(environment.positionFor(215000000).tier, 'Above first apron');
    expect(environment.positionFor(225000000).tier, 'Above second apron');
  });

  test('calculates cap, tax and apron room', () {
    final position = environment.positionFor(180000000);

    expect(position.capRoom, -15039000);
    expect(position.taxRoom, 20428000);
    expect(position.firstApronRoom, 29015000);
    expect(position.secondApronRoom, 41686000);
    expect(position.toRow()['tier'], 'Over-cap / below-tax');
  });
}
