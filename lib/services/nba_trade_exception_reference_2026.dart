class NbaTradeExceptionRecord {
  const NbaTradeExceptionRecord({
    required this.id,
    required this.team,
    required this.expires,
    required this.sourceTransaction,
    required this.original,
    required this.available,
    this.note,
    this.unusableAboveSecondApron = false,
  });
  final String id;
  final String team;
  final String expires;
  final String sourceTransaction;
  final double original;
  final double available;
  final String? note;
  final bool unusableAboveSecondApron;
  bool get exhausted => available <= 0;
}

class NbaMleRules202627 {
  const NbaMleRules202627._();
  static const double room = 9366000;
  static const double nonTaxpayer = 15044000;
  static const double taxpayer = 6064000;
  static const double biAnnual = 5477000;

  static const String roomRule =
      'Below the cap; unavailable if BAE, non-taxpayer MLE, or taxpayer MLE was already used.';
  static const String nonTaxpayerRule =
      'Above the cap but transaction must remain below the first apron; unavailable after room or taxpayer MLE use.';
  static const String taxpayerRule =
      'Available only below the second apron; unavailable after BAE, cap-room/room exception, room MLE, or non-taxpayer MLE use.';
}

class NbaTradeExceptionReference202627 {
  const NbaTradeExceptionReference202627._();

  static const Map<String, Map<String, double>> signingExceptions = {
    'ATL': {'non_tax_mle': 944000, 'bae': 5477000},
    'BOS': {'non_tax_mle': 0, 'bae': 5477000},
    'BRK': {'room_mle': 9369000},
    'CHA': {'non_tax_mle': 847026},
    'CHI': {'room_mle': 9369000},
    'CLE': {'tax_mle': 6064000},
    'DAL': {'non_tax_mle': 12044000, 'bae': 278017},
    'DEN': {'tax_mle': 6064000},
    'DET': {'non_tax_mle': 3720994},
    'GSW': {'non_tax_mle': 15044000, 'bae': 5477000},
    'HOU': {'non_tax_mle': 8980000, 'bae': 5477000},
    'IND': {'non_tax_mle': 6994000, 'bae': 5477000},
    'LAC': {'non_tax_mle': 1044000, 'bae': 5477000},
    'LAL': {'room_mle': 0},
    'MEM': {'non_tax_mle': 4694000, 'bae': 5477000},
    'MIA': {'non_tax_mle': 3379000, 'bae': 5477000},
    'MIL': {'non_tax_mle': 15044000, 'bae': 5477000},
    'MIN': {'tax_mle': 6064000},
    'NOP': {'non_tax_mle': 7239122, 'bae': 5477000},
    'NYK': {'tax_mle': 6064000},
    'OKC': {'tax_mle': 6064000},
    'ORL': {'tax_mle': 6064000},
    'PHI': {'non_tax_mle': 44000, 'bae': 2077000},
    'PHO': {'tax_mle': 0},
    'POR': {'non_tax_mle': 15044000, 'bae': 5477000},
    'SAC': {'non_tax_mle': 15044000, 'bae': 0},
    'SAS': {'non_tax_mle': 0, 'bae': 5477000},
    'TOR': {'non_tax_mle': 15044000, 'bae': 5477000},
    'UTA': {'non_tax_mle': 3044000},
    'WAS': {'non_tax_mle': 15044000},
  };

