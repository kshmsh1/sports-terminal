class NbaTradeDraftRight {
  const NbaTradeDraftRight({
    required this.id,
    required this.team,
    required this.player,
    required this.position,
    this.note = '',
    this.source = 'User-supplied Trade Machine screen recording (2026-09-30)',
  });

  final String id;
  final String team;
  final String player;
  final String position;
  final String note;
  final String source;
}

class NbaTradeFreeAgentRight {
  const NbaTradeFreeAgentRight({
    required this.id,
    required this.team,
    required this.player,
    required this.position,
    required this.capHold,
    required this.rights,
    this.signAndTradeMinimum,
    this.signAndTradeMaximum,
    this.source = 'User-supplied Trade Machine screen recording (2026-09-30)',
  });

  final String id;
  final String team;
  final String player;
  final String position;
  final double capHold;
  final String rights;
  final double? signAndTradeMinimum;
  final double? signAndTradeMaximum;
  final String source;

  bool get signAndTradeReady =>
      signAndTradeMinimum != null &&
      signAndTradeMaximum != null &&
      signAndTradeMaximum! >= signAndTradeMinimum!;
}

class NbaTradeSupplementalAssets202627 {
  const NbaTradeSupplementalAssets202627._();

  /// Draft-rights ledger transcribed from the user-supplied 2026-10-06
  /// Draft Rights reference table. Teams absent from that table intentionally
  /// return no installed draft-rights rows.
  static const List<NbaTradeDraftRight> draftRights = [
    NbaTradeDraftRight(id: 'draft-right:BOS:jhann-begarin', team: 'BOS', player: 'Juhann Begarin', position: 'F', note: '2021 R2 #45 · AS Monaco · France'),
    NbaTradeDraftRight(id: 'draft-right:BOS:yam-madar', team: 'BOS', player: 'Yam Madar', position: 'G', note: '2020 R2 #47 · Maccabi Tel Aviv · Israel'),
    NbaTradeDraftRight(id: 'draft-right:BRK:david-michinea', team: 'BRK', player: 'David Michineau', position: 'G', note: '2016 R2 #39 · Dar City · Tanzania'),
    NbaTradeDraftRight(id: 'draft-right:BRK:aaron-white', team: 'BRK', player: 'Aaron White', position: 'F', note: '2015 R2 #49 · SeaHorses Mikawa · Japan'),
    NbaTradeDraftRight(id: 'draft-right:BRK:nikola-miltinov', team: 'BRK', player: 'Nikola Milutinov', position: 'C', note: '2015 R1 #26 · Olympiacos · Russia'),
    NbaTradeDraftRight(id: 'draft-right:CHA:matteo-spagnolo', team: 'CHA', player: 'Matteo Spagnolo', position: 'G', note: '2022 R2 #50 · Saski Baskonia · Spain'),
    NbaTradeDraftRight(id: 'draft-right:CHA:tyler-harvey', team: 'CHA', player: 'Tyler Harvey', position: 'G', note: '2015 R2 #51 · Illawarra Hawks · Australia'),
    NbaTradeDraftRight(id: 'draft-right:CLE:salio-niang', team: 'CLE', player: 'Saliou Niang', position: 'F', note: '2025 R2 #58 · LSU · United States'),
    NbaTradeDraftRight(id: 'draft-right:CLE:ismael-kamagate', team: 'CLE', player: 'Ismael Kamagate', position: 'C', note: '2022 R2 #46 · Pallacanestro Varese · Italy'),
    NbaTradeDraftRight(id: 'draft-right:CLE:art-ras-gdaitis', team: 'CLE', player: 'Artūras Gudaitis', position: 'C', note: '2015 R2 #47 · Rytas Vilnius · Lithuania'),
    NbaTradeDraftRight(id: 'draft-right:CLE:chkwdiebere-madabm', team: 'CLE', player: 'Chukwudiebere Maduabum', position: 'F', note: '2011 R2 #56 · Lavertien Mie · Japan'),
    NbaTradeDraftRight(id: 'draft-right:DAL:vsevolod-ishchenko', team: 'DAL', player: 'Vsevolod Ishchenko', position: 'F', note: '2026 R2 #56 · PBC Lokomotiv Kuban · Russia'),
    NbaTradeDraftRight(id: 'draft-right:DEN:i-zzet-t-rky-lmaz', team: 'DEN', player: 'İzzet Türkyılmaz', position: 'F', note: '2012 R2 #50 · Balıkesir Büyükşehir Belediyespor'),
    NbaTradeDraftRight(id: 'draft-right:GSW:lajae-jones', team: 'GSW', player: 'Lajae Jones', position: 'F', note: '2026 R2 #54'),
    NbaTradeDraftRight(id: 'draft-right:GSW:cady-lalanne', team: 'GSW', player: 'Cady Lalanne', position: 'C', note: '2015 R2 #55 · Capitanes de Arecibo · Puerto Rico'),
    NbaTradeDraftRight(id: 'draft-right:HOU:iss-sanon', team: 'HOU', player: 'Issuf Sanon', position: 'G', note: '2018 R2 #44 · Śląsk Wrocław · Poland'),
    NbaTradeDraftRight(id: 'draft-right:LAC:narcisse-ngoy', team: 'LAC', player: 'Narcisse Ngoy', position: 'F', note: '2026 R2 #57 · Auburn · United States'),
    NbaTradeDraftRight(id: 'draft-right:LAC:vanja-marinkovic', team: 'LAC', player: 'Vanja Marinković', position: 'G', note: '2019 R2 #60 · Partizan · Serbia'),
    NbaTradeDraftRight(id: 'draft-right:MEM:richie-sanders', team: 'MEM', player: 'Richie Saunders', position: 'G', note: '2026 R2 #32'),
    NbaTradeDraftRight(id: 'draft-right:MEM:nemanja-dangbic', team: 'MEM', player: 'Nemanja Dangubić', position: 'F', note: '2014 R2 #54 · Dubai · United Arab Emirates'),
    NbaTradeDraftRight(id: 'draft-right:MIL:maliqe-lewis', team: 'MIL', player: 'Malique Lewis', position: 'F', note: '2026 R2 #60'),
    NbaTradeDraftRight(id: 'draft-right:MIL:dimitrios-agravanis', team: 'MIL', player: 'Dimitrios Agravanis', position: 'F', note: '2015 R2 #59 · Hefei Kuangfeng · China'),
    NbaTradeDraftRight(id: 'draft-right:MIN:trey-kaman-renn', team: 'MIN', player: 'Trey Kaufman-Renn', position: 'F', note: '2026 R2 #59'),
    NbaTradeDraftRight(id: 'draft-right:NYK:tyler-nickel', team: 'NYK', player: 'Tyler Nickel', position: 'F', note: '2026 R2 #47'),
    NbaTradeDraftRight(id: 'draft-right:NYK:jack-kayil', team: 'NYK', player: 'Jack Kayil', position: 'G', note: '2026 R2 #39 · Alba Berlin · Germany'),
    NbaTradeDraftRight(id: 'draft-right:NYK:melvin-ajinc-a', team: 'NYK', player: 'Melvin Ajinça', position: 'F', note: '2024 R2 #51 · Le Mans Sarthe · France'),
    NbaTradeDraftRight(id: 'draft-right:NYK:james-nnaji', team: 'NYK', player: 'James Nnaji', position: 'C', note: '2023 R2 #31 · George Mason · United States'),
    NbaTradeDraftRight(id: 'draft-right:NYK:mojave-king', team: 'NYK', player: 'Mojave King', position: 'G', note: '2023 R2 #47 · Mykonos · Greece'),
    NbaTradeDraftRight(id: 'draft-right:NYK:hgo-besson', team: 'NYK', player: 'Hugo Besson', position: 'G', note: '2022 R2 #58 · Tofaş · Turkey'),
    NbaTradeDraftRight(id: 'draft-right:NYK:rokas-jokbaitis', team: 'NYK', player: 'Rokas Jokubaitis', position: 'G', note: '2021 R2 #34 · Bayern Munich · Germany'),
    NbaTradeDraftRight(id: 'draft-right:NYK:ognjen-jaramaz', team: 'NYK', player: 'Ognjen Jaramaz', position: 'G', note: '2017 R2 #58 · Lietkabelis Panevėžys · Lithuania'),
    NbaTradeDraftRight(id: 'draft-right:NYK:wang-zhelin', team: 'NYK', player: 'Wang Zhelin', position: 'C', note: '2016 R2 #57 · Shanghai Sharks · China'),
    NbaTradeDraftRight(id: 'draft-right:NYK:dani-di-ez', team: 'NYK', player: 'Dani Díez', position: 'F', note: '2015 R2 #54 · Universidad San Pablo Burgos · Spain'),
    NbaTradeDraftRight(id: 'draft-right:NYK:jan-pablo-valet', team: 'NYK', player: 'Juan Pablo Vaulet', position: 'F', note: '2015 R2 #39 · CB Estudiantes · Spain'),
    NbaTradeDraftRight(id: 'draft-right:NYK:lka-mitrovic', team: 'NYK', player: 'Luka Mitrović', position: 'F', note: '2015 R2 #60 · Philadelphia 76ers rights chain'),
    NbaTradeDraftRight(id: 'draft-right:NYK:nikola-radic-evic', team: 'NYK', player: 'Nikola Radičević', position: 'G', note: '2015 R2 #57 · Lietkabelis Panevėžys · Lithuania'),
    NbaTradeDraftRight(id: 'draft-right:NYK:lois-labeyrie', team: 'NYK', player: 'Louis Labeyrie', position: 'F', note: '2014 R2 #57 · SIG Strasbourg · France'),
    NbaTradeDraftRight(id: 'draft-right:NYK:latavios-williams', team: 'NYK', player: 'Latavious Williams', position: 'F', note: '2010 R2 #48 · Al-Ittihad Jeddah · Saudi Arabia'),
    NbaTradeDraftRight(id: 'draft-right:NYK:sergio-llll', team: 'NYK', player: 'Sergio Llull', position: 'G', note: '2009 R2 #34 · Real Madrid · Spain'),
    NbaTradeDraftRight(id: 'draft-right:NYK:emir-preldz-ic', team: 'NYK', player: 'Emir Preldžić', position: 'F', note: '2009 R2 #57 · PHO · KK Orlovik Žepče · Bosnia and Herzegovina'),
    NbaTradeDraftRight(id: 'draft-right:NYK:chinemel-elon', team: 'NYK', player: 'Chinemelu Elonu', position: 'C', note: '2009 R2 #59 · LAL · Al Qadsia · Kuwait'),
    NbaTradeDraftRight(id: 'draft-right:OKC:bals-a-koprivica', team: 'OKC', player: 'Balša Koprivica', position: 'C', note: '2021 R2 #57 · San Pablo Burgos · Spain'),
    NbaTradeDraftRight(id: 'draft-right:PHI:jstinian-jessp', team: 'PHI', player: 'Justinian Jessup', position: 'SG', note: '2020 R2 #51 · Bayern Munich · Germany'),
    NbaTradeDraftRight(id: 'draft-right:POR:ante-tomic', team: 'POR', player: 'Ante Tomić', position: 'C', note: '2008 R2 #44 · Joventut · Spain'),
    NbaTradeDraftRight(id: 'draft-right:SAC:alpha-kaba', team: 'SAC', player: 'Alpha Kaba', position: 'C', note: '2017 R2 #60 · Shenzhen Leopards · China'),
    NbaTradeDraftRight(id: 'draft-right:SAS:a-da-m-hanga', team: 'SAS', player: 'Ádám Hanga', position: 'G-F', note: '2011 R2 #59'),
    NbaTradeDraftRight(id: 'draft-right:UTA:gabriele-procida', team: 'UTA', player: 'Gabriele Procida', position: 'G-F', note: '2022 R2 #36 · Real Madrid · Spain'),
    NbaTradeDraftRight(id: 'draft-right:WAS:yannick-nzosa', team: 'WAS', player: 'Yannick Nzosa', position: 'C', note: '2022 R2 #54 · Unicaja Malaga · Spain'),
    NbaTradeDraftRight(id: 'draft-right:WAS:mathias-lessort', team: 'WAS', player: 'Mathias Lessort', position: 'C', note: '2017 R2 #50 · Panathinaikos · Serbia'),
  ];

