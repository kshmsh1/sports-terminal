import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/product_local_store.dart';
import 'product_nba_entity_pages_v2.dart';

const _awPanel = Color(0xFF0F151C);
const _awPanel2 = Color(0xFF141C25);
const _awLine = Color(0xFF263342);
const _awText = Color(0xFFE8EDF3);
const _awMuted = Color(0xFF8895A5);
const _awBlue = Color(0xFF63A9FF);
const _awAmber = Color(0xFFE2B866);
const _awGreen = Color(0xFF69C99A);

class NbaAwardDefinition {
  const NbaAwardDefinition(this.id, this.label, this.family, this.description);
  final String id;
  final String label;
  final String family;
  final String description;
}

const nbaAwardCatalog = <NbaAwardDefinition>[
  NbaAwardDefinition('mvp', 'Most Valuable Player', 'Major Awards', 'Annual league MVP voting and winner history.'),
  NbaAwardDefinition('roy', 'Rookie of the Year', 'Major Awards', 'Annual rookie award voting and winner history.'),
  NbaAwardDefinition('dpoy', 'Defensive Player of the Year', 'Major Awards', 'Annual defensive player award voting and winner history.'),
  NbaAwardDefinition('smoy', 'Sixth Man of the Year', 'Major Awards', 'Annual reserve-player award voting and winner history.'),
  NbaAwardDefinition('mip', 'Most Improved Player', 'Major Awards', 'Annual most-improved award voting and winner history.'),
  NbaAwardDefinition('clutch', 'Clutch Player of the Year', 'Major Awards', 'Annual Jerry West Award voting and winner history.'),
  NbaAwardDefinition('finals_mvp', 'Finals MVP', 'Postseason', 'NBA Finals Most Valuable Player history.'),
  NbaAwardDefinition('ecf_mvp', 'Eastern Conference Finals MVP', 'Postseason', 'Larry Bird Trophy winner history.'),
  NbaAwardDefinition('wcf_mvp', 'Western Conference Finals MVP', 'Postseason', 'Magic Johnson Trophy winner history.'),
  NbaAwardDefinition('all_star', 'All-Star Selection', 'All-Star', 'Annual NBA All-Star selections.'),
  NbaAwardDefinition('all_star_mvp', 'All-Star Game MVP', 'All-Star', 'NBA All-Star Game MVP history.'),
  NbaAwardDefinition('all_nba_1', 'All-NBA First Team', 'All-League Teams', 'First-team All-NBA selections and voting.'),
  NbaAwardDefinition('all_nba_2', 'All-NBA Second Team', 'All-League Teams', 'Second-team All-NBA selections and voting.'),
  NbaAwardDefinition('all_nba_3', 'All-NBA Third Team', 'All-League Teams', 'Third-team All-NBA selections and voting.'),
  NbaAwardDefinition('all_defense_1', 'All-Defensive First Team', 'All-League Teams', 'First-team All-Defensive selections and voting.'),
  NbaAwardDefinition('all_defense_2', 'All-Defensive Second Team', 'All-League Teams', 'Second-team All-Defensive selections and voting.'),
  NbaAwardDefinition('all_rookie_1', 'All-Rookie First Team', 'All-League Teams', 'First-team All-Rookie selections and voting.'),
  NbaAwardDefinition('all_rookie_2', 'All-Rookie Second Team', 'All-League Teams', 'Second-team All-Rookie selections and voting.'),
  NbaAwardDefinition('all_tournament', 'NBA Cup / In-Season Tournament Team', 'Tournament', 'All-Tournament / NBA Cup selections.'),
  NbaAwardDefinition('ist_mvp', 'NBA Cup / In-Season Tournament MVP', 'Tournament', 'Tournament MVP history.'),
  NbaAwardDefinition('sportsmanship', 'Sportsmanship Award', 'Special Awards', 'Joe Dumars Trophy / NBA Sportsmanship Award history.'),
  NbaAwardDefinition('social_justice', 'Social Justice Champion', 'Special Awards', 'Kareem Abdul-Jabbar Social Justice Champion history.'),
  NbaAwardDefinition('citizenship', 'J. Walter Kennedy Citizenship Award', 'Special Awards', 'Citizenship award history.'),
  NbaAwardDefinition('teammate', 'Twyman-Stokes Teammate of the Year', 'Special Awards', 'Teammate of the Year history.'),
  NbaAwardDefinition('hustle', 'Hustle Award', 'Special Awards', 'NBA Hustle Award history.'),
  NbaAwardDefinition('comeback', 'Comeback Player of the Year', 'Historical / Discontinued', 'Historical Comeback Player award.'),
  NbaAwardDefinition('coach', 'Coach of the Year', 'Team / Executive', 'Annual NBA Coach of the Year voting.'),
  NbaAwardDefinition('executive', 'Executive of the Year', 'Team / Executive', 'Annual NBA Executive of the Year voting.'),
];

