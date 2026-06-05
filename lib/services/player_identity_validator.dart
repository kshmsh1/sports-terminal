import '../models/player_alias.dart';
import '../models/player_profile.dart';

class PlayerIdentityValidationIssue {
  const PlayerIdentityValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    required this.playerId,
  });

  final String severity;
  final String code;
  final String message;
  final String? playerId;

  bool get isBlocking => severity == 'Blocker';
}

class PlayerIdentityValidationSummary {
  const PlayerIdentityValidationSummary({required this.issues});
  final List<PlayerIdentityValidationIssue> issues;

  int get blockers => issues.where((item) => item.isBlocking).length;
  int get warnings => issues.where((item) => item.severity == 'Warning').length;
  bool get canConnect => blockers == 0;
}

class PlayerIdentityValidator {
  const PlayerIdentityValidator();

  PlayerIdentityValidationSummary validate({required List<PlayerProfile> players, List<PlayerAlias> aliases = const []}) {
    final issues = <PlayerIdentityValidationIssue>[];
    final ids = <String>{};
    final displayNames = <String, int>{};
    final aliasKeys = <String>{};

    for (final player in players) {
      if (player.id.trim().isEmpty) {
        issues.add(_blocker('missing-player-id', 'Player row is missing canonical playerId.', player.id));
      }
      if (!ids.add(player.id)) {
        issues.add(_blocker('duplicate-player-id', 'Duplicate canonical playerId found: ${player.id}.', player.id));
      }
      if (player.displayName.trim().isEmpty) {
        issues.add(_blocker('missing-display-name', 'Player row is missing displayName.', player.id));
      }
      final normalizedName = _normalize(player.displayName);
      displayNames[normalizedName] = (displayNames[normalizedName] ?? 0) + 1;
      if (player.sourceId == null || player.sourceId!.trim().isEmpty) {
        issues.add(_blocker('missing-source-id', 'Player row is missing sourceId.', player.id));
      }
      if (player.asOf == null || player.asOf!.trim().isEmpty) {
        issues.add(_blocker('missing-as-of', 'Player row is missing asOf metadata.', player.id));
      }
      if (player.firstName == null || player.firstName!.trim().isEmpty || player.lastName == null || player.lastName!.trim().isEmpty) {
        issues.add(_warning('name-parts-blank', 'firstName or lastName is blank. This is allowed only if the source cannot provide a clean split.', player.id));
      }
      if (player.isActive == null) {
        issues.add(_warning('active-status-blank', 'isActive is blank. This is allowed only if first-wave source does not provide a reliable active flag.', player.id));
      }
    }

    for (final entry in displayNames.entries) {
      if (entry.key.isNotEmpty && entry.value > 1) {
        issues.add(PlayerIdentityValidationIssue(severity: 'Blocker', code: 'duplicate-display-name', message: 'Duplicate displayName requires alias/disambiguation review: ${entry.key}.', playerId: null));
      }
    }

    for (final alias in aliases) {
      if (!ids.contains(alias.playerId)) {
        issues.add(_blocker('alias-player-missing', 'Alias references a playerId that is not in player_profiles.', alias.playerId));
      }
      if (alias.alias.trim().isEmpty) {
        issues.add(_blocker('alias-blank', 'Alias row has a blank alias value.', alias.playerId));
      }
      final aliasKey = '${alias.playerId}:${_normalize(alias.alias)}:${alias.providerName ?? ''}:${alias.providerId ?? ''}';
      if (!aliasKeys.add(aliasKey)) {
        issues.add(_warning('duplicate-alias-row', 'Duplicate alias row found for ${alias.playerId}.', alias.playerId));
      }
    }

    return PlayerIdentityValidationSummary(issues: issues);
  }

  PlayerIdentityValidationIssue _blocker(String code, String message, String? playerId) => PlayerIdentityValidationIssue(severity: 'Blocker', code: code, message: message, playerId: playerId);
  PlayerIdentityValidationIssue _warning(String code, String message, String? playerId) => PlayerIdentityValidationIssue(severity: 'Warning', code: code, message: message, playerId: playerId);
  String _normalize(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
