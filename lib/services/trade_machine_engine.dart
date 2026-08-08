enum TradeAssetType {
  player,
  draftPick,
  draftRights,
  cash,
  freeAgentRights,
  tradeException,
  signingException,
}

class NbaCbaSeasonThresholds {
  const NbaCbaSeasonThresholds({
    required this.season,
    required this.salaryCap,
    required this.taxLine,
    required this.minimumTeamSalary,
    required this.firstApron,
    required this.secondApron,
    required this.nonTaxpayerMle,
    required this.taxpayerMle,
    required this.roomMle,
  });

  final String season;
  final double salaryCap;
  final double taxLine;
  final double minimumTeamSalary;
  final double firstApron;
  final double secondApron;
  final double nonTaxpayerMle;
  final double taxpayerMle;
  final double roomMle;

  static const seasons = <String, NbaCbaSeasonThresholds>{
    '2025-26': NbaCbaSeasonThresholds(
      season: '2025-26',
      salaryCap: 154647000,
      taxLine: 187895000,
      minimumTeamSalary: 139182000,
      firstApron: 195945000,
      secondApron: 207824000,
      nonTaxpayerMle: 14104000,
      taxpayerMle: 5685000,
      roomMle: 8781000,
    ),
    '2026-27': NbaCbaSeasonThresholds(
      season: '2026-27',
      salaryCap: 164961000,
      taxLine: 200428000,
      minimumTeamSalary: 148465000,
      firstApron: 209015000,
      secondApron: 221686000,
      nonTaxpayerMle: 15044000,
      taxpayerMle: 6064000,
      roomMle: 9366000,
    ),
  };

  static NbaCbaSeasonThresholds? forSeason(String season) => seasons[season];
}

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

  bool get isPlayer => type == TradeAssetType.player;
  bool get isPick => type == TradeAssetType.draftPick;
  int? get pickYear => _int(metadata['year'] ?? metadata['pick_year']);
  int? get pickRound => _int(metadata['round'] ?? metadata['pick_round']);
  bool get isFirstRoundPick => isPick && pickRound == 1;
  bool get isFrozenPick => _bool(metadata['frozen']) || _bool(metadata['second_apron_frozen']);
  bool get isTradeable => !_bool(metadata['not_tradeable']) && !_bool(metadata['cannot_trade']);
  bool get aggregationRestricted => _bool(metadata['aggregation_restricted']) || _bool(metadata['recently_acquired_restricted']);
  bool get noTradeClause => _bool(metadata['no_trade_clause']);
  bool get noTradeConsent => _bool(metadata['no_trade_consent']) || (metadata.containsKey('trade_consent') && !_bool(metadata['trade_consent']));
  bool get poisonPill => _bool(metadata['poison_pill']);
  bool get recentlySignedRestricted => _bool(metadata['recently_signed_restricted']) || _bool(metadata['trade_restricted']);
  bool get isUnprotectedFirst => isFirstRoundPick && !_bool(metadata['protected']) && !_bool(metadata['swap']);
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
    this.standardRosterCount = 15,
    this.twoWayCount = 0,
    this.maximumRosterSize = 15,
    this.minimumRosterSize = 14,
  });

  final String team;
  final double teamSalary;
  final double salaryCap;
  final double taxLine;
  final double firstApron;
  final double secondApron;
  final double? hardCappedAt;
  final int standardRosterCount;
  final int twoWayCount;
  final int maximumRosterSize;
  final int minimumRosterSize;

  bool get aboveCap => teamSalary > salaryCap;
  bool get aboveTax => teamSalary > taxLine;
  bool get aboveFirstApron => teamSalary > firstApron;
  bool get aboveSecondApron => teamSalary > secondApron;
  double get capRoom => salaryCap > teamSalary ? salaryCap - teamSalary : 0;
}

class TradeScenario {
  const TradeScenario({
    required this.id,
    required this.name,
    required this.operatingSeason,
    required this.teams,
    required this.assignments,
    required this.capContexts,
    this.asOfDate,
    this.enforceStepien = true,
  });

  final String id;
  final String name;
  final String operatingSeason;
  final List<String> teams;
  final List<TradeAssignment> assignments;
  final Map<String, TeamCapContext> capContexts;
  final DateTime? asOfDate;
  final bool enforceStepien;

  Iterable<TradeAssignment> outgoingFor(String team) => assignments.where((item) => item.asset.originTeam == team);
  Iterable<TradeAssignment> incomingFor(String team) => assignments.where((item) => item.destinationTeam == team);

