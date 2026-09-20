enum NbaTransactionType { trade, signAndTrade, freeAgent, extension, waiver, buyout, draftTrade }

class NbaTransactionEvent {
  const NbaTransactionEvent({
    required this.date,
    required this.type,
    required this.summary,
    this.teams = const [],
    this.players = const [],
  });

  final String date;
  final NbaTransactionType type;
  final String summary;
  final List<String> teams;
  final List<String> players;
}

class NbaTransactionHistory2026 {
  const NbaTransactionHistory2026._();

  /// Official 2026 offseason trade history supplied by the user.
  static const List<NbaTransactionEvent> trades = [
    NbaTransactionEvent(date:'2026-09-14', type:NbaTransactionType.trade, summary:'LAC/TOR: Kawhi Leonard to TOR; Gradey Dick, Brandon Ingram and draft assets to LAC.', teams:['LAC','TOR'], players:['Kawhi Leonard','Gradey Dick','Brandon Ingram']),
    NbaTransactionEvent(date:'2026-09-08', type:NbaTransactionType.trade, summary:'MEM/NOP four-player swap.', teams:['MEM','NOP'], players:['Jordan Hawkins','Micah Peavy','Taj Gibson','AJ Johnson']),
    NbaTransactionEvent(date:'2026-08-29', type:NbaTransactionType.trade, summary:'UTA/MIN: Josh Green to UTA; John Konchar and Cody Williams to MIN.', teams:['UTA','MIN'], players:['Josh Green','John Konchar','Cody Williams']),
    NbaTransactionEvent(date:'2026-08-20', type:NbaTransactionType.trade, summary:'Five-team CLE/LAC/CHA/DEN/WAS transaction.', teams:['CLE','LAC','CHA','DEN','WAS'], players:['Peyton Watson','Cam Whitmore','Max Strus','Dennis Schröder','Tre Mann']),
    NbaTransactionEvent(date:'2026-07-28', type:NbaTransactionType.trade, summary:'PHI/LAC: Johni Broome to LAC for cash and a 2027 second.', teams:['PHI','LAC'], players:['Johni Broome']),
    NbaTransactionEvent(date:'2026-07-19', type:NbaTransactionType.trade, summary:'ATL/DAL/OKC: Lu Dort and Ryan Nembhard to ATL; Zaccharie Risacher to DAL.', teams:['ATL','DAL','OKC'], players:['Luguentz Dort','Ryan Nembhard','Zaccharie Risacher']),
    NbaTransactionEvent(date:'2026-07-13', type:NbaTransactionType.trade, summary:'CHA/PHO: Miles Bridges to PHO; Grayson Allen and Royce O’Neale to CHA.', teams:['CHA','PHO'], players:['Miles Bridges','Grayson Allen','Royce O’Neale']),
    NbaTransactionEvent(date:'2026-07-10', type:NbaTransactionType.trade, summary:'BKN/CHI/CHA/MIN four-team deal headlined by LaMelo Ball to MIN, Julius Randle to BKN, Nic Claxton to CHI and Naz Reid to CHA.', teams:['BKN','CHI','CHA','MIN'], players:['LaMelo Ball','Julius Randle','Nic Claxton','Naz Reid','Josh Green']),
    NbaTransactionEvent(date:'2026-07-08', type:NbaTransactionType.signAndTrade, summary:'LAL/UTA sign-and-trade: Walker Kessler to LAL.', teams:['LAL','UTA'], players:['Walker Kessler']),
    NbaTransactionEvent(date:'2026-07-08', type:NbaTransactionType.trade, summary:'Six-team WAS/MEM/DAL/MIL/DET/LAC trade.', teams:['WAS','MEM','DAL','MIL','DET','LAC'], players:['Khris Middleton','D’Angelo Russell','Isaiah Stewart','Santi Aldama','Marcus Sasser','Caris LeVert','John Collins']),
    NbaTransactionEvent(date:'2026-07-07', type:NbaTransactionType.trade, summary:'WAS/LAL: Deandre Ayton to WAS; Jaden Hardy and seconds to LAL.', teams:['WAS','LAL'], players:['Deandre Ayton','Jaden Hardy']),
    NbaTransactionEvent(date:'2026-07-06', type:NbaTransactionType.trade, summary:'HOU/CHA: Dorian Finney-Smith to CHA for cash.', teams:['HOU','CHA'], players:['Dorian Finney-Smith']),
    NbaTransactionEvent(date:'2026-07-06', type:NbaTransactionType.trade, summary:'DET/OKC: Isaiah Joe to DET.', teams:['DET','OKC'], players:['Isaiah Joe']),
    NbaTransactionEvent(date:'2026-07-06', type:NbaTransactionType.trade, summary:'BOS/PHI: Jaylen Brown to PHI; Paul George and draft assets to BOS.', teams:['BOS','PHI'], players:['Jaylen Brown','Paul George']),
    NbaTransactionEvent(date:'2026-07-06', type:NbaTransactionType.trade, summary:'MIA/MIL: Giannis Antetokounmpo and Bobby Portis to MIA; Tyler Herro, Kel’el Ware, Jaime Jaquez Jr., Kasparas Jakučionis and draft assets to MIL.', teams:['MIA','MIL'], players:['Giannis Antetokounmpo','Bobby Portis','Tyler Herro','Kel’el Ware','Jaime Jaquez Jr.','Kasparas Jakučionis']),
    NbaTransactionEvent(date:'2026-07-06', type:NbaTransactionType.trade, summary:'ATL/OKC: Aaron Wiggins to ATL for seconds.', teams:['ATL','OKC'], players:['Aaron Wiggins']),
    NbaTransactionEvent(date:'2026-06-30', type:NbaTransactionType.trade, summary:'ATL/SAC: Devin Carter to ATL.', teams:['ATL','SAC'], players:['Devin Carter']),
    NbaTransactionEvent(date:'2026-06-29', type:NbaTransactionType.trade, summary:'POR/MEM: Ja Morant to POR; Jerami Grant and Kris Murray to MEM.', teams:['POR','MEM'], players:['Ja Morant','Jerami Grant','Kris Murray']),
  ];

  static String? mostRecentAcquisitionDate(String player) {
    for (final event in trades) {
      if (event.players.contains(player)) return event.date;
    }
    return null;
  }
}
