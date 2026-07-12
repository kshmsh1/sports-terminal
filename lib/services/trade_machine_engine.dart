enum TradeAssetType { player, draftPick, draftRights, cash, freeAgentRights, tradeException, signingException }

class TradeAsset {
  const TradeAsset({
    required this.id,
    required this.type,
    required this.label,
    required this.originTeam,
    this.salary = 0,
    this.metadata = const {},
  });

  final String id;
  final TradeAssetType type;
  final String label;
  final String originTeam;
  final double salary;
  final Map<String, dynamic> metadata;
}

class TradeAssignment {
  const TradeAssignment({required this.asset, required this.destinationTeam});
  final TradeAsset asset;
  final String destinationTeam;
}

class TeamCapContext {
  const TeamCapContext({
    required this.team,
    required this.teamSalary,
    required this.salaryCap,
    required this.taxLine,
    required this.firstApron,
    required this.secondApron,
    this.hardCappedAt,
  });

  final String team;
  final double teamSalary;
  final double salaryCap;
  final double taxLine;
  final double firstApron;
  final double secondApron;
  final double? hardCappedAt;

  bool get aboveTax => teamSalary > taxLine;
  bool get aboveFirstApron => teamSalary > firstApron;
  bool get aboveSecondApron => teamSalary > secondApron;
}

class TradeScenario {
  const TradeScenario({
    required this.id,
    required this.name,
    required this.operatingSeason,
    required this.teams,
    required this.assignments,
    required this.capContexts,
  });

  final String id;
  final String name;
  final String operatingSeason;
  final List<String> teams;
  final List<TradeAssignment> assignments;
  final Map<String, TeamCapContext> capContexts;

  Iterable<TradeAssignment> outgoingFor(String team) => assignments.where((item) => item.asset.originTeam == team);
  Iterable<TradeAssignment> incomingFor(String team) => assignments.where((item) => item.destinationTeam == team);

  double outgoingSalary(String team) => outgoingFor(team).fold(0, (sum, item) => sum + item.asset.salary);
  double incomingSalary(String team) => incomingFor(team).fold(0, (sum, item) => sum + item.asset.salary);
  double postTradeSalary(String team) => (capContexts[team]?.teamSalary ?? 0) - outgoingSalary(team) + incomingSalary(team);

  TradeScenario copyWith({String? name, List<String>? teams, List<TradeAssignment>? assignments, Map<String, TeamCapContext>? capContexts}) => TradeScenario(
        id: id,
        name: name ?? this.name,
        operatingSeason: operatingSeason,
        teams: teams ?? this.teams,
        assignments: assignments ?? this.assignments,
        capContexts: capContexts ?? this.capContexts,
      );
}

enum TradeValidationSeverity { info, warning, error }

class TradeValidationFinding {
  const TradeValidationFinding({required this.code, required this.message, required this.severity, this.team});
  final String code;
  final String message;
  final TradeValidationSeverity severity;
  final String? team;
}

class TeamTradeSummary {
  const TeamTradeSummary({
    required this.team,
    required this.outgoingSalary,
    required this.incomingSalary,
    required this.postTradeSalary,
    required this.outgoingAssets,
    required this.incomingAssets,
  });

  final String team;
  final double outgoingSalary;
  final double incomingSalary;
  final double postTradeSalary;
  final int outgoingAssets;
  final int incomingAssets;
}

class TradeValidationReport {
  const TradeValidationReport({required this.findings, required this.teamSummaries});
  final List<TradeValidationFinding> findings;
  final Map<String, TeamTradeSummary> teamSummaries;

  bool get isValid => !findings.any((item) => item.severity == TradeValidationSeverity.error);
  bool get requiresReview => findings.any((item) => item.severity == TradeValidationSeverity.warning);
}

class TradeMachineEngine {
  const TradeMachineEngine();

