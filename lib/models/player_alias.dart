class PlayerAlias {
  const PlayerAlias({
    required this.playerId,
    required this.alias,
    required this.aliasType,
    this.providerId,
    this.providerName,
    this.effectiveFrom,
    this.effectiveTo,
    this.sourceId,
    this.asOf,
    this.notes,
  });

  factory PlayerAlias.fromJson(Map<String, dynamic> json) {
    return PlayerAlias(
      playerId: json['playerId'] as String,
      alias: json['alias'] as String,
      aliasType: json['aliasType'] as String,
      providerId: json['providerId'] as String?,
      providerName: json['providerName'] as String?,
      effectiveFrom: json['effectiveFrom'] as String?,
      effectiveTo: json['effectiveTo'] as String?,
      sourceId: json['sourceId'] as String?,
      asOf: json['asOf'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String playerId;
  final String alias;
  final String aliasType;
  final String? providerId;
  final String? providerName;
  final String? effectiveFrom;
  final String? effectiveTo;
  final String? sourceId;
  final String? asOf;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'alias': alias,
        'aliasType': aliasType,
        'providerId': providerId,
        'providerName': providerName,
        'effectiveFrom': effectiveFrom,
        'effectiveTo': effectiveTo,
        'sourceId': sourceId,
        'asOf': asOf,
        'notes': notes,
      };
}
