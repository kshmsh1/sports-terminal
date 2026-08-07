import 'dart:convert';

import 'nba_terminal_seed_repository.dart';
import 'product_local_store.dart';

class NbaResearchContext {
  const NbaResearchContext({
    required this.scope,
    this.season = '',
    this.league = 'NBA',
    this.seasonType = 'regular',
    this.playerKey = '',
    this.playerName = '',
    this.teamKey = '',
    this.teamName = '',
    this.gameKey = '',
    this.updatedAt,
  });

  final String scope;
  final String season;
  final String league;
  final String seasonType;
  final String playerKey;
  final String playerName;
  final String teamKey;
  final String teamName;
  final String gameKey;
  final DateTime? updatedAt;

  bool get historical => scope == 'historical';
  bool get hasEntity => playerKey.isNotEmpty || teamKey.isNotEmpty || gameKey.isNotEmpty;

  String get scopeLabel => historical
      ? [
          if (season.isNotEmpty) season,
          if (league.isNotEmpty) league,
          seasonTypeLabel,
        ].join(' · ')
      : 'Certified Current Release';

  String get seasonTypeLabel => switch (seasonType) {
        'playoffs' => 'Playoffs',
        'combined' => 'Regular + Playoffs',
        'preseason' => 'Preseason',
        'all_star' => 'All-Star',
        _ => 'Regular Season',
      };

