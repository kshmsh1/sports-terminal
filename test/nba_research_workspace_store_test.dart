import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/services/nba_research_workspace_store.dart';

void main() {
  const analyst = AppSession(
    userId: 'analyst-1',
    email: 'analyst@example.com',
    displayName: 'Analyst One',
    organizationId: '',
    organizationName: '',
    role: UserRole.analyst,
  );

  const organizationAdmin = AppSession(
    userId: 'admin-1',
    email: 'admin@example.com',
    displayName: 'Admin One',
    organizationId: 'org-1',
    organizationName: 'Basketball Operations',
    role: UserRole.organizationAdmin,
  );

  test('workspace JSON round-trip preserves research state', () {
    final createdAt = DateTime.utc(2026, 8, 4, 12);
    final workspace = NbaResearchWorkspace(
      id: 'research-1',
      title: 'Wing Evaluation',
      description: 'Compare two-way wing candidates.',
      kind: NbaResearchWorkspaceKind.playerEvaluation,
      status: NbaResearchWorkspaceStatus.review,
      ownerUserId: 'analyst-1',
      organizationId: '',
      organizationScope: false,
      createdAt: createdAt,
      updatedAt: createdAt.add(const Duration(hours: 2)),
      playerIds: const ['player-a', 'player-b'],
      teamIds: const ['BOS'],
      metricKeys: const ['pts', 'ts_pct', 'defensive_events'],
      tags: const ['personal', 'wings'],
      notes: 'Validate role and postseason sample.',
    );

    final restored = NbaResearchWorkspace.fromJson(workspace.toJson());

    expect(restored.id, workspace.id);
    expect(restored.kind, workspace.kind);
    expect(restored.status, workspace.status);
    expect(restored.playerIds, workspace.playerIds);
    expect(restored.metricKeys, workspace.metricKeys);
    expect(restored.notes, workspace.notes);
    expect(restored.updatedAt, workspace.updatedAt);
  });

  test('workspace keys separate analyst and organization scopes', () {
    const store = NbaResearchWorkspaceStore();

    expect(
      store.keyFor(analyst),
      'sports_terminal.nba.research_workspaces.v1.analyst.analyst-1',
    );
    expect(
      store.keyFor(organizationAdmin),
      'sports_terminal.nba.research_workspaces.v1.organization.org-1',
    );
  });

  test('organization templates are organization scoped', () {
    const store = NbaResearchWorkspaceStore();
    final workspace = store.createFromTemplate(
      organizationAdmin,
      NbaResearchWorkspaceKind.teamScouting,
    );

    expect(workspace.organizationScope, isTrue);
    expect(workspace.organizationId, 'org-1');
    expect(workspace.ownerUserId, 'admin-1');
    expect(workspace.metricKeys, isNotEmpty);
    expect(workspace.tags, contains('organization'));
  });

  test('starter workspaces include evaluation and coverage audit', () {
    const store = NbaResearchWorkspaceStore();
    final workspaces = store.seedWorkspaces(analyst);

    expect(workspaces, hasLength(2));
    expect(
      workspaces.map((item) => item.kind),
      containsAll([
        NbaResearchWorkspaceKind.playerEvaluation,
        NbaResearchWorkspaceKind.dataAudit,
      ]),
    );
    expect(workspaces.every((item) => item.metricKeys.isNotEmpty), isTrue);
  });
}
