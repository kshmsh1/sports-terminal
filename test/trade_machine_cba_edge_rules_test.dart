import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/trade_machine_engine.dart';

void main() {
  const engine = TradeMachineEngine();

  test('2026-27 cap context exposes official threshold model', () {
    final context = TeamCapContext.nba2026_27(
      team: 'BOS',
      teamSalary: 210000000,
    );
    expect(context.salaryCap, 164961000);
    expect(context.taxLine, 200428000);
    expect(context.firstApron, 209015000);
    expect(context.secondApron, 221686000);
    expect(context.aboveFirstApron, isTrue);
    expect(context.aboveSecondApron, isFalse);
  });

  test('BYC and poison-pill matching salaries replace nominal salary', () {
    const player = TradeAsset(
      id: 'player-complex',
      type: TradeAssetType.player,
      label: 'Complex Contract Player',
      originTeam: 'AAA',
      salary: 20000000,
      metadata: {
        'base_year_compensation': true,
        'outgoing_matching_salary': 10000000,
        'poison_pill': true,
        'incoming_matching_salary': 25000000,
      },
    );
    final report = engine.validate(
      TradeScenario(
        id: 'byc-poison',
        name: 'BYC poison pill',
        operatingSeason: '2026-27',
        teams: const ['AAA', 'BBB'],
        assignments: const [
          TradeAssignment(asset: player, destinationTeam: 'BBB'),
        ],
        capContexts: {
          'AAA': TeamCapContext.nba2026_27(
            team: 'AAA',
            teamSalary: 120000000,
          ),
          'BBB': TeamCapContext.nba2026_27(
            team: 'BBB',
            teamSalary: 100000000,
          ),
        },
      ),
    );
    expect(report.teamSummaries['AAA']!.outgoingSalary, 10000000);
    expect(report.teamSummaries['BBB']!.incomingSalary, 25000000);
    expect(
      report.findings.map((item) => item.code),
      containsAll(['BYC_APPLIED', 'POISON_PILL_APPLIED']),
    );
  });

  test('missing authoritative BYC and poison-pill values block validation', () {
    const player = TradeAsset(
      id: 'player-missing-values',
      type: TradeAssetType.player,
      label: 'Missing Values Player',
      originTeam: 'AAA',
      salary: 12000000,
      metadata: {
        'base_year_compensation': true,
        'poison_pill': true,
      },
    );
    final report = engine.validate(
      TradeScenario(
        id: 'missing-values',
        name: 'Missing values',
        operatingSeason: '2026-27',
        teams: const ['AAA', 'BBB'],
        assignments: const [
          TradeAssignment(asset: player, destinationTeam: 'BBB'),
        ],
        capContexts: {
          'AAA': TeamCapContext.nba2026_27(
            team: 'AAA',
            teamSalary: 120000000,
          ),
          'BBB': TeamCapContext.nba2026_27(
            team: 'BBB',
            teamSalary: 120000000,
          ),
        },
      ),
    );
    expect(report.isValid, isFalse);
    expect(
      report.findings.map((item) => item.code),
      containsAll(['BYC_VALUE_REQUIRED', 'POISON_PILL_VALUE_REQUIRED']),
    );
  });

  test('dated trade restriction respects scenario as-of date', () {
    const player = TradeAsset(
      id: 'recently-signed',
      type: TradeAssetType.player,
      label: 'Recently Signed Player',
      originTeam: 'AAA',
      salary: 8000000,
      metadata: {'recently_signed_until': '2026-12-15T00:00:00Z'},
    );
    final report = engine.validate(
      TradeScenario(
        id: 'dated',
        name: 'Dated restriction',
        operatingSeason: '2026-27',
        asOfDateIso: '2026-11-01T00:00:00Z',
        teams: const ['AAA', 'BBB'],
        assignments: const [
          TradeAssignment(asset: player, destinationTeam: 'BBB'),
        ],
        capContexts: {
          'AAA': TeamCapContext.nba2026_27(
            team: 'AAA',
            teamSalary: 140000000,
          ),
          'BBB': TeamCapContext.nba2026_27(
            team: 'BBB',
            teamSalary: 140000000,
          ),
        },
      ),
    );
    expect(
      report.findings.map((item) => item.code),
      contains('DATED_TRADE_RESTRICTION'),
    );
    expect(report.isValid, isFalse);
  });

  test('sign-and-trade hard-cap check rejects first-apron finish', () {
    const player = TradeAsset(
      id: 'sat-player',
      type: TradeAssetType.player,
      label: 'Sign-and-Trade Player',
      originTeam: 'AAA',
      salary: 20000000,
      metadata: {'sign_and_trade': true},
    );
    final report = engine.validate(
      TradeScenario(
        id: 'sat',
        name: 'Sign and trade',
        operatingSeason: '2026-27',
        teams: const ['AAA', 'BBB'],
        assignments: const [
          TradeAssignment(asset: player, destinationTeam: 'BBB'),
        ],
        capContexts: {
          'AAA': TeamCapContext.nba2026_27(
            team: 'AAA',
            teamSalary: 150000000,
          ),
          'BBB': TeamCapContext.nba2026_27(
            team: 'BBB',
            teamSalary: 200000000,
          ),
        },
      ),
    );
    expect(
      report.findings.map((item) => item.code),
      contains('SIGN_AND_TRADE_FIRST_APRON'),
    );
    expect(report.isValid, isFalse);
  });

  test('cash limits and frozen picks are hard blockers', () {
    const cash = TradeAsset(
      id: 'cash',
      type: TradeAssetType.cash,
      label: 'Cash Consideration',
      originTeam: 'AAA',
      metadata: {'amount': 3000000},
    );
    const pick = TradeAsset(
      id: 'pick',
      type: TradeAssetType.draftPick,
      label: '2031 first-round pick',
      originTeam: 'AAA',
      metadata: {
        'round': '1',
        'draft_year': 2031,
        'years_out': 5,
        'frozen': true,
        'protection': 'Top-4 protected',
      },
    );
    final report = engine.validate(
      TradeScenario(
        id: 'cash-pick',
        name: 'Cash and pick',
        operatingSeason: '2026-27',
        teams: const ['AAA', 'BBB'],
        assignments: const [
          TradeAssignment(asset: cash, destinationTeam: 'BBB'),
          TradeAssignment(asset: pick, destinationTeam: 'BBB'),
        ],
        capContexts: {
          'AAA': TeamCapContext.nba2026_27(
            team: 'AAA',
            teamSalary: 130000000,
            cashSentThisSeason: 4000000,
            cashLimitThisSeason: 6000000,
          ),
          'BBB': TeamCapContext.nba2026_27(
            team: 'BBB',
            teamSalary: 130000000,
          ),
        },
      ),
    );
    expect(
      report.findings.map((item) => item.code),
      containsAll(['CASH_LIMIT', 'FROZEN_PICK', 'PICK_PROTECTION']),
    );
    expect(report.isValid, isFalse);
  });

  test('consecutive first-round interests trigger Stepien review without safe metadata', () {
    const pick2029 = TradeAsset(
      id: '2029-first',
      type: TradeAssetType.draftPick,
      label: '2029 first',
      originTeam: 'AAA',
      metadata: {'round': '1', 'draft_year': 2029, 'years_out': 3},
    );
    const pick2030 = TradeAsset(
      id: '2030-first',
      type: TradeAssetType.draftPick,
      label: '2030 first',
      originTeam: 'AAA',
      metadata: {'round': '1', 'draft_year': 2030, 'years_out': 4},
    );
    final report = engine.validate(
      TradeScenario(
        id: 'stepien',
        name: 'Stepien review',
        operatingSeason: '2026-27',
        teams: const ['AAA', 'BBB'],
        assignments: const [
          TradeAssignment(asset: pick2029, destinationTeam: 'BBB'),
          TradeAssignment(asset: pick2030, destinationTeam: 'BBB'),
        ],
        capContexts: {
          'AAA': TeamCapContext.nba2026_27(
            team: 'AAA',
            teamSalary: 120000000,
          ),
          'BBB': TeamCapContext.nba2026_27(
            team: 'BBB',
            teamSalary: 120000000,
          ),
        },
      ),
    );
    expect(
      report.findings.map((item) => item.code),
      contains('STEPIEN_REVIEW'),
    );
    expect(report.requiresReview, isTrue);
  });
}
