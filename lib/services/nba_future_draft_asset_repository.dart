class NbaFutureDraftAsset {
  const NbaFutureDraftAsset({
    required this.id,
    required this.team,
    required this.year,
    required this.round,
    required this.label,
    required this.description,
    this.tradable = true,
    this.frozen = false,
    this.conditional = false,
    this.swapRight = false,
    this.stepienSafe = false,
    this.protection,
    this.source = 'RealGM PDFs supplied by user',
  });

  final String id;
  final String team;
  final int year;
  final int round;
  final String label;
  final String description;
  final bool tradable;
  final bool frozen;
  final bool conditional;
  final bool swapRight;
  final bool stepienSafe;
  final String? protection;
  final String source;
}

class NbaFutureDraftAssetRepository {
  const NbaFutureDraftAssetRepository();

  /// Normalized seed for the 2027-2033 draft interests supplied in the two
  /// RealGM PDF exports. Complex conveyance trees are intentionally preserved
  /// as conditional interests rather than flattened into guaranteed ownership.
  ///
  /// This first production seed focuses on first-round interests plus notable
  /// frozen/forfeited assets, which are the most transaction-critical for the
  /// Trade Machine and Stepien review. The repository is structured to accept
  /// the complete second-round ledger without changing the UI/engine contract.
  List<NbaFutureDraftAsset> all() => const [
        NbaFutureDraftAsset(id:'ATL-2027-1-SAS', team:'ATL', year:2027, round:1, label:'2027 1st → SAS', description:'Atlanta 2027 first-round pick is owed to San Antonio.', tradable:false),
        NbaFutureDraftAsset(id:'ATL-2028-1-SWAP', team:'ATL', year:2028, round:1, label:'2028 1st swap interest', description:'Atlanta receives the more favorable of its own first and the less favorable of Utah/Cleveland; Cleveland receives the least favorable of the three.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'ATL-2029-1', team:'ATL', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'ATL-2030-1', team:'ATL', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'ATL-2031-1', team:'ATL', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'ATL-2032-1', team:'ATL', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'ATL-2033-1', team:'ATL', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'BOS-2027-1', team:'BOS', year:2027, round:1, label:'2027 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'BOS-2028-1-COMPLEX', team:'BOS', year:2028, round:1, label:'2028 1st / complex swap', description:'Boston may retain its own/San Antonio interest and has a complex conditional swap involving Philadelphia and the Clippers.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'BOS-2029-1-OUT', team:'BOS', year:2029, round:1, label:'2029 1st obligation', description:'Boston 2029 first participates in a Portland/Washington three-pick distribution with Milwaukee.', tradable:false, conditional:true),
        NbaFutureDraftAsset(id:'BOS-2030-1', team:'BOS', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'BOS-2031-1-PHI', team:'BOS', year:2031, round:1, label:'2031 PHI 1st', description:'Philadelphia 2031 first-round pick owed to Boston.', conditional:true),
        NbaFutureDraftAsset(id:'BOS-2032-1-FROZEN', team:'BOS', year:2032, round:1, label:'2032 1st (frozen)', description:'Boston 2032 first-round pick is frozen through 2027-28.', tradable:false, frozen:true),
        NbaFutureDraftAsset(id:'BOS-2033-1', team:'BOS', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'BRK-2027-1-SWAP', team:'BRK', year:2027, round:1, label:'2027 1st / HOU swap', description:'Brooklyn owns its first subject to Houston swap rights; Brooklyn also owns the Knicks 2027 first.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'BRK-2028-1-COMPLEX', team:'BRK', year:2028, round:1, label:'2028 multi-pick rights', description:'Brooklyn has complex rights among Brooklyn, Philadelphia, Phoenix and New York.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'BRK-2029-1-NYK', team:'BRK', year:2029, round:1, label:'2029 NYK 1st', description:'New York 2029 first-round pick owed to Brooklyn.', conditional:true),
        NbaFutureDraftAsset(id:'BRK-2030-1', team:'BRK', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'BRK-2031-1-NYK', team:'BRK', year:2031, round:1, label:'2031 NYK 1st', description:'New York 2031 first-round pick owed to Brooklyn.', conditional:true),
        NbaFutureDraftAsset(id:'BRK-2032-1-DEN', team:'BRK', year:2032, round:1, label:'2032 DEN 1st', description:'Denver 2032 first-round pick owed to Brooklyn.', conditional:true),
        NbaFutureDraftAsset(id:'BRK-2033-1', team:'BRK', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'CHA-2027-1', team:'CHA', year:2027, round:1, label:'2027 1st', description:'Own first-round pick plus DAL 3-30 and MIA 15-30 interests.', conditional:true, protection:'DAL 1-2; MIA 1-14'),
        NbaFutureDraftAsset(id:'CHA-2028-1-SWAP', team:'CHA', year:2028, round:1, label:'2028 1st / MIN swap', description:'Charlotte owns its first or may swap for Minnesota; Miami may also convey if prior obligation remains.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'CHA-2029-1-COMPLEX', team:'CHA', year:2029, round:1, label:'2029 complex first', description:'Charlotte has rights tied to the least/less favorable of Utah, Cleveland and Minnesota with additional swap mechanics.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'CHA-2030-1-COMPLEX', team:'CHA', year:2030, round:1, label:'2030 complex first', description:'Charlotte has a complex swap right involving Minnesota, San Antonio and Dallas.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'CHA-2031-1', team:'CHA', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CHA-2032-1', team:'CHA', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CHA-2033-1-MIN-PHX', team:'CHA', year:2033, round:1, label:'2033 first-round interests', description:'Charlotte owns its first plus Minnesota and Phoenix first-round picks.', conditional:true),

        NbaFutureDraftAsset(id:'CHI-2027-1', team:'CHI', year:2027, round:1, label:'2027 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CHI-2028-1', team:'CHI', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CHI-2029-1', team:'CHI', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CHI-2030-1', team:'CHI', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CHI-2031-1', team:'CHI', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CHI-2032-1', team:'CHI', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CHI-2033-1', team:'CHI', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'CLE-2027-1-OUT', team:'CLE', year:2027, round:1, label:'2027 1st obligation', description:'Cleveland 2027 first participates in Utah/Minnesota distribution to Memphis, Utah and Phoenix.', tradable:false, conditional:true),
        NbaFutureDraftAsset(id:'CLE-2028-1-COMPLEX', team:'CLE', year:2028, round:1, label:'2028 complex first', description:'Cleveland participates in Utah/Lakers/Atlanta swap tree.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'CLE-2029-1-OUT', team:'CLE', year:2029, round:1, label:'2029 1st obligation', description:'Cleveland 2029 first participates in Utah/Minnesota/Charlotte conveyance tree.', tradable:false, conditional:true),
        NbaFutureDraftAsset(id:'CLE-2030-1', team:'CLE', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CLE-2031-1-DEN', team:'CLE', year:2031, round:1, label:'2031 1st → DEN', description:'Cleveland 2031 first-round pick owed to Denver.', tradable:false),
        NbaFutureDraftAsset(id:'CLE-2032-1', team:'CLE', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'CLE-2033-1-FROZEN', team:'CLE', year:2033, round:1, label:'2033 1st (frozen)', description:'Cleveland 2033 first-round pick is frozen through 2028-29.', tradable:false, frozen:true),

        NbaFutureDraftAsset(id:'DAL-2027-1-CHA', team:'DAL', year:2027, round:1, label:'2027 1st (1-2 protected)', description:'Dallas 2027 first goes to Charlotte if 3-30.', conditional:true, protection:'1-2'),
        NbaFutureDraftAsset(id:'DAL-2028-1-SWAP', team:'DAL', year:2028, round:1, label:'2028 1st / OKC swap', description:'Dallas owns its first subject to Oklahoma City swap right.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'DAL-2029-1-COMPLEX', team:'DAL', year:2029, round:1, label:'2029 multi-team first', description:'Dallas participates in Houston/Phoenix/Brooklyn distribution; Dallas also owns LAL 2029 first.', conditional:true),
        NbaFutureDraftAsset(id:'DAL-2030-1-COMPLEX', team:'DAL', year:2030, round:1, label:'2030 complex first', description:'Dallas participates in San Antonio/Minnesota swap structure.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'DAL-2031-1', team:'DAL', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'DAL-2032-1', team:'DAL', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'DAL-2033-1', team:'DAL', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'DEN-2027-1-OKC', team:'DEN', year:2027, round:1, label:'2027 1st (1-5 protected)', description:'Denver owes Oklahoma City a protected first, rolling through 2029.', conditional:true, protection:'1-5'),
        NbaFutureDraftAsset(id:'DEN-2028-1-OKC', team:'DEN', year:2028, round:1, label:'2028 1st (conditional)', description:'Denver may owe Oklahoma City 6-30 if prior obligation not settled.', conditional:true, protection:'1-5'),
        NbaFutureDraftAsset(id:'DEN-2029-1-OKC', team:'DEN', year:2029, round:1, label:'2029 1st (conditional)', description:'Denver may owe Oklahoma City 6-30 depending on prior conveyance timing.', conditional:true, protection:'1-5'),
        NbaFutureDraftAsset(id:'DEN-2030-1-OKC', team:'DEN', year:2030, round:1, label:'2030 1st (conditional)', description:'Potential final Denver protected first to Oklahoma City under rolling obligation.', conditional:true, protection:'1-5'),
        NbaFutureDraftAsset(id:'DEN-2031-1-CLE', team:'DEN', year:2031, round:1, label:'2031 CLE 1st', description:'Denver owns Cleveland 2031 first plus its own first.', conditional:true),
        NbaFutureDraftAsset(id:'DEN-2032-1-BRK', team:'DEN', year:2032, round:1, label:'2032 1st → BRK', description:'Denver 2032 first-round pick owed to Brooklyn.', tradable:false),
        NbaFutureDraftAsset(id:'DEN-2033-1', team:'DEN', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'DET-2027-1', team:'DET', year:2027, round:1, label:'2027 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'DET-2028-1', team:'DET', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'DET-2029-1', team:'DET', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'DET-2030-1', team:'DET', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'DET-2031-1', team:'DET', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'DET-2032-1', team:'DET', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'DET-2033-1', team:'DET', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'GSW-2027-1', team:'GSW', year:2027, round:1, label:'2027 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'GSW-2028-1', team:'GSW', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'GSW-2029-1', team:'GSW', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'GSW-2030-1-MEM', team:'GSW', year:2030, round:1, label:'2030 1st (1-20 protected)', description:'Golden State owes Memphis the pick if 21-30.', conditional:true, protection:'1-20'),
        NbaFutureDraftAsset(id:'GSW-2031-1', team:'GSW', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'GSW-2032-1', team:'GSW', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'GSW-2033-1', team:'GSW', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'HOU-2027-1-BRK-SWAP', team:'HOU', year:2027, round:1, label:'2027 1st / BRK swap + PHX', description:'Houston owns its first with swap rights over Brooklyn and also owns Phoenix 2027 first.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'HOU-2028-1', team:'HOU', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'HOU-2029-1-COMPLEX', team:'HOU', year:2029, round:1, label:'2029 DAL/PHX/HOU rights', description:'Houston receives two most favorable among Houston, Dallas and Phoenix; Brooklyn receives the other.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'HOU-2030-1', team:'HOU', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'HOU-2031-1', team:'HOU', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'HOU-2032-1', team:'HOU', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'HOU-2033-1', team:'HOU', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'IND-2027-1', team:'IND', year:2027, round:1, label:'2027 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'IND-2028-1', team:'IND', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'IND-2029-1-FORFEITED', team:'IND', year:2029, round:1, label:'2029 1st (forfeited by LAC)', description:'Indiana 2029 first listed as forfeited by the Clippers in the supplied RealGM detail.', tradable:false, conditional:true),
        NbaFutureDraftAsset(id:'IND-2030-1', team:'IND', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'IND-2031-1', team:'IND', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'IND-2032-1', team:'IND', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'IND-2033-1', team:'IND', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'LAC-2027-1-COMPLEX', team:'LAC', year:2027, round:1, label:'2027 complex first', description:'Clippers first is subject to Oklahoma City/Denver and Toronto swap structures.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'LAC-2028-1-OUT', team:'LAC', year:2028, round:1, label:'2028 first obligation', description:'Clippers first is owed into Boston/Philadelphia conditional structure.', tradable:false, conditional:true),
        NbaFutureDraftAsset(id:'LAC-2029-1-SWAP', team:'LAC', year:2029, round:1, label:'2029 1st / PHI swap', description:'Clippers retain 1-3; Philadelphia may swap for 4-30. RealGM also notes a forfeited Indiana-derived interest.', conditional:true, swapRight:true, protection:'1-3'),
        NbaFutureDraftAsset(id:'LAC-2030-1-FORFEITED', team:'LAC', year:2030, round:1, label:'2030 1st (forfeited)', description:'Clippers 2030 first-round pick forfeited per supplied RealGM detail.', tradable:false),
        NbaFutureDraftAsset(id:'LAC-2031-1-FORFEITED', team:'LAC', year:2031, round:1, label:'2031 1st (forfeited)', description:'Clippers 2031 first-round pick forfeited per supplied RealGM detail; Toronto first is incoming.', tradable:false),
        NbaFutureDraftAsset(id:'LAC-2032-1-FORFEITED', team:'LAC', year:2032, round:1, label:'2032 1st (forfeited)', description:'Clippers 2032 first-round pick forfeited per supplied RealGM detail.', tradable:false),
        NbaFutureDraftAsset(id:'LAC-2033-1-FORFEITED', team:'LAC', year:2033, round:1, label:'2033 1st (forfeited)', description:'Clippers 2033 first-round pick forfeited per supplied RealGM detail; Toronto first is incoming.', tradable:false),

        NbaFutureDraftAsset(id:'LAL-2027-1-MEM', team:'LAL', year:2027, round:1, label:'2027 1st (1-4 protected)', description:'Lakers owe Memphis 5-30; 1-4 is retained.', conditional:true, protection:'1-4'),
        NbaFutureDraftAsset(id:'LAL-2028-1-UTH', team:'LAL', year:2028, round:1, label:'2028 1st / UTH swap', description:'Lakers first participates in Utah/Cleveland swap structure.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'LAL-2029-1-DAL', team:'LAL', year:2029, round:1, label:'2029 1st → DAL', description:'Lakers 2029 first-round pick owed to Dallas.', tradable:false),
        NbaFutureDraftAsset(id:'LAL-2030-1-UTH-SWAP', team:'LAL', year:2030, round:1, label:'2030 1st / UTH swap', description:'Utah has swap rights over Lakers 2030 first.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'LAL-2031-1-UTH', team:'LAL', year:2031, round:1, label:'2031 1st → UTH', description:'Lakers 2031 first-round pick owed to Utah.', tradable:false),
        NbaFutureDraftAsset(id:'LAL-2032-1', team:'LAL', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'LAL-2033-1-UTH', team:'LAL', year:2033, round:1, label:'2033 1st → UTH', description:'Lakers 2033 first-round pick owed to Utah.', tradable:false),

        NbaFutureDraftAsset(id:'MEM-2027-1-MULTI', team:'MEM', year:2027, round:1, label:'2027 first-round interests', description:'Memphis owns its first, Lakers 5-30 and the most favorable of Utah/Cleveland/Minnesota.', conditional:true),
        NbaFutureDraftAsset(id:'MEM-2028-1', team:'MEM', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'MEM-2029-1-ORL-SWAP', team:'MEM', year:2029, round:1, label:'2029 1st / ORL swap', description:'Memphis may swap for Orlando 3-30; Orlando 1-2 is protected.', conditional:true, swapRight:true, protection:'ORL 1-2'),
        NbaFutureDraftAsset(id:'MEM-2030-1-MULTI', team:'MEM', year:2030, round:1, label:'2030 first-round interests', description:'Memphis has own/PHX-WAS swap plus GSW 21-30 and Orlando first.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'MEM-2031-1-PHX', team:'MEM', year:2031, round:1, label:'2031 firsts', description:'Memphis owns its first plus Phoenix first.', conditional:true),
        NbaFutureDraftAsset(id:'MEM-2032-1', team:'MEM', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'MEM-2033-1', team:'MEM', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'MIA-2027-1-CHA', team:'MIA', year:2027, round:1, label:'2027 1st (1-14 protected)', description:'Miami owes Charlotte 15-30; becomes unprotected in 2028 if not conveyed.', conditional:true, protection:'1-14'),
        NbaFutureDraftAsset(id:'MIA-2028-1-CHA', team:'MIA', year:2028, round:1, label:'2028 1st (conditional to CHA)', description:'Miami first goes to Charlotte if 2027 obligation is not already settled.', conditional:true),
        NbaFutureDraftAsset(id:'MIA-2029-1', team:'MIA', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'MIA-2030-1-MIL', team:'MIA', year:2030, round:1, label:'2030 complex first', description:'Miami participates in Milwaukee/Portland swap structure.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'MIA-2031-1-MIL', team:'MIA', year:2031, round:1, label:'2031 1st → MIL', description:'Miami 2031 first-round pick owed to Milwaukee.', tradable:false),
        NbaFutureDraftAsset(id:'MIA-2032-1', team:'MIA', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'MIA-2033-1-MIL', team:'MIA', year:2033, round:1, label:'2033 1st → MIL', description:'Miami 2033 first-round pick owed to Milwaukee.', tradable:false),

        NbaFutureDraftAsset(id:'MIL-2027-1-NOP-ATL', team:'MIL', year:2027, round:1, label:'2027 complex first', description:'Milwaukee first participates in New Orleans/Atlanta distribution with 1-4 protection on Atlanta obligation.', conditional:true, protection:'1-4'),
        NbaFutureDraftAsset(id:'MIL-2028-1-COMPLEX', team:'MIL', year:2028, round:1, label:'2028 complex first', description:'Milwaukee/Portland/Washington swap tree involving Brooklyn/Philadelphia/Phoenix.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'MIL-2029-1-COMPLEX', team:'MIL', year:2029, round:1, label:'2029 complex first', description:'Milwaukee participates in Boston/Portland/Washington distribution.', conditional:true),
        NbaFutureDraftAsset(id:'MIL-2030-1-COMPLEX', team:'MIL', year:2030, round:1, label:'2030 complex first', description:'Milwaukee may swap with Portland and Miami.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'MIL-2031-1-MIA', team:'MIL', year:2031, round:1, label:'2031 firsts', description:'Milwaukee owns its first plus Miami first.', conditional:true),
        NbaFutureDraftAsset(id:'MIL-2032-1', team:'MIL', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'MIL-2033-1-MIA', team:'MIL', year:2033, round:1, label:'2033 firsts', description:'Milwaukee owns its first plus Miami first.', conditional:true),

        NbaFutureDraftAsset(id:'MIN-2027-1-OUT', team:'MIN', year:2027, round:1, label:'2027 1st obligation', description:'Minnesota first participates in Utah/Cleveland distribution.', tradable:false, conditional:true),
        NbaFutureDraftAsset(id:'MIN-2028-1-CHA-SWAP', team:'MIN', year:2028, round:1, label:'2028 1st / CHA swap', description:'Charlotte has swap rights over Minnesota 2028 first.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'MIN-2029-1-COMPLEX', team:'MIN', year:2029, round:1, label:'2029 complex first', description:'Minnesota 1-5 retained; 6-30 participates in Utah/Charlotte/Phoenix conveyance tree.', conditional:true, protection:'1-5'),
        NbaFutureDraftAsset(id:'MIN-2030-1-COMPLEX', team:'MIN', year:2030, round:1, label:'2030 complex first', description:'Minnesota has selection-1 protection in San Antonio/Dallas structure and Charlotte has an additional complex right.', conditional:true, swapRight:true, protection:'1'),
        NbaFutureDraftAsset(id:'MIN-2031-1-SAC', team:'MIN', year:2031, round:1, label:'2031 1st → SAC', description:'Minnesota 2031 first-round pick owed to Sacramento.', tradable:false),
        NbaFutureDraftAsset(id:'MIN-2032-1-FROZEN', team:'MIN', year:2032, round:1, label:'2032 1st (frozen)', description:'Minnesota 2032 first-round pick is frozen through 2027-28.', tradable:false, frozen:true),
        NbaFutureDraftAsset(id:'MIN-2033-1-CHA', team:'MIN', year:2033, round:1, label:'2033 1st → CHA', description:'Minnesota 2033 first-round pick owed to Charlotte.', tradable:false),

        NbaFutureDraftAsset(id:'NOP-2027-1-MIL-ATL', team:'NOP', year:2027, round:1, label:'2027 complex first', description:'New Orleans receives more favorable of NOP/MIL; Atlanta may receive less favorable if outside 1-4.', conditional:true, swapRight:true, protection:'ATL obligation 1-4'),
        NbaFutureDraftAsset(id:'NOP-2028-1', team:'NOP', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'NOP-2029-1', team:'NOP', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'NOP-2030-1', team:'NOP', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'NOP-2031-1', team:'NOP', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'NOP-2032-1', team:'NOP', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'NOP-2033-1', team:'NOP', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'NYK-2027-1-BRK', team:'NYK', year:2027, round:1, label:'2027 1st → BRK', description:'New York 2027 first-round pick owed to Brooklyn.', tradable:false),
        NbaFutureDraftAsset(id:'NYK-2028-1-COMPLEX', team:'NYK', year:2028, round:1, label:'2028 complex first', description:'New York participates in Brooklyn/Phoenix/Philadelphia multi-team rights.', conditional:true),
        NbaFutureDraftAsset(id:'NYK-2029-1-BRK', team:'NYK', year:2029, round:1, label:'2029 1st → BRK', description:'New York 2029 first-round pick owed to Brooklyn.', tradable:false),
        NbaFutureDraftAsset(id:'NYK-2030-1', team:'NYK', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'NYK-2031-1-BRK', team:'NYK', year:2031, round:1, label:'2031 1st → BRK', description:'New York 2031 first-round pick owed to Brooklyn.', tradable:false),
        NbaFutureDraftAsset(id:'NYK-2032-1', team:'NYK', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'NYK-2033-1', team:'NYK', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'OKC-2027-1-MULTI', team:'OKC', year:2027, round:1, label:'2027 multiple first interests', description:'Oklahoma City has complex rights involving OKC, Denver, Clippers and San Antonio.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'OKC-2028-1-DAL-SWAP', team:'OKC', year:2028, round:1, label:'2028 1st / DAL swap', description:'Oklahoma City may swap its first for Dallas; Denver 6-30 may also convey.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'OKC-2029-1-DEN', team:'OKC', year:2029, round:1, label:'2029 first interests', description:'Own first plus possible Denver protected first.', conditional:true),
        NbaFutureDraftAsset(id:'OKC-2030-1-DEN', team:'OKC', year:2030, round:1, label:'2030 first interests', description:'Own first plus possible Denver protected first if prior timing conditions are met.', conditional:true),
        NbaFutureDraftAsset(id:'OKC-2031-1', team:'OKC', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'OKC-2032-1', team:'OKC', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'OKC-2033-1', team:'OKC', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'ORL-2027-1', team:'ORL', year:2027, round:1, label:'2027 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'ORL-2028-1-POR', team:'ORL', year:2028, round:1, label:'2028 1st → POR', description:'Orlando 2028 first-round pick owed to Portland.', tradable:false),
        NbaFutureDraftAsset(id:'ORL-2029-1-MEM-SWAP', team:'ORL', year:2029, round:1, label:'2029 1st / MEM swap', description:'Memphis may swap for Orlando 3-30; Orlando 1-2 protected.', conditional:true, swapRight:true, protection:'1-2'),
        NbaFutureDraftAsset(id:'ORL-2030-1-MEM', team:'ORL', year:2030, round:1, label:'2030 1st → MEM', description:'Orlando 2030 first-round pick owed to Memphis.', tradable:false),
        NbaFutureDraftAsset(id:'ORL-2031-1', team:'ORL', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'ORL-2032-1', team:'ORL', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'ORL-2033-1', team:'ORL', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'PHI-2027-1', team:'PHI', year:2027, round:1, label:'2027 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'PHI-2028-1-COMPLEX', team:'PHI', year:2028, round:1, label:'2028 complex first', description:'Philadelphia participates in Clippers/Boston/San Antonio/Brooklyn/Phoenix/New York structure.', conditional:true, swapRight:true, protection:'PHI 1-8 in one branch'),
        NbaFutureDraftAsset(id:'PHI-2029-1-LAC-SWAP', team:'PHI', year:2029, round:1, label:'2029 1st / LAC swap', description:'Philadelphia may swap for Clippers 4-30; Clippers 1-3 protected.', conditional:true, swapRight:true, protection:'LAC 1-3'),
        NbaFutureDraftAsset(id:'PHI-2030-1', team:'PHI', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'PHI-2031-1-BOS', team:'PHI', year:2031, round:1, label:'2031 1st → BOS', description:'Philadelphia 2031 first-round pick owed to Boston.', tradable:false),
        NbaFutureDraftAsset(id:'PHI-2032-1', team:'PHI', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'PHI-2033-1', team:'PHI', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'PHO-2027-1-HOU', team:'PHO', year:2027, round:1, label:'2027 1st → HOU', description:'Phoenix 2027 first-round pick owed to Houston.', tradable:false),
        NbaFutureDraftAsset(id:'PHO-2028-1-COMPLEX', team:'PHO', year:2028, round:1, label:'2028 complex first', description:'Phoenix participates in Brooklyn/Philadelphia/Washington/New York distribution.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'PHO-2029-1-COMPLEX', team:'PHO', year:2029, round:1, label:'2029 complex first', description:'Phoenix participates in Houston/Dallas/Brooklyn distribution and may receive a CHA/MIN-derived least favorable interest.', conditional:true),
        NbaFutureDraftAsset(id:'PHO-2030-1-COMPLEX', team:'PHO', year:2030, round:1, label:'2030 complex first', description:'Phoenix participates in Washington/Memphis swap tree.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'PHO-2031-1-MEM', team:'PHO', year:2031, round:1, label:'2031 1st → MEM', description:'Phoenix 2031 first-round pick owed to Memphis.', tradable:false),
        NbaFutureDraftAsset(id:'PHO-2032-1-FROZEN', team:'PHO', year:2032, round:1, label:'2032 1st (frozen)', description:'Phoenix 2032 first-round pick is frozen through 2027-28.', tradable:false, frozen:true),
        NbaFutureDraftAsset(id:'PHO-2033-1-CHA', team:'PHO', year:2033, round:1, label:'2033 1st → CHA', description:'Phoenix 2033 first-round pick owed to Charlotte.', tradable:false),

        NbaFutureDraftAsset(id:'POR-2027-1', team:'POR', year:2027, round:1, label:'2027 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'POR-2028-1-MIL-SWAP', team:'POR', year:2028, round:1, label:'2028 firsts', description:'Portland owns Orlando first and has swap rights over Milwaukee with Washington having further rights.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'POR-2029-1-COMPLEX', team:'POR', year:2029, round:1, label:'2029 complex first', description:'Portland receives most and least favorable among Portland/Boston/Milwaukee; Washington receives second most favorable.', conditional:true),
        NbaFutureDraftAsset(id:'POR-2030-1-COMPLEX', team:'POR', year:2030, round:1, label:'2030 complex first', description:'Portland may swap for Milwaukee; Miami may then affect conveyance.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'POR-2031-1', team:'POR', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'POR-2032-1', team:'POR', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'POR-2033-1', team:'POR', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'SAC-2027-1-MULTI', team:'SAC', year:2027, round:1, label:'2027 firsts', description:'Sacramento owns its first plus San Antonio 1-16.', conditional:true),
        NbaFutureDraftAsset(id:'SAC-2028-1', team:'SAC', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'SAC-2029-1', team:'SAC', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'SAC-2030-1', team:'SAC', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'SAC-2031-1-SAS-SWAP', team:'SAC', year:2031, round:1, label:'2031 first interests', description:'Sacramento owns its first or San Antonio via swap, plus Minnesota first.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'SAC-2032-1', team:'SAC', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'SAC-2033-1', team:'SAC', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'SAS-2027-1-ATL', team:'SAS', year:2027, round:1, label:'2027 first interests', description:'San Antonio owns Atlanta first; its own first conveys to Sacramento if 1-16 or Oklahoma City if 17-30.', conditional:true),
        NbaFutureDraftAsset(id:'SAS-2028-1-BOS-SWAP', team:'SAS', year:2028, round:1, label:'2028 1st / BOS swap', description:'San Antonio may swap its first for Boston 2-30, with Boston then having a Philadelphia-linked complex right.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'SAS-2029-1', team:'SAS', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'SAS-2030-1-COMPLEX', team:'SAS', year:2030, round:1, label:'2030 complex first', description:'San Antonio has most/more favorable rights among SAS/Dallas/Minnesota subject to Minnesota protection and Charlotte rights.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'SAS-2031-1-SAC-SWAP', team:'SAS', year:2031, round:1, label:'2031 1st / SAC swap', description:'San Antonio owns its first or may swap for Sacramento.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'SAS-2032-1', team:'SAS', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'SAS-2033-1', team:'SAS', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),

        NbaFutureDraftAsset(id:'TOR-2027-1-COMPLEX', team:'TOR', year:2027, round:1, label:'2027 complex first', description:'Toronto participates in Clippers/Oklahoma City/Denver swap structure.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'TOR-2028-1', team:'TOR', year:2028, round:1, label:'2028 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'TOR-2029-1', team:'TOR', year:2029, round:1, label:'2029 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'TOR-2030-1', team:'TOR', year:2030, round:1, label:'2030 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'TOR-2031-1-LAC', team:'TOR', year:2031, round:1, label:'2031 1st → LAC', description:'Toronto 2031 first-round pick owed to the Clippers.', tradable:false),
        NbaFutureDraftAsset(id:'TOR-2032-1', team:'TOR', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'TOR-2033-1-LAC', team:'TOR', year:2033, round:1, label:'2033 1st → LAC', description:'Toronto 2033 first-round pick owed to the Clippers.', tradable:false),

        NbaFutureDraftAsset(id:'UTA-2027-1-COMPLEX', team:'UTA', year:2027, round:1, label:'2027 complex first', description:'Utah/Cleveland/Minnesota distribution: Memphis gets most favorable, Utah second, Phoenix least; Utah cannot be 1-5 in the pool.', conditional:true, protection:'UTA 1-5 excluded'),
        NbaFutureDraftAsset(id:'UTA-2028-1-COMPLEX', team:'UTA', year:2028, round:1, label:'2028 complex first', description:'Utah controls multi-step rights involving Cleveland and Lakers.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'UTA-2029-1-COMPLEX', team:'UTA', year:2029, round:1, label:'2029 complex first', description:'Utah/Cleveland/Minnesota tree with Charlotte and Phoenix rights.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'UTA-2030-1-LAL-SWAP', team:'UTA', year:2030, round:1, label:'2030 1st / LAL swap', description:'Utah owns its first or may swap for Lakers.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'UTA-2031-1-LAL', team:'UTA', year:2031, round:1, label:'2031 firsts', description:'Utah owns its first plus Lakers first.', conditional:true),
        NbaFutureDraftAsset(id:'UTA-2032-1', team:'UTA', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'UTA-2033-1-LAL', team:'UTA', year:2033, round:1, label:'2033 firsts', description:'Utah owns its first plus Lakers first.', conditional:true),

        NbaFutureDraftAsset(id:'WAS-2027-1', team:'WAS', year:2027, round:1, label:'2027 1st', description:'Own first-round pick (cannot be selection 1 per supplied RealGM summary).', conditional:true),
        NbaFutureDraftAsset(id:'WAS-2028-1-COMPLEX', team:'WAS', year:2028, round:1, label:'2028 complex first', description:'Washington participates in Brooklyn/Philadelphia/Phoenix plus Milwaukee/Portland swap tree.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'WAS-2029-1-POR-BOS-MIL', team:'WAS', year:2029, round:1, label:'2029 first interests', description:'Washington owns its first plus second-most favorable among Portland/Boston/Milwaukee.', conditional:true),
        NbaFutureDraftAsset(id:'WAS-2030-1-COMPLEX', team:'WAS', year:2030, round:1, label:'2030 complex first', description:'Washington/Phoenix/Memphis swap structure.', conditional:true, swapRight:true),
        NbaFutureDraftAsset(id:'WAS-2031-1', team:'WAS', year:2031, round:1, label:'2031 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'WAS-2032-1', team:'WAS', year:2032, round:1, label:'2032 1st', description:'Own first-round pick.', stepienSafe:true),
        NbaFutureDraftAsset(id:'WAS-2033-1', team:'WAS', year:2033, round:1, label:'2033 1st', description:'Own first-round pick.', stepienSafe:true),
      ];

  List<NbaFutureDraftAsset> forTeam(String team) =>
      all().where((asset) => asset.team == team).toList()
        ..sort((a, b) => a.year.compareTo(b.year));
}
