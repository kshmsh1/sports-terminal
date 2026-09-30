class NbaTradeMachineTeam {
  const NbaTradeMachineTeam({
    required this.id,
    required this.name,
    required this.city,
    required this.conference,
  });

  final String id;
  final String name;
  final String city;
  final String conference;

  String get displayName => '$city $name';
}

class NbaTradeMachineContractDisplay {
  const NbaTradeMachineContractDisplay({
    required this.player,
    required this.summary,
  });

  final String player;
  final String summary;
}

class NbaTradeMachineTimingRestriction {
  const NbaTradeMachineTimingRestriction({
    required this.player,
    required this.team,
    required this.eligibleDate,
  });

  final String player;
  final String team;
  final String eligibleDate;
}

class NbaTradeMachineReacquisitionRestriction {
  const NbaTradeMachineReacquisitionRestriction({
    required this.player,
    required this.currentTeam,
    required this.blockedTeam,
    required this.eligibleDate,
  });

  final String player;
  final String currentTeam;
  final String blockedTeam;
  final String eligibleDate;
}

class NbaTradeMachineFreeAgentRight {
  const NbaTradeMachineFreeAgentRight({
    required this.id,
    required this.team,
    required this.player,
    required this.capHold,
    required this.rights,
    required this.minimumFirstYearSalary,
    required this.maximumFirstYearSalary,
    required this.defaultFirstYearSalary,
    this.supportsSignAndTrade = true,
  });

  final String id;
  final String team;
  final String player;
  final double capHold;
  final String rights;
  final double minimumFirstYearSalary;
  final double maximumFirstYearSalary;
  final double defaultFirstYearSalary;
  final bool supportsSignAndTrade;
}

class NbaTradeMachineReference202627 {
  const NbaTradeMachineReference202627._();

  static const List<NbaTradeMachineTeam> teams = [
    NbaTradeMachineTeam(id:'ATL', city:'Atlanta', name:'Hawks', conference:'East'),
    NbaTradeMachineTeam(id:'BOS', city:'Boston', name:'Celtics', conference:'East'),
    NbaTradeMachineTeam(id:'BRK', city:'Brooklyn', name:'Nets', conference:'East'),
    NbaTradeMachineTeam(id:'CHO', city:'Charlotte', name:'Hornets', conference:'East'),
    NbaTradeMachineTeam(id:'CHI', city:'Chicago', name:'Bulls', conference:'East'),
    NbaTradeMachineTeam(id:'CLE', city:'Cleveland', name:'Cavaliers', conference:'East'),
    NbaTradeMachineTeam(id:'DAL', city:'Dallas', name:'Mavericks', conference:'West'),
    NbaTradeMachineTeam(id:'DEN', city:'Denver', name:'Nuggets', conference:'West'),
    NbaTradeMachineTeam(id:'DET', city:'Detroit', name:'Pistons', conference:'East'),
    NbaTradeMachineTeam(id:'GSW', city:'Golden State', name:'Warriors', conference:'West'),
    NbaTradeMachineTeam(id:'HOU', city:'Houston', name:'Rockets', conference:'West'),
    NbaTradeMachineTeam(id:'IND', city:'Indiana', name:'Pacers', conference:'East'),
    NbaTradeMachineTeam(id:'LAC', city:'LA', name:'Clippers', conference:'West'),
    NbaTradeMachineTeam(id:'LAL', city:'Los Angeles', name:'Lakers', conference:'West'),
    NbaTradeMachineTeam(id:'MEM', city:'Memphis', name:'Grizzlies', conference:'West'),
    NbaTradeMachineTeam(id:'MIA', city:'Miami', name:'Heat', conference:'East'),
    NbaTradeMachineTeam(id:'MIL', city:'Milwaukee', name:'Bucks', conference:'East'),
    NbaTradeMachineTeam(id:'MIN', city:'Minnesota', name:'Timberwolves', conference:'West'),
    NbaTradeMachineTeam(id:'NOP', city:'New Orleans', name:'Pelicans', conference:'West'),
    NbaTradeMachineTeam(id:'NYK', city:'New York', name:'Knicks', conference:'East'),
    NbaTradeMachineTeam(id:'OKC', city:'Oklahoma City', name:'Thunder', conference:'West'),
    NbaTradeMachineTeam(id:'ORL', city:'Orlando', name:'Magic', conference:'East'),
    NbaTradeMachineTeam(id:'PHI', city:'Philadelphia', name:'76ers', conference:'East'),
    NbaTradeMachineTeam(id:'PHO', city:'Phoenix', name:'Suns', conference:'West'),
    NbaTradeMachineTeam(id:'POR', city:'Portland', name:'Trail Blazers', conference:'West'),
    NbaTradeMachineTeam(id:'SAC', city:'Sacramento', name:'Kings', conference:'West'),
    NbaTradeMachineTeam(id:'SAS', city:'San Antonio', name:'Spurs', conference:'West'),
    NbaTradeMachineTeam(id:'TOR', city:'Toronto', name:'Raptors', conference:'East'),
    NbaTradeMachineTeam(id:'UTA', city:'Utah', name:'Jazz', conference:'West'),
    NbaTradeMachineTeam(id:'WAS', city:'Washington', name:'Wizards', conference:'East'),
  ];

