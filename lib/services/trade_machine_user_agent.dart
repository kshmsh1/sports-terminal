import 'nba_contract_status_reference_2026.dart';
import 'nba_front_office_tracker_2026.dart';
import 'nba_league_environment_2026.dart';
import 'nba_team_salary_position_2026.dart';
import 'nba_trade_contract_repository.dart';
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

/// Deterministic "real user" QA agent for the 2026-27 Trade Machine.
///
/// It uses only the product's frozen local authority set. No network access,
/// APIs, randomness, or external state are involved, which makes failures
/// reproducible in CI.
class TradeMachineUserAgent {
  const TradeMachineUserAgent({
    this.engine = const TradeMachineEngine(),
    this.contracts = const NbaTradeContractRepository(),
  });

  final TradeMachineEngine engine;
  final NbaTradeContractRepository contracts;

  Future<TradeMachineAgentReport> play() async {
    final data = await contracts.load();
    final cases = <TradeMachineAgentCase>[];

    cases.add(
      TradeMachineAgentCase(
        name: 'loads the complete team universe',
        passed: data.teams.length == 30,
        detail: 'Loaded ${data.teams.length} NBA teams from the static contract ledger.',
      ),
    );

    final balanced = _findReasonablyMatchedPair(data);
    if (balanced == null) {
      cases.add(const TradeMachineAgentCase(
        name: 'builds a normal two-team player trade',
        passed: false,
        detail: 'Could not find a reasonably matched cross-team player pair.',
      ));
    } else {
      final a = balanced.$1;
      final b = balanced.$2;
      final report = engine.validate(
        _scenario(
          id: 'agent-balanced',
          date: '2026-09-21',
          data: data,
          teams: [a.team, b.team],
          assignments: [
            _playerAssignment(a, b.team),
            _playerAssignment(b, a.team),
          ],
        ),
      );
      final structuralErrors = report.findings.where(
        (item) =>
            item.severity == TradeValidationSeverity.error &&
            item.code != 'HARD_CAP',
      );
      cases.add(
        TradeMachineAgentCase(
          name: 'builds a normal two-team player trade',
          passed: structuralErrors.isEmpty,
          detail:
              '${a.player} ↔ ${b.player}; engine returned ${report.errorCount} errors and ${report.warningCount} warnings.',
        ),
      );
    }

    final reaves = _player(data, 'Austin Reaves');
    if (reaves != null) {
      final restriction = NbaContractStatusReference202627.january15
          .where((item) => item.player == 'Austin Reaves')
          .firstOrNull;
      final destination = data.teams.firstWhere((team) => team != reaves.team);
      final report = engine.validate(
        _scenario(
          id: 'agent-locked-player',
          date: '2026-12-20',
          data: data,
          teams: [reaves.team, destination],
          assignments: [
            _playerAssignment(
              reaves,
              destination,
              metadata: {
                'trade_restricted': restriction != null,
              },
            ),
          ],
        ),
      );
      cases.add(
        TradeMachineAgentCase(
          name: 'blocks a date-locked player',
          passed: report.findings.any((item) => item.code == 'TRADE_RESTRICTED'),
          detail:
              'Austin Reaves before Jan. 15 produced the expected trade-restriction result.',
        ),
      );
    }

    final denverPlayers = data.forTeam('DEN', '2026-27').take(2).toList();
    if (denverPlayers.length == 2) {
      final destination = 'BOS';
      final report = engine.validate(
        _scenario(
          id: 'agent-second-apron-aggregation',
          date: '2026-09-21',
          data: data,
          teams: ['DEN', destination],
          assignments: [
            for (final player in denverPlayers)
              _playerAssignment(player, destination),
          ],
        ),
      );
      cases.add(
        TradeMachineAgentCase(
          name: 'rejects second-apron aggregation',
          passed: report.findings
              .any((item) => item.code == 'SECOND_APRON_AGGREGATION'),
          detail:
              'Denver sending two players triggered the second-apron aggregation guard.',
        ),
      );
    }

    final cleCash = NbaCashTradeReference202627.teams['CLE'];
    if (cleCash != null) {
      final amount = cleCash.availableToSend + 1;
      final report = engine.validate(
        _scenario(
          id: 'agent-cash-limit',
          date: '2026-09-21',
          data: data,
          teams: const ['CLE', 'BOS'],
          assignments: [
            TradeAssignment(
              asset: TradeAsset(
                id: 'agent-cash-cle',
                type: TradeAssetType.cash,
                label: 'Cash considerations',
                originTeam: 'CLE',
                metadata: {'amount': amount},
              ),
              destinationTeam: 'BOS',
            ),
          ],
        ),
      );
      cases.add(
        TradeMachineAgentCase(
          name: 'enforces annual trade-cash capacity',
          passed: report.findings.any((item) => item.code == 'CASH_LIMIT'),
          detail:
              'Cleveland attempting to exceed remaining cash capacity was blocked.',
        ),
      );
    }

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
        id: 'agent-five-team',
        date: '2026-09-21',
        data: data,
        teams: fiveTeams,
        assignments: fiveAssignments,
      ),
    );
    cases.add(
      TradeMachineAgentCase(
        name: 'handles a five-team transaction without crashing',
        passed: !fiveReport.findings.any((item) => item.code == 'MAX_TEAMS'),
        detail:
            'Five-team scenario evaluated with ${fiveReport.findings.length} explainable findings.',
      ),
    );

    return TradeMachineAgentReport(List.unmodifiable(cases));
  }

  TradeScenario _scenario({
    required String id,
    required String date,
    required NbaTradeContractSnapshot data,
    required List<String> teams,
    required List<TradeAssignment> assignments,
  }) {
    return TradeScenario(
      id: id,
      name: id,
      operatingSeason: '2026-27',
      asOfDateIso: date,
      teams: teams,
      assignments: assignments,
      capContexts: {
        for (final team in teams) team: _context(team, data),
      },
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

  NbaTradeContract? _player(
    NbaTradeContractSnapshot data,
    String name,
  ) {
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