  /// Free-agent rights/cap holds directly visible in the user's reference
  /// recording. Kyle Lowry also has the displayed sign-and-trade salary range,
  /// so the UI can model that workflow without inventing values for other rows.
  static const List<NbaTradeFreeAgentRight> freeAgentRights = [
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:marjon-beauchamp',
      team: 'PHI',
      player: 'MarJon Beauchamp',
      position: 'SG',
      capHold: 2449421,
      rights: 'UFA · Non-Bird',
    ),
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:kyle-lowry',
      team: 'PHI',
      player: 'Kyle Lowry',
      position: 'PG',
      capHold: 2449421,
      rights: 'UFA · Early Bird',
      signAndTradeMinimum: 3876529,
      signAndTradeMaximum: 27678571,
    ),
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:tyrese-martin',
      team: 'PHI',
      player: 'Tyrese Martin',
      position: 'SF',
      capHold: 2449421,
      rights: 'UFA · Non-Bird',
    ),
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:jeff-dowtin',
      team: 'PHI',
      player: 'Jeff Dowtin',
      position: 'PG',
      capHold: 2185116,
      rights: 'UFA · Two-Way',
    ),
    NbaTradeFreeAgentRight(
      id: 'fa-right:PHI:jalen-hood-schifino',
      team: 'PHI',
      player: 'Jalen Hood-Schifino',
      position: 'PG',
      capHold: 2185116,
      rights: 'UFA · Two-Way',
    ),
  ];

  static List<NbaTradeDraftRight> draftRightsFor(String team) =>
      draftRights.where((item) => item.team == team).toList(growable: false);

  static List<NbaTradeFreeAgentRight> freeAgentRightsFor(String team) =>
      freeAgentRights
          .where((item) => item.team == team)
          .toList(growable: false);
}
