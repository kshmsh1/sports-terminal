import '../models/transaction_case.dart';

enum TransactionRuleSeverity { info, warning, blocker }

class TransactionRuleFinding {
  const TransactionRuleFinding({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final TransactionRuleSeverity severity;

  String get label => '${severity.name.toUpperCase()} · $code · $message';
}

class TransactionRuleInput {
  const TransactionRuleInput({
    required this.currentTeamSalary,
    required this.outgoingSalary,
    required this.incomingSalary,
    required this.salaryCap,
    required this.firstApron,
    required this.secondApron,
    this.hardCap = 0,
    this.aggregatesMultiplePlayers = false,
    this.usesCash = false,
    this.usesTradeException = false,
    this.hasNoTradeClause = false,
    this.hasRecentlySignedPlayer = false,
    this.hasPoisonPillPlayer = false,
    this.stepienAvailable = true,
    this.pickTermsVerified = true,
    this.teamHasOpenRosterSpot = true,
  });

  final double currentTeamSalary;
  final double outgoingSalary;
  final double incomingSalary;
  final double salaryCap;
  final double firstApron;
  final double secondApron;
  final double hardCap;
  final bool aggregatesMultiplePlayers;
  final bool usesCash;
  final bool usesTradeException;
  final bool hasNoTradeClause;
  final bool hasRecentlySignedPlayer;
  final bool hasPoisonPillPlayer;
  final bool stepienAvailable;
  final bool pickTermsVerified;
  final bool teamHasOpenRosterSpot;

  double get postTransactionSalary =>
      currentTeamSalary - outgoingSalary + incomingSalary;
  bool get startsAboveFirstApron => currentTeamSalary > firstApron;
  bool get startsAboveSecondApron => currentTeamSalary > secondApron;
  bool get endsAboveFirstApron => postTransactionSalary > firstApron;
  bool get endsAboveSecondApron => postTransactionSalary > secondApron;
}

class TransactionRuleReport {
  const TransactionRuleReport({
    required this.findings,
    required this.postTransactionSalary,
    required this.outcome,
  });

  final List<TransactionRuleFinding> findings;
  final double postTransactionSalary;
  final String outcome;

  bool get hasBlockers => findings.any(
        (finding) => finding.severity == TransactionRuleSeverity.blocker,
      );
  bool get requiresReview => findings.any(
        (finding) => finding.severity == TransactionRuleSeverity.warning,
      );

  List<String> get labels => [for (final finding in findings) finding.label];
}

class CbaTransactionRulesEngine {
  const CbaTransactionRulesEngine();

  TransactionRuleReport evaluate(TransactionRuleInput input) {
    final findings = <TransactionRuleFinding>[];
    if (input.currentTeamSalary < 0 ||
        input.outgoingSalary < 0 ||
        input.incomingSalary < 0) {
      findings.add(const TransactionRuleFinding(
        code: 'NEGATIVE_SALARY',
        message: 'Salary inputs cannot be negative.',
        severity: TransactionRuleSeverity.blocker,
      ));
    }
    if (input.outgoingSalary == 0 && input.incomingSalary == 0) {
      findings.add(const TransactionRuleFinding(
        code: 'EMPTY_TRANSACTION',
        message: 'Add incoming or outgoing salary before review.',
        severity: TransactionRuleSeverity.warning,
      ));
    }
    if (input.hardCap > 0 && input.postTransactionSalary > input.hardCap) {
      findings.add(TransactionRuleFinding(
        code: 'HARD_CAP_EXCEEDED',
        message:
            'Post-transaction salary exceeds the modeled hard cap by ${_money(input.postTransactionSalary - input.hardCap)}.',
        severity: TransactionRuleSeverity.blocker,
      ));
    }
    if (input.startsAboveSecondApron || input.endsAboveSecondApron) {
      if (input.incomingSalary > input.outgoingSalary) {
        findings.add(const TransactionRuleFinding(
          code: 'SECOND_APRON_INCOMING',
          message:
              'A second-apron team cannot be treated as permitted to take back more salary without a dedicated rule review.',
          severity: TransactionRuleSeverity.blocker,
        ));
      }
      if (input.aggregatesMultiplePlayers) {
        findings.add(const TransactionRuleFinding(
          code: 'SECOND_APRON_AGGREGATION',
          message:
              'Player aggregation is blocked in this preliminary evaluator for a second-apron team.',
          severity: TransactionRuleSeverity.blocker,
        ));
      }
      if (input.usesCash) {
        findings.add(const TransactionRuleFinding(
          code: 'SECOND_APRON_CASH',
          message:
              'Cash usage requires second-apron restriction review and is blocked here.',
          severity: TransactionRuleSeverity.blocker,
        ));
      }
      if (input.usesTradeException) {
        findings.add(const TransactionRuleFinding(
          code: 'SECOND_APRON_EXCEPTION',
          message:
              'Trade-exception usage is not approved for a second-apron scenario by this preliminary engine.',
          severity: TransactionRuleSeverity.blocker,
        ));
      }
    } else if (input.startsAboveFirstApron || input.endsAboveFirstApron) {
      findings.add(const TransactionRuleFinding(
        code: 'FIRST_APRON_REVIEW',
        message:
            'The team crosses or operates above the first apron; hard-cap and transaction restrictions require review.',
        severity: TransactionRuleSeverity.warning,
      ));
    } else if (input.incomingSalary > input.outgoingSalary) {
      findings.add(const TransactionRuleFinding(
        code: 'SALARY_MATCHING_REVIEW',
        message:
            'Incoming salary exceeds outgoing salary. Run the full salary-matching bands before approval.',
        severity: TransactionRuleSeverity.warning,
      ));
    }
    if (input.hasNoTradeClause) {
      findings.add(const TransactionRuleFinding(
        code: 'NO_TRADE_CONSENT',
        message: 'Player consent is required before this case can be approved.',
        severity: TransactionRuleSeverity.blocker,
      ));
    }
    if (input.hasRecentlySignedPlayer) {
      findings.add(const TransactionRuleFinding(
        code: 'RECENTLY_SIGNED',
        message:
            'Recently signed player timing and aggregation restrictions require date-specific review.',
        severity: TransactionRuleSeverity.warning,
      ));
    }
    if (input.hasPoisonPillPlayer) {
      findings.add(const TransactionRuleFinding(
        code: 'POISON_PILL',
        message:
            'Poison-pill outgoing and incoming salary treatment requires a dedicated calculation.',
        severity: TransactionRuleSeverity.warning,
      ));
    }
    if (!input.stepienAvailable) {
      findings.add(const TransactionRuleFinding(
        code: 'STEPIEN_BLOCK',
        message:
            'The modeled first-round pick cannot be treated as available under the current Stepien assumption.',
        severity: TransactionRuleSeverity.blocker,
      ));
    }
    if (!input.pickTermsVerified) {
      findings.add(const TransactionRuleFinding(
        code: 'PICK_TERMS_UNVERIFIED',
        message:
            'Pick ownership, protection and conveyance terms must be verified.',
        severity: TransactionRuleSeverity.warning,
      ));
    }
    if (!input.teamHasOpenRosterSpot) {
      findings.add(const TransactionRuleFinding(
        code: 'ROSTER_SPOT_REVIEW',
        message:
            'The modeled transaction creates a roster-count issue that requires a corresponding move.',
        severity: TransactionRuleSeverity.warning,
      ));
    }
    if (findings.isEmpty) {
      findings.add(const TransactionRuleFinding(
        code: 'PRELIMINARY_CLEAR',
        message:
            'No preliminary blockers were found. Final CBA, contract, timing and source verification is still required.',
        severity: TransactionRuleSeverity.info,
      ));
    }
    final hasBlocker = findings.any(
      (finding) => finding.severity == TransactionRuleSeverity.blocker,
    );
    final hasWarning = findings.any(
      (finding) => finding.severity == TransactionRuleSeverity.warning,
    );
    return TransactionRuleReport(
      findings: findings,
      postTransactionSalary: input.postTransactionSalary,
      outcome: hasBlocker
          ? 'Blocked'
          : hasWarning
              ? 'Review required'
              : 'Preliminary clear',
    );
  }

  TransactionCase applyToCase({
    required TransactionCase transactionCase,
    required TransactionRuleInput input,
  }) {
    final report = evaluate(input);
    return transactionCase.copyWith(
      outgoingSalary: input.outgoingSalary,
      incomingSalary: input.incomingSalary,
      currentTeamSalary: input.currentTeamSalary,
      firstApron: input.firstApron,
      secondApron: input.secondApron,
      ruleFindings: report.labels,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
  }
}

String _money(double value) => '\$${value.toStringAsFixed(0)}';