  String get entityLabel {
    if (playerName.isNotEmpty) return playerName;
    if (teamName.isNotEmpty) return teamName;
    if (gameKey.isNotEmpty) return gameKey;
    return '';
  }

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'season': season,
        'league': league,
        'seasonType': seasonType,
        'playerKey': playerKey,
        'playerName': playerName,
        'teamKey': teamKey,
        'teamName': teamName,
        'gameKey': gameKey,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory NbaResearchContext.fromJson(Map<String, dynamic> json) {
    return NbaResearchContext(
      scope: json['scope']?.toString() == 'historical' ? 'historical' : 'current',
      season: json['season']?.toString() ?? '',
      league: (json['league']?.toString() ?? 'NBA').toUpperCase(),
      seasonType: json['seasonType']?.toString() ?? 'regular',
      playerKey: json['playerKey']?.toString() ?? '',
      playerName: json['playerName']?.toString() ?? '',
      teamKey: json['teamKey']?.toString() ?? '',
      teamName: json['teamName']?.toString() ?? '',
      gameKey: json['gameKey']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class NbaResearchContextStore {
  const NbaResearchContextStore({
    ProductLocalStore localStore = const ProductLocalStore(),
  }) : _store = localStore;

  static const historyKey = 'sports_terminal.nba.research_context_history.v1';
  static const selectedPlayerNameKey = 'sports_terminal.nba.selected_player_name';
  static const selectedTeamNameKey = 'sports_terminal.nba.selected_team_name';

  final ProductLocalStore _store;

  Future<NbaResearchContext> load() async {
    final scope = await _store.loadString(
      NbaTerminalSeedRepository.dataScopeKey,
      fallback: 'current',
    );
    final season = await _store.loadString(
      NbaTerminalSeedRepository.historicalSeasonKey,
    );
    final league = await _store.loadString(
      NbaTerminalSeedRepository.historicalLeagueKey,
      fallback: 'NBA',
    );
    final seasonType = await _store.loadString(
      NbaTerminalSeedRepository.historicalSeasonTypeKey,
      fallback: 'regular',
    );
    return NbaResearchContext(
      scope: scope == 'historical' ? 'historical' : 'current',
      season: season,
      league: league.isEmpty ? 'NBA' : league.toUpperCase(),
      seasonType: seasonType.isEmpty ? 'regular' : seasonType,
      playerKey: await _store.loadString(ProductLocalStore.nbaSelectedPlayerKey),
      playerName: await _store.loadString(selectedPlayerNameKey),
      teamKey: await _store.loadString(ProductLocalStore.nbaSelectedTeamKey),
      teamName: await _store.loadString(selectedTeamNameKey),
      gameKey: await _store.loadString(ProductLocalStore.nbaSelectedGameKey),
    );
  }

  Future<NbaResearchContext> selectCurrent({bool clearEntity = false}) async {
    await const NbaTerminalSeedRepository().selectCurrent();
    if (clearEntity) await clearEntitySelection();
    final context = await load();
    await _record(context);
    return context;
  }

  Future<NbaResearchContext> activateHistorical({
    required String season,
    String league = 'NBA',
    String seasonType = 'regular',
    String playerKey = '',
    String playerName = '',
    String teamKey = '',
    String teamName = '',
    String gameKey = '',
  }) async {
    final normalizedSeason = season.trim();
    if (normalizedSeason.isEmpty) {
      throw ArgumentError.value(season, 'season', 'Historical season is required.');
    }
    final normalizedLeague = league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase();
    final normalizedType = seasonType.trim().isEmpty ? 'regular' : seasonType.trim();
    await const NbaTerminalSeedRepository().selectHistorical(
      normalizedSeason,
      league: normalizedLeague,
      seasonType: normalizedType,
    );
    await _persistEntities(
      playerKey: playerKey,
      playerName: playerName,
      teamKey: teamKey,
      teamName: teamName,
      gameKey: gameKey,
    );
    final context = NbaResearchContext(
      scope: 'historical',
      season: normalizedSeason,
      league: normalizedLeague,
      seasonType: normalizedType,
      playerKey: playerKey,
      playerName: playerName,
      teamKey: teamKey,
      teamName: teamName,
      gameKey: gameKey,
      updatedAt: DateTime.now().toUtc(),
    );
    await _record(context);
    return context;
  }

  Future<void> selectPlayer(String playerKey, {String playerName = ''}) async {
    await _store.saveString(ProductLocalStore.nbaSelectedPlayerKey, playerKey);
    await _store.saveString(selectedPlayerNameKey, playerName);
  }

  Future<void> selectTeam(String teamKey, {String teamName = ''}) async {
    await _store.saveString(ProductLocalStore.nbaSelectedTeamKey, teamKey);
    await _store.saveString(selectedTeamNameKey, teamName);
  }

  Future<void> selectGame(String gameKey) =>
      _store.saveString(ProductLocalStore.nbaSelectedGameKey, gameKey);

  Future<void> clearEntitySelection() async {
    await _store.remove(ProductLocalStore.nbaSelectedPlayerKey);
    await _store.remove(selectedPlayerNameKey);
    await _store.remove(ProductLocalStore.nbaSelectedTeamKey);
    await _store.remove(selectedTeamNameKey);
    await _store.remove(ProductLocalStore.nbaSelectedGameKey);
  }

  Future<List<NbaResearchContext>> recent({int limit = 12}) async {
    final raw = await _store.loadString(historyKey);
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded.take(limit))
          if (item is Map)
            NbaResearchContext.fromJson(item.cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> restore(NbaResearchContext context) async {
    if (context.historical && context.season.isNotEmpty) {
      await activateHistorical(
        season: context.season,
        league: context.league,
        seasonType: context.seasonType,
        playerKey: context.playerKey,
        playerName: context.playerName,
        teamKey: context.teamKey,
        teamName: context.teamName,
        gameKey: context.gameKey,
      );
      return;
    }
    await const NbaTerminalSeedRepository().selectCurrent();
    await _persistEntities(
      playerKey: context.playerKey,
      playerName: context.playerName,
      teamKey: context.teamKey,
      teamName: context.teamName,
      gameKey: context.gameKey,
    );
    await _record(
      NbaResearchContext(
        scope: 'current',
        playerKey: context.playerKey,
        playerName: context.playerName,
        teamKey: context.teamKey,
        teamName: context.teamName,
        gameKey: context.gameKey,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _persistEntities({
    required String playerKey,
    required String playerName,
    required String teamKey,
    required String teamName,
    required String gameKey,
  }) async {
    await _store.saveString(ProductLocalStore.nbaSelectedPlayerKey, playerKey);
    await _store.saveString(selectedPlayerNameKey, playerName);
    await _store.saveString(ProductLocalStore.nbaSelectedTeamKey, teamKey);
    await _store.saveString(selectedTeamNameKey, teamName);
    await _store.saveString(ProductLocalStore.nbaSelectedGameKey, gameKey);
  }

  Future<void> _record(NbaResearchContext context) async {
    final existing = await recent(limit: 30);
    final signature = _signature(context);
    final next = <NbaResearchContext>[
      NbaResearchContext(
        scope: context.scope,
        season: context.season,
        league: context.league,
        seasonType: context.seasonType,
        playerKey: context.playerKey,
        playerName: context.playerName,
        teamKey: context.teamKey,
        teamName: context.teamName,
        gameKey: context.gameKey,
        updatedAt: context.updatedAt ?? DateTime.now().toUtc(),
      ),
      for (final item in existing)
        if (_signature(item) != signature) item,
    ];
    await _store.saveString(
      historyKey,
      jsonEncode([for (final item in next.take(20)) item.toJson()]),
    );
  }

  String _signature(NbaResearchContext context) => [
        context.scope,
        context.season,
        context.league,
        context.seasonType,
        context.playerKey,
        context.teamKey,
        context.gameKey,
      ].join('|');
}
