class Season {
  const Season({
    required this.id,
    required this.label,
    required this.startYear,
    required this.endYear,
    required this.league,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] as String,
      label: json['label'] as String,
      startYear: json['startYear'] as int,
      endYear: json['endYear'] as int,
      league: json['league'] as String,
    );
  }

  final String id;
  final String label;
  final int startYear;
  final int endYear;
  final String league;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'startYear': startYear,
      'endYear': endYear,
      'league': league,
    };
  }
}