  static const List<NbaTradeExceptionRecord> tpes = [
    NbaTradeExceptionRecord(id:'CHA-ball-2027',team:'CHA',expires:'2027-07-10',sourceTransaction:'LaMelo Ball trade with MIN',original:40770520,available:40770520),
    NbaTradeExceptionRecord(id:'MEM-jackson-2027',team:'MEM',expires:'2027-02-03',sourceTransaction:'Jaren Jackson Jr. trade with UTA',original:28872920,available:28872920),
    NbaTradeExceptionRecord(id:'BOS-simons-2027',team:'BOS',expires:'2027-02-05',sourceTransaction:'Anfernee Simons trade with CHI',original:27678571,available:27678571),
    NbaTradeExceptionRecord(id:'MIL-giannis-2027',team:'MIL',expires:'2027-07-06',sourceTransaction:'Giannis Antetokounmpo trade with MIA',original:25456566,available:25456566),
    NbaTradeExceptionRecord(id:'OKC-dort-2027',team:'OKC',expires:'2027-07-19',sourceTransaction:'Lu Dort trade with ATL',original:17722222,available:17722222),
    NbaTradeExceptionRecord(id:'CLE-strus-2027',team:'CLE',expires:'2027-08-20',sourceTransaction:'Max Strus trade with LAC',original:16660836,available:16660836),
    NbaTradeExceptionRecord(id:'UTA-kessler-2027',team:'UTA',expires:'2027-07-08',sourceTransaction:'Walker Kessler trade with LAL',original:15054411,available:15054411),
    NbaTradeExceptionRecord(id:'DET-stewart-2027',team:'DET',expires:'2027-07-08',sourceTransaction:'Isaiah Stewart trade with MEM',original:15000000,available:15000000),
    NbaTradeExceptionRecord(id:'HOU-finney-smith-2027',team:'HOU',expires:'2027-07-06',sourceTransaction:'Dorian Finney-Smith trade with ATL',original:13335000,available:13335000),
    NbaTradeExceptionRecord(id:'OKC-joe-2027',team:'OKC',expires:'2027-07-06',sourceTransaction:'Isaiah Joe trade with DET',original:11323006,available:11323006),
    NbaTradeExceptionRecord(id:'MIN-conley-2027',team:'MIN',expires:'2027-02-03',sourceTransaction:'Mike Conley trade with CHI',original:10774038,available:10774038),
    NbaTradeExceptionRecord(id:'DEN-watson-2027',team:'DEN',expires:'2027-08-20',sourceTransaction:'Peyton Watson trade with CLE',original:10232558,available:10232558,note:'Unusable if Denver is over the second apron.',unusableAboveSecondApron:true),
    NbaTradeExceptionRecord(id:'CLE-ball-2027',team:'CLE',expires:'2027-02-05',sourceTransaction:'Lonzo Ball trade with UTA',original:10000000,available:10000000),
    NbaTradeExceptionRecord(id:'OKC-wiggins-2027',team:'OKC',expires:'2027-07-06',sourceTransaction:'Aaron Wiggins trade with ATL',original:9028038,available:9028038),
    NbaTradeExceptionRecord(id:'CHA-sexton-2027',team:'CHA',expires:'2027-02-04',sourceTransaction:'Collin Sexton trade with CHI',original:8200962,available:8200962),
    NbaTradeExceptionRecord(id:'NOP-hawkins-2027',team:'NOP',expires:'2027-09-08',sourceTransaction:'Jordan Hawkins trade with MEM',original:7021895,available:7021895),
    NbaTradeExceptionRecord(id:'DAL-davis-2027',team:'DAL',expires:'2027-02-05',sourceTransaction:'Anthony Davis trade with WAS',original:20830154,available:7004114,note:'Partially used by Zaccharie Risacher ($13,826,040).'),
    NbaTradeExceptionRecord(id:'CHA-jones-2027',team:'CHA',expires:'2027-02-05',sourceTransaction:'Tyus Jones trade with DAL',original:7000000,available:7000000),
    NbaTradeExceptionRecord(id:'ORL-jones-2027',team:'ORL',expires:'2027-02-04',sourceTransaction:'Tyus Jones trade with DAL',original:7000000,available:7000000),
    NbaTradeExceptionRecord(id:'MIN-dillingham-2027',team:'MIN',expires:'2027-02-05',sourceTransaction:'Rob Dillingham trade with CHI',original:6576120,available:6576120),
    NbaTradeExceptionRecord(id:'TOR-agbaji-2027',team:'TOR',expires:'2027-02-05',sourceTransaction:'Ochai Agbaji trade with BKN',original:6383525,available:6383525),
    NbaTradeExceptionRecord(id:'WAS-hardy-2027',team:'WAS',expires:'2027-07-07',sourceTransaction:'Jaden Hardy trade with LAL',original:6000000,available:6000000),
    NbaTradeExceptionRecord(id:'WAS-russell-2027',team:'WAS',expires:'2027-07-08',sourceTransaction:"D'Angelo Russell trade with MEM",original:5969250,available:5969250),
    NbaTradeExceptionRecord(id:'SAC-saric-2027',team:'SAC',expires:'2027-02-01',sourceTransaction:'Dario Saric trade with CHI',original:5426400,available:5426400),
    NbaTradeExceptionRecord(id:'DET-sasser-2027',team:'DET',expires:'2027-07-08',sourceTransaction:'Marcus Sasser trade with DAL',original:5198983,available:5198983),
    NbaTradeExceptionRecord(id:'PHO-richards-2027',team:'PHO',expires:'2027-02-05',sourceTransaction:'Nick Richards trade with CHI',original:5000000,available:5000000),
    NbaTradeExceptionRecord(id:'SAC-carter-2027',team:'SAC',expires:'2027-06-30',sourceTransaction:'Devin Carter trade with ATL',original:4923720,available:4923720),
    NbaTradeExceptionRecord(id:'ATL-bufkin-2026',team:'ATL',expires:'2026-09-16',sourceTransaction:'Kobe Bufkin trade with BKN',original:4503720,available:4503720),
    NbaTradeExceptionRecord(id:'NOP-alvarado-2027',team:'NOP',expires:'2027-02-05',sourceTransaction:'Jose Alvarado trade with NYK',original:4500000,available:4500000),
    NbaTradeExceptionRecord(id:'PHI-mccain-2027',team:'PHI',expires:'2027-02-04',sourceTransaction:'Jared McCain trade with OKC',original:4221360,available:4221360),
    NbaTradeExceptionRecord(id:'BOS-brown-2027',team:'BOS',expires:'2027-07-06',sourceTransaction:'Jaylen Brown trade with PHI',original:2952348,available:2952348),
    NbaTradeExceptionRecord(id:'DAL-hardy-2027',team:'DAL',expires:'2027-02-05',sourceTransaction:'Jaden Hardy trade with WAS',original:6000000,available:2909520,note:'Partially used by AJ Johnson ($3,090,480).'),
    NbaTradeExceptionRecord(id:'LAC-brown-2027',team:'LAC',expires:'2027-02-05',sourceTransaction:'Kobe Brown trade with IND',original:2654880,available:2654880),
    NbaTradeExceptionRecord(id:'BOS-tillman-2027',team:'BOS',expires:'2027-02-05',sourceTransaction:'Xavier Tillman Sr. trade with CHA',original:2546675,available:2546675),
    NbaTradeExceptionRecord(id:'OKC-dieng-2027',team:'OKC',expires:'2027-02-04',sourceTransaction:'Ousmane Dieng trade with CHA',original:2449522,available:2449522),
    NbaTradeExceptionRecord(id:'BOS-minott-2027',team:'BOS',expires:'2027-02-05',sourceTransaction:'Josh Minott trade with BKN',original:2378870,available:2378870),
    NbaTradeExceptionRecord(id:'ATL-krejci-2027',team:'ATL',expires:'2027-02-01',sourceTransaction:'Vit Krejci trade with POR',original:2349578,available:2349578),
    NbaTradeExceptionRecord(id:'LAC-paul-2027',team:'LAC',expires:'2027-02-05',sourceTransaction:'Chris Paul trade with TOR',original:2296274,available:2296274),
    NbaTradeExceptionRecord(id:'BOS-boucher-2027',team:'BOS',expires:'2027-02-05',sourceTransaction:'Chris Boucher trade with UTA',original:2296274,available:2296274),
    NbaTradeExceptionRecord(id:'PHI-gordon-2027',team:'PHI',expires:'2027-02-05',sourceTransaction:'Eric Gordon trade with MEM',original:2296274,available:2296274),
    NbaTradeExceptionRecord(id:'UTA-landale-2027',team:'UTA',expires:'2027-02-05',sourceTransaction:'Jock Landale trade with MEM',original:2296274,available:2296274),
    NbaTradeExceptionRecord(id:'CHA-plumlee-2027',team:'CHA',expires:'2027-02-04',sourceTransaction:'Mason Plumlee trade with OKC',original:2296274,available:2296274),
    NbaTradeExceptionRecord(id:'DEN-tyson-2027',team:'DEN',expires:'2027-02-05',sourceTransaction:'Hunter Tyson trade with BKN',original:2221677,available:2221677),
    NbaTradeExceptionRecord(id:'GSW-tjd-2027',team:'GSW',expires:'2027-02-05',sourceTransaction:'Trayce Jackson-Davis trade with TOR',original:2221677,available:2221677),
    NbaTradeExceptionRecord(id:'MEM-morant-2027',team:'MEM',expires:'2027-06-29',sourceTransaction:'Ja Morant trade with POR',original:4314089,available:2163172,note:'Partially used by Micah Peavy ($2,150,917).'),
    NbaTradeExceptionRecord(id:'DAL-nembhard-2027',team:'DAL',expires:'2027-07-19',sourceTransaction:'Ryan Nembhard trade with ATL',original:2150917,available:2150917),
    NbaTradeExceptionRecord(id:'PHO-hayes-davis-2027',team:'PHO',expires:'2027-02-05',sourceTransaction:'Nigel Hayes-Davis trade with MIL',original:2048494,available:2048494),
    NbaTradeExceptionRecord(id:'ATL-kennard-2027',team:'ATL',expires:'2027-02-05',sourceTransaction:'Luke Kennard trade with LAL',original:11000000,available:1971962,note:'Partially used by Aaron Wiggins ($9,028,038).'),
    NbaTradeExceptionRecord(id:'CLE-hunter-2027',team:'CLE',expires:'2027-02-01',sourceTransaction:"De'Andre Hunter trade with SAC",original:6897984,available:1439674,note:'Partially used by Cam Whitmore ($5,458,310).'),
    NbaTradeExceptionRecord(id:'ATL-young-2027',team:'ATL',expires:'2027-01-08',sourceTransaction:'Trae Young trade with WAS',original:1357994,available:1357993),
    NbaTradeExceptionRecord(id:'LAC-zubac-2027',team:'LAC',expires:'2027-02-05',sourceTransaction:'Ivica Zubac trade with IND',original:1314427,available:1314427),
    NbaTradeExceptionRecord(id:'IND-jones-2027',team:'IND',expires:'2027-06-24',sourceTransaction:'Kam Jones trade with CHI',original:1075459,available:1075459),
    NbaTradeExceptionRecord(id:'NYK-terry-2027',team:'NYK',expires:'2027-02-05',sourceTransaction:'Dalen Terry trade with NOP',original:899118,available:899118),
    NbaTradeExceptionRecord(id:'LAC-collins-2027',team:'LAC',expires:'2027-07-08',sourceTransaction:'John Collins trade with DET',original:17000000,available:339164,note:'Partially used by Max Strus ($16,660,836).'),
    NbaTradeExceptionRecord(id:'CLE-garland-2027',team:'CLE',expires:'2027-02-04',sourceTransaction:'Darius Garland trade with LAC',original:263397,available:263397),
    NbaTradeExceptionRecord(id:'NYK-yabusele-2027',team:'NYK',expires:'2027-02-05',sourceTransaction:'Guerschon Yabusele trade with CHI',original:100882,available:100882),
    NbaTradeExceptionRecord(id:'MIL-portis-2027',team:'MIL',expires:'2027-07-06',sourceTransaction:'Bobby Portis trade with MIA',original:85763,available:85763),
    NbaTradeExceptionRecord(id:'DAL-exum-2027',team:'DAL',expires:'2027-02-05',sourceTransaction:'Dante Exum trade with WAS',original:2296274,available:0,note:'Fully used.'),
  ];

  static List<NbaTradeExceptionRecord> forTeam(String team, {String? asOfIso}) {
    final rows = tpes.where((item) => item.team == team && !item.exhausted).where((item) {
      if (asOfIso == null || asOfIso.isEmpty) return true;
      final asOf = DateTime.tryParse(asOfIso);
      final expiry = DateTime.tryParse(item.expires);
      return asOf == null || expiry == null || !expiry.isBefore(asOf);
    }).toList()..sort((a,b) => b.available.compareTo(a.available));
    return rows;
  }

  static double? largestTpeFor(String team, {String? asOfIso}) {
    final rows = forTeam(team, asOfIso: asOfIso);
    return rows.isEmpty ? null : rows.first.available;
  }

  static Map<String, double> get largestTpe => {
    for (final team in signingExceptions.keys)
      if (largestTpeFor(team) case final amount?) team: amount,
  };
}
