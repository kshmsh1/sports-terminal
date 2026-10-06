import 'nba_league_environment_2026.dart';

class NbaTeamFinancialSnapshot {
  const NbaTeamFinancialSnapshot({
    required this.team,
    required this.standardRoster,
    required this.twoWayRoster,
    required this.capSpace,
    required this.taxSpace,
    required this.firstApronSpace,
    required this.secondApronSpace,
    required this.hardCap,
    required this.availableExceptions,
    this.largestTpe,
    this.largestTpeExpires,
  });

  final String team;
  final int standardRoster;
  final int twoWayRoster;
  final double capSpace;
  final double taxSpace;
  final double firstApronSpace;
  final double secondApronSpace;
  final String? hardCap;
  final Map<String, double> availableExceptions;
  final double? largestTpe;
  final String? largestTpeExpires;

  double get capAllocation =>
      NbaLeagueEnvironment202627.salaryCap - capSpace;
  double get taxAllocation =>
      NbaLeagueEnvironment202627.luxuryTax - taxSpace;
  double get firstApronAllocation =>
      NbaLeagueEnvironment202627.firstApron - firstApronSpace;
  double get secondApronAllocation =>
      NbaLeagueEnvironment202627.secondApron - secondApronSpace;

  /// Best transaction-ledger starting point from the supplied summary.
  ///
  /// Cap-room teams use cap allocation. Over-cap teams use the apron allocation
  /// because apron legality is measured against the apron ledger rather than a
  /// cash-payroll subtotal.
  double get transactionSalary =>
      capSpace > 0 ? capAllocation : firstApronAllocation;

  String get hardCapLabel => switch (hardCap) {
        'first' => '1st Apron',
        'second' => '2nd Apron',
        _ => 'None',
      };

  String get exceptionSummary {
    if (availableExceptions.isEmpty) return 'None';
    const labels = {
      'room_mle': 'Room MLE',
      'non_tax_mle': 'Non-Tax MLE',
      'tax_mle': 'Tax MLE',
      'bae': 'Bi-Annual',
    };
    return availableExceptions.entries
        .map((entry) =>
            '${labels[entry.key] ?? entry.key}: ${_money(entry.value)}')
        .join(' · ');
  }
}

/// 2026-27 team financial state transcribed from the first two user-supplied
/// NBA Team Summary screenshots on 2026-10-05. These rows are the Trade
/// Machine source of truth for cap/tax/apron room, hard-cap status, currently
/// available signing exceptions and each team's largest TPE.
class NbaTeamFinancialReference202627 {
  const NbaTeamFinancialReference202627._();

