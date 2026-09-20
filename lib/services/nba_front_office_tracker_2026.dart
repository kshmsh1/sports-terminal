class NbaDisabledPlayerException {
  const NbaDisabledPlayerException({
    required this.team,
    required this.player,
    required this.injuredSalary,
    required this.amount,
    required this.available,
  });

  final String team;
  final String player;
  final double injuredSalary;
  final double amount;
  final double available;
}

class NbaHardCapTriggerRecord {
  const NbaHardCapTriggerRecord({
    required this.team,
    required this.capLevel,
    this.firstApronTriggers = const [],
    this.secondApronTriggers = const [],
  });

  final String team;
  final String capLevel;
  final List<String> firstApronTriggers;
  final List<String> secondApronTriggers;
}

class NbaLuxuryTaxRecord {
  const NbaLuxuryTaxRecord({
    required this.team,
    required this.estimatedTax,
    required this.taxedAmount,
    this.repeater = false,
  });

  final String team;
  final double estimatedTax;
  final double taxedAmount;
  final bool repeater;
}

class NbaFrontOfficeTracker202627 {
  const NbaFrontOfficeTracker202627._();

  /// User-supplied exception / hard-cap / tax trackers normalized 2026-09-20.
  static const Map<String, NbaDisabledPlayerException> dpe = {
    'DAL': NbaDisabledPlayerException(team:'DAL', player:'Dereck Lively II', injuredSalary:7239130, amount:3619565, available:3619565),
    'HOU': NbaDisabledPlayerException(team:'HOU', player:'Fred VanVleet', injuredSalary:25000000, amount:12500000, available:12500000),
    'IND': NbaDisabledPlayerException(team:'IND', player:'Tyrese Haliburton', injuredSalary:48924624, amount:15044000, available:15044000),
    'LAC': NbaDisabledPlayerException(team:'LAC', player:'Bradley Beal', injuredSalary:6424800, amount:3212400, available:3212400),
    'OKC': NbaDisabledPlayerException(team:'OKC', player:'Thomas Sorber', injuredSalary:4887720, amount:2443860, available:2443860),
  };

  static const Map<String, NbaHardCapTriggerRecord> hardCaps = {
    'ATL': NbaHardCapTriggerRecord(team:'ATL', capLevel:'first', firstApronTriggers:['TP-MLE: Jock Landale (Jul 10)','Trade salary acquired: Jul 19 trade','Past-season TPE: Jul 6 trade'], secondApronTriggers:['Cash traded: Jun 24 trade']),
    'BOS': NbaHardCapTriggerRecord(team:'BOS', capLevel:'first', firstApronTriggers:['TP-MLE: Mitchell Robinson (Jul 6)']),
    'CHA': NbaHardCapTriggerRecord(team:'CHA', capLevel:'first', firstApronTriggers:['TP-MLE: Jul 6 trade','TP-MLE length: Jul 6 trade','Trade salary acquired: Jul 10 trade','Trade salary acquired: Aug 20 trade'], secondApronTriggers:['Cash traded: Jul 6 trade']),
    'CLE': NbaHardCapTriggerRecord(team:'CLE', capLevel:'first', firstApronTriggers:['Trade salary acquired: Aug 20 trade']),
    'DAL': NbaHardCapTriggerRecord(team:'DAL', capLevel:'first', firstApronTriggers:['BAE: Jul 8 trade','Trade salary acquired: Jul 8 trade'], secondApronTriggers:['Cash traded: Jun 25 trade']),
    'DET': NbaHardCapTriggerRecord(team:'DET', capLevel:'first', firstApronTriggers:['MLE trade: Jul 6 trade','S&T: John Collins (Jul 7)','Trade salary acquired: Jul 8 trade'], secondApronTriggers:['Cash traded: Jun 25 trade']),
    'IND': NbaHardCapTriggerRecord(team:'IND', capLevel:'first', firstApronTriggers:['TP-MLE: Kelly Oubre Jr. (Jul 7)'], secondApronTriggers:['Cash traded: Jun 24 trade']),
    'LAC': NbaHardCapTriggerRecord(team:'LAC', capLevel:'first', firstApronTriggers:['TP-MLE: Rui Hachimura (Jul 6)'], secondApronTriggers:['Cash traded: Jun 24 trade','Cash traded: Jul 8 trade']),
    'LAL': NbaHardCapTriggerRecord(team:'LAL', capLevel:'first', firstApronTriggers:['S&T: Walker Kessler (Jul 7)'], secondApronTriggers:['Cash traded: Jun 24 trade','Cash traded: Jun 24 trade']),
    'MEM': NbaHardCapTriggerRecord(team:'MEM', capLevel:'first', firstApronTriggers:['TP-MLE: Quinten Post (Jul 8)','Trade salary acquired: Jul 8 trade'], secondApronTriggers:['Cash traded: Jun 29 trade']),
    'MIA': NbaHardCapTriggerRecord(team:'MIA', capLevel:'first', firstApronTriggers:['TP-MLE: Tim Hardaway Jr. (Jul 6)','Trade salary acquired: Jul 6 trade','Trade salary acquired: Jul 6 trade','Past-season TPE: Jul 6 trade'], secondApronTriggers:['Cash traded: Jun 24 trade']),
    'MIL': NbaHardCapTriggerRecord(team:'MIL', capLevel:'first', firstApronTriggers:['Trade salary acquired: Jul 8 trade'], secondApronTriggers:['Cash traded: Jun 24 trade']),
    'MIN': NbaHardCapTriggerRecord(team:'MIN', capLevel:'first', firstApronTriggers:['Trade salary acquired: Jul 10 trade'], secondApronTriggers:['Cash traded: Aug 29 trade']),
    'PHI': NbaHardCapTriggerRecord(team:'PHI', capLevel:'first', firstApronTriggers:['TP-MLE: Dean Wade (Jul 6)','TP-MLE length: Dean Wade (Jul 6)','BAE: Ariel Hukporti (Jul 6)','Trade salary acquired: Jul 6 trade']),
    'SAC': NbaHardCapTriggerRecord(team:'SAC', capLevel:'first', firstApronTriggers:['BAE: Precious Achiuwa (Jul 7)']),
    'SAS': NbaHardCapTriggerRecord(team:'SAS', capLevel:'first', firstApronTriggers:['TP-MLE: Tobias Harris (Jul 6)']),
    'UTA': NbaHardCapTriggerRecord(team:'UTA', capLevel:'first', firstApronTriggers:['Trade salary acquired: Aug 29 trade']),
    'WAS': NbaHardCapTriggerRecord(team:'WAS', capLevel:'first', firstApronTriggers:['S&T: Khris Middleton (Jul 7)','Trade salary acquired: Aug 20 trade','Past-season TPE: Jul 8 trade','Past-season TPE: Jul 8 trade']),
    'HOU': NbaHardCapTriggerRecord(team:'HOU', capLevel:'second', secondApronTriggers:['Any MLE: Marcus Smart (Jul 10)']),
    'PHO': NbaHardCapTriggerRecord(team:'PHO', capLevel:'second', secondApronTriggers:['Any MLE: Luke Kennard (Jul 14)','Trade aggregate: Jul 13 trade','Cash traded: Jun 24 trade']),
  };

