class NbaTeamCapLedgerEntry {
  const NbaTeamCapLedgerEntry({
    required this.team,
    required this.totalCap,
    required this.active,
    required this.dead,
    this.retained = 0,
    this.capHolds = 0,
    this.incompleteRosterCharges = 0,
  });

  final String team;
  final double totalCap;
  final double active;
  final double dead;
  final double retained;
  final double capHolds;
  final double incompleteRosterCharges;

  double get knownComponents =>
      active + dead + retained + capHolds + incompleteRosterCharges;
  double get otherAdjustments => totalCap - knownComponents;
}

class NbaTeamCapReference202627 {
  const NbaTeamCapReference202627._();

  /// Team-level 2026-27 cap allocation ledger transcribed from the supplied
  /// Spotrac screenshots. `totalCap` comes from the multi-year cap tracker,
  /// while `active` and `dead` come from the team cap/cash tracker. Retained,
  /// cap holds and incomplete-roster charges are only populated where directly
  /// visible in the supplied references; any remaining difference is exposed as
  /// `otherAdjustments` rather than silently assigned to a bucket.
  static const Map<String, NbaTeamCapLedgerEntry> ledger = {
    'ATL': NbaTeamCapLedgerEntry(team:'ATL', totalCap:230094791, active:196744611, dead:0),
    'BOS': NbaTeamCapLedgerEntry(team:'BOS', totalCap:207991480, active:199617438, dead:0, retained:1972866),
    'BRK': NbaTeamCapLedgerEntry(team:'BRK', totalCap:163229398, active:162093164, dead:0),
    'CHA': NbaTeamCapLedgerEntry(team:'CHA', totalCap:184339245, active:180200498, dead:0),
    'CHI': NbaTeamCapLedgerEntry(team:'CHI', totalCap:163000867, active:163110161, dead:1075459),
    'CLE': NbaTeamCapLedgerEntry(team:'CLE', totalCap:273135134, active:208875884, dead:2244109),
    'DAL': NbaTeamCapLedgerEntry(team:'DAL', totalCap:212186952, active:175329617, dead:10871533),
    'DEN': NbaTeamCapLedgerEntry(team:'DEN', totalCap:242092779, active:221488348, dead:666667),
    'DET': NbaTeamCapLedgerEntry(team:'DET', totalCap:183436388, active:155695299, dead:0),
    'GSW': NbaTeamCapLedgerEntry(team:'GSW', totalCap:254337411, active:224265316, dead:0),
    'HOU': NbaTeamCapLedgerEntry(team:'HOU', totalCap:212396723, active:204141985, dead:0, retained:861974),
    'IND': NbaTeamCapLedgerEntry(team:'IND', totalCap:210934471, active:208971708, dead:0),
    'LAC': NbaTeamCapLedgerEntry(team:'LAC', totalCap:207895992, active:190567959, dead:0),
    'LAL': NbaTeamCapLedgerEntry(team:'LAL', totalCap:200897322, active:205594516, dead:0),
    'MEM': NbaTeamCapLedgerEntry(team:'MEM', totalCap:161792655, active:139968934, dead:21909021),
    'MIA': NbaTeamCapLedgerEntry(team:'MIA', totalCap:226225834, active:209452452, dead:0),
    'MIL': NbaTeamCapLedgerEntry(team:'MIL', totalCap:197382274, active:167941145, dead:21977720),
    'MIN': NbaTeamCapLedgerEntry(team:'MIN', totalCap:253034934, active:215378406, dead:2055000),
    'NOP': NbaTeamCapLedgerEntry(team:'NOP', totalCap:219591402, active:194146216, dead:148828),
    'NYK': NbaTeamCapLedgerEntry(team:'NYK', totalCap:226484114, active:221266448, dead:0),
    'OKC': NbaTeamCapLedgerEntry(team:'OKC', totalCap:216464608, active:216316138, dead:0),
    'ORL': NbaTeamCapLedgerEntry(team:'ORL', totalCap:222499858, active:214782125, dead:8000000),
    'PHI': NbaTeamCapLedgerEntry(team:'PHI', totalCap:218904967, active:209313722, dead:0),
    'PHO': NbaTeamCapLedgerEntry(team:'PHO', totalCap:242376222, active:193751775, dead:23197051),
    'POR': NbaTeamCapLedgerEntry(team:'POR', totalCap:205996284, active:192503523, dead:268032),
    'SAC': NbaTeamCapLedgerEntry(team:'SAC', totalCap:218796337, active:196379283, dead:3333333),
    'SAS': NbaTeamCapLedgerEntry(team:'SAS', totalCap:231173962, active:200153591, dead:0),
    'TOR': NbaTeamCapLedgerEntry(team:'TOR', totalCap:209710899, active:200126550, dead:0),
    'UTA': NbaTeamCapLedgerEntry(team:'UTA', totalCap:190585796, active:181873444, dead:0),
    'WAS': NbaTeamCapLedgerEntry(team:'WAS', totalCap:243265055, active:193370868, dead:0),
  };

  static Map<String, double> get totalCap => {
        for (final entry in ledger.entries) entry.key: entry.value.totalCap,
      };

  /// Hard-cap status shown in the supplied Spotrac 2026-27 team summary.
  /// `first` and `second` identify the apron ceiling; omitted teams were shown
  /// without a hard-cap designation in that reference.
  static const Map<String, String> hardCap = {
    'ATL': 'first', 'BOS': 'first', 'CHA': 'first', 'CHI': 'first',
    'CLE': 'first', 'DAL': 'first', 'DET': 'first', 'GSW': 'second',
    'HOU': 'second', 'IND': 'first', 'LAC': 'first', 'LAL': 'first',
    'MEM': 'first', 'MIA': 'first', 'MIN': 'second', 'NOP': 'first',
    'PHI': 'first', 'PHO': 'second', 'POR': 'first', 'SAC': 'first',
    'SAS': 'first', 'UTA': 'first', 'WAS': 'first',
  };

  static double teamSalary(String team, double fallback) =>
      ledger[team]?.totalCap ?? fallback;

  static NbaTeamCapLedgerEntry? forTeam(String team) => ledger[team];

  static double? hardCapAt(String team, double firstApron, double secondApron) {
    return switch (hardCap[team]) {
      'first' => firstApron,
      'second' => secondApron,
      _ => null,
    };
  }
}
