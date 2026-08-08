import '../models/app_session.dart';
import 'launch_backend_transport.dart';

class SportsTerminalProfileService {
  const SportsTerminalProfileService({
    LaunchBackendTransport transport = const LaunchBackendTransport(),
  }) : _transport = transport;

  final LaunchBackendTransport _transport;

  Future<ProfileLoadResult> load(AppSession session) async {
    final response = await _transport.getJson(
      '/v2/profile/${session.userId}',
      query: {'viewer_user_id': session.userId},
    );
    if (!response.available || response.data is! Map) {
      return ProfileLoadResult(
        available: false,
        error: response.error,
      );
    }
    return ProfileLoadResult(
      available: true,
      profile: _map(response.data as Map),
    );
  }

  Future<ProfileLoadResult> save({
    required AppSession session,
    required String displayName,
    required String handle,
    required String bio,
    required String avatarUrl,
    required bool isPublic,
    required List<String> favoriteTeams,
    required List<String> favoritePlayers,
    required bool emailDigest,
    required bool fantasyAlerts,
    required bool tradeAlerts,
    required bool editorialNewsletter,
  }) async {
    final response = await _transport.putJson(
      '/v2/profile/${session.userId}',
      {
        'actor_user_id': session.userId,
        'display_name': displayName.trim(),
        'handle': handle.trim(),
        'bio': bio.trim(),
        'avatar_url': avatarUrl.trim(),
        'is_public': isPublic,
        'favorite_teams': favoriteTeams,
        'favorite_players': favoritePlayers,
        'email_digest': emailDigest,
        'fantasy_alerts': fantasyAlerts,
        'trade_alerts': tradeAlerts,
        'editorial_newsletter': editorialNewsletter,
        'notification_preferences': {
          'trade_alerts': tradeAlerts,
          'editorial_newsletter': editorialNewsletter,
        },
      },
    );
    if (!response.available || response.data is! Map) {
      return ProfileLoadResult(
        available: response.available,
        error: response.error,
      );
    }
    return ProfileLoadResult(
      available: true,
      profile: _map(response.data as Map),
    );
  }

  static Map<String, dynamic> _map(Map value) => value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
}

class ProfileLoadResult {
  const ProfileLoadResult({
    required this.available,
    this.profile,
    this.error = '',
  });

  final bool available;
  final Map<String, dynamic>? profile;
  final String error;
}
