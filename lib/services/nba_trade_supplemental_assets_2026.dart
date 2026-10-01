class NbaTradeDraftRight {
  const NbaTradeDraftRight({
    required this.id,
    required this.team,
    required this.player,
    required this.position,
    this.note = '',
    this.source = 'User-supplied Trade Machine screen recording (2026-09-30)',
  });

  final String id;
  final String team;
  final String player;
  final String position;
  final String note;
  final String source;
}

class NbaTradeFreeAgentRight {
  const NbaTradeFreeAgentRight({
    required this.id,
    required this.team,
    required this.player,
    required this.position,
    required this.capHold,
    required this.rights,
    this.signAndTradeMinimum,
    this.signAndTradeMaximum,
    this.source = 'User-supplied Trade Machine screen recording (2026-09-30)',
  });

  final String id;
  final String team;
  final String player;
  final String position;
  final double capHold;
  final String rights;
  final double? signAndTradeMinimum;
  final double? signAndTradeMaximum;
  final String source;

  bool get signAndTradeReady =>
      signAndTradeMinimum != null &&
      signAndTradeMaximum != null &&
      signAndTradeMaximum! >= signAndTradeMinimum!;
}

class NbaTradeSupplementalAssets202627 {
  const NbaTradeSupplementalAssets202627._();

  /// Draft-rights records directly visible in the user's 2026-09-30 reference
  /// recording. This list is intentionally source-gated instead of pretending
  /// to be an all-team rights ledger before those records are normalized.
  static const List<NbaTradeDraftRight> draftRights = [
    NbaTradeDraftRight(
      id: 'draft-right:BOS:justinian-jessup',
      team: 'BOS',
      player: 'Justinian Jessup',
      position: 'SG',
      note: 'Boston draft rights shown in the supplied Spotrac reference workflow.',
    ),
  ];

  /// Free-agent rights/cap holds directly visible in the user's reference
  /// recording. Kyle Lowry also has the displayed sign-and-trade salary range,
  /// so the UI can model that workflow without inventing values for other rows.
  static const List<NbaTradeFreeAgentRight> freeAgentRights = [
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:marjon-beauchamp',
      team: 'PHI',
      player: 'MarJon Beauchamp',
      position: 'SG',
      capHold: 2449421,
      rights: 'UFA · Non-Bird',
    ),
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:kyle-lowry',
      team: 'PHI',
      player: 'Kyle Lowry',
      position: 'PG',
      capHold: 2449421,
      rights: 'UFA · Early Bird',
      signAndTradeMinimum: 3876529,
      signAndTradeMaximum: 27678571,
    ),
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:tyrese-martin',
      team: 'PHI',
      player: 'Tyrese Martin',
      position: 'SF',
      capHold: 2449421,
      rights: 'UFA · Non-Bird',
    ),
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:jeff-dowtin',
      team: 'PHI',
      player: 'Jeff Dowtin',
      position: 'PG',
      capHold: 2185116,
      rights: 'UFA · Two-Way',
    ),
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:jalen-hood-schifino',
      team: 'PHI',
      player: 'Jalen Hood-Schifino',
      position: 'PG',
      capHold: 2185116,
      rights: 'UFA · Two-Way',
    ),
  ];

  static List<NbaTradeDraftRight> draftRightsFor(String team) =>
      draftRights.where((item) => item.team == team).toList(growable: false);

  static List<NbaTradeFreeAgentRight> freeAgentRightsFor(String team) =>
      freeAgentRights
          .where((item) => item.team == team)
          .toList(growable: false);
}
