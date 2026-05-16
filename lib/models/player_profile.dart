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

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      position: json['position'] as String?,
      height: json['height'] as String?,
      weightPounds: json['weightPounds'] as int?,
      birthDate: json['birthDate'] as String?,
      birthCountry: json['birthCountry'] as String?,
      college: json['college'] as String?,
      draftYear: json['draftYear'] as int?,
      draftRound: json['draftRound'] as int?,
      draftPick: json['draftPick'] as int?,
      nbaDebutYear: json['nbaDebutYear'] as int?,
      isActive: json['isActive'] as bool?,
      primaryTeamAbbreviation: json['primaryTeamAbbreviation'] as String?,
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
    );
  }

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'position': position,
      'height': height,
      'weightPounds': weightPounds,
      'birthDate': birthDate,
      'birthCountry': birthCountry,
      'college': college,
      'draftYear': draftYear,
      'draftRound': draftRound,
      'draftPick': draftPick,
      'nbaDebutYear': nbaDebutYear,
      'isActive': isActive,
      'primaryTeamAbbreviation': primaryTeamAbbreviation,
      'sourceId': sourceId,
      'asOf': asOf,
    };
  }
}