  double outgoingSalary(String team) => outgoingFor(team).where((item) => item.asset.isPlayer).fold(0, (sum, item) => sum + item.asset.salary);
  double incomingSalary(String team) => incomingFor(team).where((item) => item.asset.isPlayer).fold(0, (sum, item) => sum + item.asset.salary);
  double postTradeSalary(String team) => (capContexts[team]?.teamSalary ?? 0) - outgoingSalary(team) + incomingSalary(team);
  int outgoingPlayers(String team) => outgoingFor(team).where((item) => item.asset.isPlayer).length;
  int incomingPlayers(String team) => incomingFor(team).where((item) => item.asset.isPlayer).length;
  int postTradeRosterCount(String team) => (capContexts[team]?.standardRosterCount ?? 15) - outgoingPlayers(team) + incomingPlayers(team);

  TradeScenario copyWith({
    String? name,
    List<String>? teams,
    List<TradeAssignment>? assignments,
    Map<String, TeamCapContext>? capContexts,
    DateTime? asOfDate,
    bool? enforceStepien,
  }) =>
      TradeScenario(
        id: id,
        name: name ?? this.name,
        operatingSeason: operatingSeason,
        teams: teams ?? this.teams,
        assignments: assignments ?? this.assignments,
        capContexts: capContexts ?? this.capContexts,
        asOfDate: asOfDate ?? this.asOfDate,
        enforceStepien: enforceStepien ?? this.enforceStepien,
      );
}

enum TradeValidationSeverity { info, warning, error }

class TradeValidationFinding {
  const TradeValidationFinding({
    required this.code,
    required this.message,
    required this.severity,
    this.team,
    this.assetId,
    this.ruleReference = '',
  });
  final String code;
  final String message;
  final TradeValidationSeverity severity;
  final String? team;
  final String? assetId;
  final String ruleReference;
}

class TeamTradeSummary {
  const TeamTradeSummary({
    required this.team,
    required this.outgoingSalary,
    required this.incomingSalary,
    required this.allowedIncomingSalary,
    required this.salaryMatchingRoom,
    required this.postTradeSalary,
    required this.outgoingAssets,
    required this.incomingAssets,
    required this.outgoingPlayers,
    required this.incomingPlayers,
    required this.postTradeRosterCount,
    required this.preTradeTier,
    required this.postTradeTier,
  });

  final String team;
  final double outgoingSalary;
  final double incomingSalary;
  final double allowedIncomingSalary;
  final double salaryMatchingRoom;
  final double postTradeSalary;
  final int outgoingAssets;
  final int incomingAssets;
  final int outgoingPlayers;
  final int incomingPlayers;
  final int postTradeRosterCount;
  final String preTradeTier;
  final String postTradeTier;
}

class TradeValidationReport {
  const TradeValidationReport({
    required this.findings,
    required this.teamSummaries,
    required this.operatingSeason,
    required this.thresholds,
  });
  final List<TradeValidationFinding> findings;
  final Map<String, TeamTradeSummary> teamSummaries;
  final String operatingSeason;
  final NbaCbaSeasonThresholds? thresholds;

  bool get isValid => !findings.any((item) => item.severity == TradeValidationSeverity.error);
  bool get requiresReview => findings.any((item) => item.severity == TradeValidationSeverity.warning);
  int get errorCount => findings.where((item) => item.severity == TradeValidationSeverity.error).length;
  int get warningCount => findings.where((item) => item.severity == TradeValidationSeverity.warning).length;
  int get infoCount => findings.where((item) => item.severity == TradeValidationSeverity.info).length;
}

class TradeMachineEngine {
  const TradeMachineEngine();