class ProductNbaAwardsScreen extends StatefulWidget {
  const ProductNbaAwardsScreen({super.key});

  @override
  State<ProductNbaAwardsScreen> createState() => _ProductNbaAwardsScreenState();
}

class _ProductNbaAwardsScreenState extends State<ProductNbaAwardsScreen> {
  final ProductLocalStore _store = const ProductLocalStore();
  final TextEditingController _search = TextEditingController();
  String _family = 'All';
  String _awardId = 'mvp';
  String _season = '';
  bool _loading = false;
  String _error = '';
  List<Map<String, dynamic>> _rows = const [];
  List<String> _sourceTables = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final baseUrl = await _store.loadString(ProductLocalStore.backendBaseUrlKey, fallback: 'http://127.0.0.1:8000');
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    try {
      final uri = Uri.parse('$base/v2/nba/awards/$_awardId').replace(queryParameters: {
        if (_season.trim().isNotEmpty) 'season': _season.trim(),
        if (_search.text.trim().isNotEmpty) 'query': _search.text.trim(),
        'limit': '1000',
      });
      final response = await http.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Awards service returned ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw Exception('Unexpected awards response.');
      final rawRows = decoded['rows'];
      final rawSources = decoded['source_tables'];
      if (!mounted) return;
      setState(() {
        _rows = rawRows is List
            ? [for (final item in rawRows) if (item is Map) item.map((key, value) => MapEntry(key.toString(), value))]
            : const [];
        _sourceTables = rawSources is List ? rawSources.map((item) => item.toString()).toList() : const [];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _rows = const [];
        _sourceTables = const [];
        _error = 'Historical awards warehouse unavailable: $error';
      });
    }
  }

  NbaAwardDefinition get _selected => nbaAwardCatalog.firstWhere((item) => item.id == _awardId);

  @override
  Widget build(BuildContext context) {
    final families = {'All', for (final item in nbaAwardCatalog) item.family}.toList();
    final visibleAwards = nbaAwardCatalog.where((item) => _family == 'All' || item.family == _family).toList();
    if (!visibleAwards.any((item) => item.id == _awardId) && visibleAwards.isNotEmpty) {
      _awardId = visibleAwards.first.id;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AwardsHero(total: nbaAwardCatalog.length),
        const SizedBox(height: 12),
        _AwardFamilyNav(families: families, selected: _family, onSelected: (value) => setState(() => _family = value)),
        const SizedBox(height: 12),
        _AwardChooser(
          awards: visibleAwards,
          selected: _awardId,
          onSelected: (value) {
            setState(() => _awardId = value);
            _load();
          },
        ),
        const SizedBox(height: 12),
        _AwardsPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selected.label, style: const TextStyle(color: _awText, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_selected.description, style: const TextStyle(color: _awMuted, height: 1.4)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
              SizedBox(
                width: 130,
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Season', hintText: '2024-25', isDense: true, border: OutlineInputBorder()),
                  onChanged: (value) => _season = value,
                  onSubmitted: (_) => _load(),
                ),
              ),
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(labelText: 'Search player / ballot', prefixIcon: Icon(Icons.search_rounded), isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (_) => _load(),
                ),
              ),
              FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Load award history')),
              _Tag('${_rows.length} ROWS', _awBlue),
              if (_sourceTables.isNotEmpty) _Tag('${_sourceTables.length} SOURCE TABLES', _awGreen),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        if (_error.isNotEmpty)
          _AwardsPanel(child: Text(_error, style: const TextStyle(color: _awAmber)))
        else if (_loading)
          const _AwardsPanel(child: Center(child: Padding(padding: EdgeInsets.all(26), child: CircularProgressIndicator())))
        else
          _AwardRows(rows: _rows),
        const SizedBox(height: 12),
        _AwardsPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SOURCE & VOTING MODEL', style: TextStyle(color: _awAmber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 7),
            const Text(
              'Sports Terminal preserves winner lists and ballot/voting rows separately where the historical source provides them. All-NBA, All-Defense and All-Rookie team placement is treated as an annual honor, while vote-share awards retain ballot fields such as first-place votes, points, vote share or rank when present.',
              style: TextStyle(color: _awMuted, height: 1.45),
            ),
            if (_sourceTables.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Active source tables: ${_sourceTables.join(' · ')}', style: const TextStyle(color: _awBlue, fontSize: 10)),
            ],
          ]),
        ),
      ],
    );
  }
}

