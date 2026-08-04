import 'dart:convert';

import '../models/app_session.dart';
import 'product_local_store.dart';

enum NbaResearchWorkspaceStatus { active, review, archived }

enum NbaResearchWorkspaceKind {
  playerEvaluation,
  teamScouting,
  opponentPrep,
  transactionReview,
  rotationPlanning,
  dataAudit,
}

extension NbaResearchWorkspaceKindLabel on NbaResearchWorkspaceKind {
  String get label => switch (this) {
        NbaResearchWorkspaceKind.playerEvaluation => 'Player Evaluation',
        NbaResearchWorkspaceKind.teamScouting => 'Team Scouting',
        NbaResearchWorkspaceKind.opponentPrep => 'Opponent Prep',
        NbaResearchWorkspaceKind.transactionReview => 'Transaction Review',
        NbaResearchWorkspaceKind.rotationPlanning => 'Rotation Planning',
        NbaResearchWorkspaceKind.dataAudit => 'Data Audit',
      };

  String get description => switch (this) {
        NbaResearchWorkspaceKind.playerEvaluation =>
          'Build a source-backed player profile, percentile view and comparison set.',
        NbaResearchWorkspaceKind.teamScouting =>
          'Review roster production, team context, ranking position and recent form.',
        NbaResearchWorkspaceKind.opponentPrep =>
          'Organize opponent tendencies and matchup questions without inventing tracking data.',
        NbaResearchWorkspaceKind.transactionReview =>
          'Frame acquisition or trade research around production, efficiency, role and risk.',
        NbaResearchWorkspaceKind.rotationPlanning =>
          'Evaluate candidate groups while preserving the distinction between box-score proxies and lineup stints.',
        NbaResearchWorkspaceKind.dataAudit =>
          'Inspect release coverage, validation status, source gates and methodological warnings.',
      };

  List<String> get defaultMetrics => switch (this) {
        NbaResearchWorkspaceKind.playerEvaluation =>
          const ['pts', 'reb', 'ast', 'ts_pct', 'efg_pct', 'game_score_proxy'],
        NbaResearchWorkspaceKind.teamScouting =>
          const ['pts', 'ast', 'reb', 'stl', 'blk', 'plus_minus'],
        NbaResearchWorkspaceKind.opponentPrep =>
          const ['pts', 'ast', 'tov', 'three_rate', 'ft_rate', 'defensive_events'],
        NbaResearchWorkspaceKind.transactionReview =>
          const ['age', 'minutes', 'pts', 'ts_pct', 'ast_to_tov', 'game_score_proxy'],
        NbaResearchWorkspaceKind.rotationPlanning =>
          const ['minutes', 'pts', 'ast', 'reb', 'plus_minus', 'defensive_events'],
        NbaResearchWorkspaceKind.dataAudit =>
          const ['games', 'minutes', 'possessions', 'pts', 'ts_pct', 'plus_minus'],
      };
}

class NbaResearchWorkspace {
  const NbaResearchWorkspace({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.status,
    required this.ownerUserId,
    required this.organizationId,
    required this.organizationScope,
    required this.createdAt,
    required this.updatedAt,
    this.playerIds = const [],
    this.teamIds = const [],
    this.metricKeys = const [],
    this.tags = const [],
    this.notes = '',
  });

  final String id;
  final String title;
  final String description;
  final NbaResearchWorkspaceKind kind;
  final NbaResearchWorkspaceStatus status;
  final String ownerUserId;
  final String organizationId;
  final bool organizationScope;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> playerIds;
  final List<String> teamIds;
  final List<String> metricKeys;
  final List<String> tags;
  final String notes;

