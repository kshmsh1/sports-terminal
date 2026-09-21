import 'nba_complete_draft_asset_repository.dart';
import 'nba_contract_status_reference_2026.dart';
import 'nba_front_office_tracker_2026.dart';
import 'nba_league_environment_2026.dart';
import 'nba_team_salary_position_2026.dart';
import 'nba_trade_contract_repository.dart';
import 'nba_trade_exception_reference_2026.dart';
import 'trade_machine_engine.dart';

class TradeMachineAgentCase {
  const TradeMachineAgentCase({
    required this.name,
    required this.passed,
    required this.detail,
  });

  final String name;
  final bool passed;
  final String detail;
}

class TradeMachineAgentReport {
  const TradeMachineAgentReport(this.cases);

  final List<TradeMachineAgentCase> cases;

  bool get passed => cases.every((item) => item.passed);
  int get passedCount => cases.where((item) => item.passed).length;
  int get failedCount => cases.length - passedCount;
}

/// Release-style deterministic QA agent for the 2026-27 Trade Machine.
///
/// This is intentionally more demanding than a unit smoke test. It acts like a
/// power user trying normal trades, malformed trades, apron-sensitive trades,
/// draft-pick structures, exceptions, cash, timing restrictions and special
/// contract treatments. It uses only the app's frozen local data.
class TradeMachineUserAgent {
  const TradeMachineUserAgent({
    this.engine = const TradeMachineEngine(),
    this.contracts = const NbaTradeContractRepository(),
    this.drafts = const NbaCompleteDraftAssetRepository(),
  });

  final TradeMachineEngine engine;
  final NbaTradeContractRepository contracts;
  final NbaCompleteDraftAssetRepository drafts;