  TradeValidationReport validate(TradeScenario scenario) {
    final findings = <TradeValidationFinding>[];
    final summaries = <String, TeamTradeSummary>{};
    final thresholds = NbaCbaSeasonThresholds.forSeason(scenario.operatingSeason);

    if (scenario.teams.length < 2) {
      findings.add(const TradeValidationFinding(code: 'MIN_TEAMS', message: 'A trade requires at least two teams.', severity: TradeValidationSeverity.error));
    }
    if (scenario.teams.length > 5) {
      findings.add(const TradeValidationFinding(code: 'MAX_TEAMS', message: 'Sports Terminal models a maximum of five teams in one trade scenario.', severity: TradeValidationSeverity.error));
    }
    if (scenario.teams.toSet().length != scenario.teams.length) {
      findings.add(const TradeValidationFinding(code: 'DUPLICATE_TEAM', message: 'Each team may appear only once in the scenario.', severity: TradeValidationSeverity.error));
    }
    if (thresholds == null) {
      findings.add(TradeValidationFinding(
        code: 'UNVERIFIED_SEASON_THRESHOLDS',
        message: 'No certified Sports Terminal CBA threshold package is installed for ${scenario.operatingSeason}; team-provided cap contexts will be used but season-level validation is incomplete.',
        severity: TradeValidationSeverity.warning,
      ));
    }

    final duplicateAssetIds = <String>{};
    final seenAssets = <String>{};
    for (final assignment in scenario.assignments) {
      if (!seenAssets.add(assignment.asset.id)) duplicateAssetIds.add(assignment.asset.id);
      if (!scenario.teams.contains(assignment.asset.originTeam) || !scenario.teams.contains(assignment.destinationTeam)) {
        findings.add(TradeValidationFinding(code: 'TEAM_SCOPE', message: '${assignment.asset.label} references a team outside this scenario.', severity: TradeValidationSeverity.error, assetId: assignment.asset.id));
      }
      if (assignment.asset.originTeam == assignment.destinationTeam) {
        findings.add(TradeValidationFinding(code: 'SAME_TEAM', message: '${assignment.asset.label} cannot be routed back to its origin team.', severity: TradeValidationSeverity.error, team: assignment.asset.originTeam, assetId: assignment.asset.id));
      }
      _validateAsset(assignment, scenario, findings);
    }
    for (final id in duplicateAssetIds) {
      findings.add(TradeValidationFinding(code: 'DUPLICATE_ASSET', message: 'Asset $id is assigned more than once.', severity: TradeValidationSeverity.error, assetId: id));
    }

    for (final team in scenario.teams) {
      final outgoing = scenario.outgoingFor(team).toList();
      final incoming = scenario.incomingFor(team).toList();
      final outgoingSalary = scenario.outgoingSalary(team);
      final incomingSalary = scenario.incomingSalary(team);
      final postTradeSalary = scenario.postTradeSalary(team);
      final outgoingPlayers = scenario.outgoingPlayers(team);
      final incomingPlayers = scenario.incomingPlayers(team);
      final postRoster = scenario.postTradeRosterCount(team);
      final context = scenario.capContexts[team];
      final allowedIncoming = context == null ? 0 : _allowedIncomingSalary(context, outgoingSalary, postTradeSalary);

      summaries[team] = TeamTradeSummary(
        team: team,
        outgoingSalary: outgoingSalary,
        incomingSalary: incomingSalary,
        allowedIncomingSalary: allowedIncoming,
        salaryMatchingRoom: allowedIncoming - incomingSalary,
        postTradeSalary: postTradeSalary,
        outgoingAssets: outgoing.length,
        incomingAssets: incoming.length,
        outgoingPlayers: outgoingPlayers,
        incomingPlayers: incomingPlayers,
        postTradeRosterCount: postRoster,
        preTradeTier: context == null ? 'Unknown' : _salaryTier(context.teamSalary, context),
        postTradeTier: context == null ? 'Unknown' : _salaryTier(postTradeSalary, context),
      );

      if (outgoing.isEmpty && incoming.isEmpty) {
        findings.add(TradeValidationFinding(code: 'NO_ACTIVITY', message: '$team has no incoming or outgoing assets.', severity: TradeValidationSeverity.warning, team: team));
      }
      if (context == null) {
        findings.add(TradeValidationFinding(code: 'MISSING_CAP_CONTEXT', message: '$team needs salary-cap context before legal validation can be completed.', severity: TradeValidationSeverity.error, team: team));
        continue;
      }

      _validateSalaryMatching(
        team: team,
        context: context,
        outgoingSalary: outgoingSalary,
        incomingSalary: incomingSalary,
        allowedIncoming: allowedIncoming,
        postTradeSalary: postTradeSalary,
        outgoingPlayers: outgoingPlayers,
        outgoing: outgoing,
        incoming: incoming,
        findings: findings,
      );
      _validateRoster(team, context, postRoster, findings);
      _validatePicks(team, outgoing, scenario, findings);
    }

    if (scenario.assignments.isEmpty) {
      findings.add(const TradeValidationFinding(code: 'EMPTY_SCENARIO', message: 'Add at least one player, pick, right, cash item or exception.', severity: TradeValidationSeverity.error));
    }

    if (findings.isEmpty) {
      findings.add(const TradeValidationFinding(
        code: 'STRUCTURAL_PASS',
        message: 'No modeled CBA or asset-rule failures were detected. Final league approval still depends on authoritative contracts, transaction timing and league administration.',
        severity: TradeValidationSeverity.info,
      ));
    }

    return TradeValidationReport(
      findings: findings,
      teamSummaries: summaries,
      operatingSeason: scenario.operatingSeason,
      thresholds: thresholds,
    );
  }