  static const Map<String, NbaTeamFinancialSnapshot> teams = {
    'ATL': NbaTeamFinancialSnapshot(team:'ATL', standardRoster:18, twoWayRoster:3, capSpace:-65091891, taxSpace:1758488, firstApronSpace:9149226, secondApronSpace:21820226, hardCap:'first', availableExceptions:{'non_tax_mle':944000,'bae':5477000}, largestTpe:2349578, largestTpeExpires:'2027-02-01'),
    'BOS': NbaTeamFinancialSnapshot(team:'BOS', standardRoster:19, twoWayRoster:2, capSpace:-43030480, taxSpace:1705594, firstApronSpace:10292594, secondApronSpace:22963594, hardCap:'first', availableExceptions:{'bae':5477000}, largestTpe:27678571, largestTpeExpires:'2027-02-05'),
    'BRK': NbaTeamFinancialSnapshot(team:'BRK', standardRoster:17, twoWayRoster:3, capSpace:1731602, taxSpace:40371642, firstApronSpace:48958642, secondApronSpace:61629642, hardCap:null, availableExceptions:{'room_mle':9369000}),
    'CHA': NbaTeamFinancialSnapshot(team:'CHA', standardRoster:18, twoWayRoster:3, capSpace:-12036392, taxSpace:25581525, firstApronSpace:33668525, secondApronSpace:46339525, hardCap:'first', availableExceptions:{'non_tax_mle':847026}, largestTpe:40770520, largestTpeExpires:'2027-07-10'),
    'CHI': NbaTeamFinancialSnapshot(team:'CHI', standardRoster:19, twoWayRoster:2, capSpace:-809083, taxSpace:34657917, firstApronSpace:40929800, secondApronSpace:53600800, hardCap:'first', availableExceptions:{'room_mle':9369000}),
    'CLE': NbaTeamFinancialSnapshot(team:'CLE', standardRoster:18, twoWayRoster:3, capSpace:-61154902, taxSpace:-8541955, firstApronSpace:45045, secondApronSpace:12716045, hardCap:'first', availableExceptions:{'tax_mle':6064000}, largestTpe:16660836, largestTpeExpires:'2027-08-20'),
    'DAL': NbaTeamFinancialSnapshot(team:'DAL', standardRoster:17, twoWayRoster:3, capSpace:-42075373, taxSpace:9648179, firstApronSpace:16890594, secondApronSpace:29561594, hardCap:'first', availableExceptions:{'non_tax_mle':12044000,'bae':278017}, largestTpe:7004114, largestTpeExpires:'2027-02-05'),
    'DEN': NbaTeamFinancialSnapshot(team:'DEN', standardRoster:18, twoWayRoster:3, capSpace:-70047821, taxSpace:-18790837, firstApronSpace:-15821337, secondApronSpace:-3150337, hardCap:null, availableExceptions:{'tax_mle':6064000}, largestTpe:10232558, largestTpeExpires:'2027-08-20'),
    'DET': NbaTeamFinancialSnapshot(team:'DET', standardRoster:17, twoWayRoster:3, capSpace:-39186599, taxSpace:5929822, firstApronSpace:14516822, secondApronSpace:27187822, hardCap:'first', availableExceptions:{'non_tax_mle':3720994}, largestTpe:15000000, largestTpeExpires:'2027-07-08'),
    'GSW': NbaTeamFinancialSnapshot(team:'GSW', standardRoster:18, twoWayRoster:3, capSpace:-89376411, taxSpace:-20410432, firstApronSpace:-12323432, secondApronSpace:347568, hardCap:'second', availableExceptions:{'non_tax_mle':15044000,'bae':5477000}, largestTpe:2221677, largestTpeExpires:'2027-02-05'),
    'HOU': NbaTeamFinancialSnapshot(team:'HOU', standardRoster:16, twoWayRoster:2, capSpace:-47435723, taxSpace:14077, firstApronSpace:8601077, secondApronSpace:21272077, hardCap:'second', availableExceptions:{'non_tax_mle':8980000,'bae':5477000}, largestTpe:13335000, largestTpeExpires:'2027-07-06'),
    'IND': NbaTeamFinancialSnapshot(team:'IND', standardRoster:18, twoWayRoster:3, capSpace:-43524050, taxSpace:-5871934, firstApronSpace:2235066, secondApronSpace:14906066, hardCap:'first', availableExceptions:{'non_tax_mle':6994000,'bae':5477000}, largestTpe:1075459, largestTpeExpires:'2027-06-24'),
    'LAC': NbaTeamFinancialSnapshot(team:'LAC', standardRoster:19, twoWayRoster:2, capSpace:-39766503, taxSpace:14805003, firstApronSpace:23392003, secondApronSpace:36063003, hardCap:'first', availableExceptions:{'non_tax_mle':1044000,'bae':5477000}, largestTpe:3168489, largestTpeExpires:'2027-09-14'),
    'LAL': NbaTeamFinancialSnapshot(team:'LAL', standardRoster:18, twoWayRoster:3, capSpace:-35936322, taxSpace:-469322, firstApronSpace:8117678, secondApronSpace:20788678, hardCap:'first', availableExceptions:{}),
    'MEM': NbaTeamFinancialSnapshot(team:'MEM', standardRoster:17, twoWayRoster:3, capSpace:3168345, taxSpace:38375172, firstApronSpace:44612172, secondApronSpace:57283172, hardCap:'first', availableExceptions:{'non_tax_mle':4694000,'bae':5477000}, largestTpe:28872920, largestTpeExpires:'2027-02-03'),
    'MIA': NbaTeamFinancialSnapshot(team:'MIA', standardRoster:18, twoWayRoster:3, capSpace:-55932370, taxSpace:-5761256, firstApronSpace:2825744, secondApronSpace:15496744, hardCap:'first', availableExceptions:{'non_tax_mle':3379000,'bae':5477000}),
    'MIL': NbaTeamFinancialSnapshot(team:'MIL', standardRoster:19, twoWayRoster:2, capSpace:-29971853, taxSpace:10129684, firstApronSpace:13941684, secondApronSpace:26612684, hardCap:'first', availableExceptions:{'non_tax_mle':15044000,'bae':5477000}, largestTpe:25456566, largestTpeExpires:'2027-07-06'),
    'MIN': NbaTeamFinancialSnapshot(team:'MIN', standardRoster:18, twoWayRoster:3, capSpace:-87677472, taxSpace:-14502954, firstApronSpace:-7665954, secondApronSpace:5005046, hardCap:'second', availableExceptions:{'tax_mle':6064000}, largestTpe:10774038, largestTpeExpires:'2027-02-03'),
    'NOP': NbaTeamFinancialSnapshot(team:'NOP', standardRoster:18, twoWayRoster:3, capSpace:-47241566, taxSpace:4058123, firstApronSpace:6226322, secondApronSpace:18897322, hardCap:'first', availableExceptions:{'non_tax_mle':7544000,'bae':5477000}, largestTpe:7021895, largestTpeExpires:'2027-09-08'),
    'NYK': NbaTeamFinancialSnapshot(team:'NYK', standardRoster:18, twoWayRoster:3, capSpace:-59073693, taxSpace:-17984232, firstApronSpace:-9397232, secondApronSpace:3273768, hardCap:null, availableExceptions:{'tax_mle':6064000}, largestTpe:899118, largestTpeExpires:'2027-02-05'),
    'OKC': NbaTeamFinancialSnapshot(team:'OKC', standardRoster:18, twoWayRoster:3, capSpace:-51503608, taxSpace:-13851492, firstApronSpace:-5764492, secondApronSpace:6906508, hardCap:null, availableExceptions:{'tax_mle':6064000}, largestTpe:17722222, largestTpeExpires:'2027-07-19'),
    'ORL': NbaTeamFinancialSnapshot(team:'ORL', standardRoster:17, twoWayRoster:3, capSpace:-57538858, taxSpace:-17437321, firstApronSpace:-10174751, secondApronSpace:2496249, hardCap:null, availableExceptions:{'tax_mle':6064000}, largestTpe:7000000, largestTpeExpires:'2027-02-04'),
    'PHI': NbaTeamFinancialSnapshot(team:'PHI', standardRoster:19, twoWayRoster:2, capSpace:-53943967, taxSpace:-6758472, firstApronSpace:1828528, secondApronSpace:14499528, hardCap:'first', availableExceptions:{'non_tax_mle':44000,'bae':2077000}, largestTpe:4221360, largestTpeExpires:'2027-02-04'),
    'PHO': NbaTeamFinancialSnapshot(team:'PHO', standardRoster:18, twoWayRoster:3, capSpace:-77415222, taxSpace:-15797506, firstApronSpace:-7210506, secondApronSpace:5460494, hardCap:'second', availableExceptions:{}, largestTpe:5000000, largestTpeExpires:'2027-02-05'),
    'POR': NbaTeamFinancialSnapshot(team:'POR', standardRoster:15, twoWayRoster:3, capSpace:-38586663, taxSpace:8334527, firstApronSpace:16921527, secondApronSpace:29592527, hardCap:'first', availableExceptions:{'non_tax_mle':15044000,'bae':5477000}),
    'SAC': NbaTeamFinancialSnapshot(team:'SAC', standardRoster:19, twoWayRoster:2, capSpace:-51385916, taxSpace:3147842, firstApronSpace:7884842, secondApronSpace:20555842, hardCap:'first', availableExceptions:{'non_tax_mle':15044000,'bae':5477000}, largestTpe:5426400, largestTpeExpires:'2027-02-01'),
    'SAS': NbaTeamFinancialSnapshot(team:'SAS', standardRoster:18, twoWayRoster:3, capSpace:-66212962, taxSpace:2148033, firstApronSpace:8035033, secondApronSpace:20706033, hardCap:'first', availableExceptions:{'bae':5477000}),
    'TOR': NbaTeamFinancialSnapshot(team:'TOR', standardRoster:18, twoWayRoster:3, capSpace:-49276151, taxSpace:-1025193, firstApronSpace:963598, secondApronSpace:13634598, hardCap:null, availableExceptions:{'non_tax_mle':15044000,'bae':5477000}, largestTpe:6383525, largestTpeExpires:'2027-02-05'),
    'UTA': NbaTeamFinancialSnapshot(team:'UTA', standardRoster:17, twoWayRoster:3, capSpace:-23439680, taxSpace:19912320, firstApronSpace:28499320, secondApronSpace:41170320, hardCap:'first', availableExceptions:{'non_tax_mle':3044000}, largestTpe:15054411, largestTpeExpires:'2027-07-08'),
    'WAS': NbaTeamFinancialSnapshot(team:'WAS', standardRoster:19, twoWayRoster:2, capSpace:-75854634, taxSpace:8414896, firstApronSpace:17001896, secondApronSpace:29672896, hardCap:'first', availableExceptions:{'non_tax_mle':15044000}, largestTpe:6000000, largestTpeExpires:'2027-07-07'),
  };

  static NbaTeamFinancialSnapshot? forTeam(String team) =>
      teams[team == 'BKN' ? 'BRK' : team];
}

String _money(double value) {
  if (value.abs() >= 1000000) {
    return '\${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value.abs() >= 1000) {
    return '\${(value / 1000).toStringAsFixed(0)}K';
  }
  return '\${value.toStringAsFixed(0)}';
}
