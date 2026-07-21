import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/front_office_ledger.dart';
import 'package:sports_terminal/models/nba_cap_environment.dart';
import 'package:sports_terminal/services/front_office_ledger_engine.dart';

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
  sourceLabel: 'Official NBA release',
  sourceUrl: 'https://www.nba.com/',
);

void main() {
  const engine = FrontOfficeLedgerEngine();

  test('contract model round trips complete financial metadata', () {
    const contract = NbaContractYear(
      id: 'bos-player-2026',
      playerLabel: 'Modeled Player',
      teamId: 'BOS',
      season: '2026-27',
      salary: 30000000,
      guaranteedAmount: 24000000,
      guarantee: ContractGuarantee.partial,
      option: ContractOption.player,
      tradeKickerPct: 10,
      noTradeClause: true,
      notes: 'User-entered test row',
    );
    final decoded = NbaContractYear.fromJson(contract.toJson());
    expect(decoded.playerLabel, 'Modeled Player');
    expect(decoded.guarantee, ContractGuarantee.partial);
    expect(decoded.option, ContractOption.player);
    expect(decoded.nonGuaranteedAmount, 6000000);
    expect(decoded.noTradeClause, isTrue);
  });

  test('ledger summary reconciles contracts and cap charges', () {
    final contracts = [
      const NbaContractYear(
        id: 'a',
        playerLabel: 'A',
        teamId: 'BOS',
        season: '2026-27',
        salary: 100000000,
        guaranteedAmount: 90000000,
      ),
      const NbaContractYear(
        id: 'b',
        playerLabel: 'B',
        teamId: 'BOS',
        season: '2026-27',
        salary: 60000000,
        guaranteedAmount: 60000000,
      ),
    ];
    final summary = engine.summarize(
      contracts: contracts,
      inputs: const NbaTeamLedgerInputs(
        teamId: 'BOS',
        season: '2026-27',
        deadMoney: 5000000,
        capHolds: 10000000,
      ),
      environment: environment,
    );
    expect(summary.activeSalary, 160000000);
    expect(summary.guaranteedSalary, 150000000);
    expect(summary.teamSalary, 175000000);
    expect(summary.position.tier, 'Over-cap / below-tax');
    expect(summary.findings.any((finding) => finding.code == 'INCOMPLETE_ROSTER'), isTrue);
  });

  test('validation blocks impossible guarantee and duplicate IDs', () {
    final findings = engine.validateContracts([
      const NbaContractYear(
        id: 'duplicate',
        playerLabel: 'A',
        teamId: 'BOS',
        season: '2026-27',
        salary: 10000000,
        guaranteedAmount: 12000000,
      ),
      const NbaContractYear(
        id: 'duplicate',
        playerLabel: 'B',
        teamId: 'BOS',
        season: '2026-27',
        salary: 5000000,
        guaranteedAmount: 5000000,
      ),
    ]);
    expect(findings.any((finding) => finding.code == 'INVALID_GUARANTEE'), isTrue);
    expect(findings.any((finding) => finding.code == 'DUPLICATE_CONTRACT'), isTrue);
  });

  test('transaction impact flags apron and incoming salary review', () {
    final current = engine.summarize(
      contracts: [
        const NbaContractYear(
          id: 'a',
          playerLabel: 'A',
          teamId: 'BOS',
          season: '2026-27',
          salary: 225000000,
          guaranteedAmount: 225000000,
        ),
      ],
      inputs: const NbaTeamLedgerInputs(teamId: 'BOS', season: '2026-27'),
      environment: environment,
    );
    final impact = engine.modelTransaction(
      current: current,
      outgoingSalary: 20000000,
      incomingSalary: 25000000,
      environment: environment,
    );
    expect(current.position.aboveSecondApron, isTrue);
    expect(impact.postTransactionSalary, 230000000);
    expect(impact.reviewFlags.length, greaterThanOrEqualTo(2));
  });

  test('contract and draft packages route structured rows', () {
    final contracts = [
      const NbaContractYear(
        id: 'a',
        playerLabel: 'A',
        teamId: 'BOS',
        season: '2026-27',
        salary: 10000000,
        guaranteedAmount: 10000000,
      ),
    ];
    final contractPayload = engine.packageContracts(
      contracts: contracts,
      targetRoute: 'Workspace',
      sourceSnapshot: 'User ledger',
    );
    final draftPayload = engine.packageDraftAssets(
      assets: const [
        NbaDraftAsset(
          id: 'bos-2028-1',
          currentOwner: 'BOS',
          originalTeam: 'BOS',
          year: 2028,
          round: 1,
          protections: 'Unprotected',
        ),
      ],
      targetRoute: 'Python Lab',
    );
    expect(contractPayload.rowCount, 1);
    expect(contractPayload.columns.any((column) => column.key == 'guaranteedAmount'), isTrue);
    expect(draftPayload.targetRoute, 'Python Lab');
    expect(draftPayload.rows.single['protections'], 'Unprotected');
  });
}
