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
    NbaTradeKickerRecord(player:'Aaron Gordon', team:'DEN', percent:3, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Al Horford', team:'GSW', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Anthony Edwards', team:'MIN', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'C.J. McCollum', team:'ATL', percent:7, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Clint Capela', team:'HOU', percent:5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Darius Garland', team:'LAC', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Derrick Jones Jr.', team:'LAC', percent:5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Derrick White', team:'BOS', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Desmond Bane', team:'ORL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Donovan Mitchell', team:'CLE', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Dorian Finney-Smith', team:'CHA', percent:3, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Evan Mobley', team:'CLE', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Giannis Antetokounmpo', team:'MIA', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Isaiah Hartenstein', team:'OKC', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Jalen Brunson', team:'NYK', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Jalen Green', team:'PHO', percent:10, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(
      player:'Jaylen Brown',
      team:'PHI',
      percent:7,
      status:NbaTradeKickerStatus.active,
      note:'Source lists 7% / \$7,000,000; exact bonus requires fixed-dollar cap treatment.',
    ),
    NbaTradeKickerRecord(player:'Jayson Tatum', team:'BOS', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Kawhi Leonard', team:'TOR', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Kevin Durant', team:'HOU', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Klay Thompson', team:'DAL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Kyle Kuzma', team:'MIL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Kyrie Irving', team:'DAL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'LaMelo Ball', team:'MIN', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Myles Turner', team:'MIL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Naji Marshall', team:'DAL', percent:5, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Nickeil Alexander-Walker', team:'ATL', percent:7, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Nikola Jokić', team:'DEN', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'OG Anunoby', team:'NYK', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Paul George', team:'BOS', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Scottie Barnes', team:'TOR', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Shai Gilgeous-Alexander', team:'OKC', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Tari Eason', team:'HOU', percent:10, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Trae Young', team:'WAS', percent:7, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Tyrese Haliburton', team:'IND', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Victor Wembanyama', team:'SAS', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Walker Kessler', team:'LAL', percent:15, status:NbaTradeKickerStatus.active),
    NbaTradeKickerRecord(player:'Zach LaVine', team:'SAC', percent:15, status:NbaTradeKickerStatus.active),
  ];

  static NbaTradeKickerRecord? forPlayer(String player) {
    final key = player.toLowerCase();
    for (final record in records) {
      if (record.player.toLowerCase() == key) return record;
    }
    return null;
  }
}
