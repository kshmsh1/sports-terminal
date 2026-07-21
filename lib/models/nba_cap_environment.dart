class NbaCapEnvironment {
  const NbaCapEnvironment({
    required this.season,
    required this.effectiveDate,
    required this.salaryCap,
    required this.taxLevel,
    required this.minimumTeamSalary,
    required this.firstApron,
    required this.secondApron,
    required this.nonTaxpayerMle,
    required this.taxpayerMle,
    required this.roomMle,
    required this.sourceLabel,
    required this.sourceUrl,
  });

  final String season;
  final String effectiveDate;
  final double salaryCap;
  final double taxLevel;
  final double minimumTeamSalary;
  final double firstApron;
  final double secondApron;
  final double nonTaxpayerMle;
  final double taxpayerMle;
  final double roomMle;
  final String sourceLabel;
  final String sourceUrl;

  factory NbaCapEnvironment.fromJson(Map<String, dynamic> json) {
    double money(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return NbaCapEnvironment(
      season: json['season']?.toString() ?? '',
      effectiveDate: json['effectiveDate']?.toString() ?? '',
      salaryCap: money('salaryCap'),
      taxLevel: money('taxLevel'),
      minimumTeamSalary: money('minimumTeamSalary'),
      firstApron: money('firstApron'),
      secondApron: money('secondApron'),
      nonTaxpayerMle: money('nonTaxpayerMle'),
      taxpayerMle: money('taxpayerMle'),
      roomMle: money('roomMle'),
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'season': season,
        'effectiveDate': effectiveDate,
        'salaryCap': salaryCap,
        'taxLevel': taxLevel,
        'minimumTeamSalary': minimumTeamSalary,
        'firstApron': firstApron,
        'secondApron': secondApron,
        'nonTaxpayerMle': nonTaxpayerMle,
        'taxpayerMle': taxpayerMle,
        'roomMle': roomMle,
        'sourceLabel': sourceLabel,
        'sourceUrl': sourceUrl,
      };

  NbaCapPosition positionFor(double teamSalary) {
    return NbaCapPosition(environment: this, teamSalary: teamSalary);
  }
}

class NbaCapPosition {
  const NbaCapPosition({
    required this.environment,
    required this.teamSalary,
  });

  final NbaCapEnvironment environment;
  final double teamSalary;

  double get capRoom => environment.salaryCap - teamSalary;
  double get taxRoom => environment.taxLevel - teamSalary;
  double get firstApronRoom => environment.firstApron - teamSalary;
  double get secondApronRoom => environment.secondApron - teamSalary;
  double get minimumSalaryGap => environment.minimumTeamSalary - teamSalary;

  bool get belowMinimum => teamSalary < environment.minimumTeamSalary;
  bool get overCap => teamSalary > environment.salaryCap;
  bool get overTax => teamSalary > environment.taxLevel;
  bool get overFirstApron => teamSalary > environment.firstApron;
  bool get overSecondApron => teamSalary > environment.secondApron;

  String get tier {
    if (overSecondApron) return 'Above second apron';
    if (overFirstApron) return 'Above first apron';
    if (overTax) return 'Tax team';
    if (overCap) return 'Over-cap / below-tax';
    if (belowMinimum) return 'Below minimum team salary';
    return 'Cap-space team';
  }

  Map<String, dynamic> toRow() => {
        'season': environment.season,
        'modeled_team_salary': teamSalary,
        'salary_cap': environment.salaryCap,
        'tax_level': environment.taxLevel,
        'first_apron': environment.firstApron,
        'second_apron': environment.secondApron,
        'cap_room': capRoom,
        'tax_room': taxRoom,
        'first_apron_room': firstApronRoom,
        'second_apron_room': secondApronRoom,
        'tier': tier,
        'source': environment.sourceLabel,
      };
}