  double _allowedIncomingSalary(TeamCapContext context, double outgoingSalary, double postTradeSalary) {
    if (outgoingSalary <= 0) {
      // A team under the cap can absorb salary using room; a team over the cap
      // generally needs an exception or outgoing salary to receive a player.
      return context.capRoom;
    }
    // Cap room can be combined with outgoing salary when a below-cap team
    // structures the trade using room instead of relying solely on an exception.
    final roomStructure = outgoingSalary + context.capRoom;
    // Cap room can be combined with outgoing salary when a below-cap team
    // structures the trade using room instead of relying solely on an exception.
    final roomStructure = outgoingSalary + context.capRoom;
    // Cap room can be combined with outgoing salary when a below-cap team
    // structures the trade using room instead of relying solely on an exception.
    final roomStructure = outgoingSalary + context.capRoom;
    // Cap room can be combined with outgoing salary when a below-cap team
    // structures the trade using room instead of relying solely on an exception.
    final roomStructure = outgoingSalary + context.capRoom;
    // Cap room can be combined with outgoing salary when a below-cap team
    // structures the trade using room instead of relying solely on an exception.
    final roomStructure = outgoingSalary + context.capRoom;
    // Cap room can be combined with outgoing salary when a below-cap team
    // structures the trade using room instead of relying solely on an exception.
    final roomStructure = outgoingSalary + context.capRoom;
    if (context.aboveSecondApron || postTradeSalary > context.secondApron) {
      return outgoingSalary;
    }
    if (context.aboveFirstApron || postTradeSalary > context.firstApron) {
      return outgoingSalary + 250000;
    }
    // Expanded TPE formula under the 2023 CBA: greater of
    // (a) min(200% outgoing + $250k, outgoing + $7.5m) and
    // (b) 125% outgoing + $250k. The $7.5m amount is the base value represented
    // by the current CBA implementation; season escalation can be supplied later
    // through certified rule metadata without changing the formula interface.
    final doubleA = outgoingSalary * 2 + 250000;
    final roomA = outgoingSalary + 7500000;
    final firstBranch = doubleA < roomA ? doubleA : roomA;
    final secondBranch = outgoingSalary * 1.25 + 250000;
    final exceptionStructure = firstBranch > secondBranch ? firstBranch : secondBranch;
    return roomStructure > exceptionStructure ? roomStructure : exceptionStructure;
  }

