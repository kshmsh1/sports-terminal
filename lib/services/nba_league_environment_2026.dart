class NbaLeagueEnvironment202627 {
  const NbaLeagueEnvironment202627._();

  static const double salaryCap = 164961000;
  static const double luxuryTax = 200428000;
  static const double firstApron = 209015000;
  static const double secondApron = 221686000;
  static const double minimumTeamSalary = 148465000;
  static const double nonTaxpayerMle = 15044000;
  static const double taxpayerMle = 6064000;
  static const double roomMle = 9366000;
  static const double biAnnual = 5477000;
  static const double maxSalary0To6 = 41240250;
  static const double maxSalary7To9 = 49488300;
  static const double maxSalary10Plus = 57736350;
  static const double twoWaySalary = 678882;
  static const double earlyBirdMaximum = 15235500;
  static const double estimatedAverageSalary = 15163000;
  static const double tradeCashLimit = 8495000;
  static const double exhibit10BonusMaximum = 91000;
  static const double expandedTpeAmount = 9096000;
}

class NbaCashTradeAvailability {
  const NbaCashTradeAvailability({
    required this.team,
    required this.availableToSend,
    required this.availableToReceive,
    this.sendRestrictedAboveSecondApron = false,
  });

  final String team;
  final double availableToSend;
  final double availableToReceive;
  final bool sendRestrictedAboveSecondApron;
}

class NbaCashTradeReference202627 {
  const NbaCashTradeReference202627._();

  static const double limit = 8495000;
  static const Map<String, NbaCashTradeAvailability> teams = {
    'ATL': NbaCashTradeAvailability(team:'ATL', availableToSend:8495000, availableToReceive:8495000),
    'BOS': NbaCashTradeAvailability(team:'BOS', availableToSend:8495000, availableToReceive:8495000),
    'BKN': NbaCashTradeAvailability(team:'BKN', availableToSend:8495000, availableToReceive:8495000),
    'CHA': NbaCashTradeAvailability(team:'CHA', availableToSend:8385000, availableToReceive:4145000),
    'CHI': NbaCashTradeAvailability(team:'CHI', availableToSend:8495000, availableToReceive:8495000),
    'CLE': NbaCashTradeAvailability(team:'CLE', availableToSend:1145000, availableToReceive:8495000),
    'DAL': NbaCashTradeAvailability(team:'DAL', availableToSend:8495000, availableToReceive:8495000),
    'DEN': NbaCashTradeAvailability(team:'DEN', availableToSend:8495000, availableToReceive:8495000, sendRestrictedAboveSecondApron:true),
    'DET': NbaCashTradeAvailability(team:'DET', availableToSend:8495000, availableToReceive:8495000),
    'GSW': NbaCashTradeAvailability(team:'GSW', availableToSend:8495000, availableToReceive:8495000),
    'HOU': NbaCashTradeAvailability(team:'HOU', availableToSend:8495000, availableToReceive:8385000),
    'IND': NbaCashTradeAvailability(team:'IND', availableToSend:8495000, availableToReceive:8495000),
    'LAC': NbaCashTradeAvailability(team:'LAC', availableToSend:6395000, availableToReceive:8495000),
    'LAL': NbaCashTradeAvailability(team:'LAL', availableToSend:8495000, availableToReceive:8495000),
    'MEM': NbaCashTradeAvailability(team:'MEM', availableToSend:8495000, availableToReceive:8495000),
    'MIA': NbaCashTradeAvailability(team:'MIA', availableToSend:8495000, availableToReceive:8495000),
    'MIL': NbaCashTradeAvailability(team:'MIL', availableToSend:8495000, availableToReceive:7395000),
    'MIN': NbaCashTradeAvailability(team:'MIN', availableToSend:4495000, availableToReceive:8495000),
    'NOP': NbaCashTradeAvailability(team:'NOP', availableToSend:8495000, availableToReceive:8495000),
    'NYK': NbaCashTradeAvailability(team:'NYK', availableToSend:8495000, availableToReceive:8495000),
    'OKC': NbaCashTradeAvailability(team:'OKC', availableToSend:8495000, availableToReceive:8495000),
    'ORL': NbaCashTradeAvailability(team:'ORL', availableToSend:8495000, availableToReceive:8495000),
    'PHI': NbaCashTradeAvailability(team:'PHI', availableToSend:8495000, availableToReceive:7495000),
    'PHO': NbaCashTradeAvailability(team:'PHO', availableToSend:8495000, availableToReceive:8495000),
    'POR': NbaCashTradeAvailability(team:'POR', availableToSend:8495000, availableToReceive:8495000),
    'SAC': NbaCashTradeAvailability(team:'SAC', availableToSend:8495000, availableToReceive:8495000),
    'SAS': NbaCashTradeAvailability(team:'SAS', availableToSend:8495000, availableToReceive:8495000),
    'TOR': NbaCashTradeAvailability(team:'TOR', availableToSend:8495000, availableToReceive:8495000),
    'UTA': NbaCashTradeAvailability(team:'UTA', availableToSend:8495000, availableToReceive:4495000),
    'WAS': NbaCashTradeAvailability(team:'WAS', availableToSend:8495000, availableToReceive:5495000),
  };
}
