class NbaTradeExceptionRecord {
  const NbaTradeExceptionRecord({
    required this.id,
    required this.team,
    required this.expireDateIso,
    required this.sourceTransaction,
    required this.originalAmount,
    required this.availableAmount,
    this.note,
  });

  final String id;
  final String team;
  final String expireDateIso;
  final String sourceTransaction;
  final double originalAmount;
  final double availableAmount;
  final String? note;
}

class NbaTradeExceptionLedger202627 {
  const NbaTradeExceptionLedger202627._();

  /// Complete ledger transcribed from the user-supplied 2026-09-11 TPE tracker
  /// screenshots. Amounts distinguish original exception size from current
  /// available balance when partially used.
  static const List<NbaTradeExceptionRecord> records = [
    NbaTradeExceptionRecord(id:'CHA-lamelo-ball-2027-07-10', team:'CHA', expireDateIso:'2027-07-10', sourceTransaction:'LaMelo Ball trade with MIN', originalAmount:40770520, availableAmount:40770520),
    NbaTradeExceptionRecord(id:'MEM-jaren-jackson-2027-02-03', team:'MEM', expireDateIso:'2027-02-03', sourceTransaction:'Jaren Jackson Jr. trade with UTA', originalAmount:28872920, availableAmount:28872920),
    NbaTradeExceptionRecord(id:'BOS-anfernee-simons-2027-02-05', team:'BOS', expireDateIso:'2027-02-05', sourceTransaction:'Anfernee Simons trade with CHI', originalAmount:27678571, availableAmount:27678571),
    NbaTradeExceptionRecord(id:'MIL-giannis-2027-07-06', team:'MIL', expireDateIso:'2027-07-06', sourceTransaction:'Giannis Antetokounmpo trade with MIA', originalAmount:25456566, availableAmount:25456566),
    NbaTradeExceptionRecord(id:'OKC-lu-dort-2027-07-19', team:'OKC', expireDateIso:'2027-07-19', sourceTransaction:'Lu Dort trade with ATL', originalAmount:17722222, availableAmount:17722222),
    NbaTradeExceptionRecord(id:'CLE-max-strus-2027-08-20', team:'CLE', expireDateIso:'2027-08-20', sourceTransaction:'Max Strus trade with LAC', originalAmount:16660836, availableAmount:16660836),
    NbaTradeExceptionRecord(id:'UTA-walker-kessler-2027-07-08', team:'UTA', expireDateIso:'2027-07-08', sourceTransaction:'Walker Kessler trade with LAL', originalAmount:15054411, availableAmount:15054411),
    NbaTradeExceptionRecord(id:'DET-isaiah-stewart-2027-07-08', team:'DET', expireDateIso:'2027-07-08', sourceTransaction:'Isaiah Stewart trade with MEM', originalAmount:15000000, availableAmount:15000000),
    NbaTradeExceptionRecord(id:'HOU-dorian-finney-smith-2027-07-06', team:'HOU', expireDateIso:'2027-07-06', sourceTransaction:'Dorian Finney-Smith trade with ATL', originalAmount:13335000, availableAmount:13335000),
    NbaTradeExceptionRecord(id:'OKC-isaiah-joe-2027-07-06', team:'OKC', expireDateIso:'2027-07-06', sourceTransaction:'Isaiah Joe trade with DET', originalAmount:11323006, availableAmount:11323006),
    NbaTradeExceptionRecord(id:'MIN-mike-conley-2027-02-03', team:'MIN', expireDateIso:'2027-02-03', sourceTransaction:'Mike Conley trade with CHI', originalAmount:10774038, availableAmount:10774038),
    NbaTradeExceptionRecord(id:'DEN-peyton-watson-2027-08-20', team:'DEN', expireDateIso:'2027-08-20', sourceTransaction:'Peyton Watson trade with CLE', originalAmount:10232558, availableAmount:10232558, note:'Unusable if team is over second apron'),
    NbaTradeExceptionRecord(id:'CLE-lonzo-ball-2027-02-05', team:'CLE', expireDateIso:'2027-02-05', sourceTransaction:'Lonzo Ball trade with UTA', originalAmount:10000000, availableAmount:10000000),
    NbaTradeExceptionRecord(id:'OKC-aaron-wiggins-2027-07-06', team:'OKC', expireDateIso:'2027-07-06', sourceTransaction:'Aaron Wiggins trade with ATL', originalAmount:9028038, availableAmount:9028038),
    NbaTradeExceptionRecord(id:'CHA-collin-sexton-2027-02-04', team:'CHA', expireDateIso:'2027-02-04', sourceTransaction:'Collin Sexton trade with CHI', originalAmount:8200962, availableAmount:8200962),
    NbaTradeExceptionRecord(id:'NOP-jordan-hawkins-2027-09-08', team:'NOP', expireDateIso:'2027-09-08', sourceTransaction:'Jordan Hawkins trade with MEM', originalAmount:7021895, availableAmount:7021895),
    NbaTradeExceptionRecord(id:'DAL-anthony-davis-2027-02-05', team:'DAL', expireDateIso:'2027-02-05', sourceTransaction:'Anthony Davis trade with WAS', originalAmount:20830154, availableAmount:7004114, note:'Partially used on Zaccharie Risacher ($13,826,040)'),
    NbaTradeExceptionRecord(id:'CHA-tyus-jones-2027-02-05', team:'CHA', expireDateIso:'2027-02-05', sourceTransaction:'Tyus Jones trade with DAL', originalAmount:7000000, availableAmount:7000000),
    NbaTradeExceptionRecord(id:'ORL-tyus-jones-2027-02-04', team:'ORL', expireDateIso:'2027-02-04', sourceTransaction:'Tyus Jones trade with DAL', originalAmount:7000000, availableAmount:7000000),
    NbaTradeExceptionRecord(id:'MIN-rob-dillingham-2027-02-05', team:'MIN', expireDateIso:'2027-02-05', sourceTransaction:'Rob Dillingham trade with CHI', originalAmount:6576120, availableAmount:6576120),
    NbaTradeExceptionRecord(id:'TOR-ochai-agbaji-2027-02-05', team:'TOR', expireDateIso:'2027-02-05', sourceTransaction:'Ochai Agbaji trade with BKN', originalAmount:6383525, availableAmount:6383525),
    NbaTradeExceptionRecord(id:'WAS-jaden-hardy-2027-07-07', team:'WAS', expireDateIso:'2027-07-07', sourceTransaction:'Jaden Hardy trade with LAL', originalAmount:6000000, availableAmount:6000000),
    NbaTradeExceptionRecord(id:'WAS-dangelo-russell-2027-07-08', team:'WAS', expireDateIso:'2027-07-08', sourceTransaction:'D’Angelo Russell trade with MEM', originalAmount:5969250, availableAmount:5969250),
    NbaTradeExceptionRecord(id:'SAC-dario-saric-2027-02-01', team:'SAC', expireDateIso:'2027-02-01', sourceTransaction:'Dario Saric trade with CHI', originalAmount:5426400, availableAmount:5426400),
    NbaTradeExceptionRecord(id:'DET-marcus-sasser-2027-07-08', team:'DET', expireDateIso:'2027-07-08', sourceTransaction:'Marcus Sasser trade with DAL', originalAmount:5198983, availableAmount:5198983),
    NbaTradeExceptionRecord(id:'PHO-nick-richards-2027-02-05', team:'PHO', expireDateIso:'2027-02-05', sourceTransaction:'Nick Richards trade with CHI', originalAmount:5000000, availableAmount:5000000),
    NbaTradeExceptionRecord(id:'SAC-devin-carter-2027-06-30', team:'SAC', expireDateIso:'2027-06-30', sourceTransaction:'Devin Carter trade with ATL', originalAmount:4923720, availableAmount:4923720),
    NbaTradeExceptionRecord(id:'ATL-kobe-bufkin-2026-09-16', team:'ATL', expireDateIso:'2026-09-16', sourceTransaction:'Kobe Bufkin trade with BKN', originalAmount:4503720, availableAmount:4503720),
    NbaTradeExceptionRecord(id:'NOP-jose-alvarado-2027-02-05', team:'NOP', expireDateIso:'2027-02-05', sourceTransaction:'Jose Alvarado trade with NYK', originalAmount:4500000, availableAmount:4500000),
    NbaTradeExceptionRecord(id:'PHI-jared-mccain-2027-02-04', team:'PHI', expireDateIso:'2027-02-04', sourceTransaction:'Jared McCain trade with OKC', originalAmount:4221360, availableAmount:4221360),
    NbaTradeExceptionRecord(id:'BOS-jaylen-brown-2027-07-06', team:'BOS', expireDateIso:'2027-07-06', sourceTransaction:'Jaylen Brown trade with PHI', originalAmount:2952348, availableAmount:2952348),
    NbaTradeExceptionRecord(id:'DAL-jaden-hardy-2027-02-05', team:'DAL', expireDateIso:'2027-02-05', sourceTransaction:'Jaden Hardy trade with WAS', originalAmount:6000000, availableAmount:2909520, note:'Partially used on AJ Johnson ($3,090,480)'),
    NbaTradeExceptionRecord(id:'LAC-kobe-brown-2027-02-05', team:'LAC', expireDateIso:'2027-02-05', sourceTransaction:'Kobe Brown trade with IND', originalAmount:2654880, availableAmount:2654880),
    NbaTradeExceptionRecord(id:'BOS-xavier-tillman-2027-02-05', team:'BOS', expireDateIso:'2027-02-05', sourceTransaction:'Xavier Tillman Sr trade with CHA', originalAmount:2546675, availableAmount:2546675),
    NbaTradeExceptionRecord(id:'OKC-ousmane-dieng-2027-02-04', team:'OKC', expireDateIso:'2027-02-04', sourceTransaction:'Ousmane Dieng trade with CHA', originalAmount:2449522, availableAmount:2449522),
    NbaTradeExceptionRecord(id:'BOS-josh-minott-2027-02-05', team:'BOS', expireDateIso:'2027-02-05', sourceTransaction:'Josh Minott trade with BKN', originalAmount:2378870, availableAmount:2378870),
    NbaTradeExceptionRecord(id:'ATL-vit-krejci-2027-02-01', team:'ATL', expireDateIso:'2027-02-01', sourceTransaction:'Vit Krejci trade with POR', originalAmount:2349578, availableAmount:2349578),
    NbaTradeExceptionRecord(id:'LAC-chris-paul-2027-02-05', team:'LAC', expireDateIso:'2027-02-05', sourceTransaction:'Chris Paul trade with TOR', originalAmount:2296274, availableAmount:2296274),
    NbaTradeExceptionRecord(id:'BOS-chris-boucher-2027-02-05', team:'BOS', expireDateIso:'2027-02-05', sourceTransaction:'Chris Boucher trade with UTA', originalAmount:2296274, availableAmount:2296274),
    NbaTradeExceptionRecord(id:'PHI-eric-gordon-2027-02-05', team:'PHI', expireDateIso:'2027-02-05', sourceTransaction:'Eric Gordon trade with MEM', originalAmount:2296274, availableAmount:2296274),
    NbaTradeExceptionRecord(id:'UTA-jock-landale-2027-02-05', team:'UTA', expireDateIso:'2027-02-05', sourceTransaction:'Jock Landale trade with MEM', originalAmount:2296274, availableAmount:2296274),
    NbaTradeExceptionRecord(id:'CHA-mason-plumlee-2027-02-04', team:'CHA', expireDateIso:'2027-02-04', sourceTransaction:'Mason Plumlee trade with OKC', originalAmount:2296274, availableAmount:2296274),
    NbaTradeExceptionRecord(id:'DEN-hunter-tyson-2027-02-05', team:'DEN', expireDateIso:'2027-02-05', sourceTransaction:'Hunter Tyson trade with BKN', originalAmount:2221677, availableAmount:2221677),
    NbaTradeExceptionRecord(id:'GSW-trayce-jackson-davis-2027-02-05', team:'GSW', expireDateIso:'2027-02-05', sourceTransaction:'Trayce Jackson-Davis trade with TOR', originalAmount:2221677, availableAmount:2221677),
    NbaTradeExceptionRecord(id:'MEM-ja-morant-2027-06-29', team:'MEM', expireDateIso:'2027-06-29', sourceTransaction:'Ja Morant trade with POR', originalAmount:4314089, availableAmount:2163172, note:'Partially used on Micah Peavy ($2,150,917)'),
    NbaTradeExceptionRecord(id:'DAL-ryan-nembhard-2027-07-19', team:'DAL', expireDateIso:'2027-07-19', sourceTransaction:'Ryan Nembhard trade with ATL', originalAmount:2150917, availableAmount:2150917),
    NbaTradeExceptionRecord(id:'PHO-nigel-hayes-davis-2027-02-05', team:'PHO', expireDateIso:'2027-02-05', sourceTransaction:'Nigel Hayes-Davis trade with MIL', originalAmount:2048494, availableAmount:2048494),
    NbaTradeExceptionRecord(id:'ATL-luke-kennard-2027-02-05', team:'ATL', expireDateIso:'2027-02-05', sourceTransaction:'Luke Kennard trade with LAL', originalAmount:11000000, availableAmount:1971962, note:'Partially used on Aaron Wiggins ($9,028,038)'),
    NbaTradeExceptionRecord(id:'CLE-deandre-hunter-2027-02-01', team:'CLE', expireDateIso:'2027-02-01', sourceTransaction:'De’Andre Hunter trade with SAC', originalAmount:6897984, availableAmount:1439674, note:'Partially used on Cam Whitmore ($5,458,310)'),
    NbaTradeExceptionRecord(id:'ATL-trae-young-2027-01-08', team:'ATL', expireDateIso:'2027-01-08', sourceTransaction:'Trae Young trade with WAS', originalAmount:1357994, availableAmount:1357993),
    NbaTradeExceptionRecord(id:'LAC-ivica-zubac-2027-02-05', team:'LAC', expireDateIso:'2027-02-05', sourceTransaction:'Ivica Zubac trade with IND', originalAmount:1314427, availableAmount:1314427),
    NbaTradeExceptionRecord(id:'IND-kam-jones-2027-06-24', team:'IND', expireDateIso:'2027-06-24', sourceTransaction:'Kam Jones trade with CHI', originalAmount:1075459, availableAmount:1075459),
    NbaTradeExceptionRecord(id:'NYK-dalen-terry-2027-02-05', team:'NYK', expireDateIso:'2027-02-05', sourceTransaction:'Dalen Terry trade with NOP', originalAmount:899118, availableAmount:899118),
    NbaTradeExceptionRecord(id:'LAC-john-collins-2027-07-08', team:'LAC', expireDateIso:'2027-07-08', sourceTransaction:'John Collins trade with DET', originalAmount:17000000, availableAmount:339164, note:'Partially used on Max Strus ($16,660,836)'),
    NbaTradeExceptionRecord(id:'CLE-darius-garland-2027-02-04', team:'CLE', expireDateIso:'2027-02-04', sourceTransaction:'Darius Garland trade with LAC', originalAmount:263397, availableAmount:263397),
    NbaTradeExceptionRecord(id:'NYK-guerschon-yabusele-2027-02-05', team:'NYK', expireDateIso:'2027-02-05', sourceTransaction:'Guerschon Yabusele trade with CHI', originalAmount:100882, availableAmount:100882),
    NbaTradeExceptionRecord(id:'MIL-bobby-portis-2027-07-06', team:'MIL', expireDateIso:'2027-07-06', sourceTransaction:'Bobby Portis trade with MIA', originalAmount:85763, availableAmount:85763),
    NbaTradeExceptionRecord(id:'DAL-dante-exum-2027-02-05', team:'DAL', expireDateIso:'2027-02-05', sourceTransaction:'Dante Exum trade with WAS', originalAmount:2296274, availableAmount:0),
  ];

  static List<NbaTradeExceptionRecord> forTeam(String team) =>
      records.where((item) => item.team == team).toList()
        ..sort((a, b) => b.availableAmount.compareTo(a.availableAmount));
}
