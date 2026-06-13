import 'package:flutter/foundation.dart';

import '../models/app_session.dart';
import '../models/internal_workspace_document.dart';

class InternalWorkspaceController extends ChangeNotifier {
  final List<InternalWorkspaceDocument> _documents = [];

  List<InternalWorkspaceDocument> documentsFor(AppSession session) {
    return _documents
        .where((document) => document.organizationId == session.organizationId)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  InternalWorkspaceDocument save({
    required AppSession session,
    required String name,
    required InternalWorkspaceDocumentType type,
    required String sourceDataset,
    required String content,
    required int rowCount,
  }) {
    final now = DateTime.now().toUtc();
    final document = InternalWorkspaceDocument(
      id: 'workspace-${now.microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? '${type.label} Workspace' : name.trim(),
      type: type,
      organizationId: session.organizationId,
      ownerUserId: session.userId,
      sourceDataset: sourceDataset,
      content: content,
      rowCount: rowCount,
      updatedAt: now,
    );
    _documents.insert(0, document);
    notifyListeners();
    return document;
  }

  void delete(String id, AppSession session) {
    _documents.removeWhere(
      (document) =>
          document.id == id && document.organizationId == session.organizationId,
    );
    notifyListeners();
  }

  void clearOrganization(AppSession session) {
    _documents.removeWhere(
      (document) => document.organizationId == session.organizationId,
    );
    notifyListeners();
  }
}
