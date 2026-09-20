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
    'ATL': NbaTeamSalaryPosition(team:'ATL', totalSalary:194904228, guaranteed:188245692),
    'DAL': NbaTeamSalaryPosition(team:'DAL', totalSalary:197866095, guaranteed:196773537),
    'SAS': NbaTeamSalaryPosition(team:'SAS', totalSalary:212239327, guaranteed:212239327),
    'SAC': NbaTeamSalaryPosition(team:'SAC', totalSalary:212079480, guaranteed:212079480),
    'MIN': NbaTeamSalaryPosition(team:'MIN', totalSalary:211347399, guaranteed:210397978),
    'ORL': NbaTeamSalaryPosition(team:'ORL', totalSalary:209865321, guaranteed:209865321),
    'TOR': NbaTeamSalaryPosition(team:'TOR', totalSalary:207962511, guaranteed:207962511),
    'DEN': NbaTeamSalaryPosition(team:'DEN', totalSalary:209867065, guaranteed:209867065),
    'LAL': NbaTeamSalaryPosition(team:'LAL', totalSalary:200897322, guaranteed:200897322),
    'HOU': NbaTeamSalaryPosition(team:'HOU', totalSalary:206539541, guaranteed:206539541),
    'IND': NbaTeamSalaryPosition(team:'IND', totalSalary:206299934, guaranteed:206299934),
    'BOS': NbaTeamSalaryPosition(team:'BOS', totalSalary:198722406, guaranteed:195978366),
    'UTA': NbaTeamSalaryPosition(team:'UTA', totalSalary:204407908, guaranteed:201151249),
    'PHO': NbaTeamSalaryPosition(team:'PHO', totalSalary:199450792, guaranteed:195386363),
    'GSW': NbaTeamSalaryPosition(team:'GSW', totalSalary:186848391, guaranteed:185798970),
    'MIA': NbaTeamSalaryPosition(team:'MIA', totalSalary:197215694, guaranteed:197215694),
    'CHI': NbaTeamSalaryPosition(team:'CHI', totalSalary:163543763, guaranteed:163543763),
    'CHA': NbaTeamSalaryPosition(team:'CHA', totalSalary:174444624, guaranteed:170628763),
    'NOP': NbaTeamSalaryPosition(team:'NOP', totalSalary:192207320, guaranteed:192207320),
    'MIL': NbaTeamSalaryPosition(team:'MIL', totalSalary:192159316, guaranteed:189621790),
    'POR': NbaTeamSalaryPosition(team:'POR', totalSalary:191824641, guaranteed:186908885),
    'MEM': NbaTeamSalaryPosition(team:'MEM', totalSalary:163549353, guaranteed:161553082),
    'WAS': NbaTeamSalaryPosition(team:'WAS', totalSalary:189471414, guaranteed:186803470),
    'BRK': NbaTeamSalaryPosition(team:'BRK', totalSalary:160324650, guaranteed:131518500),
    'CLE': NbaTeamSalaryPosition(team:'CLE', totalSalary:182342872, guaranteed:182342872),
    'LAC': NbaTeamSalaryPosition(team:'LAC', totalSalary:158420641, guaranteed:156124370),
    'DET': NbaTeamSalaryPosition(team:'DET', totalSalary:145177073, guaranteed:145177073),
  };

  static NbaTeamSalaryPosition? forTeam(String team) => positions[team];
}