  void _validateSalaryMatching({
    required String team,
    required TeamCapContext context,
    required double outgoingSalary,
    required double incomingSalary,
    required double allowedIncoming,
    required double postTradeSalary,
    required int outgoingPlayers,
    required List<TradeAssignment> outgoing,
    required List<TradeAssignment> incoming,
    required List<TradeValidationFinding> findings,
  }) {
    if (incomingSalary > allowedIncoming + 1) {
      findings.add(TradeValidationFinding(
        code: 'SALARY_MATCHING',
        message: '$team receives ${_money(incomingSalary)} but the modeled salary-matching ceiling is ${_money(allowedIncoming)}.',
        severity: TradeValidationSeverity.error,
        team: team,
        ruleReference: 'CBA Article VII §6(j)',
      ));
    } else if (incomingSalary > 0) {
      findings.add(TradeValidationFinding(
        code: 'SALARY_MATCHING_HEADROOM',
        message: '$team is ${_money(allowedIncoming - incomingSalary)} below its modeled incoming-salary ceiling.',
        severity: TradeValidationSeverity.info,
        team: team,
        ruleReference: 'CBA Article VII §6(j)',
      ));
    }

    if (context.hardCappedAt != null && postTradeSalary > context.hardCappedAt! + 1) {
      findings.add(TradeValidationFinding(code: 'HARD_CAP', message: '$team exceeds its hard cap by ${_money(postTradeSalary - context.hardCappedAt!)} after the trade.', severity: TradeValidationSeverity.error, team: team));
    }

    if (postTradeSalary > context.secondApron) {
      findings.add(TradeValidationFinding(code: 'SECOND_APRON', message: '$team is above the second apron after the trade; second-apron transaction restrictions apply.', severity: TradeValidationSeverity.warning, team: team));
    } else if (postTradeSalary > context.firstApron) {
      findings.add(TradeValidationFinding(code: 'FIRST_APRON', message: '$team is above the first apron after the trade; first-apron salary matching and hard-cap consequences require review.', severity: TradeValidationSeverity.info, team: team));
    }

    final hasOutgoingCash = outgoing.any((item) => item.asset.type == TradeAssetType.cash);
    if (hasOutgoingCash && context.aboveSecondApron) {
      findings.add(TradeValidationFinding(
        code: 'SECOND_APRON_CASH',
        message: '$team is above the second apron and is modeled as sending cash in the trade.',
        severity: TradeValidationSeverity.error,
        team: team,
        ruleReference: 'CBA Second Apron transaction restrictions',
      ));
    }

    if (context.aboveSecondApron && outgoingPlayers > 1) {
      findings.add(TradeValidationFinding(
        code: 'SECOND_APRON_AGGREGATION',
        message: '$team is above the second apron and aggregates $outgoingPlayers outgoing players for salary matching.',
        severity: TradeValidationSeverity.error,
        team: team,
        ruleReference: 'CBA Second Apron aggregation restriction',
      ));
    }

    if (outgoingPlayers > 1 && outgoing.any((item) => item.asset.aggregationRestricted)) {
      findings.add(TradeValidationFinding(
        code: 'RECENT_ACQUISITION_AGGREGATION',
        message: '$team aggregates a player marked as recently acquired / aggregation restricted.',
        severity: TradeValidationSeverity.error,
        team: team,
        ruleReference: 'CBA Article VII §6 aggregation timing',
      ));
    }

    final usesException = incoming.any((item) => item.asset.type == TradeAssetType.tradeException || item.asset.type == TradeAssetType.signingException);
    if (usesException) {
      findings.add(TradeValidationFinding(
        code: 'EXCEPTION_REVIEW',
        message: '$team uses a trade/signing exception. Amount, expiration, aggregation and apron consequences must match the underlying exception record.',
        severity: TradeValidationSeverity.warning,
        team: team,
      ));
    }
  }

  void _validateRoster(String team, TeamCapContext context, int postRoster, List<TradeValidationFinding> findings) {
    if (postRoster > context.maximumRosterSize) {
      findings.add(TradeValidationFinding(
        code: 'ROSTER_OVER_MAX',
        message: '$team would have $postRoster standard-roster players versus the modeled ${context.maximumRosterSize}-player regular-season maximum. A corresponding waiver/roster move may be required.',
        severity: TradeValidationSeverity.warning,
        team: team,
      ));
    }
    if (postRoster < context.minimumRosterSize) {
      findings.add(TradeValidationFinding(
        code: 'ROSTER_BELOW_MIN',
        message: '$team would have $postRoster standard-roster players versus the modeled ${context.minimumRosterSize}-player minimum and may need to add players within the applicable compliance window.',
        severity: TradeValidationSeverity.warning,
        team: team,
      ));
    }
  }

