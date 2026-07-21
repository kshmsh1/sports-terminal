enum TransactionActivityKind {
  created,
  imported,
  status,
  comment,
  assignment,
  approval,
  notification,
}

class TransactionActivity {
  const TransactionActivity({
    required this.id,
    required this.caseId,
    required this.organizationId,
    required this.actorUserId,
    required this.actorName,
    required this.kind,
    required this.message,
    required this.createdAtIso,
    this.recipientUserId = '',
  });

  final String id;
  final String caseId;
  final String organizationId;
  final String actorUserId;
  final String actorName;
  final TransactionActivityKind kind;
  final String message;
  final String createdAtIso;
  final String recipientUserId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'caseId': caseId,
        'organizationId': organizationId,
        'actorUserId': actorUserId,
        'actorName': actorName,
        'kind': kind.name,
        'message': message,
        'createdAtIso': createdAtIso,
        'recipientUserId': recipientUserId,
      };

  factory TransactionActivity.fromJson(Map<String, dynamic> json) {
    return TransactionActivity(
      id: json['id']?.toString() ?? '',
      caseId: json['caseId']?.toString() ?? '',
      organizationId: json['organizationId']?.toString() ?? '',
      actorUserId: json['actorUserId']?.toString() ?? '',
      actorName: json['actorName']?.toString() ?? '',
      kind: TransactionActivityKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => TransactionActivityKind.notification,
      ),
      message: json['message']?.toString() ?? '',
      createdAtIso: json['createdAtIso']?.toString() ?? '',
      recipientUserId: json['recipientUserId']?.toString() ?? '',
    );
  }
}

class TransactionNotification {
  const TransactionNotification({
    required this.id,
    required this.caseId,
    required this.organizationId,
    required this.recipientUserId,
    required this.title,
    required this.body,
    required this.createdAtIso,
    this.isRead = false,
  });

  final String id;
  final String caseId;
  final String organizationId;
  final String recipientUserId;
  final String title;
  final String body;
  final String createdAtIso;
  final bool isRead;

  TransactionNotification copyWith({bool? isRead}) => TransactionNotification(
        id: id,
        caseId: caseId,
        organizationId: organizationId,
        recipientUserId: recipientUserId,
        title: title,
        body: body,
        createdAtIso: createdAtIso,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'caseId': caseId,
        'organizationId': organizationId,
        'recipientUserId': recipientUserId,
        'title': title,
        'body': body,
        'createdAtIso': createdAtIso,
        'isRead': isRead,
      };

  factory TransactionNotification.fromJson(Map<String, dynamic> json) {
    return TransactionNotification(
      id: json['id']?.toString() ?? '',
      caseId: json['caseId']?.toString() ?? '',
      organizationId: json['organizationId']?.toString() ?? '',
      recipientUserId: json['recipientUserId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Transaction update',
      body: json['body']?.toString() ?? '',
      createdAtIso: json['createdAtIso']?.toString() ?? '',
      isRead: json['isRead'] == true,
    );
  }
}

class OrganizationMemberRecord {
  const OrganizationMemberRecord({
    required this.userId,
    required this.displayName,
    required this.roleLabel,
    required this.createdAtIso,
    this.teamFocus = 'League-wide',
    this.active = true,
    this.reviewCapacity = 5,
  });

  final String userId;
  final String displayName;
  final String roleLabel;
  final String createdAtIso;
  final String teamFocus;
  final bool active;
  final int reviewCapacity;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'roleLabel': roleLabel,
        'createdAtIso': createdAtIso,
        'teamFocus': teamFocus,
        'active': active,
        'reviewCapacity': reviewCapacity,
      };

  factory OrganizationMemberRecord.fromJson(Map<String, dynamic> json) {
    return OrganizationMemberRecord(
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      roleLabel: json['roleLabel']?.toString() ?? 'Analyst',
      createdAtIso: json['createdAtIso']?.toString() ?? '',
      teamFocus: json['teamFocus']?.toString() ?? 'League-wide',
      active: json['active'] != false,
      reviewCapacity: (json['reviewCapacity'] as num?)?.toInt() ?? 5,
    );
  }
}
