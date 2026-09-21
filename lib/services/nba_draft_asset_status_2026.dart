class NbaFrozenPickRecord {
  const NbaFrozenPickRecord({
    required this.team,
    required this.pickYear,
    required this.triggerSeason,
    required this.unfreezeIfBelowSecondApronYears,
  });

  final String team;
  final int pickYear;
  final String triggerSeason;
  final List<String> unfreezeIfBelowSecondApronYears;
}

class Nba2027FirstRoundPickStatus {
  const Nba2027FirstRoundPickStatus({
    required this.team,
    required this.summary,
    this.stepienRestricted = false,
  });

  final String team;
  final String summary;
  final bool stepienRestricted;
}

class NbaDraftAssetStatus202627 {
  const NbaDraftAssetStatus202627._();

  static const List<NbaFrozenPickRecord> frozenFirsts = [
    NbaFrozenPickRecord(team:'BOS', pickYear:2032, triggerSeason:'2024-25', unfreezeIfBelowSecondApronYears:['2025-26','2026-27']),
    NbaFrozenPickRecord(team:'MIN', pickYear:2032, triggerSeason:'2024-25', unfreezeIfBelowSecondApronYears:['2025-26','2026-27']),
    NbaFrozenPickRecord(team:'PHO', pickYear:2032, triggerSeason:'2024-25', unfreezeIfBelowSecondApronYears:['2025-26','2026-27']),
    NbaFrozenPickRecord(team:'CLE', pickYear:2033, triggerSeason:'2025-26', unfreezeIfBelowSecondApronYears:['2026-27']),
  ];

  static const Map<String, Nba2027FirstRoundPickStatus> firstRound2027 = {
    'BOS': Nba2027FirstRoundPickStatus(team:'BOS', summary:'Own pick.'),
    'BKN': Nba2027FirstRoundPickStatus(team:'BKN', summary:'Own pick; Houston holds swap rights.'),
    'NYK': Nba2027FirstRoundPickStatus(team:'NYK', summary:'Traded to Brooklyn.'),
    'PHI': Nba2027FirstRoundPickStatus(team:'PHI', summary:'Own pick; 2027 cannot be freely traded because 2028 first is already traded.', stepienRestricted:true),
    'TOR': Nba2027FirstRoundPickStatus(team:'TOR', summary:'Toronto/Clippers/Thunder/Nuggets multi-pick swap structure; Toronto receives least favorable of specified comparison pair.'),
    'CHI': Nba2027FirstRoundPickStatus(team:'CHI', summary:'Own pick.'),
    'CLE': Nba2027FirstRoundPickStatus(team:'CLE', summary:'Conveyance pool with Minnesota and Utah: MEM receives most favorable, UTA second-most favorable, PHO least favorable; Utah top-five protection can alter pool.'),
    'DET': Nba2027FirstRoundPickStatus(team:'DET', summary:'Own pick.'),
    'IND': Nba2027FirstRoundPickStatus(team:'IND', summary:'Own pick.'),
    'MIL': Nba2027FirstRoundPickStatus(team:'MIL', summary:'Pelicans receive more favorable of NOP/MIL; Hawks receive less favorable, subject to top-four scenario.'),
    'ATL': Nba2027FirstRoundPickStatus(team:'ATL', summary:'Traded to San Antonio.'),
    'CHA': Nba2027FirstRoundPickStatus(team:'CHA', summary:'Own pick.'),
    'MIA': Nba2027FirstRoundPickStatus(team:'MIA', summary:'Traded to Charlotte, top-14 protected; if protected, 2028 unprotected first conveys instead.'),
    'ORL': Nba2027FirstRoundPickStatus(team:'ORL', summary:'Own pick; 2027 cannot be freely traded because 2028 first is already traded.', stepienRestricted:true),
    'WAS': Nba2027FirstRoundPickStatus(team:'WAS', summary:'Own pick.'),
    'DEN': Nba2027FirstRoundPickStatus(team:'DEN', summary:'Top-five protected; in OKC/LAC/DEN/TOR distribution structure.', stepienRestricted:false),
    'MIN': Nba2027FirstRoundPickStatus(team:'MIN', summary:'Conveyance pool with Cleveland and Utah: MEM receives most favorable, UTA second-most favorable, PHO least favorable; Utah top-five protection can alter pool.'),
    'OKC': Nba2027FirstRoundPickStatus(team:'OKC', summary:'Own pick with swap/distribution rights involving LAC, DEN and TOR.'),
    'POR': Nba2027FirstRoundPickStatus(team:'POR', summary:'Own pick.'),
    'UTA': Nba2027FirstRoundPickStatus(team:'UTA', summary:'Top-five protected in CLE/MIN/UTA conveyance pool; may be retained if top five.'),
    'GSW': Nba2027FirstRoundPickStatus(team:'GSW', summary:'Own pick.'),
    'LAC': Nba2027FirstRoundPickStatus(team:'LAC', summary:'Thunder hold swap/distribution rights; 2027 cannot be freely traded because 2028 first is already traded.', stepienRestricted:true),
    'LAL': Nba2027FirstRoundPickStatus(team:'LAL', summary:'Traded to Memphis, top-four protected; if protected, 2027 second conveys instead.'),
    'PHO': Nba2027FirstRoundPickStatus(team:'PHO', summary:'Traded to Houston.'),
    'SAC': Nba2027FirstRoundPickStatus(team:'SAC', summary:'Own pick.'),
    'DAL': Nba2027FirstRoundPickStatus(team:'DAL', summary:'Traded to Charlotte, top-two protected; if protected, Heat 2028 second conveys instead.'),
    'HOU': Nba2027FirstRoundPickStatus(team:'HOU', summary:'Own pick with right to swap for Brooklyn first.'),
    'MEM': Nba2027FirstRoundPickStatus(team:'MEM', summary:'Own pick.'),
    'NOP': Nba2027FirstRoundPickStatus(team:'NOP', summary:'Own pick with favorable swap/conveyance rights against Milwaukee.'),
    'SAS': Nba2027FirstRoundPickStatus(team:'SAS', summary:'Conveys to Sacramento if 1-16; otherwise to Oklahoma City at 17-30. If SAC receives it, SAC sends specified seconds to OKC.'),
  };
}
