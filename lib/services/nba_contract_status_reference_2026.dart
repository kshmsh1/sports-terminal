enum NbaGuaranteeStatus { fullyGuaranteed, partiallyGuaranteed, nonGuaranteed, exhibit10 }

class NbaGuaranteeTrigger {
  const NbaGuaranteeTrigger({
    required this.player,
    required this.team,
    required this.triggerDate,
    required this.fromGuaranteed,
    required this.toGuaranteed,
    required this.resolved,
    this.note = '',
  });

  final String player;
  final String team;
  final String triggerDate;
  final double fromGuaranteed;
  final double toGuaranteed;
  final bool resolved;
  final String note;
}

class NbaTradeEligibilityRestriction {
  const NbaTradeEligibilityRestriction({
    required this.player,
    required this.team,
    required this.eligibleDate,
    this.hasTradeVeto = false,
  });

  final String player;
  final String team;
  final String eligibleDate;
  final bool hasTradeVeto;
}

class NbaContractStatusReference202627 {
  const NbaContractStatusReference202627._();

  static const List<NbaGuaranteeTrigger> guaranteeTriggers = [
    NbaGuaranteeTrigger(player:'Buddy Hield', team:'ATL', triggerDate:'2026-06-28', fromGuaranteed:3000000, toGuaranteed:9658536, resolved:true),
    NbaGuaranteeTrigger(player:'Jonathan Isaac', team:'ORL', triggerDate:'2026-06-28', fromGuaranteed:8000000, toGuaranteed:14500000, resolved:false),
    NbaGuaranteeTrigger(player:'Dru Smith', team:'MIA', triggerDate:'2026-06-28', fromGuaranteed:0, toGuaranteed:2584539, resolved:true),
    NbaGuaranteeTrigger(player:'Bronny James', team:'LAL', triggerDate:'2026-06-29', fromGuaranteed:1258873, toGuaranteed:2296271, resolved:true),
    NbaGuaranteeTrigger(player:'Jamison Battle', team:'TOR', triggerDate:'2026-06-30', fromGuaranteed:0, toGuaranteed:2296271, resolved:true),
    NbaGuaranteeTrigger(player:'Kris Dunn', team:'LAC', triggerDate:'2026-06-30', fromGuaranteed:0, toGuaranteed:5684800, resolved:true),
    NbaGuaranteeTrigger(player:'Kyle Filipowski', team:'UTA', triggerDate:'2026-06-30', fromGuaranteed:0, toGuaranteed:3000000, resolved:true),
    NbaGuaranteeTrigger(player:'Kam Jones', team:'CHI', triggerDate:'2026-06-30', fromGuaranteed:1075459, toGuaranteed:2150917, resolved:false),
    NbaGuaranteeTrigger(player:'Leonard Miller', team:'CHI', triggerDate:'2026-06-30', fromGuaranteed:0, toGuaranteed:2406205, resolved:true),
    NbaGuaranteeTrigger(player:'Ajay Mitchell', team:'OKC', triggerDate:'2026-06-30', fromGuaranteed:1500000, toGuaranteed:2850000, resolved:true),
    NbaGuaranteeTrigger(player:'Svi Mykhailiuk', team:'UTA', triggerDate:'2026-06-30', fromGuaranteed:0, toGuaranteed:3850000, resolved:true),
    NbaGuaranteeTrigger(player:'Scotty Pippen Jr.', team:'MEM', triggerDate:'2026-07-03', fromGuaranteed:350000, toGuaranteed:2461462, resolved:true),
    NbaGuaranteeTrigger(player:'Pete Nance', team:'MIL', triggerDate:'2026-07-04', fromGuaranteed:0, toGuaranteed:2497812, resolved:false),
    NbaGuaranteeTrigger(player:'Adem Bona', team:'PHI', triggerDate:'2026-07-07', fromGuaranteed:0, toGuaranteed:2296271, resolved:true),
    NbaGuaranteeTrigger(player:'Kristaps Porzingis', team:'GSW', triggerDate:'2026-07-07', fromGuaranteed:3000000, toGuaranteed:20000000, resolved:true),
    NbaGuaranteeTrigger(player:'Jonas Valanciunas', team:'DEN', triggerDate:'2026-07-08', fromGuaranteed:2000000, toGuaranteed:10000000, resolved:false),
    NbaGuaranteeTrigger(player:'Mo Bamba', team:'UTA', triggerDate:'2026-07-15', fromGuaranteed:0, toGuaranteed:250000, resolved:true),
    NbaGuaranteeTrigger(player:'Sidy Cissoko', team:'POR', triggerDate:'2026-07-15', fromGuaranteed:0, toGuaranteed:2497812, resolved:true),
    NbaGuaranteeTrigger(player:'Quenton Jackson', team:'IND', triggerDate:'2026-07-15', fromGuaranteed:250000, toGuaranteed:2584539, resolved:true),
    NbaGuaranteeTrigger(player:'Jordan Walsh', team:'BOS', triggerDate:'2026-07-20', fromGuaranteed:0, toGuaranteed:2406205, resolved:true),
    NbaGuaranteeTrigger(player:'Vit Krejci', team:'POR', triggerDate:'2026-08-01', fromGuaranteed:0, toGuaranteed:250000, resolved:true),
    NbaGuaranteeTrigger(player:'Bradley Beal', team:'LAC', triggerDate:'2026-08-18', fromGuaranteed:3212400, toGuaranteed:6424800, resolved:true),
    NbaGuaranteeTrigger(player:'Moussa Cisse', team:'DAL', triggerDate:'2026-09-01', fromGuaranteed:0, toGuaranteed:1092558, resolved:true),
    NbaGuaranteeTrigger(player:'Moussa Cisse', team:'DAL', triggerDate:'2026-10-01', fromGuaranteed:1092558, toGuaranteed:2185116, resolved:false),
    NbaGuaranteeTrigger(player:'Cam Christie', team:'LAC', triggerDate:'2026-10-15', fromGuaranteed:0, toGuaranteed:2296271, resolved:false),
  ];

  static const List<NbaTradeEligibilityRestriction> january15 = [
    NbaTradeEligibilityRestriction(player:'Coby White', team:'CHA', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Spencer Jones', team:'DEN', eligibleDate:'2027-01-15', hasTradeVeto:true),
    NbaTradeEligibilityRestriction(player:'Tari Eason', team:'HOU', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Jordan Miller', team:'LAC', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Austin Reaves', team:'LAL', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Gary Trent Jr.', team:'MIL', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Jaylen Clark', team:'MIN', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Ayo Dosunmu', team:'MIN', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Landry Shamet', team:'NYK', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Collin Gillespie', team:'PHO', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Jordan Goodwin', team:'PHO', eligibleDate:'2027-01-15'),
    NbaTradeEligibilityRestriction(player:'Mark Williams', team:'PHO', eligibleDate:'2027-01-15'),
  ];

  static const Map<String, double> partiallyGuaranteed = {
    'Moussa Cisse':1092558,
    'Duncan Robinson':2000000,
    'Georges Niang':1838009,
    'Charles Bassey':1400000,
    'Jae’Sean Tate':1039669,
    'Jaylen Wells':300000,
    'Myron Gardner':500000,
    'Trey Lyles':1500000,
    'Trendon Watford':250000,
    'Jabari Walker':250000,
    'Vit Krejci':250000,
    'Mo Bamba':200000,
  };
}
