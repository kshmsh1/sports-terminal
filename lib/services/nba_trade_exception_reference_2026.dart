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
      'Above the cap; first-year salary must leave the team below the first apron; unavailable after room or taxpayer MLE use.';
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

  static final List<NbaTradeExceptionRecord> tpes = _parseTpeSeed();

  static List<NbaTradeExceptionRecord> forTeam(
    String team, {
    String? asOfIso,
  }) {
    final asOf = asOfIso == null ? null : DateTime.tryParse(asOfIso);
    final rows = tpes.where((item) {
      if (item.team != team || item.exhausted) return false;
      if (asOf == null) return true;
      final expiry = DateTime.tryParse(item.expires);
      return expiry == null || !expiry.isBefore(asOf);
    }).toList()
      ..sort((a, b) => b.available.compareTo(a.available));
    return rows;
  }

  static double? largestTpeFor(String team, {String? asOfIso}) {
    final rows = forTeam(team, asOfIso: asOfIso);
    return rows.isEmpty ? null : rows.first.available;
  }

  static Map<String, double> get largestTpe {
    final result = <String, double>{};
    for (final team in _nbaTeams) {
      final amount = largestTpeFor(team);
      if (amount != null) result[team] = amount;
    }
    return result;
  }
}

const _nbaTeams = <String>[
  'ATL','BOS','BRK','CHA','CHI','CLE','DAL','DEN','DET','GSW','HOU','IND','LAC','LAL','MEM',
  'MIA','MIL','MIN','NOP','NYK','OKC','ORL','PHI','PHO','POR','SAC','SAS','TOR','UTA','WAS',
];

