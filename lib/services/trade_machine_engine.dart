enum TradeAssetType {
  player,
  draftPick,
  draftRights,
  cash,
  freeAgentRights,
  tradeException,
  signingException,
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
    this.standardRosterPlayers = 14,
    this.minimumStandardRosterPlayers = 14,
    this.cashSentThisSeason = 0,
    this.cashLimitThisSeason = double.infinity,
  });

  factory TeamCapContext.nba2026_27({
    required String team,
    required double teamSalary,
    double? hardCappedAt,
    int standardRosterPlayers = 14,
    int minimumStandardRosterPlayers = 14,
    double cashSentThisSeason = 0,
    double cashLimitThisSeason = double.infinity,
  }) {
    return TeamCapContext(
      team: team,
      teamSalary: teamSalary,
      salaryCap: 164961000,
      taxLine: 200428000,
      firstApron: 209015000,
      secondApron: 221686000,
      hardCappedAt: hardCappedAt,
      standardRosterPlayers: standardRosterPlayers,
      minimumStandardRosterPlayers: minimumStandardRosterPlayers,
      cashSentThisSeason: cashSentThisSeason,
      cashLimitThisSeason: cashLimitThisSeason,
    );
  }

  final String team;
  final double teamSalary;
  final double salaryCap;
  final double taxLine;
  final double firstApron;
  final double secondApron;
  final double? hardCappedAt;
  final int standardRosterPlayers;
  final int minimumStandardRosterPlayers;
  final double cashSentThisSeason;
  final double cashLimitThisSeason;

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
    this.asOfDateIso = '',
  });

  final String id;
  final String name;
  final String operatingSeason;
  final List<String> teams;
  final List<TradeAssignment> assignments;
  final Map<String, TeamCapContext> capContexts;
  final String asOfDateIso;

  Iterable<TradeAssignment> outgoingFor(String team) =>
      assignments.where((item) => item.asset.originTeam == team);
  Iterable<TradeAssignment> incomingFor(String team) =>
      assignments.where((item) => item.destinationTeam == team);

  /// Nominal salary is retained for compatibility with scenario/report code. The
  /// validator uses sender/receiver-specific matching salary internally so BYC,
  /// poison-pill, two-way and non-salary assets do not silently use this value.
  double outgoingSalary(String team) =>
      outgoingFor(team).fold(0, (sum, item) => sum + item.asset.salary);
  double incomingSalary(String team) =>
      incomingFor(team).fold(0, (sum, item) => sum + item.asset.salary);
  double postTradeSalary(String team) =>
      (capContexts[team]?.teamSalary ?? 0) -
      outgoingSalary(team) +
      incomingSalary(team);
}

enum TradeValidationSeverity { info, warning, error }

class TradeValidationFinding {
  const TradeValidationFinding({
    required this.code,
    required this.message,
    required this.severity,
    this.team,
    this.assetId,
  });

  final String code;
  final String message;
  final TradeValidationSeverity severity;
  final String? team;
  final String? assetId;
}

class TeamTradeSummary {
  const TeamTradeSummary({
    required this.team,
    required this.outgoingSalary,
    required this.incomingSalary,
    required this.postTradeSalary,
    required this.outgoingAssets,
    required this.incomingAssets,
    required this.maximumIncomingSalary,
    required this.projectedRosterPlayers,
    this.cashSent = 0,
    this.apronStatus = 'below-first-apron',
  });

  final String team;
  final double outgoingSalary;
  final double incomingSalary;
  final double postTradeSalary;
  final int outgoingAssets;
  final int incomingAssets;
  final double maximumIncomingSalary;
  final int projectedRosterPlayers;
  final double cashSent;
  final String apronStatus;
}

class TradeValidationReport {
  const TradeValidationReport({
    required this.findings,
    required this.teamSummaries,
  });

  final List<TradeValidationFinding> findings;
  final Map<String, TeamTradeSummary> teamSummaries;

