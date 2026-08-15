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
    await store.saveString(
      storageKey,
      jsonEncode([for (final item in objects.take(200)) item.toJson()]),
    );
  }

  ResearchObject reproduce(ResearchObject source) {
    // Reproduction intentionally preserves release, query, filters and code.
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
    );
  }
}
