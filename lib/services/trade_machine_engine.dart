enum TradeAssetType { player, draftPick, draftRights, cash, freeAgentRights, tradeException, signingException }

class TradeAsset {
  const TradeAsset({required this.id, required this.type, required this.label, required this.originTeam, this.salary = 0, this.metadata = const {}});
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
  const TeamCapContext({required this.team, required this.teamSalary, required this.salaryCap, required this.taxLine, required this.firstApron, required this.secondApron, this.hardCappedAt, this.standardRosterPlayers = 14});
  final String team;
  final double teamSalary;
  final double salaryCap;
  final double taxLine;
  final double firstApron;
  final double secondApron;
  final double? hardCappedAt;
  final int standardRosterPlayers;
  bool get aboveTax => teamSalary > taxLine;
  bool get aboveFirstApron => teamSalary > firstApron;
  bool get aboveSecondApron => teamSalary > secondApron;
}

class TradeScenario {
  const TradeScenario({required this.id, required this.name, required this.operatingSeason, required this.teams, required this.assignments, required this.capContexts});
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
  const TeamTradeSummary({required this.team, required this.outgoingSalary, required this.incomingSalary, required this.postTradeSalary, required this.outgoingAssets, required this.incomingAssets, required this.maximumIncomingSalary, required this.projectedRosterPlayers});
  final String team;
  final double outgoingSalary;
  final double incomingSalary;
  final double postTradeSalary;
  final int outgoingAssets;
  final int incomingAssets;
  final double maximumIncomingSalary;
  final int projectedRosterPlayers;
}

class TradeValidationReport {
  const TradeValidationReport({required this.findings, required this.teamSummaries});
  final List<TradeValidationFinding> findings;
  final Map<String, TeamTradeSummary> teamSummaries;
  bool get isValid => !findings.any((item) => item.severity == TradeValidationSeverity.error);
  bool get requiresReview => findings.any((item) => item.severity == TradeValidationSeverity.warning);
  int get errorCount => findings.where((item) => item.severity == TradeValidationSeverity.error).length;
  int get warningCount => findings.where((item) => item.severity == TradeValidationSeverity.warning).length;
}

class TradeMachineEngine {
  const TradeMachineEngine();
  static const double _cba2023Cap = 136021000;

