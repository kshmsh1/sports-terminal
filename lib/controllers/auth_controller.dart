import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_session.dart';
import '../services/launch_auth_client.dart';

class AuthController extends ChangeNotifier {
  AuthController({LaunchAuthClient authClient = const LaunchAuthClient()})
      : _authClient = authClient;

  final LaunchAuthClient _authClient;

  AppSession? _session;
  String? _error;
  bool _busy = false;
  bool _hydrated = false;

  AppSession? get session => _session;
  String? get error => _error;
  bool get isAuthenticated => _session != null;
  bool get busy => _busy;
  bool get hydrated => _hydrated;

  static const _demoAccounts =
      <String, ({String password, AppSession session})>{
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

  Future<void> hydrate() async {
    if (_hydrated || _busy) return;
    _busy = true;
    notifyListeners();
    final result = await _authClient.restore();
    _session = result.session;
    if (result.available && result.error.isNotEmpty) {
      _error = result.error;
    }
    _busy = false;
    _hydrated = true;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (_busy) return false;
    _setBusy(true);
    final normalizedEmail = email.trim().toLowerCase();
    final remote = await _authClient.signIn(
      email: normalizedEmail,
      password: password,
    );
    if (remote.succeeded) {
      _session = remote.session;
      _error = null;
      _busy = false;
      _hydrated = true;
      notifyListeners();
      return true;
    }

    final demo = _demoAccounts[normalizedEmail];
    if (!remote.available &&
        demo != null &&
        demo.password == password) {
      _session = demo.session;
      _error = null;
      _busy = false;
      _hydrated = true;
      notifyListeners();
      return true;
    }

    _session = null;
    _error = remote.available
        ? (remote.error.isEmpty
            ? 'Email or password is incorrect.'
            : remote.error)
        : 'The account service is offline. Start the launch backend or use a development demo role.';
    _busy = false;
    _hydrated = true;
    notifyListeners();
    return false;
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
    required bool organizationAccount,
    String organizationName = '',
  }) async {
    if (_busy) return false;
    _setBusy(true);
    final result = await _authClient.signUp(
      email: email,
      password: password,
      displayName: displayName,
      organizationAccount: organizationAccount,
      organizationName: organizationName,
    );
    if (result.succeeded) {
      _session = result.session;
      _error = null;
      _busy = false;
      _hydrated = true;
      notifyListeners();
      return true;
    }
    _session = null;
    _error = result.available
        ? (result.error.isEmpty
            ? 'Account creation failed.'
            : result.error)
        : 'The account service is offline. Start the launch backend before creating a customer account.';
    _busy = false;
    _hydrated = true;
    notifyListeners();
    return false;
  }

  void signInAsDemo(AppSession session) {
    _session = session;
    _error = null;
    _busy = false;
    _hydrated = true;
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
    _busy = false;
    _hydrated = true;
    notifyListeners();
    unawaited(_authClient.signOut());
  }

  void _setBusy(bool value) {
    _busy = value;
    _error = null;
    notifyListeners();
  }
}
