class StandingsRecord {
  const StandingsRecord({
    required this.id,
    required this.teamId,
    required this.seasonId,
    this.conference,
    this.division,
    this.seed,
    this.wins,
    this.losses,
    this.winPercentage,
    this.gamesBack,
    this.sourceId,
    this.asOf,
  });

  factory StandingsRecord.fromJson(Map<String, dynamic> json) {
    return StandingsRecord(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      seasonId: json['seasonId'] as String,
      conference: json['conference'] as String?,
      division: json['division'] as String?,
      seed: json['seed'] as int?,
      wins: json['wins'] as int?,
      losses: json['losses'] as int?,
      winPercentage: (json['winPercentage'] as num?)?.toDouble(),
      gamesBack: (json['gamesBack'] as num?)?.toDouble(),
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

  final String id;
  final String teamId;
  final String seasonId;
  final String? conference;
  final String? division;
  final int? seed;
  final int? wins;
  final int? losses;
  final double? winPercentage;
  final double? gamesBack;
  final String? sourceId;
  final String? asOf;
}