  TradeValidationReport validate(TradeScenario scenario) {
    final findings = <TradeValidationFinding>[];
    final summaries = <String, TeamTradeSummary>{};
    if (scenario.teams.length < 2) findings.add(const TradeValidationFinding(code: 'MIN_TEAMS', message: 'A trade requires at least two teams.', severity: TradeValidationSeverity.error));
    if (scenario.teams.length > 5) findings.add(const TradeValidationFinding(code: 'MAX_TEAMS', message: 'This product currently supports up to five participating teams per transaction.', severity: TradeValidationSeverity.error));

    final duplicateAssetIds = <String>{};
    final seenAssets = <String>{};
    for (final assignment in scenario.assignments) {
      if (!seenAssets.add(assignment.asset.id)) duplicateAssetIds.add(assignment.asset.id);
      if (!scenario.teams.contains(assignment.asset.originTeam) || !scenario.teams.contains(assignment.destinationTeam)) findings.add(TradeValidationFinding(code: 'TEAM_SCOPE', message: '${assignment.asset.label} references a team outside this scenario.', severity: TradeValidationSeverity.error));
      if (assignment.asset.originTeam == assignment.destinationTeam) findings.add(TradeValidationFinding(code: 'SAME_TEAM', message: '${assignment.asset.label} cannot be routed back to its origin team.', severity: TradeValidationSeverity.error, team: assignment.asset.originTeam));
    }
    for (final id in duplicateAssetIds) findings.add(TradeValidationFinding(code: 'DUPLICATE_ASSET', message: 'Asset $id is assigned more than once.', severity: TradeValidationSeverity.error));

    for (final team in scenario.teams) {
      final outgoing = scenario.outgoingFor(team).toList();
      final incoming = scenario.incomingFor(team).toList();
      final outgoingPlayers = outgoing.where((a) => a.asset.type == TradeAssetType.player).toList();
      final incomingPlayers = incoming.where((a) => a.asset.type == TradeAssetType.player).toList();
      final outgoingSalary = scenario.outgoingSalary(team);
      final incomingSalary = scenario.incomingSalary(team);
      final postTradeSalary = scenario.postTradeSalary(team);
      final context = scenario.capContexts[team];
      final roster = (context?.standardRosterPlayers ?? 14) - outgoingPlayers.length + incomingPlayers.length;
      final maxIncoming = context == null ? double.infinity : _maximumIncoming(context, outgoingSalary, postTradeSalary);
      summaries[team] = TeamTradeSummary(team: team, outgoingSalary: outgoingSalary, incomingSalary: incomingSalary, postTradeSalary: postTradeSalary, outgoingAssets: outgoing.length, incomingAssets: incoming.length, maximumIncomingSalary: maxIncoming, projectedRosterPlayers: roster);

      if (outgoing.isEmpty && incoming.isEmpty) findings.add(TradeValidationFinding(code: 'NO_ACTIVITY', message: '$team has no incoming or outgoing assets.', severity: TradeValidationSeverity.warning, team: team));
      if (context == null) {
        findings.add(TradeValidationFinding(code: 'MISSING_CAP_CONTEXT', message: '$team needs salary-cap context before legal validation can be completed.', severity: TradeValidationSeverity.warning, team: team));
        continue;
      }
      if (roster > 15) findings.add(TradeValidationFinding(code: 'ROSTER_MAX', message: '$team projects to $roster standard-contract players; a subsequent waiver or roster move may be required before the transaction can be completed.', severity: TradeValidationSeverity.warning, team: team));
      if (context.hardCappedAt != null && postTradeSalary > context.hardCappedAt!) findings.add(TradeValidationFinding(code: 'HARD_CAP', message: '$team exceeds its modeled hard cap after the trade.', severity: TradeValidationSeverity.error, team: team));
      if (incomingSalary > maxIncoming + .01) findings.add(TradeValidationFinding(code: 'SALARY_MATCH', message: '$team receives ${_money(incomingSalary)}, above the modeled CBA incoming-salary limit of ${_money(maxIncoming)} for this cap position.', severity: TradeValidationSeverity.error, team: team));

      final hasCash = outgoing.any((item) => item.asset.type == TradeAssetType.cash);
      final usesException = incoming.any((item) => item.asset.type == TradeAssetType.tradeException || item.asset.type == TradeAssetType.signingException);
      if (context.aboveSecondApron || postTradeSalary > context.secondApron) {
        if (outgoingPlayers.length > 1 && incomingPlayers.isNotEmpty) findings.add(TradeValidationFinding(code: 'SECOND_APRON_AGGREGATION', message: '$team is above the second apron and is aggregating multiple outgoing player salaries. The current CBA second-apron transaction restrictions require this structure to be rejected or restructured.', severity: TradeValidationSeverity.error, team: team));
        if (hasCash) findings.add(TradeValidationFinding(code: 'SECOND_APRON_CASH', message: '$team is above the second apron and is sending cash; second-apron transaction restrictions prohibit this structure.', severity: TradeValidationSeverity.error, team: team));
        if (usesException) findings.add(TradeValidationFinding(code: 'SECOND_APRON_EXCEPTION', message: '$team is above the second apron and is using a trade/signing exception. Verify the specific exception against second-apron restrictions; this scenario is blocked conservatively.', severity: TradeValidationSeverity.error, team: team));
        final distantFirst = outgoing.where((item) => item.asset.type == TradeAssetType.draftPick && item.asset.metadata['round']?.toString() == '1' && (item.asset.metadata['years_out'] as num?)?.toInt() == 7).toList();
        if (distantFirst.isNotEmpty) findings.add(TradeValidationFinding(code: 'SECOND_APRON_FROZEN_PICK', message: '$team is routing a first-round pick seven seasons out. Second-apron teams can have that pick frozen from trade and later moved to the end of the first round under the CBA draft-pick penalty.', severity: TradeValidationSeverity.error, team: team));
      } else if (postTradeSalary > context.firstApron) {
        findings.add(TradeValidationFinding(code: 'FIRST_APRON', message: '$team projects above the first apron. The modeled $250,000 TPE allowance is removed and hard-cap-triggering transaction types require review.', severity: TradeValidationSeverity.warning, team: team));
      }

      for (final asset in outgoing.where((a) => a.asset.type == TradeAssetType.player)) {
        if (asset.asset.metadata['no_trade'] == true) findings.add(TradeValidationFinding(code: 'NO_TRADE_CLAUSE', message: '${asset.asset.label} is marked with trade-consent rights and requires player approval.', severity: TradeValidationSeverity.warning, team: team));
        if (asset.asset.metadata['trade_restricted'] == true) findings.add(TradeValidationFinding(code: 'TRADE_RESTRICTED', message: '${asset.asset.label} is currently marked trade-restricted by contract/timing metadata.', severity: TradeValidationSeverity.error, team: team));
        if (asset.asset.metadata['trade_bonus'] is num) findings.add(TradeValidationFinding(code: 'TRADE_BONUS', message: '${asset.asset.label} has a modeled trade bonus/kicker; recalculate matching salary and team salary after allocation.', severity: TradeValidationSeverity.warning, team: team));
      }
      if (usesException) findings.add(TradeValidationFinding(code: 'EXCEPTION_REVIEW', message: '$team uses an exception. Amount, expiration, aggregation, apron and hard-cap consequences must match the authoritative exception record.', severity: TradeValidationSeverity.warning, team: team));
    }

    if (scenario.assignments.isEmpty) findings.add(const TradeValidationFinding(code: 'EMPTY_SCENARIO', message: 'Add at least one player, pick, right, cash item or exception.', severity: TradeValidationSeverity.error));
    return TradeValidationReport(findings: findings, teamSummaries: summaries);
  }

  double _maximumIncoming(TeamCapContext context, double outgoing, double postTradeSalary) {
    if (context.teamSalary < context.salaryCap) {
      final room = (context.salaryCap - context.teamSalary).clamp(0, double.infinity).toDouble();
      return outgoing + room + 250000;
    }
    if (postTradeSalary > context.firstApron) return outgoing;
    if (outgoing <= 0) return 0;
    final scaledSevenPointFive = 7500000 * (context.salaryCap / _cba2023Cap);
    final expanded = <double>[
      (2 * outgoing + 250000).clamp(0, outgoing + scaledSevenPointFive).toDouble(),
      1.25 * outgoing + 250000,
    ].reduce((a, b) => a > b ? a : b);
    return expanded;
  }
}

String _money(double value) {
  if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}K';
  return '\$${value.toStringAsFixed(0)}';
}
