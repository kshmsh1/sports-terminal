import 'dart:convert';

class UniversalQueryFilter {
  const UniversalQueryFilter({
    required this.field,
    required this.operator,
    required this.value,
  });

  final String field;
  final String operator;
  final Object? value;

  Map<String, dynamic> toJson() => {
        'field': field,
        'operator': operator,
        'value': value,
      };

  factory UniversalQueryFilter.fromJson(Map<String, dynamic> json) => UniversalQueryFilter(
        field: json['field']?.toString() ?? '',
        operator: json['operator']?.toString() ?? '=',
        value: json['value'],
      );
}

class UniversalQuery {
  const UniversalQuery({
    required this.sport,
    required this.league,
    required this.objectType,
    required this.metrics,
    required this.filters,
    this.seasons = const [],
    this.seasonType = 'regular',
    this.groupBy = const [],
    this.sort = const [],
    this.limit = 100,
    this.naturalLanguage = '',
    this.release = '',
  });

  final String sport;
  final String league;
  final String objectType;
  final List<String> metrics;
  final List<UniversalQueryFilter> filters;
  final List<String> seasons;
  final String seasonType;
  final List<String> groupBy;
  final List<String> sort;
  final int limit;
  final String naturalLanguage;
  final String release;

  String get signature => jsonEncode(toJson());

  UniversalQuery copyWith({
    List<String>? metrics,
    List<UniversalQueryFilter>? filters,
    List<String>? seasons,
    String? seasonType,
    List<String>? groupBy,
    List<String>? sort,
    int? limit,
    String? naturalLanguage,
    String? release,
  }) => UniversalQuery(
        sport: sport,
        league: league,
        objectType: objectType,
        metrics: metrics ?? this.metrics,
        filters: filters ?? this.filters,
        seasons: seasons ?? this.seasons,
        seasonType: seasonType ?? this.seasonType,
        groupBy: groupBy ?? this.groupBy,
        sort: sort ?? this.sort,
        limit: limit ?? this.limit,
        naturalLanguage: naturalLanguage ?? this.naturalLanguage,
        release: release ?? this.release,
      );

  Map<String, dynamic> toJson() => {
        'sport': sport,
        'league': league,
        'objectType': objectType,
        'metrics': metrics,
        'filters': [for (final filter in filters) filter.toJson()],
        'seasons': seasons,
        'seasonType': seasonType,
        'groupBy': groupBy,
        'sort': sort,
        'limit': limit,
        'naturalLanguage': naturalLanguage,
        'release': release,
      };

  factory UniversalQuery.fromJson(Map<String, dynamic> json) => UniversalQuery(
        sport: json['sport']?.toString() ?? '',
        league: json['league']?.toString() ?? '',
        objectType: json['objectType']?.toString() ?? '',
        metrics: json['metrics'] is List
            ? [for (final value in json['metrics'] as List) value.toString()]
            : const [],
        filters: json['filters'] is List
            ? [
                for (final raw in json['filters'] as List)
                  if (raw is Map)
                    UniversalQueryFilter.fromJson(
                      raw.map((key, value) => MapEntry(key.toString(), value)),
                    ),
              ]
            : const [],
        seasons: json['seasons'] is List
            ? [for (final value in json['seasons'] as List) value.toString()]
            : const [],
        seasonType: json['seasonType']?.toString() ?? 'regular',
        groupBy: json['groupBy'] is List
            ? [for (final value in json['groupBy'] as List) value.toString()]
            : const [],
        sort: json['sort'] is List
            ? [for (final value in json['sort'] as List) value.toString()]
            : const [],
        limit: (json['limit'] as num?)?.toInt() ?? 100,
        naturalLanguage: json['naturalLanguage']?.toString() ?? '',
        release: json['release']?.toString() ?? '',
      );
}
