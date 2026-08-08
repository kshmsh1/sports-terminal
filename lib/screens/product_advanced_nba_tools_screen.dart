import 'package:flutter/material.dart';

import '../services/historical_nba_repository.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import 'product_analytics_suite_screen.dart';
import 'product_nba_advanced_stats_document_screen.dart';

const _advPanel = Color(0xFF0F151C);
const _advPanel2 = Color(0xFF141C25);
const _advLine = Color(0xFF263342);
const _advText = Color(0xFFE8EDF3);
const _advMuted = Color(0xFF8895A5);
const _advBlue = Color(0xFF63A9FF);
const _advAmber = Color(0xFFE2B866);

class ProductAdvancedNbaToolsScreen extends StatefulWidget {
  const ProductAdvancedNbaToolsScreen({super.key});

  @override
  State<ProductAdvancedNbaToolsScreen> createState() =>
      _ProductAdvancedNbaToolsScreenState();
}

class _ProductAdvancedNbaToolsScreenState extends State<ProductAdvancedNbaToolsScreen> {
  final NbaTerminalSeedRepository _seed = const NbaTerminalSeedRepository();
  final HistoricalNbaRepository _history = const HistoricalNbaRepository();
  final ProductLocalStore _store = const ProductLocalStore();

  bool _historical = false;
  bool _loading = true;
  bool _analytics = false;
  String _season = '';
  String _league = 'NBA';
  String _seasonType = 'regular';
  String _error = '';
  int _revision = 0;
  List<String> _seasons = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final scope = await _store.loadString(NbaTerminalSeedRepository.dataScopeKey, fallback: 'current');
    final league = await _store.loadString(NbaTerminalSeedRepository.historicalLeagueKey, fallback: 'NBA');
    final savedSeason = await _store.loadString(NbaTerminalSeedRepository.historicalSeasonKey);
    final savedType = await _store.loadString(NbaTerminalSeedRepository.historicalSeasonTypeKey, fallback: 'regular');
    var seasons = <String>[];
    var error = '';
    try {
      seasons = (await _history.seasons(league: league))
          .map((row) => row['season_id']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
    } catch (exception) {
      error = exception.toString();
    }
    final season = seasons.contains(savedSeason) ? savedSeason : seasons.isNotEmpty ? seasons.last : savedSeason;
    if (!mounted) return;
    setState(() {
      _historical = scope == 'historical';
      _league = league.isEmpty ? 'NBA' : league;
      _season = season;
      _seasonType = const {'regular', 'playoffs'}.contains(savedType) ? savedType : 'regular';
      _seasons = seasons;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _selectCurrent() async {
    await _seed.selectCurrent();
    if (!mounted) return;
    setState(() {
      _historical = false;
      _error = '';
      _revision++;
    });
  }

  Future<void> _selectHistorical() async {
    if (_season.isEmpty) {
      setState(() => _error = 'Canonical historical seasons are not installed yet.');
      return;
    }
    await _seed.selectHistorical(_season, league: _league, seasonType: _seasonType);
    if (!mounted) return;
    setState(() {
      _historical = true;
      _error = '';
      _revision++;
    });
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
      if (!seasons.contains(_season)) _season = seasons.isEmpty ? '' : seasons.last;
      if (_historical && _season.isNotEmpty) {
        await _seed.selectHistorical(_season, league: _league, seasonType: _seasonType);
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _revision++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _changeSeason(String value) async {
    _season = value;
    await _selectHistorical();
  }

  Future<void> _changeSeasonType(String value) async {
    _seasonType = value;
    await _selectHistorical();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdvancedScopeBar(
          historical: _historical,
          loading: _loading,
          league: _league,
          season: _season,
          seasonType: _seasonType,
          seasons: _seasons,
          error: _error,
          analytics: _analytics,
          onAnalytics: (value) => setState(() => _analytics = value),
          onCurrent: _selectCurrent,
          onHistorical: _selectHistorical,
          onLeague: _changeLeague,
          onSeason: _changeSeason,
          onSeasonType: _changeSeasonType,
        ),
        const SizedBox(height: 12),
        if (_analytics)
          ProductAnalyticsSuiteScreen(key: ValueKey('analytics-$_revision-$_league-$_season-$_seasonType'))
        else
          ProductNbaAdvancedStatsDocumentScreen(key: ValueKey('stats-$_revision-$_league-$_season-$_seasonType')),
      ],
    );
  }
}

class _AdvancedScopeBar extends StatelessWidget {
  const _AdvancedScopeBar({
    required this.historical,
    required this.loading,
    required this.league,
    required this.season,
    required this.seasonType,
    required this.seasons,
    required this.error,
    required this.analytics,
    required this.onAnalytics,
    required this.onCurrent,
    required this.onHistorical,
    required this.onLeague,
    required this.onSeason,
    required this.onSeasonType,
  });
  final bool historical;
  final bool loading;
  final String league;
  final String season;
  final String seasonType;
  final List<String> seasons;
  final String error;
  final bool analytics;
  final ValueChanged<bool> onAnalytics;
  final VoidCallback onCurrent;
  final VoidCallback onHistorical;
  final ValueChanged<String> onLeague;
  final ValueChanged<String> onSeason;
  final ValueChanged<String> onSeasonType;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _advPanel, border: Border.all(color: _advLine), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('ADVANCED STATS', style: TextStyle(color: _advBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Stats Workstation'), icon: Icon(Icons.table_chart_rounded)),
                ButtonSegment(value: true, label: Text('Analytics Suite'), icon: Icon(Icons.analytics_rounded)),
              ],
              selected: {analytics},
              onSelectionChanged: (values) => onAnalytics(values.first),
            ),
            ChoiceChip(label: const Text('Current'), selected: !historical, onSelected: (_) => onCurrent()),
            ChoiceChip(label: const Text('Historical'), selected: historical, onSelected: (_) => onHistorical()),
            if (historical) ...[
              _ScopeDrop(value: league, values: const ['NBA', 'ABA', 'BAA'], onChanged: onLeague),
              _ScopeDrop(
                value: seasonType,
                values: const ['regular', 'playoffs'],
                labels: const {'regular': 'Regular Season', 'playoffs': 'Playoffs'},
                onChanged: onSeasonType,
              ),
              if (seasons.isNotEmpty)
                _ScopeDrop(value: seasons.contains(season) ? season : seasons.last, values: seasons.reversed.toList(), onChanged: onSeason),
            ],
            if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _advAmber)),
          ]),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
          ],
          const SizedBox(height: 7),
          Text(
            analytics
                ? 'Dashboard, compare, rankings, recent form, shot profile, lineup builder, tier list, ORtg sandbox and data coverage.'
                : 'The complete source-aware metric infrastructure. This page uses the platform document scroll rather than a nested vertical stats pane.',
            style: const TextStyle(color: _advMuted, fontSize: 10, height: 1.35),
          ),
        ]),
      );
}

class _ScopeDrop extends StatelessWidget {
  const _ScopeDrop({required this.value, required this.values, required this.onChanged, this.labels = const {}});
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final Map<String, String> labels;
  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: _advPanel2, border: Border.all(color: _advLine), borderRadius: BorderRadius.circular(6)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: _advPanel2,
            style: const TextStyle(color: _advText, fontSize: 9, fontWeight: FontWeight.w800),
            items: [for (final item in values) DropdownMenuItem(value: item, child: Text(labels[item] ?? item))],
            onChanged: (next) { if (next != null) onChanged(next); },
          ),
        ),
      );
}
