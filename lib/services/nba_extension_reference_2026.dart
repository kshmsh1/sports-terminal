enum NbaExtensionType { rookieScale, veteran }

class NbaExtensionRecord {
  const NbaExtensionRecord({
    required this.player,
    required this.team,
    required this.type,
    required this.startsSeason,
    required this.years,
    required this.reportedTotal,
    this.playerOption = false,
    this.teamOption = false,
    this.mutualOption = false,
    this.tradeKickerPercent,
    this.note = '',
  });

  final String player;
  final String team;
  final NbaExtensionType type;
  final String startsSeason;
  final int years;
  final double reportedTotal;
  final bool playerOption;
  final bool teamOption;
  final bool mutualOption;
  final double? tradeKickerPercent;
  final String note;
}

class NbaExtensionReference202627 {
  const NbaExtensionReference202627._();

  static const List<NbaExtensionRecord> records = [
    NbaExtensionRecord(player:'Victor Wembanyama', team:'SAS', type:NbaExtensionType.rookieScale, startsSeason:'2027-28', years:5, reportedTotal:255200000, playerOption:true, tradeKickerPercent:15, note:'Projected maximum-salary value; actual depends on 2027-28 cap.'),
    NbaExtensionRecord(player:'Amen Thompson', team:'HOU', type:NbaExtensionType.rookieScale, startsSeason:'2027-28', years:5, reportedTotal:208000000, tradeKickerPercent:10),
    NbaExtensionRecord(player:'Keyonte George', team:'UTA', type:NbaExtensionType.rookieScale, startsSeason:'2027-28', years:5, reportedTotal:155000000, note:'Includes \$2.5M incentives; exact details to be confirmed.'),
    NbaExtensionRecord(player:'Ausar Thompson', team:'DET', type:NbaExtensionType.rookieScale, startsSeason:'2027-28', years:5, reportedTotal:155000000, note:'Exact details to be confirmed.'),
    NbaExtensionRecord(player:'Donovan Mitchell', team:'CLE', type:NbaExtensionType.veteran, startsSeason:'2027-28', years:4, reportedTotal:275968000, playerOption:true, tradeKickerPercent:15, note:'Projected maximum-salary value; actual depends on 2027-28 cap.'),
    NbaExtensionRecord(player:'Dillon Brooks', team:'PHO', type:NbaExtensionType.veteran, startsSeason:'2027-28', years:3, reportedTotal:72999999),
    NbaExtensionRecord(player:'Pelle Larsson', team:'MIA', type:NbaExtensionType.veteran, startsSeason:'2027-28', years:4, reportedTotal:60000000, mutualOption:true, note:'Exact details to be confirmed.'),
    NbaExtensionRecord(player:'Neemias Queta', team:'BOS', type:NbaExtensionType.veteran, startsSeason:'2027-28', years:4, reportedTotal:56000000),
    NbaExtensionRecord(player:'Saddiq Bey', team:'NOP', type:NbaExtensionType.veteran, startsSeason:'2027-28', years:3, reportedTotal:55500000, note:'Trade kicker is lesser of \$1M and 15%; exact details to be confirmed.'),
    NbaExtensionRecord(player:'Naji Marshall', team:'DAL', type:NbaExtensionType.veteran, startsSeason:'2027-28', years:3, reportedTotal:52200000),
    NbaExtensionRecord(player:'Andrew Wiggins', team:'MIA', type:NbaExtensionType.veteran, startsSeason:'2027-28', years:2, reportedTotal:33830356, playerOption:true),
    NbaExtensionRecord(player:'Jordan Walsh', team:'BOS', type:NbaExtensionType.veteran, startsSeason:'2027-28', years:3, reportedTotal:15750000, teamOption:true),
  ];
}
