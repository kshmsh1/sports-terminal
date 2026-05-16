class Team {
  const Team({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.city,
    required this.conference,
    required this.division,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String,
      city: json['city'] as String,
      conference: json['conference'] as String,
      division: json['division'] as String,
    );
  }

  final String id;
  final String name;
  final String abbreviation;
  final String city;
  final String conference;
  final String division;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'abbreviation': abbreviation,
      'city': city,
      'conference': conference,
      'division': division,
    };
  }
}
