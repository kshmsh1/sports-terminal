import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/research_object.dart';
import 'package:sports_terminal/services/terminal_research_bundle_service.dart';

void main() {
  test('research bundle fingerprint ignores wrapper id and build timestamp', () {
    const service = TerminalResearchBundleService();
    const research = ResearchObject(
      id: 'r1',
      version: 1,
      title: 'Portable Research',
      authorId: 'analyst',
      createdAtIso: '2026-08-15T17:00:00Z',
      dataRelease: 'release-1',
      queryDefinitions: [],
      selectedEntities: [],
      filters: {},
      computedMetrics: [],
      chartSpecs: [],
      methodNotes: 'Exact release.',
      citations: [],
      contentFingerprint: 'research-content',
    );

    final first = service.compile(
      research: research,
      bundleId: 'bundle-a',
      createdAtIso: '2026-08-15T18:00:00Z',
    );
    final second = service.compile(
      research: research,
      bundleId: 'bundle-b',
      createdAtIso: '2026-08-16T18:00:00Z',
    );

    expect(first.fingerprint, second.fingerprint);
    expect(service.integrityFailures(first), isEmpty);
    expect(service.integrityFailures(second), isEmpty);
  });
}