  void _validateAsset(TradeAssignment assignment, TradeScenario scenario, List<TradeValidationFinding> findings) {
    final asset = assignment.asset;
    if (!asset.isTradeable) {
      findings.add(TradeValidationFinding(code: 'ASSET_NOT_TRADEABLE', message: '${asset.label} is marked not tradeable in the active asset record.', severity: TradeValidationSeverity.error, team: asset.originTeam, assetId: asset.id));
    }
    if (asset.isFrozenPick) {
      findings.add(TradeValidationFinding(code: 'FROZEN_PICK', message: '${asset.label} is marked as a frozen draft pick and cannot be included without first resolving the applicable restriction.', severity: TradeValidationSeverity.error, team: asset.originTeam, assetId: asset.id, ruleReference: 'Second Apron future-pick restriction'));
    }
    if (asset.recentlySignedRestricted) {
      findings.add(TradeValidationFinding(code: 'PLAYER_TRADE_RESTRICTION', message: '${asset.label} is marked as subject to a signing/trade eligibility restriction.', severity: TradeValidationSeverity.error, team: asset.originTeam, assetId: asset.id));
    }
    final eligible = _date(asset.metadata['trade_eligible_date']);
    final asOf = scenario.asOfDate ?? DateTime.now();
    if (eligible != null && eligible.isAfter(asOf)) {
      findings.add(TradeValidationFinding(code: 'TRADE_ELIGIBILITY_DATE', message: '${asset.label} cannot be traded until ${eligible.toIso8601String().split('T').first}.', severity: TradeValidationSeverity.error, team: asset.originTeam, assetId: asset.id));
    }
    if (asset.noTradeClause && !asset.noTradeConsent) {
      findings.add(TradeValidationFinding(code: 'NO_TRADE_CONSENT', message: '${asset.label} is marked with a no-trade right and no consent is recorded for this scenario.', severity: TradeValidationSeverity.error, team: asset.originTeam, assetId: asset.id));
    }
    if (asset.poisonPill) {
      findings.add(TradeValidationFinding(code: 'POISON_PILL', message: '${asset.label} is marked as poison-pill affected; sending and receiving salary treatment may differ and requires contract-level calculation.', severity: TradeValidationSeverity.warning, team: asset.originTeam, assetId: asset.id));
    }
    final kicker = _double(asset.metadata['trade_kicker_pct'] ?? asset.metadata['trade_bonus_pct']);
    if (kicker > 0) {
      findings.add(TradeValidationFinding(code: 'TRADE_KICKER', message: '${asset.label} carries a ${(kicker * 100).toStringAsFixed(1)}% modeled trade bonus/kicker; confirm waiver and salary-matching treatment.', severity: TradeValidationSeverity.warning, team: asset.originTeam, assetId: asset.id));
    }
  }

  void _validatePicks(String team, List<TradeAssignment> outgoing, TradeScenario scenario, List<TradeValidationFinding> findings) {
    final picks = outgoing.map((item) => item.asset).where((asset) => asset.isPick).toList();
    if (!scenario.enforceStepien || picks.isEmpty) return;
    final firstYears = picks.where((asset) => asset.isUnprotectedFirst && asset.pickYear != null).map((asset) => asset.pickYear!).toSet().toList()..sort();
    for (var i = 1; i < firstYears.length; i++) {
      if (firstYears[i] - firstYears[i - 1] == 1) {
        findings.add(TradeValidationFinding(
          code: 'STEPIEN_CONSECUTIVE_FIRSTS',
          message: '$team sends unprotected first-round picks in consecutive future drafts (${firstYears[i - 1]} and ${firstYears[i]}). Review the Stepien Rule and the team’s remaining first-round inventory.',
          severity: TradeValidationSeverity.error,
          team: team,
          ruleReference: 'Stepien Rule / future first-round pick restrictions',
        ));
      }
    }
    for (final asset in picks) {
      if (_bool(asset.metadata['stepien_review'])) {
        findings.add(TradeValidationFinding(code: 'STEPIEN_REVIEW', message: '${asset.label} is explicitly marked for Stepien-rule review against other owned/owed first-round picks.', severity: TradeValidationSeverity.warning, team: team, assetId: asset.id));
      }
      if (_bool(asset.metadata['seven_year_limit'])) {
        findings.add(TradeValidationFinding(code: 'SEVEN_YEAR_PICK_LIMIT', message: '${asset.label} is marked outside or at the edge of the permitted future-draft trading horizon.', severity: TradeValidationSeverity.error, team: team, assetId: asset.id));
      }
    }
  }
}

String _salaryTier(double salary, TeamCapContext context) {
  if (salary > context.secondApron) return 'Above second apron';
  if (salary > context.firstApron) return 'Above first apron';
  if (salary > context.taxLine) return 'Tax team';
  if (salary > context.salaryCap) return 'Above cap';
  return 'Below cap';
}

bool _bool(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim() ?? '';
  return {'true', '1', 'yes', 'y'}.contains(text);
}
int? _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
double _double(Object? value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
DateTime? _date(Object? value) => DateTime.tryParse(value?.toString() ?? '');
String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  if (amount >= 1000000) return '$sign\$${(amount / 1000000).toStringAsFixed(2)}M';
  if (amount >= 1000) return '$sign\$${(amount / 1000).toStringAsFixed(0)}K';
  return '$sign\$${amount.toStringAsFixed(0)}';
}
