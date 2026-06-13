enum InternalWorkspaceDocumentType {
  spreadsheet,
  sql,
}

extension InternalWorkspaceDocumentTypeLabel on InternalWorkspaceDocumentType {
  String get label => switch (this) {
        InternalWorkspaceDocumentType.spreadsheet => 'Spreadsheet',
        InternalWorkspaceDocumentType.sql => 'SQL',
      };
}

class InternalWorkspaceDocument {
  const InternalWorkspaceDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.organizationId,
    required this.ownerUserId,
    required this.sourceDataset,
    required this.content,
    required this.rowCount,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final InternalWorkspaceDocumentType type;
  final String organizationId;
  final String ownerUserId;
  final String sourceDataset;
  final String content;
  final int rowCount;
  final DateTime updatedAt;
}