  static NbaTradeMachineTeam? team(String id) {
    for (final item in teams) {
      if (item.id == id) return item;
    }
    return null;
  }

  static String leagueKey(String id) => switch (id) {
        'BRK' => 'BKN',
        'CHO' => 'CHA',
        _ => id,
      };

  static String salaryKey(String id) => switch (id) {
        'CHO' => 'CHA',
        _ => id,
      };

  /// Contract-term labels visible in the user-supplied Spotrac screen recording.
  /// Players not listed here remain explicitly source-gated in the Trade Machine.
  static const Map<String, NbaTradeMachineContractDisplay> contractDisplay = {
    'Jayson Tatum': NbaTradeMachineContractDisplay(player:'Jayson Tatum', summary:'+3 years · PO'),
    'Paul George': NbaTradeMachineContractDisplay(player:'Paul George', summary:'+1 year · PO'),
    'Derrick White': NbaTradeMachineContractDisplay(player:'Derrick White', summary:'+2 years · PO'),
    'Mitchell Robinson': NbaTradeMachineContractDisplay(player:'Mitchell Robinson', summary:'+2 years · PO'),
    'Sam Hauser': NbaTradeMachineContractDisplay(player:'Sam Hauser', summary:'+2 years'),
    'Payton Pritchard': NbaTradeMachineContractDisplay(player:'Payton Pritchard', summary:'+1 year'),
    'Ron Harper Jr.': NbaTradeMachineContractDisplay(player:'Ron Harper Jr.', summary:'+3 years · TO'),
    'Chris Cenac Jr.': NbaTradeMachineContractDisplay(player:'Chris Cenac Jr.', summary:'+3 years · TO'),
    'Hugo González': NbaTradeMachineContractDisplay(player:'Hugo González', summary:'+2 years · TO'),
    'Luka Garza': NbaTradeMachineContractDisplay(player:'Luka Garza', summary:'Expiring'),
    'Joel Embiid': NbaTradeMachineContractDisplay(player:'Joel Embiid', summary:'+2 years · PO'),
    'Jaylen Brown': NbaTradeMachineContractDisplay(player:'Jaylen Brown', summary:'+3 years'),
    'Tyrese Maxey': NbaTradeMachineContractDisplay(player:'Tyrese Maxey', summary:'+2 years'),
    'VJ Edgecombe': NbaTradeMachineContractDisplay(player:'VJ Edgecombe', summary:'+2 years · TO'),
    'Dean Wade': NbaTradeMachineContractDisplay(player:'Dean Wade', summary:'+3 years'),
    'Anfernee Simons': NbaTradeMachineContractDisplay(player:'Anfernee Simons', summary:'+1 year · PO'),
    'LeBron James': NbaTradeMachineContractDisplay(player:'LeBron James', summary:'+1 year · PO'),
    'Labaron Philon Jr.': NbaTradeMachineContractDisplay(player:'Labaron Philon Jr.', summary:'+3 years · TO'),
    'Dominick Barlow': NbaTradeMachineContractDisplay(player:'Dominick Barlow', summary:'Expiring'),
    'Ariel Hukporti': NbaTradeMachineContractDisplay(player:'Ariel Hukporti', summary:'Expiring'),
  };

