import 'package:flutter/material.dart';

import '../services/historical_nba_repository.dart';
import '../services/nba_research_context_store.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import 'product_analytics_suite_screen.dart';

class ProductAdvancedNbaToolsScreen extends StatefulWidget {
  const ProductAdvancedNbaToolsScreen({super.key});

  @override
  State<ProductAdvancedNbaToolsScreen> createState() =>
      _ProductAdvancedNbaToolsScreenState();
}

class _ProductAdvancedNbaToolsScreenState
    extends State<ProductAdvancedNbaToolsScreen> {
  final NbaTerminalSeedRepository _seed = const NbaTerminalSeedRepository();
  final HistoricalNbaRepository _history = const HistoricalNbaRepository();
  final NbaResearchContextStore _contexts = const NbaResearchContextStore();
  final ProductLocalStore _store = const ProductLocalStore();

  bool _historical = false;
  bool _loading = true;
  String _season = '';
  String _league = 'NBA';
  String _seasonType = 'regular';
  String _error = '';
  int _revision = 0;
  List<String> _seasons = const [];
  late Future<NbaResearchContext> _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = _contexts.load();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final scope = await _store.loadString(
      NbaTerminalSeedRepository.dataScopeKey,
      fallback: 'current',
    );
    final savedLeague = await _store.loadString(
      NbaTerminalSeedRepository.historicalLeagueKey,
      fallback: 'NBA',
    );
    final savedSeason = await _store.loadString(
      NbaTerminalSeedRepository.historicalSeasonKey,
    );
    final savedType = await _store.loadString(
      NbaTerminalSeedRepository.historicalSeasonTypeKey,
      fallback: 'regular',
    );
    var seasons = <String>[];
    var error = '';
    try {
      seasons = (await _history.seasons(league: savedLeague))
          .map((row) => row['season_id']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
    } catch (exception) {
      error = exception.toString();
    }
    final season = seasons.contains(savedSeason)
        ? savedSeason
        : seasons.isNotEmpty
            ? seasons.last
            : savedSeason;
    if (!mounted) return;
    setState(() {
      _historical = scope == 'historical';
      _league = savedLeague.isEmpty ? 'NBA' : savedLeague;
      _season = season;
      _seasonType = const {'regular', 'playoffs', 'combined'}.contains(savedType)
          ? savedType
          : 'regular';
      _seasons = seasons;
      _error = error;
      _loading = false;
      _contextFuture = _contexts.load();
    });
    if (_historical && _season.isNotEmpty) {
      await _seed.selectHistorical(
        _season,
        league: _league,
        seasonType: _seasonType,
      );
    }
  }

  Future<void> _selectCurrent() async {
    await _seed.selectCurrent();
    if (!mounted) return;
    setState(() {
      _historical = false;
      _error = '';
      _revision++;
      _contextFuture = _contexts.load();
    });
  }

  Future<void> _selectHistorical() async {
    if (_season.isEmpty) {
      setState(() => _error = 'Canonical historical seasons are not available yet.');
      return;
    }
    await _seed.selectHistorical(
      _season,
      league: _league,
      seasonType: _seasonType,
    );
    if (!mounted) return;
    setState(() {
      _historical = true;
      _error = '';
      _revision++;
      _contextFuture = _contexts.load();
    });
  }

  Future<void> _changeSeason(String value) async {
    _season = value;
    await _selectHistorical();
  }

  Future<void> _changeSeasonType(String value) async {
    _seasonType = value;
    await _selectHistorical();
  }

  Future<void> _changeLeague(String value) async {
    setState(() {
      _league = value;
      _loading = true;
      _error = '';
    });
    try {
      final seasons = (await _history.seasons(league: value))
          .map((row) => row['season_id']?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
      _seasons = seasons;
      if (!seasons.contains(_season)) {
        _season = seasons.isEmpty ? '' : seasons.last;
      }
      if (_historical && _season.isNotEmpty) {
        await _seed.selectHistorical(
          _season,
          league: _league,
          seasonType: _seasonType,
        );
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _revision++;
        _contextFuture = _contexts.load();
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = exception.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF111824),
      child: Column(
        children: [
          _DataScopeBar(
            historical: _historical,
            loading: _loading,
            season: _season,
            seasons: _seasons,
            league: _league,
            seasonType: _seasonType,
            error: _error,
            contextFuture: _contextFuture,
            onCurrent: _selectCurrent,
            onHistorical: _selectHistorical,
            onSeason: _changeSeason,
            onLeague: _changeLeague,
            onSeasonType: _changeSeasonType,
          ),
          Expanded(
            child: ProductAnalyticsSuiteScreen(
              key: ValueKey(
                '${_historical ? 'history' : 'current'}-$_league-$_season-$_seasonType-$_revision',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataScopeBar extends StatelessWidget {
  const _DataScopeBar({
    required this.historical,
    required this.loading,
    required this.season,
    required this.seasons,
    required this.league,
    required this.seasonType,
    required this.error,
    required this.contextFuture,
    required this.onCurrent,
    required this.onHistorical,
    required this.onSeason,
    required this.onLeague,
    required this.onSeasonType,
  });

  final bool historical;
  final bool loading;
  final String season;
  final List<String> seasons;
  final String league;
  final String seasonType;
  final String error;
  final Future<NbaResearchContext> contextFuture;
  final VoidCallback onCurrent;
  final VoidCallback onHistorical;
  final ValueChanged<String> onSeason;
  final ValueChanged<String> onLeague;
  final ValueChanged<String> onSeasonType;

  @override
  Widget build(BuildContext context) {
    const text = Color(0xFFF3F6FB);
    const muted = Color(0xFF98A5B8);
    const line = Color(0xFF344154);
    const yellow = Color(0xFFFFCB45);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF182130),
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'ANALYTICS DATA',
            style: TextStyle(
              color: yellow,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          ChoiceChip(
            selected: !historical,
            label: const Text('Certified / Current'),
            onSelected: (_) => onCurrent(),
          ),
          ChoiceChip(
            selected: historical,
            label: const Text('Canonical History'),
            onSelected: (_) => onHistorical(),
          ),
          if (historical) ...[
            _ScopeDrop(
              value: league,
              values: const ['NBA', 'ABA', 'BAA'],
              onChanged: onLeague,
            ),
            _ScopeDrop(
              value: seasonType,
              values: const ['regular', 'playoffs', 'combined'],
              labels: const {
                'regular': 'Regular Season',
                'playoffs': 'Playoffs',
                'combined': 'Combined',
              },
              onChanged: onSeasonType,
            ),
            if (seasons.isNotEmpty)
              _ScopeDrop(
                value: seasons.contains(season) ? season : seasons.last,
                values: seasons.reversed.toList(),
                onChanged: onSeason,
              ),
          ],
          if (loading)
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: yellow),
            ),
          Text(
            historical
                ? '${season.isEmpty ? 'NO SEASON' : season} · canonical warehouse projected into original seed contract'
                : 'validated asset / fallback seed contract',
            style: const TextStyle(color: muted, fontSize: 9),
          ),
          FutureBuilder<NbaResearchContext>(
            future: contextFuture,
            builder: (context, snapshot) {
              final active = snapshot.data;
              if (active == null || active.entityLabel.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x2265B5FF),
                  border: Border.all(color: const Color(0x5565B5FF)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ENTITY · ${active.entityLabel}',
                  style: const TextStyle(
                    color: Color(0xFF65B5FF),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
          if (error.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Text(
                error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.redAccent, fontSize: 9),
              ),
            ),
          const Text(
            'Same Player Dashboard · Compare · Rankings · Team Compare · Recent Games · Shot Profile · Lineup Builder · Tier List',
            style: TextStyle(color: text, fontSize: 8, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ScopeDrop extends StatelessWidget {
  const _ScopeDrop({
    required this.value,
    required this.values,
    required this.onChanged,
    this.labels = const {},
  });

  final String value;
  final List<String> values;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF222D3E),
          border: Border.all(color: const Color(0xFF344154)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: const Color(0xFF222D3E),
            style: const TextStyle(
              color: Color(0xFFF3F6FB),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
            items: [
              for (final item in values)
                DropdownMenuItem(
                  value: item,
                  child: Text(labels[item] ?? item),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}
