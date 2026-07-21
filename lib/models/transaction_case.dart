enum TransactionCaseStatus {
  draft,
  analysis,
  review,
  approved,
  rejected,
  archived,
}

enum TransactionCasePriority { low, normal, high, urgent }

enum TransactionApprovalDecision { pending, approved, changesRequested, rejected }

class TransactionApproval {
  const TransactionApproval({
    required this.approverId,
    required this.approverName,
    required this.decision,
    required this.updatedAtIso,
    this.note = '',
  });

  final String approverId;
  final String approverName;
  final TransactionApprovalDecision decision;
  final String updatedAtIso;
  final String note;

  Map<String, dynamic> toJson() => {
        'approverId': approverId,
        'approverName': approverName,
        'decision': decision.name,
        'updatedAtIso': updatedAtIso,
        'note': note,
      };

  factory TransactionApproval.fromJson(Map<String, dynamic> json) {
    return TransactionApproval(
      approverId: json['approverId']?.toString() ?? '',
      approverName: json['approverName']?.toString() ?? '',
      decision: TransactionApprovalDecision.values.firstWhere(
        (value) => value.name == json['decision'],
        orElse: () => TransactionApprovalDecision.pending,
      ),
      updatedAtIso: json['updatedAtIso']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class TransactionCaseComment {
  const TransactionCaseComment({
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAtIso,
  });

  final String authorId;
  final String authorName;
  final String body;
  final String createdAtIso;

  Map<String, dynamic> toJson() => {
        'authorId': authorId,
        'authorName': authorName,
        'body': body,
        'createdAtIso': createdAtIso,
      };

  factory TransactionCaseComment.fromJson(Map<String, dynamic> json) {
    return TransactionCaseComment(
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAtIso: json['createdAtIso']?.toString() ?? '',
    );
  }
}

class TransactionCase {
  const TransactionCase({
    required this.id,
    required this.title,
    required this.organizationId,
    required this.organizationName,
    required this.ownerUserId,
    required this.ownerName,
    required this.operatingSeason,
    required this.teams,
    required this.status,
    required this.priority,
    required this.createdAtIso,
    required this.updatedAtIso,
    this.summary = '',
    this.assumptions = const [],
    this.outgoingSalary = 0,
    this.incomingSalary = 0,
    this.currentTeamSalary = 0,
    this.firstApron = 0,
    this.secondApron = 0,
    this.ruleFindings = const [],
    this.approvals = const [],
    this.comments = const [],
    this.assignedUserIds = const [],
    this.sourcePayloadId = '',
    this.isOrganizationVisible = false,
  });

  final String id;
  final String title;
  final String organizationId;
  final String organizationName;
  final String ownerUserId;
  final String ownerName;
  final String operatingSeason;
  final List<String> teams;
  final TransactionCaseStatus status;
  final TransactionCasePriority priority;
  final String createdAtIso;
  final String updatedAtIso;
  final String summary;
  final List<String> assumptions;
  final double outgoingSalary;
  final double incomingSalary;
  final double currentTeamSalary;
  final double firstApron;
  final double secondApron;
  final List<String> ruleFindings;
  final List<TransactionApproval> approvals;
  final List<TransactionCaseComment> comments;
  final List<String> assignedUserIds;
  final String sourcePayloadId;
  final bool isOrganizationVisible;

  double get postTransactionSalary =>
      currentTeamSalary - outgoingSalary + incomingSalary;

  bool get needsApproval =>
      status == TransactionCaseStatus.review ||
      approvals.any((approval) =>
          approval.decision == TransactionApprovalDecision.pending);

  bool get hasBlockingDecision => approvals.any((approval) =>
      approval.decision == TransactionApprovalDecision.rejected ||
      approval.decision == TransactionApprovalDecision.changesRequested);

  TransactionCase copyWith({
    String? title,
    String? organizationId,
    String? organizationName,
    String? ownerUserId,
    String? ownerName,
    String? operatingSeason,
    List<String>? teams,
    TransactionCaseStatus? status,
    TransactionCasePriority? priority,
    String? updatedAtIso,
    String? summary,
    List<String>? assumptions,
    double? outgoingSalary,
    double? incomingSalary,
    double? currentTeamSalary,
    double? firstApron,
    double? secondApron,
    List<String>? ruleFindings,
    List<TransactionApproval>? approvals,
    List<TransactionCaseComment>? comments,
    List<String>? assignedUserIds,
    String? sourcePayloadId,
    bool? isOrganizationVisible,
  }) {
    return TransactionCase(
      id: id,
      title: title ?? this.title,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerName: ownerName ?? this.ownerName,
      operatingSeason: operatingSeason ?? this.operatingSeason,
      teams: teams ?? this.teams,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAtIso: createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      summary: summary ?? this.summary,
      assumptions: assumptions ?? this.assumptions,
      outgoingSalary: outgoingSalary ?? this.outgoingSalary,
      incomingSalary: incomingSalary ?? this.incomingSalary,
      currentTeamSalary: currentTeamSalary ?? this.currentTeamSalary,
      firstApron: firstApron ?? this.firstApron,
      secondApron: secondApron ?? this.secondApron,
      ruleFindings: ruleFindings ?? this.ruleFindings,
      approvals: approvals ?? this.approvals,
      comments: comments ?? this.comments,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      sourcePayloadId: sourcePayloadId ?? this.sourcePayloadId,
      isOrganizationVisible:
          isOrganizationVisible ?? this.isOrganizationVisible,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'organizationId': organizationId,
        'organizationName': organizationName,
        'ownerUserId': ownerUserId,
        'ownerName': ownerName,
        'operatingSeason': operatingSeason,
        'teams': teams,
        'status': status.name,
        'priority': priority.name,
        'createdAtIso': createdAtIso,
        'updatedAtIso': updatedAtIso,
        'summary': summary,
        'assumptions': assumptions,
        'outgoingSalary': outgoingSalary,
        'incomingSalary': incomingSalary,
        'currentTeamSalary': currentTeamSalary,
        'firstApron': firstApron,
        'secondApron': secondApron,
        'ruleFindings': ruleFindings,
        'approvals': [for (final approval in approvals) approval.toJson()],
        'comments': [for (final comment in comments) comment.toJson()],
        'assignedUserIds': assignedUserIds,
        'sourcePayloadId': sourcePayloadId,
        'isOrganizationVisible': isOrganizationVisible,
      };

  factory TransactionCase.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic value) => value is List
        ? [for (final item in value) item.toString()]
        : const [];
    return TransactionCase(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled transaction case',
      organizationId: json['organizationId']?.toString() ?? '',
      organizationName: json['organizationName']?.toString() ?? '',
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      operatingSeason: json['operatingSeason']?.toString() ?? '2026-27',
      teams: strings(json['teams']),
      status: TransactionCaseStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => TransactionCaseStatus.draft,
      ),
      priority: TransactionCasePriority.values.firstWhere(
        (value) => value.name == json['priority'],
        orElse: () => TransactionCasePriority.normal,
      ),
      createdAtIso: json['createdAtIso']?.toString() ?? '',
      updatedAtIso: json['updatedAtIso']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      assumptions: strings(json['assumptions']),
      outgoingSalary: (json['outgoingSalary'] as num?)?.toDouble() ?? 0,
      incomingSalary: (json['incomingSalary'] as num?)?.toDouble() ?? 0,
      currentTeamSalary:
          (json['currentTeamSalary'] as num?)?.toDouble() ?? 0,
      firstApron: (json['firstApron'] as num?)?.toDouble() ?? 0,
      secondApron: (json['secondApron'] as num?)?.toDouble() ?? 0,
      ruleFindings: strings(json['ruleFindings']),
      approvals: [
        for (final item in (json['approvals'] as List? ?? const []))
          if (item is Map)
            TransactionApproval.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
      ],
      comments: [
        for (final item in (json['comments'] as List? ?? const []))
          if (item is Map)
            TransactionCaseComment.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
      ],
      assignedUserIds: strings(json['assignedUserIds']),
      sourcePayloadId: json['sourcePayloadId']?.toString() ?? '',
      isOrganizationVisible: json['isOrganizationVisible'] == true,
    );
  }
}
