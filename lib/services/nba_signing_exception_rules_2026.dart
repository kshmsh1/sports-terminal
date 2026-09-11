enum NbaMleType { room, nonTaxpayer, taxpayer }

class NbaSigningExceptionState {
  const NbaSigningExceptionState({
    required this.team,
    this.roomMleRemaining = 0,
    this.nonTaxMleRemaining = 0,
    this.taxMleRemaining = 0,
    this.baeRemaining = 0,
    this.usedRoomMle = false,
    this.usedNonTaxMle = false,
    this.usedTaxMle = false,
    this.usedBae = false,
    this.usedCapRoomOrRoomException = false,
  });

  final String team;
  final double roomMleRemaining;
  final double nonTaxMleRemaining;
  final double taxMleRemaining;
  final double baeRemaining;
  final bool usedRoomMle;
  final bool usedNonTaxMle;
  final bool usedTaxMle;
  final bool usedBae;
  final bool usedCapRoomOrRoomException;
}

class NbaSigningExceptionRules202627 {
  const NbaSigningExceptionRules202627._();

  static const roomMle = 9366000.0;
  static const nonTaxMle = 15044000.0;
  static const taxpayerMle = 6064000.0;
  static const biAnnual = 5477000.0;

  static bool roomMleEligible({
    required double teamCapAllocation,
    required double salaryCap,
    required NbaSigningExceptionState state,
  }) {
    return teamCapAllocation < salaryCap &&
        !state.usedBae &&
        !state.usedNonTaxMle &&
        !state.usedTaxMle;
  }

  static bool nonTaxMleEligible({
    required double teamCapAllocation,
    required double salaryCap,
    required double firstApron,
    required double firstYearSalary,
    required NbaSigningExceptionState state,
  }) {
    return teamCapAllocation >= salaryCap &&
        teamCapAllocation < firstApron &&
        teamCapAllocation + firstYearSalary <= firstApron &&
        !state.usedRoomMle &&
        !state.usedTaxMle;
  }

  static bool taxpayerMleEligible({
    required double teamCapAllocation,
    required double firstApron,
    required double secondApron,
    required double firstYearSalary,
    required NbaSigningExceptionState state,
  }) {
    return teamCapAllocation + firstYearSalary > firstApron &&
        teamCapAllocation + firstYearSalary <= secondApron &&
        !state.usedBae &&
        !state.usedCapRoomOrRoomException &&
        !state.usedRoomMle &&
        !state.usedNonTaxMle;
  }

  static bool amountFits(double remaining, double amount) =>
      amount > 0 && amount <= remaining + .01;
}
