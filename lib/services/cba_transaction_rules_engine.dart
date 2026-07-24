import '../models/transaction_case.dart';

enum TransactionRuleSeverity { info, warning, blocker }

enum TransactionSalaryMatchingMode {
  automatic,
  capRoom,
  standard,
  aggregatedStandard,
  expanded,
}

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
    this.salaryMatchingMode = TransactionSalaryMatchingMode.automatic,
    this.salaryCap2023 = 136021000,
    this.expandedAllowance2023 = 7500000,
    this.transactionDateIso = '',
    this.recentlyAcquiredViaExceptionDateIso = '',
    this.tradeDeadlineIso = '',
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
  final TransactionSalaryMatchingMode salaryMatchingMode;

  /// Article VII scales the expanded traded-player allowance from the
  /// 2023-24 salary cap. Keeping both values explicit makes the calculator
  /// season-configurable instead of hard-coding only one future cap year.
  final double salaryCap2023;
  final double expandedAllowance2023;

  /// Optional transaction facts for the recently-acquired aggregation review.
  /// Empty values remain visible review items rather than invented dates.
  final String transactionDateIso;
  final String recentlyAcquiredViaExceptionDateIso;
  final String tradeDeadlineIso;

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
    this.maximumIncomingSalary = 0,
    this.salaryMatchingMode = TransactionSalaryMatchingMode.automatic,
  });

  final List<TransactionRuleFinding> findings;
  final double postTransactionSalary;
  final String outcome;
  final double maximumIncomingSalary;
  final TransactionSalaryMatchingMode salaryMatchingMode;

  bool get hasBlockers => findings.any(
        (finding) => finding.severity == TransactionRuleSeverity.blocker,
      );
  bool get requiresReview => findings.any(
        (finding) => finding.severity == TransactionRuleSeverity.warning,
      );
  double get salaryMatchingMargin => maximumIncomingSalary <= 0
      ? 0
      : maximumIncomingSalary -
          (postTransactionSalary - postTransactionSalary + 0);

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
    if (input.salaryCap <= 0 ||
        input.firstApron <= input.salaryCap ||
        input.secondApron <= input.firstApron) {
      findings.add(const TransactionRuleFinding(
        code: 'INVALID_CAP_ENVIRONMENT',
        message:
            'Salary cap and apron inputs must be positive and ordered correctly.',
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

    final matching = _salaryMatching(input);
    if (input.incomingSalary > matching.maximumIncomingSalary + 0.01) {
      findings.add(TransactionRuleFinding(
        code: 'SALARY_MATCHING_EXCEEDED',
        message:
            'The ${_matchingLabel(matching.mode)} calculation permits up to ${_money(matching.maximumIncomingSalary)} of incoming salary. The scenario exceeds that modeled limit by ${_money(input.incomingSalary - matching.maximumIncomingSalary)}.',
        severity: TransactionRuleSeverity.blocker,
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
              'A second-apron team cannot be treated as permitted to take back more salary than it sends out.',
          severity: TransactionRuleSeverity.blocker,
        ));
      }
      if (input.aggregatesMultiplePlayers) {
        findings.add(const TransactionRuleFinding(
          code: 'SECOND_APRON_AGGREGATION',
          message:
              'Player aggregation is blocked in this evaluator for a second-apron team.',
          severity: TransactionRuleSeverity.blocker,
        ));
      }
      if (input.usesCash) {
        findings.add(const TransactionRuleFinding(
          code: 'SECOND_APRON_CASH',
          message:
              'Cash usage is blocked here for a second-apron transaction scenario.',
          severity: TransactionRuleSeverity.blocker,
        ));
      }
      if (input.usesTradeException) {
        findings.add(const TransactionRuleFinding(
          code: 'SECOND_APRON_EXCEPTION',
          message:
              'Trade-exception usage is not approved for a second-apron scenario by this evaluator.',
          severity: TransactionRuleSeverity.blocker,
        ));
      }
    } else if (input.startsAboveFirstApron || input.endsAboveFirstApron) {
      findings.add(const TransactionRuleFinding(
        code: 'FIRST_APRON_REVIEW',
        message:
            'The team crosses or operates above the first apron. Expanded matching and the additional allowance are not assumed available, and hard-cap trigger history still requires review.',
        severity: TransactionRuleSeverity.warning,
      ));
    }

    if (input.aggregatesMultiplePlayers) {
      _reviewAggregationDates(input, findings);
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
      findings.add(TransactionRuleFinding(
        code: 'PRELIMINARY_CLEAR',
        message:
            'The ${_matchingLabel(matching.mode)} salary calculation permits up to ${_money(matching.maximumIncomingSalary)}. No preliminary blockers were found, but final CBA, contract, timing and source verification is still required.',
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
      maximumIncomingSalary: matching.maximumIncomingSalary,
      salaryMatchingMode: matching.mode,
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

  _SalaryMatchingCalculation _salaryMatching(TransactionRuleInput input) {
    final automatic = input.currentTeamSalary < input.salaryCap
        ? TransactionSalaryMatchingMode.capRoom
        : input.startsAboveFirstApron || input.endsAboveFirstApron
            ? (input.aggregatesMultiplePlayers
                ? TransactionSalaryMatchingMode.aggregatedStandard
                : TransactionSalaryMatchingMode.standard)
            : TransactionSalaryMatchingMode.expanded;
    final mode =
        input.salaryMatchingMode == TransactionSalaryMatchingMode.automatic
            ? automatic
            : input.salaryMatchingMode;
    final allowance = input.startsAboveFirstApron || input.endsAboveFirstApron
        ? 0.0
        : 250000.0;

    switch (mode) {
      case TransactionSalaryMatchingMode.capRoom:
        final salaryAfterOutgoing =
            input.currentTeamSalary - input.outgoingSalary;
        final room = input.salaryCap - salaryAfterOutgoing;
        return _SalaryMatchingCalculation(
          mode,
          (room < 0 ? 0 : room) + allowance,
        );
      case TransactionSalaryMatchingMode.standard:
      case TransactionSalaryMatchingMode.aggregatedStandard:
        return _SalaryMatchingCalculation(
          mode,
          input.outgoingSalary + allowance,
        );
      case TransactionSalaryMatchingMode.expanded:
        final scaledAllowance = input.salaryCap2023 <= 0
            ? input.expandedAllowance2023
            : input.expandedAllowance2023 *
                input.salaryCap /
                input.salaryCap2023;
        final twoHundredPercent = input.outgoingSalary * 2 + allowance;
        final scaledBranch = input.outgoingSalary + scaledAllowance;
        final cappedExpanded = twoHundredPercent < scaledBranch
            ? twoHundredPercent
            : scaledBranch;
        final oneTwentyFivePercent =
            input.outgoingSalary * 1.25 + allowance;
        return _SalaryMatchingCalculation(
          mode,
          cappedExpanded > oneTwentyFivePercent
              ? cappedExpanded
              : oneTwentyFivePercent,
        );
      case TransactionSalaryMatchingMode.automatic:
        throw StateError('Automatic salary matching must resolve first.');
    }
  }

  void _reviewAggregationDates(
    TransactionRuleInput input,
    List<TransactionRuleFinding> findings,
  ) {
    if (input.recentlyAcquiredViaExceptionDateIso.isEmpty) {
      findings.add(const TransactionRuleFinding(
        code: 'AGGREGATION_DATE_REVIEW',
        message:
            'Confirm whether any aggregated outgoing player was acquired through an exception during the preceding two months.',
        severity: TransactionRuleSeverity.warning,
      ));
      return;
    }
    final acquired =
        DateTime.tryParse(input.recentlyAcquiredViaExceptionDateIso);
    final transaction = DateTime.tryParse(input.transactionDateIso);
    if (acquired == null || transaction == null) {
      findings.add(const TransactionRuleFinding(
        code: 'AGGREGATION_DATE_INVALID',
        message:
            'Valid acquisition and transaction dates are required for the two-month aggregation review.',
        severity: TransactionRuleSeverity.warning,
      ));
      return;
    }
    final eligible = DateTime(acquired.year, acquired.month + 2, acquired.day);
    final deadline = DateTime.tryParse(input.tradeDeadlineIso);
    final nearDeadlineException = acquired.month == 12 &&
        acquired.day <= 16 &&
        deadline != null &&
        !transaction.isBefore(deadline.subtract(const Duration(days: 1)));
    if (transaction.isBefore(eligible) && !nearDeadlineException) {
      findings.add(TransactionRuleFinding(
        code: 'RECENTLY_ACQUIRED_AGGREGATION',
        message:
            'The modeled transaction occurs before the entered two-month aggregation eligibility date of ${eligible.toIso8601String().split('T').first}.',
        severity: TransactionRuleSeverity.blocker,
      ));
    }
  }
}

class _SalaryMatchingCalculation {
  const _SalaryMatchingCalculation(this.mode, this.maximumIncomingSalary);

  final TransactionSalaryMatchingMode mode;
  final double maximumIncomingSalary;
}

String _matchingLabel(TransactionSalaryMatchingMode mode) {
  return switch (mode) {
    TransactionSalaryMatchingMode.capRoom => 'cap-room',
    TransactionSalaryMatchingMode.standard => 'standard traded-player',
    TransactionSalaryMatchingMode.aggregatedStandard =>
      'aggregated standard traded-player',
    TransactionSalaryMatchingMode.expanded => 'expanded traded-player',
    TransactionSalaryMatchingMode.automatic => 'automatic',
  };
}

String _money(double value) {
  final absolute = value.abs();
  if (absolute >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (absolute >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(1)}K';
  }
  return '\$${value.toStringAsFixed(0)}';
}
