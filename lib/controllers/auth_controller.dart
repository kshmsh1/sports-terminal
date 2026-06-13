import 'package:flutter/foundation.dart';

import '../models/app_session.dart';

class AuthController extends ChangeNotifier {
  AppSession? _session;
  String? _error;

  AppSession? get session => _session;
  String? get error => _error;
  bool get isAuthenticated => _session != null;

  static const _demoAccounts = <String, ({String password, AppSession session})>{
    'analyst@sportsterminal.local': (
      password: 'demo123',
      session: AppSession(
        userId: 'demo-analyst',
        email: 'analyst@sportsterminal.local',
        displayName: 'Demo Analyst',
        organizationId: 'demo-org',
        organizationName: 'Sports Terminal Demo Organization',
        role: UserRole.analyst,
      ),
    ),
    'admin@sportsterminal.local': (
      password: 'demo123',
      session: AppSession(
        userId: 'demo-org-admin',
        email: 'admin@sportsterminal.local',
        displayName: 'Demo Organization Admin',
        organizationId: 'demo-org',
        organizationName: 'Sports Terminal Demo Organization',
        role: UserRole.organizationAdmin,
      ),
    ),
    'platform@sportsterminal.local': (
      password: 'demo123',
      session: AppSession(
        userId: 'demo-platform-admin',
        email: 'platform@sportsterminal.local',
        displayName: 'Demo Platform Admin',
        organizationId: 'sports-terminal-internal',
        organizationName: 'Sports Terminal Internal',
        role: UserRole.platformAdmin,
      ),
    ),
  };

  List<AppSession> get demoSessions =>
      _demoAccounts.values.map((item) => item.session).toList(growable: false);

  bool signIn({required String email, required String password}) {
    final normalizedEmail = email.trim().toLowerCase();
    final account = _demoAccounts[normalizedEmail];
    if (account == null || account.password != password) {
      _error = 'Invalid demo account credentials.';
      notifyListeners();
      return false;
    }
    _session = account.session;
    _error = null;
    notifyListeners();
    return true;
  }

  void signInAsDemo(AppSession session) {
    _session = session;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void signOut() {
    _session = null;
    _error = null;
    notifyListeners();
  }
}