  bool get isValid => !findings.any(
        (item) => item.severity == TradeValidationSeverity.error,
      );
  bool get requiresReview => findings.any(
        (item) => item.severity == TradeValidationSeverity.warning,
      );
  int get errorCount => findings
      .where((item) => item.severity == TradeValidationSeverity.error)
      .length;
  int get warningCount => findings
      .where((item) => item.severity == TradeValidationSeverity.warning)
      .length;
}

class TradeMachineEngine {
  const TradeMachineEngine();

  static const double _cba2023Cap = 136021000;

  TradeValidationReport validate(TradeScenario scenario) {
    final findings = <TradeValidationFinding>[];
    final summaries = <String, TeamTradeSummary>{};
    final asOf = _parseDate(scenario.asOfDateIso);

    if (scenario.teams.length < 2) {
      findings.add(
        const TradeValidationFinding(
          code: 'MIN_TEAMS',
          message: 'A trade requires at least two teams.',
          severity: TradeValidationSeverity.error,
        ),
      );
    }
    if (scenario.teams.length > 5) {
      findings.add(
        const TradeValidationFinding(
          code: 'MAX_TEAMS',
          message:
              'This product supports up to five participating teams per transaction.',
          severity: TradeValidationSeverity.error,
        ),
      );
    }
    if (scenario.teams.toSet().length != scenario.teams.length) {
      findings.add(
        const TradeValidationFinding(
          code: 'DUPLICATE_TEAM',
          message: 'A participating team is listed more than once.',
          severity: TradeValidationSeverity.error,
        ),
      );
    }

    final duplicateAssetIds = <String>{};
    final seenAssets = <String>{};
    for (final assignment in scenario.assignments) {
      final asset = assignment.asset;
      if (!seenAssets.add(asset.id)) duplicateAssetIds.add(asset.id);
      if (!scenario.teams.contains(asset.originTeam) ||
          !scenario.teams.contains(assignment.destinationTeam)) {
        findings.add(
          TradeValidationFinding(
            code: 'TEAM_SCOPE',
            message: '${asset.label} references a team outside this scenario.',
            severity: TradeValidationSeverity.error,
            assetId: asset.id,
          ),
        );
      }
      if (asset.originTeam == assignment.destinationTeam) {
        findings.add(
          TradeValidationFinding(
            code: 'SAME_TEAM',
            message: '${asset.label} cannot be routed back to its origin team.',
            severity: TradeValidationSeverity.error,
            team: asset.originTeam,
            assetId: asset.id,
          ),
        );
      }
      _validateAssetIntrinsic(
        scenario: scenario,
        assignment: assignment,
        asOf: asOf,
        findings: findings,
      );
    }
    for (final id in duplicateAssetIds) {
      findings.add(
        TradeValidationFinding(
          code: 'DUPLICATE_ASSET',
          message: 'Asset $id is assigned more than once.',
          severity: TradeValidationSeverity.error,
          assetId: id,
        ),
      );
    }

    for (final team in scenario.teams) {
      final outgoing = scenario.outgoingFor(team).toList();
      final incoming = scenario.incomingFor(team).toList();
      final outgoingPlayers = outgoing
          .where((item) =>
              item.asset.type == TradeAssetType.player &&
              item.asset.metadata['two_way'] != true)
          .toList();
      final incomingPlayers = incoming
          .where((item) =>
              item.asset.type == TradeAssetType.player &&
              item.asset.metadata['two_way'] != true)
          .toList();
      final outgoingSalary = outgoing.fold<double>(
        0,
        (sum, assignment) => sum + _outgoingMatchingSalary(assignment.asset),
      );
      final incomingSalary = incoming.fold<double>(
        0,
        (sum, assignment) => sum + _incomingMatchingSalary(assignment.asset),
      );
      final context = scenario.capContexts[team];
      final postTradeSalary = (context?.teamSalary ?? 0) -
          outgoingSalary +
          incomingSalary;
      final roster = (context?.standardRosterPlayers ?? 14) -
          outgoingPlayers.length +
          incomingPlayers.length;
      final maxIncoming = context == null
          ? double.infinity
          : _maximumIncoming(context, outgoingSalary, postTradeSalary);
      final cashSent = outgoing
          .where((item) => item.asset.type == TradeAssetType.cash)
          .fold<double>(0, (sum, item) => sum + _cashAmount(item.asset));

      summaries[team] = TeamTradeSummary(
        team: team,
        outgoingSalary: outgoingSalary,
        incomingSalary: incomingSalary,
        postTradeSalary: postTradeSalary,
        outgoingAssets: outgoing.length,
        incomingAssets: incoming.length,
        maximumIncomingSalary: maxIncoming,
        projectedRosterPlayers: roster,
        cashSent: cashSent,
        apronStatus: context == null
            ? 'unknown'
            : postTradeSalary > context.secondApron
                ? 'above-second-apron'
                : postTradeSalary > context.firstApron
                    ? 'above-first-apron'
                    : postTradeSalary > context.taxLine
                        ? 'tax'
                        : postTradeSalary > context.salaryCap
                            ? 'over-cap'
                            : 'cap-room',
      );

      if (outgoing.isEmpty && incoming.isEmpty) {
        findings.add(
          TradeValidationFinding(
            code: 'NO_ACTIVITY',
            message: '$team has no incoming or outgoing assets.',
            severity: TradeValidationSeverity.warning,
            team: team,
          ),
        );
      }
      if (context == null) {
        findings.add(
          TradeValidationFinding(
            code: 'MISSING_CAP_CONTEXT',
            message:
                '$team needs salary-cap context before legal validation can be completed.',
            severity: TradeValidationSeverity.warning,
            team: team,
          ),
        );
        continue;
      }

      if (roster > 15) {
        findings.add(
          TradeValidationFinding(
            code: 'ROSTER_MAX',
            message:
                '$team projects to $roster standard-contract players; the transaction requires a roster-compliance move.',
            severity: TradeValidationSeverity.warning,
            team: team,
          ),
        );
      }
      if (roster < context.minimumStandardRosterPlayers) {
        findings.add(
          TradeValidationFinding(
            code: 'ROSTER_MIN',
            message:
                '$team projects to $roster standard-contract players, below the modeled minimum of ${context.minimumStandardRosterPlayers}; subsequent signings or roster actions are required.',
            severity: TradeValidationSeverity.warning,
            team: team,
          ),
        );
      }
      if (context.hardCappedAt != null &&
          postTradeSalary > context.hardCappedAt!) {
        findings.add(
          TradeValidationFinding(
            code: 'HARD_CAP',
            message: '$team exceeds its modeled hard cap after the trade.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
      }
      if (incomingSalary > maxIncoming + .01) {
        findings.add(
          TradeValidationFinding(
            code: 'SALARY_MATCH',
            message:
                '$team receives ${_money(incomingSalary)}, above the modeled incoming-salary limit of ${_money(maxIncoming)} for this cap position.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
      }

      final usesException = incoming.any(
        (item) =>
            item.asset.type == TradeAssetType.tradeException ||
            item.asset.type == TradeAssetType.signingException,
      );
      final hasSignAndTrade = incoming.any(
        (item) => item.asset.metadata['sign_and_trade'] == true,
      );
      final aggregatesPlayers = outgoingPlayers.length > 1;

      if (cashSent > 0 && context.cashLimitThisSeason.isFinite) {
        final remaining =
            (context.cashLimitThisSeason - context.cashSentThisSeason)
                .clamp(0, double.infinity)
                .toDouble();
        if (cashSent > remaining + .01) {
          findings.add(
            TradeValidationFinding(
              code: 'CASH_LIMIT',
              message:
                  '$team sends ${_money(cashSent)} in cash but has only ${_money(remaining)} of the modeled annual cash limit remaining.',
              severity: TradeValidationSeverity.error,
              team: team,
            ),
          );
        }
      }

      if (context.aboveSecondApron || postTradeSalary > context.secondApron) {
        if (aggregatesPlayers && incomingPlayers.isNotEmpty) {
          findings.add(
            TradeValidationFinding(
              code: 'SECOND_APRON_AGGREGATION',
              message:
                  '$team is above the second apron and is aggregating multiple outgoing player salaries; this structure is blocked by the modeled second-apron transaction rules.',
              severity: TradeValidationSeverity.error,
              team: team,
            ),
          );
        }
        if (cashSent > 0) {
          findings.add(
            TradeValidationFinding(
              code: 'SECOND_APRON_CASH',
              message:
                  '$team is above the second apron and is sending cash; the modeled second-apron transaction rules prohibit this structure.',
              severity: TradeValidationSeverity.error,
              team: team,
            ),
          );
        }
        if (usesException) {
          findings.add(
            TradeValidationFinding(
              code: 'SECOND_APRON_EXCEPTION',
              message:
                  '$team is above the second apron and is using a trade/signing exception. This scenario is blocked conservatively pending the authoritative exception record.',
              severity: TradeValidationSeverity.error,
              team: team,
            ),
          );
        }
        if (hasSignAndTrade) {
          findings.add(
            TradeValidationFinding(
              code: 'SECOND_APRON_SIGN_AND_TRADE',
              message:
                  '$team cannot complete the modeled sign-and-trade while ending above the second apron; the transaction also requires first-apron hard-cap validation.',
              severity: TradeValidationSeverity.error,
              team: team,
            ),
          );
        }
      } else if (postTradeSalary > context.firstApron) {
        findings.add(
          TradeValidationFinding(
            code: 'FIRST_APRON',
            message:
                '$team projects above the first apron. The modeled \$250,000 traded-player-exception allowance is removed and hard-cap-triggering transaction types require review.',
            severity: TradeValidationSeverity.warning,
            team: team,
          ),
        );
      }

      if (hasSignAndTrade) {
        if (postTradeSalary > context.firstApron) {
          findings.add(
            TradeValidationFinding(
              code: 'SIGN_AND_TRADE_FIRST_APRON',
              message:
                  '$team acquires a sign-and-trade player and projects above the first apron. The modeled hard-cap consequence makes this transaction invalid.',
              severity: TradeValidationSeverity.error,
              team: team,
            ),
          );
        } else {
          findings.add(
            TradeValidationFinding(
              code: 'SIGN_AND_TRADE_HARD_CAP',
              message:
                  '$team acquires a sign-and-trade player; treat the first apron as a hard transaction ceiling and verify all related signing requirements.',
              severity: TradeValidationSeverity.warning,
              team: team,
            ),
          );
        }
      }

      for (final assignment
          in outgoing.where((item) => item.asset.type == TradeAssetType.player)) {
        final asset = assignment.asset;
        if (asset.metadata['no_trade'] == true) {
          findings.add(
            TradeValidationFinding(
              code: 'NO_TRADE_CLAUSE',
              message:
                  '${asset.label} is marked with trade-consent rights and requires player approval.',
              severity: TradeValidationSeverity.warning,
              team: team,
              assetId: asset.id,
            ),
          );
        }
        if (asset.metadata['trade_restricted'] == true) {
          findings.add(
            TradeValidationFinding(
              code: 'TRADE_RESTRICTED',
              message:
                  '${asset.label} is currently marked trade-restricted by contract/timing metadata.',
              severity: TradeValidationSeverity.error,
              team: team,
              assetId: asset.id,
            ),
          );
        }
        if (asset.metadata['cannot_aggregate'] == true && aggregatesPlayers) {
          findings.add(
            TradeValidationFinding(
              code: 'PLAYER_AGGREGATION_RESTRICTED',
              message:
                  '${asset.label} is marked as ineligible to aggregate with another outgoing player salary.',
              severity: TradeValidationSeverity.error,
              team: team,
              assetId: asset.id,
            ),
          );
        }
        if (asset.metadata['trade_bonus'] is num ||
            asset.metadata['trade_kicker'] is num) {
          findings.add(
            TradeValidationFinding(
              code: 'TRADE_BONUS',
              message:
                  '${asset.label} has a modeled trade bonus/kicker; matching salary and team salary must reflect its authoritative allocation.',
              severity: TradeValidationSeverity.warning,
              team: team,
              assetId: asset.id,
            ),
          );
        }
      }
      if (usesException) {
        findings.add(
          TradeValidationFinding(
            code: 'EXCEPTION_REVIEW',
            message:
                '$team uses an exception. Amount, expiration, aggregation, apron and hard-cap consequences must match the authoritative exception record.',
            severity: TradeValidationSeverity.warning,
            team: team,
          ),
        );
      }
    }

    _validatePickContinuity(scenario, findings);

    if (scenario.assignments.isEmpty) {
      findings.add(
        const TradeValidationFinding(
          code: 'EMPTY_SCENARIO',
          message:
              'Add at least one player, pick, right, cash item or exception.',
          severity: TradeValidationSeverity.error,
        ),
      );
    }
    return TradeValidationReport(
      findings: findings,
      teamSummaries: summaries,
    );
  }

  void _validateAssetIntrinsic({
    required TradeScenario scenario,
    required TradeAssignment assignment,
    required DateTime? asOf,
    required List<TradeValidationFinding> findings,
  }) {
    final asset = assignment.asset;
    final team = asset.originTeam;
    final metadata = asset.metadata;

    if (asset.type == TradeAssetType.player) {
      final restrictionUntil = _firstDate(
        metadata,
        const [
          'trade_restricted_until',
          'recently_signed_until',
          'recently_acquired_until',
        ],
      );
      if (restrictionUntil != null) {
        if (asOf == null) {
          findings.add(
            TradeValidationFinding(
              code: 'DATED_TRADE_RESTRICTION_REVIEW',
              message:
                  '${asset.label} has a trade-restriction date through ${_date(restrictionUntil)}, but this scenario has no as-of date. Add an as-of date before treating the player as trade-eligible.',
              severity: TradeValidationSeverity.warning,
              team: team,
              assetId: asset.id,
            ),
          );
        } else if (asOf.isBefore(restrictionUntil)) {
          findings.add(
            TradeValidationFinding(
              code: 'DATED_TRADE_RESTRICTION',
              message:
                  '${asset.label} is marked ineligible to be traded until ${_date(restrictionUntil)}.',
              severity: TradeValidationSeverity.error,
              team: team,
              assetId: asset.id,
            ),
          );
        }
      }
      if (metadata['base_year_compensation'] == true) {
        final explicit = _number(metadata['outgoing_matching_salary']) ??
            _number(metadata['byc_outgoing_salary']);
        findings.add(
          TradeValidationFinding(
            code: explicit == null ? 'BYC_VALUE_REQUIRED' : 'BYC_APPLIED',
            message: explicit == null
                ? '${asset.label} is marked Base Year Compensation but has no authoritative outgoing matching-salary value. The scenario cannot rely on nominal salary.'
                : '${asset.label} uses a BYC outgoing matching salary of ${_money(explicit)} rather than nominal salary.',
            severity: explicit == null
                ? TradeValidationSeverity.error
                : TradeValidationSeverity.info,
            team: team,
            assetId: asset.id,
          ),
        );
      }
      if (metadata['poison_pill'] == true) {
        final explicit = _number(metadata['incoming_matching_salary']) ??
            _number(metadata['poison_pill_incoming_salary']);
        findings.add(
          TradeValidationFinding(
            code: explicit == null
                ? 'POISON_PILL_VALUE_REQUIRED'
                : 'POISON_PILL_APPLIED',
            message: explicit == null
                ? '${asset.label} is marked poison-pill but has no authoritative receiving-team matching salary. Add that value before validating the trade.'
                : '${asset.label} uses a poison-pill receiving-team matching salary of ${_money(explicit)}.',
            severity: explicit == null
                ? TradeValidationSeverity.error
                : TradeValidationSeverity.info,
            team: assignment.destinationTeam,
            assetId: asset.id,
          ),
        );
      }
      if (metadata['two_way'] == true) {
        findings.add(
          TradeValidationFinding(
            code: 'TWO_WAY_CONTRACT',
            message:
                '${asset.label} is marked as a two-way contract. It is excluded from standard-roster and salary-matching calculations and requires two-way eligibility validation.',
            severity: TradeValidationSeverity.warning,
            team: team,
            assetId: asset.id,
          ),
        );
      }
      if (metadata['sign_and_trade'] == true &&
          assignment.destinationTeam == asset.originTeam) {
        findings.add(
          TradeValidationFinding(
            code: 'SIGN_AND_TRADE_DESTINATION',
            message:
                '${asset.label} is marked sign-and-trade but is not changing teams.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: asset.id,
          ),
        );
      }
    }

    if (asset.type == TradeAssetType.draftPick) {
      if (metadata['stepien_conflict'] == true) {
        findings.add(
          TradeValidationFinding(
            code: 'STEPIEN_CONFLICT',
            message:
                '${asset.label} is marked as creating a prohibited future first-round-pick continuity gap. The pick cannot be traded in this structure.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: asset.id,
          ),
        );
      }
      if (metadata['frozen'] == true || metadata['trade_frozen'] == true) {
        findings.add(
          TradeValidationFinding(
            code: 'FROZEN_PICK',
            message:
                '${asset.label} is marked frozen/unavailable for trade under the team’s current draft-asset restrictions.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: asset.id,
          ),
        );
      }
      if ('${metadata['protection'] ?? ''}'.trim().isNotEmpty) {
        findings.add(
          TradeValidationFinding(
            code: 'PICK_PROTECTION',
            message:
                '${asset.label} carries ${metadata['protection']} protection. Conveyance, rollover and downstream obligations must be modeled before final approval.',
            severity: TradeValidationSeverity.info,
            team: team,
            assetId: asset.id,
          ),
        );
      }
      if (metadata['swap_right'] == true) {
        findings.add(
          TradeValidationFinding(
            code: 'PICK_SWAP',
            message:
                '${asset.label} is a swap right. The underlying pick ownership, better/worse convention and competing swap obligations remain attached to the asset.',
            severity: TradeValidationSeverity.info,
            team: team,
            assetId: asset.id,
          ),
        );
      }
      if (metadata['conveyance_uncertain'] == true) {
        findings.add(
          TradeValidationFinding(
            code: 'PICK_CONVEYANCE_UNCERTAIN',
            message:
                '${asset.label} has uncertain conveyance. This scenario requires the complete protection/rollover tree before execution.',
            severity: TradeValidationSeverity.warning,
            team: team,
            assetId: asset.id,
          ),
        );
      }
      final yearsOut = _number(metadata['years_out'])?.toInt();
      if (yearsOut != null && yearsOut > 7) {
        findings.add(
          TradeValidationFinding(
            code: 'PICK_TOO_DISTANT',
            message:
                '${asset.label} is $yearsOut seasons out, beyond the modeled seven-season first-round trade horizon.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: asset.id,
          ),
        );
      }
    }

    if (asset.type == TradeAssetType.cash && _cashAmount(asset) <= 0) {
      findings.add(
        TradeValidationFinding(
          code: 'CASH_AMOUNT_REQUIRED',
          message: '${asset.label} needs a positive cash amount.',
          severity: TradeValidationSeverity.error,
          team: team,
          assetId: asset.id,
        ),
      );
    }

    if (asset.type == TradeAssetType.tradeException ||
        asset.type == TradeAssetType.signingException) {
      final expiresAt = _parseDate('${metadata['expires_at'] ?? ''}');
      if (expiresAt != null && asOf != null && asOf.isAfter(expiresAt)) {
        findings.add(
          TradeValidationFinding(
            code: 'EXPIRED_EXCEPTION',
            message: '${asset.label} expired on ${_date(expiresAt)}.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: asset.id,
          ),
        );
      }
      final amount = _number(metadata['amount']) ?? asset.salary;
      if (amount <= 0) {
        findings.add(
          TradeValidationFinding(
            code: 'EXCEPTION_AMOUNT_REQUIRED',
            message:
                '${asset.label} requires an authoritative available exception amount.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: asset.id,
          ),
        );
      }
    }
  }

  void _validatePickContinuity(
    TradeScenario scenario,
    List<TradeValidationFinding> findings,
  ) {
    for (final team in scenario.teams) {
      final outgoingFirsts = scenario
          .outgoingFor(team)
          .where(
            (item) =>
                item.asset.type == TradeAssetType.draftPick &&
                '${item.asset.metadata['round'] ?? ''}' == '1',
          )
          .toList();
      final byYear = <int, List<TradeAsset>>{};
      for (final assignment in outgoingFirsts) {
        final year = _number(assignment.asset.metadata['draft_year'])?.toInt();
        if (year == null) continue;
        byYear.putIfAbsent(year, () => []).add(assignment.asset);
      }
      final years = byYear.keys.toList()..sort();
      for (var index = 0; index + 1 < years.length; index++) {
        if (years[index + 1] == years[index] + 1) {
          final first = byYear[years[index]]!;
          final second = byYear[years[index + 1]]!;
          final hasExplicitSafeMetadata = [...first, ...second].every(
            (asset) =>
                asset.metadata['stepien_safe'] == true ||
                asset.metadata['swap_right'] == true,
          );
          if (!hasExplicitSafeMetadata) {
            findings.add(
              TradeValidationFinding(
                code: 'STEPIEN_REVIEW',
                message:
                    '$team sends first-round interests in consecutive draft years ${years[index]} and ${years[index + 1]}. Validate retained first-round control, protections and swaps before approval.',
                severity: TradeValidationSeverity.warning,
                team: team,
              ),
            );
          }
        }
      }
    }
  }

  double _outgoingMatchingSalary(TradeAsset asset) {
    if (asset.type != TradeAssetType.player) return 0;
    if (asset.metadata['two_way'] == true) return 0;
    return _number(asset.metadata['outgoing_matching_salary']) ??
        _number(asset.metadata['byc_outgoing_salary']) ??
        asset.salary;
  }

  double _incomingMatchingSalary(TradeAsset asset) {
    if (asset.type != TradeAssetType.player) return 0;
    if (asset.metadata['two_way'] == true) return 0;
    return _number(asset.metadata['incoming_matching_salary']) ??
        _number(asset.metadata['poison_pill_incoming_salary']) ??
        asset.salary;
  }

  double _cashAmount(TradeAsset asset) =>
      _number(asset.metadata['amount']) ?? asset.salary;

  double _maximumIncoming(
    TeamCapContext context,
    double outgoing,
    double postTradeSalary,
  ) {
    if (context.teamSalary < context.salaryCap) {
      final room = (context.salaryCap - context.teamSalary)
          .clamp(0, double.infinity)
          .toDouble();
      return outgoing + room + 250000;
    }
    if (postTradeSalary > context.firstApron) return outgoing;
    if (outgoing <= 0) return 0;
    final scaledSevenPointFive = 7500000 * (context.salaryCap / _cba2023Cap);
    final expanded = <double>[
      (2 * outgoing + 250000)
          .clamp(0, outgoing + scaledSevenPointFive)
          .toDouble(),
      1.25 * outgoing + 250000,
    ].reduce((a, b) => a > b ? a : b);
    return expanded;
  }
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}');
}

DateTime? _parseDate(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  return DateTime.tryParse(normalized)?.toUtc();
}

DateTime? _firstDate(Map<String, dynamic> metadata, List<String> keys) {
  for (final key in keys) {
    final parsed = _parseDate('${metadata[key] ?? ''}');
    if (parsed != null) return parsed;
  }
  return null;
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _money(double value) {
  if (value >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(0)}K';
  }
  return '\$${value.toStringAsFixed(0)}';
}