  TradeValidationReport validate(TradeScenario scenario) {
    final findings = <TradeValidationFinding>[];
    final summaries = <String, TeamTradeSummary>{};

    if (scenario.teams.length < 2) {
      findings.add(const TradeValidationFinding(code: 'MIN_TEAMS', message: 'A trade requires at least two teams.', severity: TradeValidationSeverity.error));
    }

    final duplicateAssetIds = <String>{};
    final seenAssets = <String>{};
    for (final assignment in scenario.assignments) {
      if (!seenAssets.add(assignment.asset.id)) duplicateAssetIds.add(assignment.asset.id);
      if (!scenario.teams.contains(assignment.asset.originTeam) || !scenario.teams.contains(assignment.destinationTeam)) {
        findings.add(TradeValidationFinding(code: 'TEAM_SCOPE', message: '${assignment.asset.label} references a team outside this scenario.', severity: TradeValidationSeverity.error));
      }
      if (assignment.asset.originTeam == assignment.destinationTeam) {
        findings.add(TradeValidationFinding(code: 'SAME_TEAM', message: '${assignment.asset.label} cannot be routed back to its origin team.', severity: TradeValidationSeverity.error, team: assignment.asset.originTeam));
      }
    }
    for (final id in duplicateAssetIds) {
      findings.add(TradeValidationFinding(code: 'DUPLICATE_ASSET', message: 'Asset $id is assigned more than once.', severity: TradeValidationSeverity.error));
    }

    for (final team in scenario.teams) {
      final outgoing = scenario.outgoingFor(team).toList();
      final incoming = scenario.incomingFor(team).toList();
      final outgoingSalary = scenario.outgoingSalary(team);
      final incomingSalary = scenario.incomingSalary(team);
      final postTradeSalary = scenario.postTradeSalary(team);
      final context = scenario.capContexts[team];

      summaries[team] = TeamTradeSummary(
        team: team,
        outgoingSalary: outgoingSalary,
        incomingSalary: incomingSalary,
        postTradeSalary: postTradeSalary,
        outgoingAssets: outgoing.length,
        incomingAssets: incoming.length,
      );

      if (outgoing.isEmpty && incoming.isEmpty) {
        findings.add(TradeValidationFinding(code: 'NO_ACTIVITY', message: '$team has no incoming or outgoing assets.', severity: TradeValidationSeverity.warning, team: team));
      }
      if (context == null) {
        findings.add(TradeValidationFinding(code: 'MISSING_CAP_CONTEXT', message: '$team needs salary-cap context before legal validation can be completed.', severity: TradeValidationSeverity.warning, team: team));
        continue;
      }
      if (context.hardCappedAt != null && postTradeSalary > context.hardCappedAt!) {
        findings.add(TradeValidationFinding(code: 'HARD_CAP', message: '$team exceeds its hard cap after the trade.', severity: TradeValidationSeverity.error, team: team));
      }
      if (postTradeSalary > context.secondApron) {
        findings.add(TradeValidationFinding(code: 'SECOND_APRON', message: '$team remains above the second apron; aggregation, cash and exception restrictions require CBA review.', severity: TradeValidationSeverity.warning, team: team));
      } else if (postTradeSalary > context.firstApron) {
        findings.add(TradeValidationFinding(code: 'FIRST_APRON', message: '$team is above the first apron after the trade.', severity: TradeValidationSeverity.info, team: team));
      }

      final hasCash = outgoing.any((item) => item.asset.type == TradeAssetType.cash);
      if (hasCash && context.aboveSecondApron) {
        findings.add(TradeValidationFinding(code: 'SECOND_APRON_CASH', message: '$team is modeled above the second apron and is sending cash; this requires a prohibited-action check.', severity: TradeValidationSeverity.warning, team: team));
      }
      final usesException = incoming.any((item) => item.asset.type == TradeAssetType.tradeException || item.asset.type == TradeAssetType.signingException);
      if (usesException) {
        findings.add(TradeValidationFinding(code: 'EXCEPTION_REVIEW', message: '$team uses an exception. Verify amount, expiration, aggregation and hard-cap consequences.', severity: TradeValidationSeverity.warning, team: team));
      }
    }

    if (scenario.assignments.isEmpty) {
      findings.add(const TradeValidationFinding(code: 'EMPTY_SCENARIO', message: 'Add at least one player, pick, right, cash item or exception.', severity: TradeValidationSeverity.error));
    }

    return TradeValidationReport(findings: findings, teamSummaries: summaries);
  }
}
