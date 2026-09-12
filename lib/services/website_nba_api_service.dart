import 'nba_terminal_seed_repository.dart';
import 'website_nba_static_repository.dart';

class WebsiteNbaSeason {
  const WebsiteNbaSeason({
    required this.id,
    required this.label,
    required this.startYear,
    required this.rowCount,
  });

  final String id;
  final String label;
  final int startYear;
  final int rowCount;
}

/// Compatibility facade for website NBA data.
///
/// Historical basketball data is now a static website concern. The canonical
/// SQLite warehouse is compiled before launch into sharded JSON under
/// `web/data/nba_static`, and the browser reads those files directly.
/// No FastAPI request or runtime SQLite query is required for Home, Stats,
/// Advanced Stats, player pages, team pages, awards, drafts, or historical
/// game metadata.
///
/// The class keeps its existing name so the website UI does not need a broad
/// migration solely because the transport boundary changed. Future live
/// current-season overlays can be layered above this immutable static base.
class WebsiteNbaApiService {
  const WebsiteNbaApiService();

  static final WebsiteNbaStaticRepository _static = WebsiteNbaStaticRepository();

  Future<Map<String, dynamic>> manifest() => _static.manifest();

  /// Provider inventory, source precedence and local-first runtime policy.
  Future<Map<String, dynamic>> dataFoundation() => _static.dataFoundation();

  /// Dataset-family capability catalog used by research and coverage surfaces.
  Future<Map<String, dynamic>> researchCatalog() => _static.researchCatalog();

  Future<List<WebsiteNbaSeason>> seasons() async {
    final seasons = await _static.seasons();
    return [
      for (final season in seasons)
        WebsiteNbaSeason(
          id: season.id,
          label: season.label,
          startYear: season.startYear,
          rowCount: season.playerCount,
        ),
    ];
  }

  Future<Map<String, dynamic>> seasonDashboard(String season) =>
      _static.seasonDashboard(season);

  Future<NbaTerminalSeedSnapshot> seasonSnapshot(
    String season, {
    String seasonType = 'regular',
    bool includeGameLogs = false,
  }) {
    // includeGameLogs is intentionally ignored for the season table contract.
    // Historical per-player logs live in player dossier shards rather than
    // bloating every season-level website request.
    return _static.seasonSnapshot(season, seasonType: seasonType);
  }

  Future<Map<String, dynamic>> playerDossier(
    String playerKey, {
    String seasonType = 'combined',
    int recentGames = 30,
  }) async {
    final dossier = await _static.playerDossier(playerKey);
    if (seasonType == 'combined') return dossier;
    final normalized = seasonType.toLowerCase().contains('play') ? 'playoffs' : 'regular';
    final rows = _mapList(dossier['seasons'])
        .where((row) => row['season_type']?.toString() == normalized)
        .toList();
    return {
      ...dossier,
      'seasons': rows,
      if (normalized == 'regular') 'regular_seasons': rows,
      if (normalized == 'playoffs') 'playoff_seasons': rows,
    };
  }

  Future<Map<String, dynamic>> teamDossier(String teamKey) =>
      _static.teamDossier(teamKey);

  Future<Map<String, dynamic>> searchEntities(
    String query, {
    String kinds = 'player,team',
    int limitPerKind = 12,
  }) {
    return _static.searchEntities(
      query,
      kinds: kinds,
      limitPerKind: limitPerKind,
    );
  }

  Future<String?> resolveTeamKey(String idOrAbbreviation) =>
      _static.resolveTeamKey(idOrAbbreviation);

  /// Read the immutable historical game catalog and optionally narrow it to a
  /// season, season type, or team. Filtering happens locally after the static
  /// catalog is cached, so opening historical games never requires a runtime
  /// NBA.com request or the local FastAPI process.
  Future<List<Map<String, dynamic>>> games({
    String? season,
    String? seasonType,
    String? team,
  }) async {
    final rows = await _static.gameIndex();
    final normalizedType = seasonType == null || seasonType.isEmpty
        ? null
        : (seasonType.toLowerCase().contains('play') ? 'playoffs' : 'regular');
    final teamNeedle = (team ?? '').trim().toLowerCase();
    return rows.where((row) {
      if (season != null && season.isNotEmpty && row['season_id']?.toString() != season) {
        return false;
      }
      if (normalizedType != null && row['season_type']?.toString() != normalizedType) {
        return false;
      }
      if (teamNeedle.isNotEmpty) {
        final haystack = [
          row['home_team_key'],
          row['away_team_key'],
          row['home_team_name'],
          row['away_team_name'],
          row['home_team_abbreviation'],
          row['away_team_abbreviation'],
        ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
        if (!haystack.contains(teamNeedle)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> gameDetail(String gameKey) =>
      _static.gameDetail(gameKey);

  Future<List<Map<String, dynamic>>> gamePlayByPlay(String gameKey) =>
      _static.gamePlayByPlay(gameKey);

  Future<List<Map<String, dynamic>>> awards() => _static.awards();
  Future<List<Map<String, dynamic>>> allStar() => _static.allStar();
  Future<List<Map<String, dynamic>>> draft() => _static.draft();
  Future<List<Map<String, dynamic>>> coverage() => _static.coverage();
}

class WebsiteNbaApiException implements Exception {
  const WebsiteNbaApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, field) => MapEntry(key.toString(), field)),
  ];
}
