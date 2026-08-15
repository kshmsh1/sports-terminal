import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/data_rights_envelope.dart';
import 'package:sports_terminal/models/research_object.dart';
import 'package:sports_terminal/models/terminal_action.dart';
import 'package:sports_terminal/models/terminal_board.dart';
import 'package:sports_terminal/models/universal_query.dart';
import 'package:sports_terminal/services/query_continuity_service.dart';
import 'package:sports_terminal/services/research_object_service.dart';
import 'package:sports_terminal/services/terminal_command_engine.dart';

void main() {
  test('derived rights use the most restrictive input permissions', () {
    const left = DataRightsEnvelope(
      sourceId: 'licensed',
      licenseClass: TerminalLicenseClass.licensedThirdParty,
      display: TerminalDataPermission.allowed,
      export: TerminalDataPermission.allowed,
      api: TerminalDataPermission.conditional,
      redistribution: TerminalDataPermission.denied,
      territories: ['US', 'CA'],
    );
    const right = DataRightsEnvelope(
      sourceId: 'partner',
      licenseClass: TerminalLicenseClass.partnerModel,
      display: TerminalDataPermission.allowed,
      export: TerminalDataPermission.denied,
      api: TerminalDataPermission.allowed,
      redistribution: TerminalDataPermission.allowed,
      territories: ['US', 'GB'],
    );

    final derived = left.intersect(right);
    expect(derived.display, TerminalDataPermission.allowed);
    expect(derived.export, TerminalDataPermission.denied);
    expect(derived.api, TerminalDataPermission.conditional);
    expect(derived.redistribution, TerminalDataPermission.denied);
    expect(derived.territories, ['US']);
  });

  test('universal query remains inspectable through route continuity', () {
    const query = UniversalQuery(
      sport: 'basketball',
      league: 'NBA',
      objectType: 'player-season',
      metrics: ['pts_per_game', 'true_shooting_pct'],
      filters: [
        UniversalQueryFilter(field: 'age', op: '<', value: 25),
        UniversalQueryFilter(field: 'pts_per_game', op: '>=', value: 20),
      ],
      seasons: ['2024-25', '2025-26'],
      naturalLanguage: 'guards under 25 scoring at least 20',
      release: 'NBA-HISTORICAL-2026.08.15',
    );

    final payload = const QueryContinuityService().package(
      query,
      targetRoute: 'Python Lab',
    );
    expect(payload.readinessState, 'Ready');
    expect(payload.metadata['query'], query.toJson());
    expect(payload.filterSummary, contains('age<25'));
    expect(payload.sourceSnapshot, 'NBA-HISTORICAL-2026.08.15');
  });

  test('command engine separates operations, entities and free queries', () {
    const engine = TerminalCommandEngine();
    const entries = [
      TerminalCommandEntry(
        id: 'nba-terminal',
        label: 'NBA Terminal',
        kind: 'workspace',
        aliases: ['NBA'],
      ),
    ];

    final operation = engine.interpret('COMPARE Jokic', entries);
    expect(operation.mode, 'operation');
    expect(operation.action?.kind, TerminalActionKind.compare);
    expect(operation.query, 'Jokic');

    final entity = engine.interpret('NBA', entries);
    expect(entity.mode, 'entity');
    expect(entity.entry?.id, 'nba-terminal');

    final query = engine.interpret('players ppg > 25', entries);
    expect(query.mode, 'query');
    expect(query.action?.kind, TerminalActionKind.query);
  });

  test('research reproduction preserves release and fork records lineage', () {
    const source = ResearchObject(
      id: 'research-1',
      version: 3,
      title: 'Half-court defense study',
      authorId: 'analyst-1',
      createdAtIso: '2026-08-15T00:00:00Z',
      dataRelease: 'NBA-HISTORICAL-2026.08.15',
      queryDefinitions: [],
      selectedEntities: [],
      filters: {},
      computedMetrics: [],
      chartSpecs: [],
      methodNotes: 'Observed evidence only.',
      citations: [],
    );

    const service = ResearchObjectService();
    final reproduced = service.reproduce(source);
    expect(reproduced.revisionKey, source.revisionKey);
    expect(reproduced.dataRelease, source.dataRelease);

    final fork = service.fork(
      source,
      newId: 'research-2',
      authorId: 'analyst-2',
      dataRelease: 'NBA-HISTORICAL-2026.08.16',
      currentData: true,
    );
    expect(fork.parentResearchId, source.id);
    expect(fork.parentVersion, source.version);
    expect(fork.dataRelease, 'NBA-HISTORICAL-2026.08.16');
    expect(fork.published, isFalse);
  });

  test('board serialization preserves workflow state', () {
    const board = TerminalBoard(
      id: 'board-1',
      title: 'Morning NBA Board',
      updatedAtIso: '2026-08-15T00:00:00Z',
      filters: {'season': '2025-26'},
      collaborators: ['analyst-1'],
      liveRefresh: true,
      panels: [
        TerminalBoardPanel(
          id: 'panel-1',
          kind: 'query',
          title: 'Watched Players',
          payload: {'queryId': 'q-1'},
          width: 2,
        ),
      ],
    );

    final roundTrip = TerminalBoard.fromJson(board.toJson());
    expect(roundTrip.title, board.title);
    expect(roundTrip.filters['season'], '2025-26');
    expect(roundTrip.panels.single.width, 2);
    expect(roundTrip.liveRefresh, isTrue);
  });
}
