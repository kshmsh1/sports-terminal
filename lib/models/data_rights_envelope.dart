enum TerminalLicenseClass {
  official,
  licensedThirdParty,
  terminalDerived,
  partnerModel,
  communityResearch,
  userProvided,
  developmentOnly,
  unknown,
}

enum TerminalDataPermission { allowed, denied, conditional, unknown }

class DataRightsEnvelope {
  const DataRightsEnvelope({
    required this.sourceId,
    required this.licenseClass,
    required this.display,
    required this.export,
    required this.api,
    required this.redistribution,
    this.sourceRecordId = '',
    this.sourceRevision = '',
    this.ingestionRelease = '',
    this.derivationId = '',
    this.validTimeIso = '',
    this.observedAtIso = '',
    this.retentionRule = '',
    this.territories = const [],
    this.notes = '',
  });

  final String sourceId;
  final TerminalLicenseClass licenseClass;
  final TerminalDataPermission display;
  final TerminalDataPermission export;
  final TerminalDataPermission api;
  final TerminalDataPermission redistribution;
  final String sourceRecordId;
  final String sourceRevision;
  final String ingestionRelease;
  final String derivationId;
  final String validTimeIso;
  final String observedAtIso;
  final String retentionRule;
  final List<String> territories;
  final String notes;

  bool get canDisplay => display == TerminalDataPermission.allowed;
  bool get canExport => export == TerminalDataPermission.allowed;
  bool get canServeApi => api == TerminalDataPermission.allowed;
  bool get canRedistribute => redistribution == TerminalDataPermission.allowed;

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'licenseClass': licenseClass.name,
        'display': display.name,
        'export': export.name,
        'api': api.name,
        'redistribution': redistribution.name,
        'sourceRecordId': sourceRecordId,
        'sourceRevision': sourceRevision,
        'ingestionRelease': ingestionRelease,
        'derivationId': derivationId,
        'validTimeIso': validTimeIso,
        'observedAtIso': observedAtIso,
        'retentionRule': retentionRule,
        'territories': territories,
        'notes': notes,
      };

  factory DataRightsEnvelope.fromJson(Map<String, dynamic> json) => DataRightsEnvelope(
        sourceId: json['sourceId']?.toString() ?? '',
        licenseClass: _enumByName(
          TerminalLicenseClass.values,
          json['licenseClass']?.toString(),
          TerminalLicenseClass.unknown,
        ),
        display: _permission(json['display']),
        export: _permission(json['export']),
        api: _permission(json['api']),
        redistribution: _permission(json['redistribution']),
        sourceRecordId: json['sourceRecordId']?.toString() ?? '',
        sourceRevision: json['sourceRevision']?.toString() ?? '',
        ingestionRelease: json['ingestionRelease']?.toString() ?? '',
        derivationId: json['derivationId']?.toString() ?? '',
        validTimeIso: json['validTimeIso']?.toString() ?? '',
        observedAtIso: json['observedAtIso']?.toString() ?? '',
        retentionRule: json['retentionRule']?.toString() ?? '',
        territories: json['territories'] is List
            ? [for (final value in json['territories'] as List) value.toString()]
            : const [],
        notes: json['notes']?.toString() ?? '',
      );

  DataRightsEnvelope intersect(DataRightsEnvelope other) => DataRightsEnvelope(
        sourceId: '$sourceId+${other.sourceId}',
        licenseClass: TerminalLicenseClass.terminalDerived,
        display: _mostRestrictive(display, other.display),
        export: _mostRestrictive(export, other.export),
        api: _mostRestrictive(api, other.api),
        redistribution: _mostRestrictive(redistribution, other.redistribution),
        ingestionRelease: ingestionRelease == other.ingestionRelease
            ? ingestionRelease
            : '$ingestionRelease|${other.ingestionRelease}',
        observedAtIso: observedAtIso.compareTo(other.observedAtIso) >= 0
            ? observedAtIso
            : other.observedAtIso,
        territories: territories.isEmpty
            ? other.territories
            : other.territories.isEmpty
                ? territories
                : territories.where(other.territories.contains).toList(growable: false),
        notes: 'Derived rights are the restrictive intersection of all inputs.',
      );
}

TerminalDataPermission _permission(dynamic value) => _enumByName(
      TerminalDataPermission.values,
      value?.toString(),
      TerminalDataPermission.unknown,
    );

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

TerminalDataPermission _mostRestrictive(
  TerminalDataPermission left,
  TerminalDataPermission right,
) {
  const rank = {
    TerminalDataPermission.allowed: 0,
    TerminalDataPermission.conditional: 1,
    TerminalDataPermission.unknown: 2,
    TerminalDataPermission.denied: 3,
  };
  return rank[left]! >= rank[right]! ? left : right;
}
