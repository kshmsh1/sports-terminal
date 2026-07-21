import '../models/front_office_ledger.dart';
import '../models/nba_cap_environment.dart';
import '../models/route_payload.dart';
import 'sports_object_router.dart';

class LedgerFinding {
  const LedgerFinding({required this.code, required this.message, required this.severity});

  final String code;
  final String message;
  final String severity;
}

class TeamLedgerSummary {
  const TeamLedgerSummary({
    required this.teamId,
    required this.season,
    required this.activeSalary,
    required this.guaranteedSalary,
    required this.nonGuaranteedSalary,
    required this.nonContractCharges,
    required this.teamSalary,
    required this.rosterCount,
    required this.position,
    required this.findings,
  });

  final String teamId;
  final String season;
  final double activeSalary;
  final double guaranteedSalary;
  final double nonGuaranteedSalary;
  final double nonContractCharges;
  final double teamSalary;
  final int rosterCount;
  final NbaCapPosition position;
  final List<LedgerFinding> findings;

  bool get readyForScenario => findings.every((finding) => finding.severity != 'error');
}

class TransactionImpact {
  const TransactionImpact({
    required this.outgoingSalary,
    required this.incomingSalary,
    required this.postTransactionSalary,
    required this.position,
    required this.reviewFlags,
  });

  final double outgoingSalary;
  final double incomingSalary;
  final double postTransactionSalary;
  final NbaCapPosition position;
  final List<String> reviewFlags;
}

class FrontOfficeLedgerEngine {
  const FrontOfficeLedgerEngine();

  TeamLedgerSummary summarize({
    required List<NbaContractYear> contracts,
    required NbaTeamLedgerInputs inputs,
    required NbaCapEnvironment environment,
  }) {
    final scoped = contracts
        .where((contract) => contract.teamId == inputs.teamId && contract.season == inputs.season)
        .toList();
    final activeSalary = scoped.fold<double>(0, (sum, contract) => sum + contract.salary);
    final guaranteed = scoped.fold<double>(0, (sum, contract) => sum + contract.guaranteedAmount);
    final teamSalary = activeSalary + inputs.nonContractCharges;
    final findings = validateContracts(scoped);
    if (inputs.season != environment.season) {
      findings.add(LedgerFinding(
        code: 'SEASON_MISMATCH',
        message: 'Ledger season ${inputs.season} does not match cap environment ${environment.season}.',
        severity: 'error',
      ));
    }
    if (scoped.length < 14) {
      findings.add(const LedgerFinding(
        code: 'INCOMPLETE_ROSTER',
        message: 'Fewer than 14 modeled contract rows are loaded. Incomplete-roster charges may be required.',
        severity: 'warning',
      ));
    }
    return TeamLedgerSummary(
      teamId: inputs.teamId,
      season: inputs.season,
      activeSalary: activeSalary,
      guaranteedSalary: guaranteed,
      nonGuaranteedSalary: activeSalary - guaranteed,
      nonContractCharges: inputs.nonContractCharges,
      teamSalary: teamSalary,
      rosterCount: scoped.length,
      position: environment.positionFor(teamSalary),
      findings: findings,
    );
  }

  List<LedgerFinding> validateContracts(List<NbaContractYear> contracts) {
    final findings = <LedgerFinding>[];
    final ids = <String>{};
    for (final contract in contracts) {
      if (!ids.add(contract.id)) {
        findings.add(LedgerFinding(
          code: 'DUPLICATE_CONTRACT',
          message: 'Contract ID ${contract.id} appears more than once.',
          severity: 'error',
        ));
      }
      if (contract.playerLabel.trim().isEmpty || contract.teamId.trim().isEmpty || contract.season.trim().isEmpty) {
        findings.add(LedgerFinding(
          code: 'MISSING_IDENTITY',
          message: 'Contract ${contract.id} is missing player, team, or season identity.',
          severity: 'error',
        ));
      }
      if (contract.salary <= 0) {
        findings.add(LedgerFinding(
          code: 'INVALID_SALARY',
          message: '${contract.playerLabel} needs a positive salary.',
          severity: 'error',
        ));
      }
      if (contract.guaranteedAmount < 0 || contract.guaranteedAmount > contract.salary) {
        findings.add(LedgerFinding(
          code: 'INVALID_GUARANTEE',
          message: '${contract.playerLabel} has a guarantee outside the salary range.',
          severity: 'error',
        ));
      }
      if (contract.tradeKickerPct < 0 || contract.tradeKickerPct > 15) {
        findings.add(LedgerFinding(
          code: 'TRADE_KICKER_REVIEW',
          message: '${contract.playerLabel} has a modeled trade kicker outside the 0%–15% input guardrail.',
          severity: 'warning',
        ));
      }
      if (contract.noTradeClause) {
        findings.add(LedgerFinding(
          code: 'NO_TRADE_CLAUSE',
          message: '${contract.playerLabel} is marked with a no-trade clause and requires consent review.',
          severity: 'warning',
        ));
      }
    }
    return findings;
  }