const _tpeSeed = r'''
CHA|ball|2027-07-10|LaMelo Ball trade with MIN|40770520|40770520||0
MEM|jackson|2027-02-03|Jaren Jackson Jr. trade with UTA|28872920|28872920||0
BOS|simons|2027-02-05|Anfernee Simons trade with CHI|27678571|27678571||0
MIL|giannis|2027-07-06|Giannis Antetokounmpo trade with MIA|25456566|25456566||0
OKC|dort|2027-07-19|Lu Dort trade with ATL|17722222|17722222||0
CLE|strus|2027-08-20|Max Strus trade with LAC|16660836|16660836||0
UTA|kessler|2027-07-08|Walker Kessler trade with LAL|15054411|15054411||0
DET|stewart|2027-07-08|Isaiah Stewart trade with MEM|15000000|15000000||0
HOU|finney-smith|2027-07-06|Dorian Finney-Smith trade with ATL|13335000|13335000||0
OKC|joe|2027-07-06|Isaiah Joe trade with DET|11323006|11323006||0
MIN|conley|2027-02-03|Mike Conley trade with CHI|10774038|10774038||0
DEN|watson|2027-08-20|Peyton Watson trade with CLE|10232558|10232558|Unusable if Denver is over the second apron.|1
CLE|lonzo|2027-02-05|Lonzo Ball trade with UTA|10000000|10000000||0
OKC|wiggins|2027-07-06|Aaron Wiggins trade with ATL|9028038|9028038||0
CHA|sexton|2027-02-04|Collin Sexton trade with CHI|8200962|8200962||0
NOP|hawkins|2027-09-08|Jordan Hawkins trade with MEM|7021895|7021895||0
DAL|davis|2027-02-05|Anthony Davis trade with WAS|20830154|7004114|Partially used by Zaccharie Risacher (13,826,040).|0
CHA|tyus-dal|2027-02-05|Tyus Jones trade with DAL|7000000|7000000||0
ORL|tyus-dal|2027-02-04|Tyus Jones trade with DAL|7000000|7000000||0
MIN|dillingham|2027-02-05|Rob Dillingham trade with CHI|6576120|6576120||0
TOR|agbaji|2027-02-05|Ochai Agbaji trade with BKN|6383525|6383525||0
WAS|hardy-lal|2027-07-07|Jaden Hardy trade with LAL|6000000|6000000||0
WAS|russell|2027-07-08|D'Angelo Russell trade with MEM|5969250|5969250||0
SAC|saric|2027-02-01|Dario Saric trade with CHI|5426400|5426400||0
DET|sasser|2027-07-08|Marcus Sasser trade with DAL|5198983|5198983||0
PHO|richards|2027-02-05|Nick Richards trade with CHI|5000000|5000000||0
SAC|carter|2027-06-30|Devin Carter trade with ATL|4923720|4923720||0
ATL|bufkin|2026-09-16|Kobe Bufkin trade with BKN|4503720|4503720||0
NOP|alvarado|2027-02-05|Jose Alvarado trade with NYK|4500000|4500000||0
PHI|mccain|2027-02-04|Jared McCain trade with OKC|4221360|4221360||0
BOS|brown|2027-07-06|Jaylen Brown trade with PHI|2952348|2952348||0
DAL|hardy-was|2027-02-05|Jaden Hardy trade with WAS|6000000|2909520|Partially used by AJ Johnson (3,090,480).|0
LAC|brown|2027-02-05|Kobe Brown trade with IND|2654880|2654880||0
BOS|tillman|2027-02-05|Xavier Tillman Sr. trade with CHA|2546675|2546675||0
OKC|dieng|2027-02-04|Ousmane Dieng trade with CHA|2449522|2449522||0
BOS|minott|2027-02-05|Josh Minott trade with BKN|2378870|2378870||0
ATL|krejci|2027-02-01|Vit Krejci trade with POR|2349578|2349578||0
LAC|paul|2027-02-05|Chris Paul trade with TOR|2296274|2296274||0
BOS|boucher|2027-02-05|Chris Boucher trade with UTA|2296274|2296274||0
PHI|gordon|2027-02-05|Eric Gordon trade with MEM|2296274|2296274||0
UTA|landale|2027-02-05|Jock Landale trade with MEM|2296274|2296274||0
CHA|plumlee|2027-02-04|Mason Plumlee trade with OKC|2296274|2296274||0
DEN|tyson|2027-02-05|Hunter Tyson trade with BKN|2221677|2221677||0
GSW|tjd|2027-02-05|Trayce Jackson-Davis trade with TOR|2221677|2221677||0
MEM|morant|2027-06-29|Ja Morant trade with POR|4314089|2163172|Partially used by Micah Peavy (2,150,917).|0
DAL|nembhard|2027-07-19|Ryan Nembhard trade with ATL|2150917|2150917||0
PHO|hayes-davis|2027-02-05|Nigel Hayes-Davis trade with MIL|2048494|2048494||0
ATL|kennard|2027-02-05|Luke Kennard trade with LAL|11000000|1971962|Partially used by Aaron Wiggins (9,028,038).|0
CLE|hunter|2027-02-01|De'Andre Hunter trade with SAC|6897984|1439674|Partially used by Cam Whitmore (5,458,310).|0
ATL|young|2027-01-08|Trae Young trade with WAS|1357994|1357993||0
LAC|zubac|2027-02-05|Ivica Zubac trade with IND|1314427|1314427||0
IND|jones|2027-06-24|Kam Jones trade with CHI|1075459|1075459||0
NYK|terry|2027-02-05|Dalen Terry trade with NOP|899118|899118||0
LAC|collins|2027-07-08|John Collins trade with DET|17000000|339164|Partially used by Max Strus (16,660,836).|0
CLE|garland|2027-02-04|Darius Garland trade with LAC|263397|263397||0
NYK|yabusele|2027-02-05|Guerschon Yabusele trade with CHI|100882|100882||0
MIL|portis|2027-07-06|Bobby Portis trade with MIA|85763|85763||0
DAL|exum|2027-02-05|Dante Exum trade with WAS|2296274|0|Fully used.|0
''';

List<NbaTradeExceptionRecord> _parseTpeSeed() {
  final rows = <NbaTradeExceptionRecord>[];
  for (final raw in _tpeSeed.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final fields = line.split('|');
    if (fields.length != 8) continue;
    rows.add(NbaTradeExceptionRecord(
      id: '${fields[0]}-${fields[1]}-${fields[2]}',
      team: fields[0],
      expires: fields[2],
      sourceTransaction: fields[3],
      original: double.tryParse(fields[4]) ?? 0,
      available: double.tryParse(fields[5]) ?? 0,
      note: fields[6].isEmpty ? null : fields[6],
      unusableAboveSecondApron: fields[7] == '1',
    ));
  }
  return List.unmodifiable(rows);
}