  Future<TradeMachineAgentReport> play() async {
    final data = await contracts.load();
    final cases = <TradeMachineAgentCase>[];

    void expectCode(
      String name,
      TradeValidationReport report,
      String code,
      String detail,
    ) {
      cases.add(
        TradeMachineAgentCase(
          name: name,
          passed: report.findings.any((item) => item.code == code),
          detail: detail,
        ),
      );
    }

    cases.add(
      TradeMachineAgentCase(
        name: 'loads complete static league authority',
        passed:
            data.teams.length == 30 &&
            data.records.isNotEmpty &&
            drafts.all().isNotEmpty,
        detail:
            'Loaded ${data.teams.length} teams, ${data.records.length} contracts and ${drafts.all().length} draft interests.',
      ),
    );

    final teamsWithNoContracts =
        data.teams.where((team) => data.forTeam(team, '2026-27').isEmpty).toList();
    cases.add(
      TradeMachineAgentCase(
        name: 'every team has a usable 2026-27 standard roster ledger',
        passed: teamsWithNoContracts.isEmpty,
        detail: teamsWithNoContracts.isEmpty
            ? 'All 30 teams have contract rows.'
            : 'Missing contract rows: ${teamsWithNoContracts.join(', ')}',
      ),
    );

    final balanced = _findReasonablyMatchedPair(data);
    if (balanced == null) {
      cases.add(const TradeMachineAgentCase(
        name: 'normal two-team player trade evaluates',
        passed: false,
        detail: 'Could not find a reasonably matched cross-team salary pair.',
      ));
    } else {
      final a = balanced.$1;
      final b = balanced.$2;
      final report = engine.validate(
        _scenario(
          id: 'balanced',
          date: '2026-09-21',
          data: data,
          teams: [a.team, b.team],
          assignments: [
            _playerAssignment(a, b.team),
            _playerAssignment(b, a.team),
          ],
        ),
      );
      cases.add(
        TradeMachineAgentCase(
          name: 'normal two-team player trade evaluates',
          passed:
              report.teamSummaries.length == 2 &&
              !report.findings.any((item) =>
                  item.code == 'TEAM_SCOPE' ||
                  item.code == 'SAME_TEAM' ||
                  item.code == 'DUPLICATE_ASSET'),
          detail:
              '${a.player} ↔ ${b.player} produced both team summaries and ${report.findings.length} explainable findings.',
        ),
      );
    }

    final low = data.records
        .where((p) => p.salaryFor('2026-27') > 0)
        .reduce((a, b) => a.salaryFor('2026-27') < b.salaryFor('2026-27') ? a : b);
    final high = data.records
        .where((p) => p.team != low.team)
        .reduce((a, b) => a.salaryFor('2026-27') > b.salaryFor('2026-27') ? a : b);
    final mismatch = engine.validate(
      _scenario(
        id: 'salary-mismatch',
        date: '2026-09-21',
        data: data,
        teams: [low.team, high.team],
        assignments: [
          _playerAssignment(low, high.team),
          _playerAssignment(high, low.team),
        ],
      ),
    );
    expectCode(
      'blocks clearly illegal salary matching',
      mismatch,
      'SALARY_MATCH',
      'A minimum/low salary was swapped against one of the largest salaries in the ledger.',
    );

    final reaves = _player(data, 'Austin Reaves');
    if (reaves != null) {
      final destination = data.teams.firstWhere((team) => team != reaves.team);
      final before = engine.validate(
        _scenario(
          id: 'jan15-before',
          date: '2026-12-20',
          data: data,
          teams: [reaves.team, destination],
          assignments: [
            _playerAssignment(
              reaves,
              destination,
              metadata: const {
                'trade_restricted': true,
                'trade_restricted_until': '2027-01-15',
              },
            ),
          ],
        ),
      );
      expectCode(
        'blocks known January 15 player before eligibility date',
        before,
        'DATED_TRADE_RESTRICTION',
        'Austin Reaves is tested before January 15, 2027.',
      );

      final after = engine.validate(
        _scenario(
          id: 'jan15-after',
          date: '2027-01-16',
          data: data,
          teams: [reaves.team, destination],
          assignments: [
            _playerAssignment(
              reaves,
              destination,
              metadata: const {'trade_restricted_until': '2027-01-15'},
            ),
          ],
        ),
      );
      cases.add(
        TradeMachineAgentCase(
          name: 'date restriction expires when eligibility date passes',
          passed: !after.findings.any(
            (item) => item.code == 'DATED_TRADE_RESTRICTION',
          ),
          detail: 'The same player is retested on January 16, 2027.',
        ),
      );
    }

    final consent = data.forTeam('DEN', '2026-27').first;
    final consentReport = engine.validate(
      _scenario(
        id: 'consent',
        date: '2026-09-21',
        data: data,
        teams: const ['DEN', 'BOS'],
        assignments: [
          _playerAssignment(consent, 'BOS', metadata: const {'no_trade': true}),
        ],
      ),
    );
    expectCode(
      'surfaces player consent/no-trade rights',
      consentReport,
      'NO_TRADE_CLAUSE',
      'A player marked with trade-consent rights requires approval.',
    );

    final kickerReport = engine.validate(
      _scenario(
        id: 'kicker',
        date: '2026-09-21',
        data: data,
        teams: const ['DEN', 'BOS'],
        assignments: [
          _playerAssignment(
            consent,
            'BOS',
            metadata: const {'trade_kicker': 3},
          ),
        ],
      ),
    );
    expectCode(
      'surfaces trade kicker treatment',
      kickerReport,
      'TRADE_BONUS',
      'A player carrying a modeled trade kicker is flagged for matching treatment.',
    );

    final denverPlayers = data.forTeam('DEN', '2026-27').take(2).toList();
    if (denverPlayers.length == 2) {
      final base = _scenario(
        id: 'second-apron-aggregation',
        date: '2026-09-21',
        data: data,
        teams: const ['DEN', 'BOS'],
        assignments: [
          for (final player in denverPlayers)
            _playerAssignment(player, 'BOS'),
          _playerAssignment(data.forTeam('BOS', '2026-27').first, 'DEN'),
        ],
      );
      final report = engine.validate(
        _replaceContext(
          base,
          'DEN',
          _syntheticContext(
            'DEN',
            NbaLeagueEnvironment202627.secondApron + 1,
            data,
          ),
        ),
      );
      expectCode(
        'blocks second-apron salary aggregation',
        report,
        'SECOND_APRON_AGGREGATION',
        'A synthetic above-second-apron Denver sends two standard players.',
      );
    }

    final secondApronCash = engine.validate(
      _scenario(
        id: 'second-apron-cash',
        date: '2026-09-21',
        data: data,
        teams: const ['DEN', 'BOS'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'cash-second-apron',
              type: TradeAssetType.cash,
              label: 'Cash considerations',
              originTeam: 'DEN',
              metadata: {'amount': 1},
            ),
            destinationTeam: 'BOS',
          ),
        ],
        overrides: {
          'DEN': TeamCapContext(
            team: 'DEN',
            teamSalary: 221686001,
            salaryCap: 164961000,
            taxLine: 200428000,
            firstApron: 209015000,
            secondApron: 221686000,
            cashLimitThisSeason: 8495000,
          ),
        },
      ),
    );
    expectCode(
      'blocks second-apron team from sending cash',
      secondApronCash,
      'SECOND_APRON_CASH',
      'An above-second-apron team attempts to include cash.',
    );

    final cleCash = NbaCashTradeReference202627.teams['CLE']!;
    final cashLimit = engine.validate(
      _scenario(
        id: 'cash-limit',
        date: '2026-09-21',
        data: data,
        teams: const ['CLE', 'BOS'],
        assignments: [
          TradeAssignment(
            asset: TradeAsset(
              id: 'cash-cle',
              type: TradeAssetType.cash,
              label: 'Cash considerations',
              originTeam: 'CLE',
              metadata: {'amount': cleCash.availableToSend + 1},
            ),
            destinationTeam: 'BOS',
          ),
        ],
      ),
    );
    expectCode(
      'enforces remaining annual trade-cash capacity',
      cashLimit,
      'CASH_LIMIT',
      'Cleveland attempts to send one dollar more than its remaining authority.',
    );

    final zeroCash = engine.validate(
      _scenario(
        id: 'cash-zero',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'cash-zero',
              type: TradeAssetType.cash,
              label: 'Cash considerations',
              originTeam: 'BOS',
              metadata: {'amount': 0},
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'rejects empty cash consideration',
      zeroCash,
      'CASH_AMOUNT_REQUIRED',
      'A cash asset must have a positive amount.',
    );

    final hardCapReport = engine.validate(
      _scenario(
        id: 'hard-cap',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: [
          TradeAssignment(
            asset: TradeAsset(
              id: 'hard-cap-player',
              type: TradeAssetType.player,
              label: 'Synthetic incoming salary',
              originTeam: 'PHI',
              salary: 5000000,
            ),
            destinationTeam: 'BOS',
          ),
        ],
        overrides: {
          'BOS': TeamCapContext(
            team: 'BOS',
            teamSalary: 208000000,
            salaryCap: 164961000,
            taxLine: 200428000,
            firstApron: 209015000,
            secondApron: 221686000,
            hardCappedAt: 209015000,
            standardRosterPlayers: 14,
          ),
        },
      ),
    );
    expectCode(
      'enforces hard-cap ceiling',
      hardCapReport,
      'HARD_CAP',
      'Boston is modeled just below its hard cap and receives enough salary to cross it.',
    );

    final tpe = NbaTradeExceptionReference202627.tpes
        .firstWhere((item) => !item.exhausted);
    final tpeReport = engine.validate(
      _scenario(
        id: 'valid-tpe',
        date: '2026-09-21',
        data: data,
        teams: [tpe.team, data.teams.firstWhere((team) => team != tpe.team)],
        assignments: [
          TradeAssignment(
            asset: TradeAsset(
              id: tpe.id,
              type: TradeAssetType.tradeException,
              label: 'TPE · ${tpe.sourceTransaction}',
              originTeam: tpe.team,
              salary: tpe.available,
              metadata: {
                'amount': tpe.available,
                'expires_at': tpe.expires,
              },
            ),
            destinationTeam:
                data.teams.firstWhere((team) => team != tpe.team),
          ),
        ],
      ),
    );
    expectCode(
      'recognizes live traded-player exception usage',
      tpeReport,
      'EXCEPTION_REVIEW',
      'A current non-exhausted TPE is routed through the engine.',
    );

    final expiredTpe = engine.validate(
      _scenario(
        id: 'expired-tpe',
        date: '2028-01-01',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'expired-tpe',
              type: TradeAssetType.tradeException,
              label: 'Expired TPE',
              originTeam: 'BOS',
              salary: 1000000,
              metadata: {
                'amount': 1000000,
                'expires_at': '2027-01-01',
              },
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'rejects expired exception',
      expiredTpe,
      'EXPIRED_EXCEPTION',
      'An exception is tested after its expiration date.',
    );

    final frozen = drafts.all().firstWhere((item) => item.frozen);
    final frozenReport = engine.validate(
      _scenario(
        id: 'frozen-pick',
        date: '2026-09-21',
        data: data,
        teams: [frozen.team, data.teams.firstWhere((t) => t != frozen.team)],
        assignments: [
          _draftAssignment(
            frozen.team,
            data.teams.firstWhere((t) => t != frozen.team),
            frozen.id,
            frozen.label,
            frozen.year,
            frozen.round,
            frozen: true,
          ),
        ],
      ),
    );
    expectCode(
      'blocks frozen first-round pick',
      frozenReport,
      'FROZEN_PICK',
      'The static draft repository contains a frozen pick and it is rejected.',
    );

    final protected = drafts.all().firstWhere(
      (item) => item.protection != null && item.protection!.isNotEmpty,
    );
    final protectedReport = engine.validate(
      _scenario(
        id: 'protected-pick',
        date: '2026-09-21',
        data: data,
        teams: [
          protected.team,
          data.teams.firstWhere((t) => t != protected.team),
        ],
        assignments: [
          _draftAssignment(
            protected.team,
            data.teams.firstWhere((t) => t != protected.team),
            protected.id,
            protected.label,
            protected.year,
            protected.round,
            protection: protected.protection,
          ),
        ],
      ),
    );
    expectCode(
      'preserves pick protection semantics',
      protectedReport,
      'PICK_PROTECTION',
      'A real protected draft interest retains its protection metadata.',
    );

    final swap = drafts.all().firstWhere((item) => item.swapRight);
    final swapReport = engine.validate(
      _scenario(
        id: 'swap-pick',
        date: '2026-09-21',
        data: data,
        teams: [swap.team, data.teams.firstWhere((t) => t != swap.team)],
        assignments: [
          _draftAssignment(
            swap.team,
            data.teams.firstWhere((t) => t != swap.team),
            swap.id,
            swap.label,
            swap.year,
            swap.round,
            swapRight: true,
          ),
        ],
      ),
    );
    expectCode(
      'preserves pick-swap semantics',
      swapReport,
      'PICK_SWAP',
      'A real swap interest is recognized as a swap rather than a plain pick.',
    );

    final stepien = engine.validate(
      _scenario(
        id: 'stepien',
        date: '2026-09-21',
        data: data,
        teams: const ['CHI', 'BOS'],
        assignments: [
          _draftAssignment('CHI', 'BOS', 'chi-2028', '2028 CHI 1st', 2028, 1),
          _draftAssignment('CHI', 'BOS', 'chi-2029', '2029 CHI 1st', 2029, 1),
        ],
      ),
    );
    expectCode(
      'flags consecutive outgoing first-round interests for Stepien review',
      stepien,
      'STEPIEN_REVIEW',
      'Chicago sends first-round interests in consecutive draft years.',
    );

    final twoWay = engine.validate(
      _scenario(
        id: 'two-way',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'two-way-player',
              type: TradeAssetType.player,
              label: 'Two-Way Player',
              originTeam: 'BOS',
              salary: 678882,
              metadata: {'two_way': true},
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'recognizes two-way contract treatment',
      twoWay,
      'TWO_WAY_CONTRACT',
      'Two-way salary is excluded from normal matching and standard-roster counts.',
    );
    cases.add(
      TradeMachineAgentCase(
        name: 'two-way salary is excluded from matching totals',
        passed: twoWay.teamSummaries['BOS']?.outgoingSalary == 0,
        detail:
            'Boston outgoing matching salary is ${twoWay.teamSummaries['BOS']?.outgoingSalary}.',
      ),
    );

    final bycRequired = engine.validate(
      _scenario(
        id: 'byc-required',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'byc-required-player',
              type: TradeAssetType.player,
              label: 'BYC Player',
              originTeam: 'BOS',
              salary: 20000000,
              metadata: {'base_year_compensation': true},
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'requires authoritative BYC matching value',
      bycRequired,
      'BYC_VALUE_REQUIRED',
      'Nominal salary alone cannot validate a BYC player.',
    );

    final poisonRequired = engine.validate(
      _scenario(
        id: 'poison-required',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'poison-required-player',
              type: TradeAssetType.player,
              label: 'Poison Pill Player',
              originTeam: 'BOS',
              salary: 10000000,
              metadata: {'poison_pill': true},
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'requires authoritative poison-pill receiving value',
      poisonRequired,
      'POISON_PILL_VALUE_REQUIRED',
      'A poison-pill player cannot use nominal salary for the receiving team.',
    );

    final signAndTrade = engine.validate(
      _scenario(
        id: 'sign-and-trade',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'sat-player',
              type: TradeAssetType.player,
              label: 'Sign-and-Trade Player',
              originTeam: 'PHI',
              salary: 1000000,
              metadata: {'sign_and_trade': true},
            ),
            destinationTeam: 'BOS',
          ),
        ],
        overrides: {
          'BOS': TeamCapContext(
            team: 'BOS',
            teamSalary: 209000000,
            salaryCap: 164961000,
            taxLine: 200428000,
            firstApron: 209015000,
            secondApron: 221686000,
            standardRosterPlayers: 14,
          ),
        },
      ),
    );
    expectCode(
      'blocks sign-and-trade acquisition above first apron',
      signAndTrade,
      'SIGN_AND_TRADE_FIRST_APRON',
      'The receiving team would finish above the first apron.',
    );

    final duplicate = engine.validate(
      _scenario(
        id: 'duplicate',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'dup',
              type: TradeAssetType.cash,
              label: 'Cash A',
              originTeam: 'BOS',
              metadata: {'amount': 1},
            ),
            destinationTeam: 'PHI',
          ),
          TradeAssignment(
            asset: TradeAsset(
              id: 'dup',
              type: TradeAssetType.cash,
              label: 'Cash B',
              originTeam: 'BOS',
              metadata: {'amount': 1},
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'rejects duplicate asset routing',
      duplicate,
      'DUPLICATE_ASSET',
      'The same asset ID cannot be routed twice.',
    );

    final sameTeam = engine.validate(
      _scenario(
        id: 'same-team',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'same',
              type: TradeAssetType.cash,
              label: 'Cash',
              originTeam: 'BOS',
              metadata: {'amount': 1},
            ),
            destinationTeam: 'BOS',
          ),
        ],
      ),
    );
    expectCode(
      'rejects routing an asset back to its origin team',
      sameTeam,
      'SAME_TEAM',
      'Origin and destination cannot be identical.',
    );

    final empty = engine.validate(
      _scenario(
        id: 'empty',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [],
      ),
    );
    expectCode(
      'rejects empty trade scenario',
      empty,
      'EMPTY_SCENARIO',
      'A transaction must contain at least one asset.',
    );

    final minTeams = engine.validate(
      TradeScenario(
        id: 'min-teams',
        name: 'min-teams',
        operatingSeason: '2026-27',
        asOfDateIso: '2026-09-21',
        teams: const ['BOS'],
        assignments: const [],
        capContexts: {'BOS': TeamCapContext.nba2026_27(team: 'BOS', teamSalary: 190000000)},
      ),
    );
    expectCode(
      'requires at least two teams',
      minTeams,
      'MIN_TEAMS',
      'A one-team scenario is rejected.',
    );

    final duplicateTeam = engine.validate(
      TradeScenario(
        id: 'duplicate-team',
        name: 'duplicate-team',
        operatingSeason: '2026-27',
        asOfDateIso: '2026-09-21',
        teams: const ['BOS', 'BOS'],
        assignments: const [],
        capContexts: {'BOS': TeamCapContext.nba2026_27(team: 'BOS', teamSalary: 190000000)},
      ),
    );
    expectCode(
      'rejects duplicate participating teams',
      duplicateTeam,
      'DUPLICATE_TEAM',
      'The same franchise cannot occupy two participant slots.',
    );

    final teamScope = engine.validate(
      _scenario(
        id: 'team-scope',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'scope',
              type: TradeAssetType.cash,
              label: 'Out-of-scope cash',
              originTeam: 'LAL',
              metadata: {'amount': 1},
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'rejects assets from non-participating teams',
      teamScope,
      'TEAM_SCOPE',
      'An asset originating outside the selected teams is rejected.',
    );

    final restrictedAggregation = engine.validate(
      _scenario(
        id: 'restricted-aggregation',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'aggregate-a',
              type: TradeAssetType.player,
              label: 'Restricted Aggregation Player',
              originTeam: 'BOS',
              salary: 5000000,
              metadata: {'cannot_aggregate': true},
            ),
            destinationTeam: 'PHI',
          ),
          TradeAssignment(
            asset: TradeAsset(
              id: 'aggregate-b',
              type: TradeAssetType.player,
              label: 'Second Player',
              originTeam: 'BOS',
              salary: 5000000,
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'enforces player-specific aggregation restrictions',
      restrictedAggregation,
      'PLAYER_AGGREGATION_RESTRICTED',
      'A player flagged as non-aggregatable is combined with another outgoing salary.',
    );

    final exceptionAmount = engine.validate(
      _scenario(
        id: 'exception-amount',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'zero-exception',
              type: TradeAssetType.tradeException,
              label: 'Zero TPE',
              originTeam: 'BOS',
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'requires a positive exception amount',
      exceptionAmount,
      'EXCEPTION_AMOUNT_REQUIRED',
      'A zero-dollar exception cannot be used.',
    );

    final uncertainPick = engine.validate(
      _scenario(
        id: 'uncertain-pick',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: [
          _draftAssignment(
            'BOS',
            'PHI',
            'uncertain-pick',
            'Conditional first',
            2029,
            1,
            conveyanceUncertain: true,
          ),
        ],
      ),
    );
    expectCode(
      'preserves uncertain conveyance review',
      uncertainPick,
      'PICK_CONVEYANCE_UNCERTAIN',
      'A conditional conveyance remains visibly unresolved.',
    );

    final distantPick = engine.validate(
      _scenario(
        id: 'distant-pick',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: [
          _draftAssignment(
            'BOS',
            'PHI',
            'distant-pick',
            '2035 first',
            2035,
            1,
            yearsOut: 9,
          ),
        ],
      ),
    );
    expectCode(
      'blocks picks beyond the modeled seven-season horizon',
      distantPick,
      'PICK_TOO_DISTANT',
      'A first-round asset nine seasons out is rejected.',
    );

    final explicitStepien = engine.validate(
      _scenario(
        id: 'explicit-stepien',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: [
          _draftAssignment(
            'BOS',
            'PHI',
            'stepien-conflict',
            'Blocked first',
            2030,
            1,
            stepienConflict: true,
          ),
        ],
      ),
    );
    expectCode(
      'blocks explicit Stepien conflicts',
      explicitStepien,
      'STEPIEN_CONFLICT',
      'A pick explicitly marked as creating a continuity gap is rejected.',
    );

    final datedReview = engine.validate(
      TradeScenario(
        id: 'dated-review',
        name: 'dated-review',
        operatingSeason: '2026-27',
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'dated-review-player',
              type: TradeAssetType.player,
              label: 'Recently signed player',
              originTeam: 'BOS',
              salary: 5000000,
              metadata: {'recently_signed_until': '2026-12-15'},
            ),
            destinationTeam: 'PHI',
          ),
        ],
        capContexts: const {
          'BOS': TeamCapContext.nba2026_27(team: 'BOS', teamSalary: 190000000),
          'PHI': TeamCapContext.nba2026_27(team: 'PHI', teamSalary: 190000000),
        },
      ),
    );
    expectCode(
      'requires date review when timed restriction lacks scenario date',
      datedReview,
      'DATED_TRADE_RESTRICTION_REVIEW',
      'A timed restriction cannot silently pass without an as-of date.',
    );

    final bycApplied = engine.validate(
      _scenario(
        id: 'byc-applied',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'byc-applied-player',
              type: TradeAssetType.player,
              label: 'BYC Applied Player',
              originTeam: 'BOS',
              salary: 20000000,
              metadata: {
                'base_year_compensation': true,
                'outgoing_matching_salary': 10000000,
              },
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'uses explicit BYC outgoing matching salary',
      bycApplied,
      'BYC_APPLIED',
      'The engine reports the authoritative sender-side BYC value.',
    );

    final poisonApplied = engine.validate(
      _scenario(
        id: 'poison-applied',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'poison-applied-player',
              type: TradeAssetType.player,
              label: 'Poison Pill Applied Player',
              originTeam: 'BOS',
              salary: 10000000,
              metadata: {
                'poison_pill': true,
                'incoming_matching_salary': 18000000,
              },
            ),
            destinationTeam: 'PHI',
          ),
        ],
      ),
    );
    expectCode(
      'uses explicit poison-pill receiving salary',
      poisonApplied,
      'POISON_PILL_APPLIED',
      'The engine reports the authoritative receiving-team matching value.',
    );

    final rosterMax = engine.validate(
      _scenario(
        id: 'roster-max',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'roster-player',
              type: TradeAssetType.player,
              label: 'Roster Player',
              originTeam: 'PHI',
              salary: 1000000,
            ),
            destinationTeam: 'BOS',
          ),
        ],
        overrides: const {
          'BOS': TeamCapContext.nba2026_27(
            team: 'BOS',
            teamSalary: 190000000,
            standardRosterPlayers: 15,
          ),
        },
      ),
    );
    expectCode(
      'warns when a trade creates more than 15 standard contracts',
      rosterMax,
      'ROSTER_MAX',
      'A 15-man roster receives an additional standard player.',
    );

    final rosterMin = engine.validate(
      _scenario(
        id: 'roster-min',
        date: '2026-09-21',
        data: data,
        teams: const ['BOS', 'PHI'],
        assignments: const [
          TradeAssignment(
            asset: TradeAsset(
              id: 'roster-out',
              type: TradeAssetType.player,
              label: 'Outgoing Player',
              originTeam: 'BOS',
              salary: 1000000,
            ),
            destinationTeam: 'PHI',
          ),
        ],
        overrides: const {
          'BOS': TeamCapContext.nba2026_27(
            team: 'BOS',
            teamSalary: 190000000,
            standardRosterPlayers: 14,
            minimumStandardRosterPlayers: 14,
          ),
        },
      ),
    );
    expectCode(
      'warns when standard roster falls below modeled minimum',
      rosterMin,
      'ROSTER_MIN',
      'A 14-man roster sends a standard player without receiving one.',
    );

    final fiveTeams = data.teams.take(5).toList();
    final fiveAssignments = <TradeAssignment>[];
    for (var index = 0; index < fiveTeams.length; index++) {
      final team = fiveTeams[index];
      final next = fiveTeams[(index + 1) % fiveTeams.length];
      final roster = data.forTeam(team, '2026-27');
      if (roster.isNotEmpty) {
        fiveAssignments.add(_playerAssignment(roster.first, next));
      }
    }
    final fiveReport = engine.validate(
      _scenario(
        id: 'five-team',
        date: '2026-09-21',
        data: data,
        teams: fiveTeams,
        assignments: fiveAssignments,
      ),
    );
    cases.add(
      TradeMachineAgentCase(
        name: 'supports the product maximum of five teams',
        passed: !fiveReport.findings.any((item) => item.code == 'MAX_TEAMS'),
        detail:
            'Five-team scenario evaluated with ${fiveReport.findings.length} explainable findings.',
      ),
    );

    final sixReport = engine.validate(
      _scenario(
        id: 'six-team',
        date: '2026-09-21',
        data: data,
        teams: data.teams.take(6).toList(),
        assignments: const [],
      ),
    );
    expectCode(
      'rejects more than five participating teams',
      sixReport,
      'MAX_TEAMS',
      'Six teams exceeds the product transaction limit.',
    );

    return TradeMachineAgentReport(List.unmodifiable(cases));
  }

  TradeScenario _scenario({
    required String id,
    required String date,
    required NbaTradeContractSnapshot data,
    required List<String> teams,
    required List<TradeAssignment> assignments,
    Map<String, TeamCapContext> overrides = const {},
  }) {
    return TradeScenario(
      id: id,
      name: id,
      operatingSeason: '2026-27',
      asOfDateIso: date,
      teams: teams,
      assignments: assignments,
      capContexts: {
        for (final team in teams)
          team: overrides[team] ?? _context(team, data),
      },
    );
  }

  TradeScenario _replaceContext(
    TradeScenario scenario,
    String team,
    TeamCapContext context,
  ) {
    return TradeScenario(
      id: scenario.id,
      name: scenario.name,
      operatingSeason: scenario.operatingSeason,
      asOfDateIso: scenario.asOfDateIso,
      teams: scenario.teams,
      assignments: scenario.assignments,
      capContexts: {...scenario.capContexts, team: context},
    );
  }

  TeamCapContext _context(String team, NbaTradeContractSnapshot data) {
    final total =
        NbaTeamSalaryPosition202627.forTeam(team)?.totalSalary ??
        data.payroll(team, '2026-27');
    final hardCap = switch (
      NbaFrontOfficeTracker202627.hardCaps[team]?.capLevel
    ) {
      'first' => NbaLeagueEnvironment202627.firstApron,
      'second' => NbaLeagueEnvironment202627.secondApron,
      _ => null,
    };
    final cash = NbaCashTradeReference202627.teams[team];
    return TeamCapContext(
      team: team,
      teamSalary: total,
      salaryCap: NbaLeagueEnvironment202627.salaryCap,
      taxLine: NbaLeagueEnvironment202627.luxuryTax,
      firstApron: NbaLeagueEnvironment202627.firstApron,
      secondApron: NbaLeagueEnvironment202627.secondApron,
      hardCappedAt: hardCap,
      standardRosterPlayers: data.forTeam(team, '2026-27').length,
      cashSentThisSeason:
          NbaCashTradeReference202627.limit -
          (cash?.availableToSend ?? NbaCashTradeReference202627.limit),
      cashLimitThisSeason: NbaCashTradeReference202627.limit,
    );
  }

  TeamCapContext _syntheticContext(
    String team,
    double salary,
    NbaTradeContractSnapshot data,
  ) {
    return TeamCapContext(
      team: team,
      teamSalary: salary,
      salaryCap: NbaLeagueEnvironment202627.salaryCap,
      taxLine: NbaLeagueEnvironment202627.luxuryTax,
      firstApron: NbaLeagueEnvironment202627.firstApron,
      secondApron: NbaLeagueEnvironment202627.secondApron,
      standardRosterPlayers: data.forTeam(team, '2026-27').length,
      cashLimitThisSeason: NbaCashTradeReference202627.limit,
    );
  }

  TradeAssignment _playerAssignment(
    NbaTradeContract player,
    String destination, {
    Map<String, dynamic> metadata = const {},
  }) {
    return TradeAssignment(
      asset: TradeAsset(
        id: player.id,
        type: TradeAssetType.player,
        label: player.player,
        originTeam: player.team,
        salary: player.salaryFor('2026-27'),
        metadata: metadata,
      ),
      destinationTeam: destination,
    );
  }

  TradeAssignment _draftAssignment(
    String origin,
    String destination,
    String id,
    String label,
    int year,
    int round, {
    bool frozen = false,
    bool swapRight = false,
    String? protection,
    bool conveyanceUncertain = false,
    bool stepienConflict = false,
    int? yearsOut,
  }) {
    return TradeAssignment(
      asset: TradeAsset(
        id: id,
        type: TradeAssetType.draftPick,
        label: label,
        originTeam: origin,
        metadata: {
          'draft_year': year,
          'round': '$round',
          if (frozen) 'frozen': true,
          if (swapRight) 'swap_right': true,
          if (protection != null) 'protection': protection,
          if (conveyanceUncertain) 'conveyance_uncertain': true,
          if (stepienConflict) 'stepien_conflict': true,
          if (yearsOut != null) 'years_out': yearsOut,
        },
      ),
      destinationTeam: destination,
    );
  }

  NbaTradeContract? _player(NbaTradeContractSnapshot data, String name) {
    for (final item in data.records) {
      if (item.player == name) return item;
    }
    return null;
  }

  (NbaTradeContract, NbaTradeContract)? _findReasonablyMatchedPair(
    NbaTradeContractSnapshot data,
  ) {
    for (final a in data.records) {
      final aSalary = a.salaryFor('2026-27');
      if (aSalary < 3000000) continue;
      for (final b in data.records) {
        if (a.team == b.team) continue;
        final bSalary = b.salaryFor('2026-27');
        if (bSalary < 3000000) continue;
        final ratio = aSalary > bSalary ? aSalary / bSalary : bSalary / aSalary;
        if (ratio <= 1.08) return (a, b);
      }
    }
    return null;
  }
}