  static const Map<String, NbaLuxuryTaxRecord> luxuryTax = {
    'ATL': NbaLuxuryTaxRecord(team:'ATL', estimatedTax:0, taxedAmount:0),
    'BOS': NbaLuxuryTaxRecord(team:'BOS', estimatedTax:16933407, taxedAmount:5644469, repeater:true),
    'BKN': NbaLuxuryTaxRecord(team:'BKN', estimatedTax:0, taxedAmount:0),
    'CHA': NbaLuxuryTaxRecord(team:'CHA', estimatedTax:0, taxedAmount:0),
    'CHI': NbaLuxuryTaxRecord(team:'CHI', estimatedTax:0, taxedAmount:0),
    'CLE': NbaLuxuryTaxRecord(team:'CLE', estimatedTax:10292070, taxedAmount:9446456),
    'DAL': NbaLuxuryTaxRecord(team:'DAL', estimatedTax:0, taxedAmount:0),
    'DEN': NbaLuxuryTaxRecord(team:'DEN', estimatedTax:132041366, taxedAmount:26994947, repeater:true),
    'DET': NbaLuxuryTaxRecord(team:'DET', estimatedTax:0, taxedAmount:0),
    'GSW': NbaLuxuryTaxRecord(team:'GSW', estimatedTax:137622075, taxedAmount:27764700, repeater:true),
    'HOU': NbaLuxuryTaxRecord(team:'HOU', estimatedTax:6864253, taxedAmount:6704202),
    'IND': NbaLuxuryTaxRecord(team:'IND', estimatedTax:12623245, taxedAmount:11311396),
    'LAC': NbaLuxuryTaxRecord(team:'LAC', estimatedTax:0, taxedAmount:0, repeater:true),
    'LAL': NbaLuxuryTaxRecord(team:'LAL', estimatedTax:27136179, taxedAmount:8816055, repeater:true),
    'MEM': NbaLuxuryTaxRecord(team:'MEM', estimatedTax:0, taxedAmount:0),
    'MIA': NbaLuxuryTaxRecord(team:'MIA', estimatedTax:10787696, taxedAmount:9842957),
    'MIL': NbaLuxuryTaxRecord(team:'MIL', estimatedTax:0, taxedAmount:0, repeater:true),
    'MIN': NbaLuxuryTaxRecord(team:'MIN', estimatedTax:21956343, taxedAmount:14502955),
    'NOP': NbaLuxuryTaxRecord(team:'NOP', estimatedTax:5865250, taxedAmount:5865250),
    'NYK': NbaLuxuryTaxRecord(team:'NYK', estimatedTax:95042519, taxedAmount:30231337),
    'OKC': NbaLuxuryTaxRecord(team:'OKC', estimatedTax:33962176, taxedAmount:17933193),
    'ORL': NbaLuxuryTaxRecord(team:'ORL', estimatedTax:61022127, taxedAmount:23698132),
    'PHI': NbaLuxuryTaxRecord(team:'PHI', estimatedTax:26253107, taxedAmount:15730602),
    'PHO': NbaLuxuryTaxRecord(team:'PHO', estimatedTax:96759339, taxedAmount:21970865, repeater:true),
    'POR': NbaLuxuryTaxRecord(team:'POR', estimatedTax:0, taxedAmount:0),
    'SAC': NbaLuxuryTaxRecord(team:'SAC', estimatedTax:4880793, taxedAmount:4880793),
    'SAS': NbaLuxuryTaxRecord(team:'SAS', estimatedTax:1394846, taxedAmount:1394846),
    'TOR': NbaLuxuryTaxRecord(team:'TOR', estimatedTax:6930743, taxedAmount:6757394),
    'UTA': NbaLuxuryTaxRecord(team:'UTA', estimatedTax:0, taxedAmount:0),
    'WAS': NbaLuxuryTaxRecord(team:'WAS', estimatedTax:0, taxedAmount:0),
  };
}