  /// Trade-timing labels visible in the supplied recording. The separate
  /// contract-status reference remains authoritative for its January 15 list.
  static const List<NbaTradeMachineTimingRestriction> timingRestrictions = [
    NbaTradeMachineTimingRestriction(player:'Mitchell Robinson', team:'BOS', eligibleDate:'2026-12-15'),
    NbaTradeMachineTimingRestriction(player:'Ron Harper Jr.', team:'BOS', eligibleDate:'2027-01-15'),
    NbaTradeMachineTimingRestriction(player:'Dean Wade', team:'PHI', eligibleDate:'2026-12-15'),
    NbaTradeMachineTimingRestriction(player:'Anfernee Simons', team:'PHI', eligibleDate:'2026-12-15'),
    NbaTradeMachineTimingRestriction(player:'LeBron James', team:'PHI', eligibleDate:'2026-12-15'),
    NbaTradeMachineTimingRestriction(player:'Ariel Hukporti', team:'PHI', eligibleDate:'2026-12-15'),
  ];

  static String? timingEligibleDate(String player, String team) {
    for (final item in timingRestrictions) {
      if (item.player == player && item.team == team) return item.eligibleDate;
    }
    return null;
  }

  /// Same-season reacquisition restrictions demonstrated in the recording.
  static const List<NbaTradeMachineReacquisitionRestriction> reacquisitionRestrictions = [
    NbaTradeMachineReacquisitionRestriction(
      player:'Paul George',
      currentTeam:'BOS',
      blockedTeam:'PHI',
      eligibleDate:'2027-07-01',
    ),
    NbaTradeMachineReacquisitionRestriction(
      player:'Jaylen Brown',
      currentTeam:'PHI',
      blockedTeam:'BOS',
      eligibleDate:'2027-07-01',
    ),
  ];

  static NbaTradeMachineReacquisitionRestriction? reacquisition(
    String player,
    String currentTeam,
    String destinationTeam,
  ) {
    for (final item in reacquisitionRestrictions) {
      if (item.player == player &&
          item.currentTeam == currentTeam &&
          item.blockedTeam == destinationTeam) {
        return item;
      }
    }
    return null;
  }

  /// Free-agent rights shown in the user-supplied Trade Machine recording.
  /// The model intentionally does not fabricate rights for teams not covered by
  /// the supplied source. Additional source-backed rights can be appended here.
  static const List<NbaTradeMachineFreeAgentRight> freeAgentRights = [
    NbaTradeMachineFreeAgentRight(
      id:'BOS-fa-marjon-beauchamp',
      team:'BOS',
      player:'MarJon Beauchamp',
      capHold:2449421,
      rights:'UFA · Non-Bird',
      minimumFirstYearSalary:2449421,
      maximumFirstYearSalary:2449421,
      defaultFirstYearSalary:2449421,
    ),
    NbaTradeMachineFreeAgentRight(
      id:'BOS-fa-kyle-lowry',
      team:'BOS',
      player:'Kyle Lowry',
      capHold:2449421,
      rights:'UFA · Early Bird',
      minimumFirstYearSalary:3876529,
      maximumFirstYearSalary:27678571,
      defaultFirstYearSalary:5500000,
    ),
    NbaTradeMachineFreeAgentRight(
      id:'BOS-fa-tyrese-martin',
      team:'BOS',
      player:'Tyrese Martin',
      capHold:2449421,
      rights:'UFA · Non-Bird',
      minimumFirstYearSalary:2449421,
      maximumFirstYearSalary:2449421,
      defaultFirstYearSalary:2449421,
    ),
    NbaTradeMachineFreeAgentRight(
      id:'BOS-fa-jeff-dowtin',
      team:'BOS',
      player:'Jeff Dowtin',
      capHold:2185116,
      rights:'UFA · Two-Way',
      minimumFirstYearSalary:2185116,
      maximumFirstYearSalary:2185116,
      defaultFirstYearSalary:2185116,
      supportsSignAndTrade:false,
    ),
    NbaTradeMachineFreeAgentRight(
      id:'BOS-fa-jalen-hood-schifino',
      team:'BOS',
      player:'Jalen Hood-Schifino',
      capHold:2185116,
      rights:'UFA · Two-Way',
      minimumFirstYearSalary:2185116,
      maximumFirstYearSalary:2185116,
      defaultFirstYearSalary:2185116,
      supportsSignAndTrade:false,
    ),
  ];

  static List<NbaTradeMachineFreeAgentRight> freeAgentsFor(String team) =>
      freeAgentRights.where((item) => item.team == team).toList();
}
