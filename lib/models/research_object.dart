import 'dart:convert';

class ResearchObject {
  const ResearchObject({
    required this.id,
    required this.version,
    required this.title,
    required this.authorId,
    required this.createdAtIso,
    required this.dataRelease,
    required this.queryDefinitions,
    required this.selectedEntities,
    required this.filters,
    required this.computedMetrics,
    required this.chartSpecs,
    required this.methodNotes,
    required this.citations,
    this.parentResearchId = '',
    this.parentVersion = 0,
    this.code = '',
    this.discussionId = '',
    this.published = false,
  });

  final String id;
  final int version;
  final String title;
  final String authorId;
  final String createdAtIso;
  final String dataRelease;
  final List<Map<String, dynamic>> queryDefinitions;
  final List<Map<String, dynamic>> selectedEntities;
  final Map<String, dynamic> filters;
  final List<Map<String, dynamic>> computedMetrics;
  final List<Map<String, dynamic>> chartSpecs;
  final String methodNotes;
  final List<Map<String, dynamic>> citations;
  final String parentResearchId;
  final int parentVersion;
  final String code;
  final String discussionId;
  final bool published;

  String get revisionKey => '$id@$version';
  bool get isFork => parentResearchId.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'title': title,
        'authorId': authorId,
        'createdAtIso': createdAtIso,
        'dataRelease': dataRelease,
        'queryDefinitions': queryDefinitions,
        'selectedEntities': selectedEntities,
        'filters': filters,
        'computedMetrics': computedMetrics,
        'chartSpecs': chartSpecs,
        'methodNotes': methodNotes,
        'citations': citations,
        'parentResearchId': parentResearchId,
        'parentVersion': parentVersion,
        'code': code,
        'discussionId': discussionId,
        'published': published,
      };

  factory ResearchObject.fromJson(Map<String, dynamic> json) => ResearchObject(
        id: json['id']?.toString() ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
        title: json['title']?.toString() ?? 'Untitled Research',
        authorId: json['authorId']?.toString() ?? '',
        createdAtIso: json['createdAtIso']?.toString() ?? '',
        dataRelease: json['dataRelease']?.toString() ?? '',
        queryDefinitions: _mapList(json['queryDefinitions']),
        selectedEntities: _mapList(json['selectedEntities']),
        filters: _stringMap(json['filters']),
        computedMetrics: _mapList(json['computedMetrics']),
        chartSpecs: _mapList(json['chartSpecs']),
        methodNotes: json['methodNotes']?.toString() ?? '',
        citations: _mapList(json['citations']),
        parentResearchId: json['parentResearchId']?.toString() ?? '',
        parentVersion: (json['parentVersion'] as num?)?.toInt() ?? 0,
        code: json['code']?.toString() ?? '',
        discussionId: json['discussionId']?.toString() ?? '',
        published: json['published'] == true,
      );

  String encode() => jsonEncode(toJson());
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

Map<String, dynamic> _stringMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map((key, value) => MapEntry(key.toString(), value));
}
