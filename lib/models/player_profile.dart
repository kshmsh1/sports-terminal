class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.position,
    this.height,
    this.weightPounds,
    this.birthDate,
    this.birthCountry,
    this.college,
    this.draftYear,
    this.draftRound,
    this.draftPick,
    this.nbaDebutYear,
    this.isActive,
    this.primaryTeamAbbreviation,
    this.sourceId,
    this.asOf,
  });

  final String id;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final String? position;
  final String? height;
  final int? weightPounds;
  final String? birthDate;
  final String? birthCountry;
  final String? college;
  final int? draftYear;
  final int? draftRound;
  final int? draftPick;
  final int? nbaDebutYear;
  final bool? isActive;
  final String? primaryTeamAbbreviation;
  final String? sourceId;
  final String? asOf;
}
