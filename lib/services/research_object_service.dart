import 'dart:convert';

import '../models/research_object.dart';
import 'product_local_store.dart';

class ResearchObjectService {
  const ResearchObjectService({this.store = const ProductLocalStore()});

  static const storageKey = 'sports_terminal.research.objects.v1';
  final ProductLocalStore store;

  Future<List<ResearchObject>> loadAll() async {
    final raw = await store.loadString(storageKey);
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final results = <ResearchObject>[];
      for (final item in decoded) {
        if (item is Map) {
          results.add(ResearchObject.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      }
      results.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(ResearchObject object) async {
    final objects = (await loadAll()).toList();
    final revision = object.revisionKey;
    if (objects.any((item) => item.revisionKey == revision)) {
      throw StateError('Research revisions are immutable: $revision already exists.');
    }
    objects.insert(0, object);
    await _write(objects.take(500).toList(growable: false));
  }

  Future<ResearchObject> saveIfNewFingerprint(ResearchObject object) async {
    if (object.contentFingerprint.trim().isNotEmpty) {
      final existing = await findByFingerprint(object.contentFingerprint);
      if (existing != null) return existing;
    }
    await save(object);
    return object;
  }

  Future<ResearchObject?> findByFingerprint(String fingerprint) async {
    final normalized = fingerprint.trim();
    if (normalized.isEmpty) return null;
    for (final object in await loadAll()) {
      if (object.contentFingerprint == normalized) return object;
    }
    return null;
  }

  Future<List<ResearchObject>> find(
    String query, {
    String tag = '',
    String status = '',
    String release = '',
    String artifactType = '',
    bool latestOnly = true,
  }) async {
    final source = latestOnly ? await latestAll() : await loadAll();
    final normalized = query.trim().toLowerCase();
    final normalizedTag = tag.trim().toLowerCase();
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedRelease = release.trim().toLowerCase();
    final normalizedType = artifactType.trim().toLowerCase();
    return source.where((item) {
      final searchable = <String>[
        item.title,
        item.summary,
        item.authorId,
        item.dataRelease,
        item.artifactType,
        item.status,
        item.contentFingerprint,
        ...item.tags,
      ].join(' ').toLowerCase();
      return (normalized.isEmpty || searchable.contains(normalized)) &&
          (normalizedTag.isEmpty ||
              item.tags.any((value) => value.toLowerCase() == normalizedTag)) &&
          (normalizedStatus.isEmpty || item.status.toLowerCase() == normalizedStatus) &&
          (normalizedRelease.isEmpty || item.dataRelease.toLowerCase().contains(normalizedRelease)) &&
          (normalizedType.isEmpty || item.artifactType.toLowerCase() == normalizedType);
    }).toList(growable: false);
  }

  Future<List<ResearchObject>> latestAll() async {
    final objects = await loadAll();
    final latest = <String, ResearchObject>{};
    for (final object in objects) {
      final current = latest[object.id];
      if (current == null || object.version > current.version) {
        latest[object.id] = object;
      }
    }
    final results = latest.values.toList()
      ..sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
    return results;
  }

  Future<ResearchObject?> latest(String id) async {
    ResearchObject? latestObject;
    for (final object in await loadAll()) {
      if (object.id != id) continue;
      if (latestObject == null || object.version > latestObject.version) {
        latestObject = object;
      }
    }
    return latestObject;
  }

  Future<List<ResearchObject>> lineage(String id) async {
    final results = (await loadAll()).where((item) => item.id == id).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    return results;
  }

  Future<int> nextVersion(String id) async {
    final current = await latest(id);
    return (current?.version ?? 0) + 1;
  }

  ResearchObject revise(
    ResearchObject source, {
    String? title,
    String? dataRelease,
    String? methodNotes,
    List<String>? tags,
    String? status,
    Map<String, dynamic>? artifactPayload,
    List<Map<String, dynamic>>? rightsEnvelopes,
    String? summary,
    String? contentFingerprint,
  }) {
    return ResearchObject(
      id: source.id,
      version: source.version + 1,
      title: title ?? source.title,
      authorId: source.authorId,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      dataRelease: dataRelease ?? source.dataRelease,
      queryDefinitions: source.queryDefinitions,
      selectedEntities: source.selectedEntities,
      filters: source.filters,
      computedMetrics: source.computedMetrics,
      chartSpecs: source.chartSpecs,
      methodNotes: methodNotes ?? source.methodNotes,
      citations: source.citations,
      parentResearchId: source.parentResearchId,
      parentVersion: source.parentVersion,
      code: source.code,
      discussionId: source.discussionId,
      published: source.published,
      schemaVersion: 2,
      artifactType: source.artifactType,
      artifactPayload: artifactPayload ?? source.artifactPayload,
      tags: tags ?? source.tags,
      status: status ?? source.status,
      contentFingerprint: contentFingerprint ?? source.contentFingerprint,
      rightsEnvelopes: rightsEnvelopes ?? source.rightsEnvelopes,
      summary: summary ?? source.summary,
      previousRevisionKey: source.revisionKey,
    );
  }

  ResearchObject reproduce(ResearchObject source) {
    return ResearchObject(
      id: source.id,
      version: source.version,
      title: source.title,
      authorId: source.authorId,
      createdAtIso: source.createdAtIso,
      dataRelease: source.dataRelease,
      queryDefinitions: source.queryDefinitions,
      selectedEntities: source.selectedEntities,
      filters: source.filters,
      computedMetrics: source.computedMetrics,
      chartSpecs: source.chartSpecs,
      methodNotes: source.methodNotes,
      citations: source.citations,
      parentResearchId: source.parentResearchId,
      parentVersion: source.parentVersion,
      code: source.code,
      discussionId: source.discussionId,
      published: source.published,
      schemaVersion: source.schemaVersion,
      artifactType: source.artifactType,
      artifactPayload: source.artifactPayload,
      tags: source.tags,
      status: source.status,
      contentFingerprint: source.contentFingerprint,
      rightsEnvelopes: source.rightsEnvelopes,
      summary: source.summary,
      previousRevisionKey: source.previousRevisionKey,
    );
  }

  ResearchObject fork(
    ResearchObject source, {
    required String newId,
    required String authorId,
    required String dataRelease,
    bool currentData = false,
  }) {
    final release = currentData ? dataRelease.trim() : source.dataRelease;
    if (release.isEmpty) {
      throw ArgumentError('A fork must retain or select an explicit data release.');
    }
    return ResearchObject(
      id: newId,
      version: 1,
      title: '${source.title} · Fork',
      authorId: authorId,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      dataRelease: release,
      queryDefinitions: source.queryDefinitions,
      selectedEntities: source.selectedEntities,
      filters: source.filters,
      computedMetrics: source.computedMetrics,
      chartSpecs: source.chartSpecs,
      methodNotes: source.methodNotes,
      citations: source.citations,
      parentResearchId: source.id,
      parentVersion: source.version,
      code: source.code,
      discussionId: '',
      published: false,
      schemaVersion: 2,
      artifactType: source.artifactType,
      artifactPayload: source.artifactPayload,
      tags: source.tags,
      status: 'draft',
      contentFingerprint: source.contentFingerprint,
      rightsEnvelopes: source.rightsEnvelopes,
      summary: source.summary,
    );
  }

  Future<String> exportJson({bool latestOnly = false}) async {
    final objects = latestOnly ? await latestAll() : await loadAll();
    return const JsonEncoder.withIndent('  ')
        .convert([for (final item in objects) item.toJson()]);
  }

  Future<void> _write(List<ResearchObject> objects) => store.saveString(
        storageKey,
        jsonEncode([for (final item in objects) item.toJson()]),
      );
}
