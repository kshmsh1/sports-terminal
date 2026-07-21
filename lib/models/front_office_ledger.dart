enum ContractGuarantee { full, partial, none }

enum ContractOption { none, team, player, earlyTermination, qualifyingOffer }

enum TransactionType { trade, signing, waiver, extension, optionDecision, draft }

class NbaContractYear {
  const NbaContractYear({
    required this.id,
    required this.playerLabel,
    required this.teamId,
    required this.season,
    required this.salary,
    required this.guaranteedAmount,
    this.guarantee = ContractGuarantee.full,
    this.option = ContractOption.none,
    this.tradeKickerPct = 0,
    this.noTradeClause = false,
    this.notes = '',
  });

  final String id;
  final String playerLabel;
  final String teamId;
  final String season;
  final double salary;
  final double guaranteedAmount;
  final ContractGuarantee guarantee;
  final ContractOption option;
  final double tradeKickerPct;
  final bool noTradeClause;
  final String notes;

  double get nonGuaranteedAmount => salary - guaranteedAmount;
  bool get isFullyGuaranteed => guaranteedAmount >= salary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerLabel': playerLabel,
        'teamId': teamId,
        'season': season,
        'salary': salary,
        'guaranteedAmount': guaranteedAmount,
        'guarantee': guarantee.name,
        'option': option.name,
        'tradeKickerPct': tradeKickerPct,
        'noTradeClause': noTradeClause,
        'notes': notes,
      };

  factory NbaContractYear.fromJson(Map<String, dynamic> json) => NbaContractYear(
        id: json['id']?.toString() ?? '',
        playerLabel: json['playerLabel']?.toString() ?? '',
        teamId: json['teamId']?.toString() ?? '',
        season: json['season']?.toString() ?? '',
        salary: (json['salary'] as num?)?.toDouble() ?? 0,
        guaranteedAmount: (json['guaranteedAmount'] as num?)?.toDouble() ?? 0,
        guarantee: ContractGuarantee.values.firstWhere(
          (value) => value.name == json['guarantee'],
          orElse: () => ContractGuarantee.full,
        ),
        option: ContractOption.values.firstWhere(
          (value) => value.name == json['option'],
          orElse: () => ContractOption.none,
        ),
        tradeKickerPct: (json['tradeKickerPct'] as num?)?.toDouble() ?? 0,
        noTradeClause: json['noTradeClause'] == true,
        notes: json['notes']?.toString() ?? '',
      );
}

class NbaDraftAsset {
  const NbaDraftAsset({
    required this.id,
    required this.currentOwner,
    required this.originalTeam,
    required this.year,
    required this.round,
    this.protections = 'Unspecified',
    this.swapRights = false,
    this.stepienAvailable = false,
    this.conveyanceNotes = '',
  });

  final String id;
  final String currentOwner;
  final String originalTeam;
  final int year;
  final int round;
  final String protections;
  final bool swapRights;
  final bool stepienAvailable;
  final String conveyanceNotes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'currentOwner': currentOwner,
        'originalTeam': originalTeam,
        'year': year,
        'round': round,
        'protections': protections,
        'swapRights': swapRights,
        'stepienAvailable': stepienAvailable,
        'conveyanceNotes': conveyanceNotes,
      };

  factory NbaDraftAsset.fromJson(Map<String, dynamic> json) => NbaDraftAsset(
        id: json['id']?.toString() ?? '',
        currentOwner: json['currentOwner']?.toString() ?? '',
        originalTeam: json['originalTeam']?.toString() ?? '',
        year: (json['year'] as num?)?.toInt() ?? 0,
        round: (json['round'] as num?)?.toInt() ?? 1,
        protections: json['protections']?.toString() ?? 'Unspecified',
        swapRights: json['swapRights'] == true,
        stepienAvailable: json['stepienAvailable'] == true,
        conveyanceNotes: json['conveyanceNotes']?.toString() ?? '',
      );
}

class NbaTransactionEntry {
  const NbaTransactionEntry({
    required this.id,
    required this.effectiveDate,
    required this.type,
    required this.teams,
    required this.description,
    this.assetIds = const [],
    this.cashAmount = 0,
    this.status = 'Modeled',
  });

  final String id;
  final String effectiveDate;
  final TransactionType type;
  final List<String> teams;
  final String description;
  final List<String> assetIds;
  final double cashAmount;
  final String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'effectiveDate': effectiveDate,
        'type': type.name,
        'teams': teams,
        'description': description,
        'assetIds': assetIds,
        'cashAmount': cashAmount,
        'status': status,
      };

  factory NbaTransactionEntry.fromJson(Map<String, dynamic> json) => NbaTransactionEntry(
        id: json['id']?.toString() ?? '',
        effectiveDate: json['effectiveDate']?.toString() ?? '',
        type: TransactionType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => TransactionType.trade,
        ),
        teams: [for (final value in (json['teams'] as List? ?? const [])) value.toString()],
        description: json['description']?.toString() ?? '',
        assetIds: [for (final value in (json['assetIds'] as List? ?? const [])) value.toString()],
        cashAmount: (json['cashAmount'] as num?)?.toDouble() ?? 0,
        status: json['status']?.toString() ?? 'Modeled',
      );
}

class NbaTeamLedgerInputs {
  const NbaTeamLedgerInputs({
    required this.teamId,
    required this.season,
    this.deadMoney = 0,
    this.capHolds = 0,
    this.draftCapHolds = 0,
    this.incompleteRosterCharges = 0,
    this.cashSent = 0,
    this.cashReceived = 0,
  });

  final String teamId;
  final String season;
  final double deadMoney;
  final double capHolds;
  final double draftCapHolds;
  final double incompleteRosterCharges;
  final double cashSent;
  final double cashReceived;

  double get nonContractCharges => deadMoney + capHolds + draftCapHolds + incompleteRosterCharges;

  Map<String, dynamic> toJson() => {
        'teamId': teamId,
        'season': season,
        'deadMoney': deadMoney,
        'capHolds': capHolds,
        'draftCapHolds': draftCapHolds,
        'incompleteRosterCharges': incompleteRosterCharges,
        'cashSent': cashSent,
        'cashReceived': cashReceived,
      };

  factory NbaTeamLedgerInputs.fromJson(Map<String, dynamic> json) => NbaTeamLedgerInputs(
        teamId: json['teamId']?.toString() ?? '',
        season: json['season']?.toString() ?? '',
        deadMoney: (json['deadMoney'] as num?)?.toDouble() ?? 0,
        capHolds: (json['capHolds'] as num?)?.toDouble() ?? 0,
        draftCapHolds: (json['draftCapHolds'] as num?)?.toDouble() ?? 0,
        incompleteRosterCharges: (json['incompleteRosterCharges'] as num?)?.toDouble() ?? 0,
        cashSent: (json['cashSent'] as num?)?.toDouble() ?? 0,
        cashReceived: (json['cashReceived'] as num?)?.toDouble() ?? 0,
      );
}