  List<LedgerFinding> validateDraftAssets(List<NbaDraftAsset> assets) {
    final findings = <LedgerFinding>[];
    final ids = <String>{};
    for (final asset in assets) {
      if (!ids.add(asset.id)) {
        findings.add(LedgerFinding(
          code: 'DUPLICATE_DRAFT_ASSET',
          message: 'Draft asset ${asset.id} appears more than once.',
          severity: 'error',
        ));
      }
      if (asset.year < 2024 || asset.round < 1 || asset.round > 2) {
        findings.add(LedgerFinding(
          code: 'INVALID_DRAFT_ASSET',
          message: 'Draft asset ${asset.id} has an invalid year or round.',
          severity: 'error',
        ));
      }
      if (asset.protections == 'Unspecified') {
        findings.add(LedgerFinding(
          code: 'PROTECTION_PENDING',
          message: '${asset.id} needs protection and conveyance terms before trade use.',
          severity: 'warning',
        ));
      }
    }
    return findings;
  }

  TransactionImpact modelTransaction({
    required TeamLedgerSummary current,
    required double outgoingSalary,
    required double incomingSalary,
    required NbaCapEnvironment environment,
  }) {
    final post = current.teamSalary - outgoingSalary + incomingSalary;
    final flags = <String>[];
    if (outgoingSalary < 0 || incomingSalary < 0) flags.add('Salary inputs cannot be negative.');
    if (current.position.aboveFirstApron) {
      flags.add('First-apron transaction restrictions require dedicated CBA review.');
    }
    if (current.position.aboveSecondApron) {
      flags.add('Second-apron aggregation, cash, exception and incoming-salary restrictions require dedicated CBA review.');
    }
    if (incomingSalary > outgoingSalary) {
      flags.add('Incoming salary exceeds outgoing salary; run the full salary-matching module before treating this as legal.');
    }
    return TransactionImpact(
      outgoingSalary: outgoingSalary,
      incomingSalary: incomingSalary,
      postTransactionSalary: post,
      position: environment.positionFor(post),
      reviewFlags: flags,
    );
  }

  RoutePayload packageContracts({
    required List<NbaContractYear> contracts,
    required String targetRoute,
    required String sourceSnapshot,
  }) {
    return const SportsObjectRouter().packageRows(
      datasetId: 'modeled_contract_years',
      displayLabel: 'Modeled Contract Ledger',
      sourceObjectType: 'ContractLedger',
      rows: [for (final contract in contracts) contract.toJson()],
      targetRoute: targetRoute,
      sourceSnapshot: sourceSnapshot,
      readinessState: 'User modeled',
      rowKey: 'id',
      preferredColumns: const [
        'playerLabel',
        'teamId',
        'season',
        'salary',
        'guaranteedAmount',
        'guarantee',
        'option',
        'tradeKickerPct',
        'noTradeClause',
        'notes',
      ],
      blockers: const ['Not a sourced live contract ledger', 'Transaction legality requires full CBA rules'],
    );
  }

  RoutePayload packageDraftAssets({
    required List<NbaDraftAsset> assets,
    required String targetRoute,
  }) {
    return const SportsObjectRouter().packageRows(
      datasetId: 'modeled_draft_assets',
      displayLabel: 'Modeled Draft Asset Ledger',
      sourceObjectType: 'DraftAssetLedger',
      rows: [for (final asset in assets) asset.toJson()],
      targetRoute: targetRoute,
      sourceSnapshot: 'User-entered draft asset ledger',
      readinessState: 'User modeled',
      rowKey: 'id',
      preferredColumns: const [
        'currentOwner',
        'originalTeam',
        'year',
        'round',
        'protections',
        'swapRights',
        'stepienAvailable',
        'conveyanceNotes',
      ],
      blockers: const ['Ownership, protections and Stepien availability require source verification'],
    );
  }
}