class _AwardRows extends StatelessWidget {
  const _AwardRows({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _AwardsPanel(child: Text('No matching rows are available in the installed historical source tables for this award/filter.', style: TextStyle(color: _awMuted)));
    }
    return _AwardsPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            _AwardRow(row: rows[index], index: index),
        ],
      ),
    );
  }
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.row, required this.index});
  final Map<String, dynamic> row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final player = _firstValue(row, const ['player', 'player_name', 'name', 'recipient']);
    final season = _firstValue(row, const ['_season', 'season', 'year']);
    final award = _firstValue(row, const ['award', 'award_name', 'type', 'team']);
    final team = _firstValue(row, const ['tm', 'team', 'team_abbreviation', 'team_id']);
    final votes = _firstValue(row, const ['pts_won', 'points_won', 'points', 'votes', 'first', 'first_place_votes', 'share']);
    final detailEntries = row.entries
        .where((entry) => !entry.key.startsWith('__') && !entry.key.startsWith('_') && entry.value != null && entry.value.toString().trim().isNotEmpty)
        .take(12)
        .toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: index.isEven ? _awPanel : const Color(0xFF0D131A),
        border: const Border(bottom: BorderSide(color: _awLine, width: .5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 90, child: Text(season, style: const TextStyle(color: _awMuted, fontSize: 10, fontWeight: FontWeight.w700))),
          Expanded(
            child: player == '—'
                ? Text(award, style: const TextStyle(color: _awText, fontWeight: FontWeight.w800))
                : InkWell(
                    onTap: () => openNbaPlayerPage(context, playerId: _slugGuess(player), playerName: player),
                    child: Text(player, style: const TextStyle(color: _awBlue, fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
          ),
          if (team != '—')
            TextButton(onPressed: () => openNbaTeamPage(context, teamId: team), child: Text(team)),
          if (votes != '—') _Tag(votes, _awAmber),
        ]),
        const SizedBox(height: 5),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final entry in detailEntries.take(8))
              Text('${entry.key}: ${entry.value}', style: const TextStyle(color: _awMuted, fontSize: 9)),
          ],
        ),
      ]),
    );
  }
}

class _AwardsHero extends StatelessWidget {
  const _AwardsHero({required this.total});
  final int total;
  @override
  Widget build(BuildContext context) => _AwardsPanel(
        child: LayoutBuilder(builder: (context, constraints) {
          final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NBA / HONORS & VOTING', style: TextStyle(color: _awBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 5),
            const Text('Awards, Teams & Ballots', style: TextStyle(color: _awText, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('A single annual-history system for league awards, postseason honors, All-Star selections, All-NBA / All-Defense / All-Rookie teams, tournament honors, special awards, coaches and executives.', style: TextStyle(color: _awMuted, height: 1.4)),
          ]);
          if (constraints.maxWidth < 760) return copy;
          return Row(children: [Expanded(child: copy), _Tag('$total HONOR TYPES', _awGreen)]);
        }),
      );
}

class _AwardFamilyNav extends StatelessWidget {
  const _AwardFamilyNav({required this.families, required this.selected, required this.onSelected});
  final List<String> families;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => _AwardsPanel(
        padding: const EdgeInsets.all(9),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final family in families)
            ChoiceChip(label: Text(family), selected: selected == family, onSelected: (_) => onSelected(family)),
        ]),
      );
}

class _AwardChooser extends StatelessWidget {
  const _AwardChooser({required this.awards, required this.selected, required this.onSelected});
  final List<NbaAwardDefinition> awards;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => _AwardsPanel(
        padding: const EdgeInsets.all(9),
        child: Wrap(spacing: 7, runSpacing: 7, children: [
          for (final award in awards)
            FilterChip(
              label: Text(award.label),
              selected: selected == award.id,
              onSelected: (_) => onSelected(award.id),
              selectedColor: const Color(0x2263A9FF),
            ),
        ]),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .6)), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .4)),
      );
}

class _AwardsPanel extends StatelessWidget {
  const _AwardsPanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _awPanel, border: Border.all(color: _awLine), borderRadius: BorderRadius.circular(9)),
        child: child,
      );
}

String _firstValue(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    for (final entry in row.entries) {
      if (_norm(entry.key) == _norm(key)) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
  }
  return '—';
}
String _norm(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
String _slugGuess(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