  NbaResearchWorkspace copyWith({
    String? id,
    String? title,
    String? description,
    NbaResearchWorkspaceKind? kind,
    NbaResearchWorkspaceStatus? status,
    String? ownerUserId,
    String? organizationId,
    bool? organizationScope,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? playerIds,
    List<String>? teamIds,
    List<String>? metricKeys,
    List<String>? tags,
    String? notes,
  }) {
    return NbaResearchWorkspace(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      organizationId: organizationId ?? this.organizationId,
      organizationScope: organizationScope ?? this.organizationScope,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      playerIds: playerIds ?? this.playerIds,
      teamIds: teamIds ?? this.teamIds,
      metricKeys: metricKeys ?? this.metricKeys,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'kind': kind.name,
        'status': status.name,
        'ownerUserId': ownerUserId,
        'organizationId': organizationId,
        'organizationScope': organizationScope,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'playerIds': playerIds,
        'teamIds': teamIds,
        'metricKeys': metricKeys,
        'tags': tags,
        'notes': notes,
      };

  factory NbaResearchWorkspace.fromJson(Map<String, dynamic> json) {
    return NbaResearchWorkspace(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Research',
      description: json['description']?.toString() ?? '',
      kind: NbaResearchWorkspaceKind.values.firstWhere(
        (value) => value.name == json['kind']?.toString(),
        orElse: () => NbaResearchWorkspaceKind.playerEvaluation,
      ),
      status: NbaResearchWorkspaceStatus.values.firstWhere(
        (value) => value.name == json['status']?.toString(),
        orElse: () => NbaResearchWorkspaceStatus.active,
      ),
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      organizationId: json['organizationId']?.toString() ?? '',
      organizationScope: json['organizationScope'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      playerIds: _stringList(json['playerIds']),
      teamIds: _stringList(json['teamIds']),
      metricKeys: _stringList(json['metricKeys']),
      tags: _stringList(json['tags']),
      notes: json['notes']?.toString() ?? '',
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [for (final item in value) item.toString()];
  }
}

class NbaResearchWorkspaceStore {
  const NbaResearchWorkspaceStore({this.localStore = const ProductLocalStore()});

  final ProductLocalStore localStore;

  String keyFor(AppSession session) {
    final scope = session.role.canManageOrganization &&
            session.organizationId.isNotEmpty
        ? 'organization.${session.organizationId}'
        : 'analyst.${session.userId}';
    return 'sports_terminal.nba.research_workspaces.v1.$scope';
  }

  Future<List<NbaResearchWorkspace>> load(AppSession session) async {
    final raw = await localStore.loadString(keyFor(session));
    if (raw.isEmpty) {
      final seeded = seedWorkspaces(session);
      await saveAll(session, seeded);
      return seeded;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final workspaces = <NbaResearchWorkspace>[
          for (final item in decoded)
            if (item is Map)
              NbaResearchWorkspace.fromJson(item.cast<String, dynamic>()),
        ];
        workspaces.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return workspaces;
      }
    } catch (_) {
      // Corrupt local state falls back to transparent starter workspaces.
    }
    final seeded = seedWorkspaces(session);
    await saveAll(session, seeded);
    return seeded;
  }

  Future<void> saveAll(
    AppSession session,
    List<NbaResearchWorkspace> workspaces,
  ) async {
    final ordered = [...workspaces]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await localStore.saveString(
      keyFor(session),
      jsonEncode([for (final workspace in ordered) workspace.toJson()]),
    );
  }

  Future<List<NbaResearchWorkspace>> upsert(
    AppSession session,
    List<NbaResearchWorkspace> current,
    NbaResearchWorkspace workspace,
  ) async {
    final next = [...current];
    final index = next.indexWhere((item) => item.id == workspace.id);
    if (index == -1) {
      next.add(workspace);
    } else {
      next[index] = workspace;
    }
    await saveAll(session, next);
    next.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return next;
  }

  Future<List<NbaResearchWorkspace>> remove(
    AppSession session,
    List<NbaResearchWorkspace> current,
    String workspaceId,
  ) async {
    final next = current.where((item) => item.id != workspaceId).toList();
    await saveAll(session, next);
    return next;
  }

  NbaResearchWorkspace createFromTemplate(
    AppSession session,
    NbaResearchWorkspaceKind kind, {
    String? title,
  }) {
    final now = DateTime.now().toUtc();
    final organizationScope = session.role.canManageOrganization &&
        session.organizationId.isNotEmpty;
    final resolvedTitle = (title ?? '').trim();
    return NbaResearchWorkspace(
      id: 'research-${now.microsecondsSinceEpoch}',
      title: resolvedTitle.isNotEmpty ? resolvedTitle : kind.label,
      description: kind.description,
      kind: kind,
      status: NbaResearchWorkspaceStatus.active,
      ownerUserId: session.userId,
      organizationId: organizationScope ? session.organizationId : '',
      organizationScope: organizationScope,
      createdAt: now,
      updatedAt: now,
      metricKeys: kind.defaultMetrics,
      tags: [
        organizationScope ? 'organization' : 'personal',
        kind.name,
      ],
    );
  }

  List<NbaResearchWorkspace> seedWorkspaces(AppSession session) {
    final primary = createFromTemplate(
      session,
      NbaResearchWorkspaceKind.playerEvaluation,
      title: session.role.canManageOrganization
          ? '${session.organizationName} Player Board'
          : 'My Player Evaluation Board',
    );
    final audit = createFromTemplate(
      session,
      NbaResearchWorkspaceKind.dataAudit,
      title: '2025–26 Data Coverage Audit',
    );
    return [primary, audit];
  }
}
