enum NbaTradeKickerStatus {
  active,
  voidedAtMaxSalary,
  futureExtension,
  waivedOnTrade,
}

class NbaTradeKickerRecord {
  const NbaTradeKickerRecord({
    required this.player,
    required this.team,
    required this.percent,
    required this.status,
    this.note = '',
  });

  final String player;
  final String team;
  final double percent;
  final NbaTradeKickerStatus status;
  final String note;

  bool get affects202627 =>
      status == NbaTradeKickerStatus.active;
}

class NbaTradeKickerReference202627 {
  const NbaTradeKickerReference202627._();

  /// User-supplied 2026-27 trade-kicker reference, normalized 2026-09-20.
  ///
  /// Important CBA/accounting notes:
  /// - A trade bonus is paid by the team trading the player.
  /// - A player may waive part or all of the kicker in connection with a trade.
  /// - A percentage kicker is generally measured against remaining eligible
  ///   contract value and cannot increase salary beyond the applicable max.
  /// - Option years require separate treatment when calculating the actual bonus.
  static const List<NbaTradeKickerRecord> records = [
    NbaTradeKickerRecord(player:'Nickeil Alexander-Walker', team:'ATL', percent:7.5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'OG Anunoby', team:'NYK', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Bradley Beal', team:'LAC', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Devin Booker', team:'PHO', percent:10, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Mikal Bridges', team:'NYK', percent:5.69, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Jalen Brunson', team:'NYK', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Clint Capela', team:'HOU', percent:5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Tari Eason', team:'HOU', percent:10, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Anthony Edwards', team:'MIN', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Shai Gilgeous-Alexander', team:'OKC', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Rudy Gobert', team:'MIN', percent:7.5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Aaron Gordon', team:'DEN', percent:3, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Draymond Green', team:'GSW', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Tyrese Haliburton', team:'IND', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'James Harden', team:'CLE', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Isaiah Hartenstein', team:'OKC', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Al Horford', team:'GSW', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Kyrie Irving', team:'DAL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'LeBron James', team:'PHI', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Ty Jerome', team:'MEM', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Derrick Jones Jr.', team:'LAC', percent:5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Walker Kessler', team:'LAL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Naji Marshall', team:'DAL', percent:5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'CJ McCollum', team:'ATL', percent:7.5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Jordan Miller', team:'LAC', percent:3, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Klay Thompson', team:'MIA', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Myles Turner', team:'MIL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Peyton Watson', team:'CLE', percent:7.5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Derrick White', team:'BOS', percent:15, status:NbaTradeKickerStatus.active),

    // The kicker exists contractually but would not create 2026-27 additional
    // salary because the player is already at this season's maximum salary.
    NbaTradeKickerRecord(player:'Scottie Barnes', team:'TOR', percent:15, status:NbaTradeKickerStatus.voidedAtMaxSalary),
    NbaTradeKickerRecord(player:'Stephen Curry', team:'GSW', percent:15, status:NbaTradeKickerStatus.voidedAtMaxSalary),
    NbaTradeKickerRecord(player:'Nikola Jokić', team:'DEN', percent:15, status:NbaTradeKickerStatus.voidedAtMaxSalary),
    NbaTradeKickerRecord(player:'Evan Mobley', team:'CLE', percent:15, status:NbaTradeKickerStatus.voidedAtMaxSalary),
    NbaTradeKickerRecord(player:'Jayson Tatum', team:'BOS', percent:15, status:NbaTradeKickerStatus.voidedAtMaxSalary),
    NbaTradeKickerRecord(player:'Trae Young', team:'WAS', percent:7.5, status:NbaTradeKickerStatus.voidedAtMaxSalary),

    // Extension kicker begins in a later league year.
    NbaTradeKickerRecord(player:'Donovan Mitchell', team:'CLE', percent:15, status:NbaTradeKickerStatus.futureExtension),
    NbaTradeKickerRecord(player:'Aaron Nesmith', team:'IND', percent:7.5, status:NbaTradeKickerStatus.futureExtension),
    NbaTradeKickerRecord(player:'Jakob Poeltl', team:'TOR', percent:5, status:NbaTradeKickerStatus.futureExtension),
    NbaTradeKickerRecord(player:'Amen Thompson', team:'HOU', percent:10, status:NbaTradeKickerStatus.futureExtension),
    NbaTradeKickerRecord(player:'Victor Wembanyama', team:'SAS', percent:15, status:NbaTradeKickerStatus.futureExtension),

    // Leonard's 2026 trade bonus was waived in connection with the Toronto trade.
    NbaTradeKickerRecord(
      player:'Kawhi Leonard',
      team:'TOR',
      percent:15,
      status:NbaTradeKickerStatus.waivedOnTrade,
      note:'Trade bonus waived in connection with the 2026 trade to Toronto.',
    ),
  ];

  static NbaTradeKickerRecord? forPlayer(String player) {
    final key = player.toLowerCase();
    for (final record in records) {
      if (record.player.toLowerCase() == key) return record;
    }
    return null;
  }
}
