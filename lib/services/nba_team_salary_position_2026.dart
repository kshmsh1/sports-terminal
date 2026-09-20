class NbaTeamSalaryPosition {
  const NbaTeamSalaryPosition({
    required this.team,
    required this.totalSalary,
    required this.guaranteed,
  });

  final String team;
  final double totalSalary;
  final double guaranteed;

  double aboveBelowCap(double salaryCap) => totalSalary - salaryCap;
}

class NbaTeamSalaryPosition202627 {
  const NbaTeamSalaryPosition202627._();

  /// User-supplied current 2026-27 salary commitments, normalized 2026-09-20.
  /// These are kept separate from the detailed cap-ledger breakdown so the
  /// Trade Machine can distinguish current salary commitments from unresolved
  /// cap-accounting components.
  static const Map<String, NbaTeamSalaryPosition> positions = {
    'OKC': NbaTeamSalaryPosition(team:'OKC', totalSalary:235297492, guaranteed:235297492),
    'NYK': NbaTeamSalaryPosition(team:'NYK', totalSalary:218412232, guaranteed:218412232),
    'PHI': NbaTeamSalaryPosition(team:'PHI', totalSalary:216666747, guaranteed:214332208),
    'ATL': NbaTeamSalaryPosition(team:'ATL', totalSalary:216508308, guaranteed:209849772),
    'DAL': NbaTeamSalaryPosition(team:'DAL', totalSalary:214529039, guaranteed:213436481),
    'SAS': NbaTeamSalaryPosition(team:'SAS', totalSalary:212239327, guaranteed:212239327),
    'SAC': NbaTeamSalaryPosition(team:'SAC', totalSalary:212079480, guaranteed:212079480),
    'MIN': NbaTeamSalaryPosition(team:'MIN', totalSalary:211347399, guaranteed:210397978),
    'ORL': NbaTeamSalaryPosition(team:'ORL', totalSalary:209865321, guaranteed:209865321),
    'TOR': NbaTeamSalaryPosition(team:'TOR', totalSalary:207962511, guaranteed:207962511),
    'DEN': NbaTeamSalaryPosition(team:'DEN', totalSalary:207867065, guaranteed:207867065),
    'LAL': NbaTeamSalaryPosition(team:'LAL', totalSalary:207528042, guaranteed:207528042),
    'HOU': NbaTeamSalaryPosition(team:'HOU', totalSalary:206539541, guaranteed:206539541),
    'IND': NbaTeamSalaryPosition(team:'IND', totalSalary:206299934, guaranteed:206299934),
    'BOS': NbaTeamSalaryPosition(team:'BOS', totalSalary:204698646, guaranteed:201954606),
    'UTA': NbaTeamSalaryPosition(team:'UTA', totalSalary:204407908, guaranteed:201151249),
    'PHO': NbaTeamSalaryPosition(team:'PHO', totalSalary:199450792, guaranteed:195386363),
    'GSW': NbaTeamSalaryPosition(team:'GSW', totalSalary:199040871, guaranteed:197991450),
    'MIA': NbaTeamSalaryPosition(team:'MIA', totalSalary:197215694, guaranteed:197215694),
    'CHI': NbaTeamSalaryPosition(team:'CHI', totalSalary:193766704, guaranteed:193766704),
    'CHA': NbaTeamSalaryPosition(team:'CHA', totalSalary:193413984, guaranteed:189598123),
    'NOP': NbaTeamSalaryPosition(team:'NOP', totalSalary:192207320, guaranteed:192207320),
    'MIL': NbaTeamSalaryPosition(team:'MIL', totalSalary:192159316, guaranteed:189621790),
    'POR': NbaTeamSalaryPosition(team:'POR', totalSalary:191824641, guaranteed:186908885),
    'MEM': NbaTeamSalaryPosition(team:'MEM', totalSalary:190578343, guaranteed:188582072),
    'WAS': NbaTeamSalaryPosition(team:'WAS', totalSalary:189471414, guaranteed:186803470),
    'BRK': NbaTeamSalaryPosition(team:'BRK', totalSalary:183837690, guaranteed:155031540),
    'CLE': NbaTeamSalaryPosition(team:'CLE', totalSalary:181918200, guaranteed:181918200),
    'LAC': NbaTeamSalaryPosition(team:'LAC', totalSalary:177770161, guaranteed:175473890),
    'DET': NbaTeamSalaryPosition(team:'DET', totalSalary:154139633, guaranteed:154139633),
  };

  static NbaTeamSalaryPosition? forTeam(String team) => positions[team];
}
