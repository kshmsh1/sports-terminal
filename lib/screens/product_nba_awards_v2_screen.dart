import 'package:flutter/material.dart';

import '../services/nba_awards_repository.dart';
import 'product_nba_public_pages_screen.dart';

const _aBg = Color(0xFF090D12);
const _aPanel = Color(0xFF0F151C);
const _aPanel2 = Color(0xFF141C25);
const _aLine = Color(0xFF263342);
const _aText = Color(0xFFE8EDF3);
const _aMuted = Color(0xFF8895A5);
const _aBlue = Color(0xFF63A9FF);
const _aGreen = Color(0xFF69C99A);
const _aAmber = Color(0xFFE2B866);

class ProductNbaAwardsVotingScreen extends StatefulWidget {
  const ProductNbaAwardsVotingScreen({super.key});

  @override
  State<ProductNbaAwardsVotingScreen> createState() =>
      _ProductNbaAwardsVotingScreenState();
}

class _ProductNbaAwardsVotingScreenState
    extends State<ProductNbaAwardsVotingScreen> {
  final NbaAwardsRepository repository = const NbaAwardsRepository();
  final TextEditingController search = TextEditingController();
  late Future<Map<String, dynamic>> catalogFuture;
  Future<Map<String, dynamic>>? historyFuture;
  String group = 'All';
  String selectedAwardKey = '';
  String selectedAwardLabel = '';
  String selectedSeason = 'All seasons';
  bool winnerOnly = false;

  @override
  void initState() {
    super.initState();
    catalogFuture = repository.catalog();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _selectAward(String key, String label) {
    setState(() {
      selectedAwardKey = key;
      selectedAwardLabel = label;
      selectedSeason = 'All seasons';
      winnerOnly = false;
      historyFuture = repository.history(key, limit: 2000);
    });
  }

  void _refreshHistory() {
    if (selectedAwardKey.isEmpty) return;
    setState(() {
      historyFuture = repository.history(
        selectedAwardKey,
        season: selectedSeason == 'All seasons' ? '' : selectedSeason,
        winnerOnly: winnerOnly,
        limit: 2000,
      );
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _aBg,
        child: FutureBuilder<Map<String, dynamic>>(
          future: catalogFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _AwardPanel(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _AwardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AWARDS DATA OFFLINE',
                      style: TextStyle(
                        color: _aAmber,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: _aMuted),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => setState(
                        () => catalogFuture = repository.catalog(),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry canonical awards'),
                    ),
                  ],
                ),
              );
            }
            final rawCatalog = snapshot.data!['catalog'];
            final catalog = rawCatalog is List
                ? [
                    for (final item in rawCatalog)
                      if (item is Map)
                        item.map(
                          (key, value) => MapEntry(key.toString(), value),
                        ),
                  ]
                : <Map<String, dynamic>>[];
            final groups = <String>{
              'All',
              for (final item in catalog) '${item['group'] ?? 'Other'}',
            }.toList();
            final query = search.text.trim().toLowerCase();
            final visible = catalog.where((item) {
              if (group != 'All' && '${item['group']}' != group) return false;
              if (query.isEmpty) return true;
              return '${item['label']} ${item['group']} ${item['key']}'
                  .toLowerCase()
                  .contains(query);
            }).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AwardHero(),
                const SizedBox(height: 12),
                _AwardPanel(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: search,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: _aText),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search awards and honors…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      _AwardDrop(
                        value: group,
                        values: groups,
                        onChanged: (value) => setState(() => group = value),
                      ),
                      _AwardKpi('Award types', '${catalog.length}'),
                      _AwardKpi(
                        'Canonical records',
                        '${catalog.fold<int>(0, (sum, item) => sum + _int(item['records']))}',
                      ),
                      _AwardKpi(
                        'With voting',
                        '${catalog.where((item) => item['has_voting'] == true).length}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const _Section('AWARD DIRECTORY'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final award in visible)
                      _AwardCard(
                        award: award,
                        selected: selectedAwardKey == '${award['key']}',
                        onTap: () => _selectAward(
                          '${award['key']}',
                          '${award['label']}',
                        ),
                      ),
                  ],
                ),
                if (selectedAwardKey.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  FutureBuilder<Map<String, dynamic>>(
                    future: historyFuture,
                    builder: (context, historySnapshot) => _HistorySection(
                      awardLabel: selectedAwardLabel,
                      selectedSeason: selectedSeason,
                      winnerOnly: winnerOnly,
                      payload: historySnapshot.data,
                      loading:
                          historySnapshot.connectionState != ConnectionState.done,
                      error: historySnapshot.error,
                      onSeasonChanged: (value) {
                        selectedSeason = value;
                        _refreshHistory();
                      },
                      onWinnerOnlyChanged: (value) {
                        winnerOnly = value;
                        _refreshHistory();
                      },
                    ),
                  ),
                ],
                finalUnclassified(snapshot.data!),
              ],
            );
          },
        ),
      );

  Widget finalUnclassified(Map<String, dynamic> payload) {
    final count = _int(payload['unclassified_records']);
    final raw = payload['unclassified_source_labels'];
    final rows = raw is List ? raw : const [];
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: _AwardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Section('SOURCE LABEL AUDIT'),
            const SizedBox(height: 7),
            Text(
              '$count canonical award records do not yet map cleanly into the Sports Terminal taxonomy. They remain preserved rather than being silently discarded.',
              style: const TextStyle(color: _aMuted, height: 1.45),
            ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final item in rows.take(20))
                    if (item is Map)
                      _AuditChip(
                        '${item['label'] ?? 'Unknown'} · ${item['records'] ?? 0}',
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AwardHero extends StatelessWidget {
  const _AwardHero();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _aPanel,
          border: Border.all(color: _aLine),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NBA / AWARDS & VOTING',
              style: TextStyle(
                color: _aBlue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'The complete honors archive',
              style: TextStyle(
                color: _aText,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Annual awards, All-NBA and All-Defense teams, All-Star selections and voting shares are queried from the canonical historical warehouse. Source records remain preserved when a modern product category does not apply cleanly.',
              style: TextStyle(color: _aMuted, height: 1.5),
            ),
          ],
        ),
      );
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({
    required this.award,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> award;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 315,
        child: Material(
          color: selected ? const Color(0xFF17273A) : _aPanel,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? _aBlue : _aLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${award['group'] ?? 'Other'}'.toUpperCase(),
                    style: const TextStyle(
                      color: _aBlue,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${award['label'] ?? award['key']}',
                    style: const TextStyle(
                      color: _aText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Mini('${award['records'] ?? 0} records'),
                      _Mini('${award['winners'] ?? 0} winners'),
                      if (award['has_voting'] == true) const _Mini('Voting'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _seasonRange(award),
                    style: const TextStyle(color: _aMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.awardLabel,
    required this.selectedSeason,
    required this.winnerOnly,
    required this.payload,
    required this.loading,
    required this.error,
    required this.onSeasonChanged,
    required this.onWinnerOnlyChanged,
  });

  final String awardLabel;
  final String selectedSeason;
  final bool winnerOnly;
  final Map<String, dynamic>? payload;
  final bool loading;
  final Object? error;
  final ValueChanged<String> onSeasonChanged;
  final ValueChanged<bool> onWinnerOnlyChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _AwardPanel(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null || payload == null) {
      return _AwardPanel(
        child: Text(
          'Award history unavailable: $error',
          style: const TextStyle(color: _aMuted),
        ),
      );
    }
    final rawRows = payload!['rows'];
    final rows = rawRows is List
        ? [
            for (final item in rawRows)
              if (item is Map)
                item.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
          ]
        : <Map<String, dynamic>>[];
    final seasons = <String>{
      'All seasons',
      for (final row in rows)
        if ('${row['season_id'] ?? ''}'.isNotEmpty) '${row['season_id']}',
    }.toList()
      ..sort((a, b) {
        if (a == 'All seasons') return -1;
        if (b == 'All seasons') return 1;
        return b.compareTo(a);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AwardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                awardLabel,
                style: const TextStyle(
                  color: _aText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${payload!['matched_rows'] ?? rows.length} canonical records · winner, rank and vote/share fields appear when supplied by the historical source.',
                style: const TextStyle(color: _aMuted, height: 1.4),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _AwardDrop(
                    value: seasons.contains(selectedSeason)
                        ? selectedSeason
                        : 'All seasons',
                    values: seasons,
                    onChanged: onSeasonChanged,
                  ),
                  FilterChip(
                    label: const Text('Winners only'),
                    selected: winnerOnly,
                    onSelected: onWinnerOnlyChanged,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _AwardPanel(
          child: Column(
            children: [
              const Row(
                children: [
                  SizedBox(width: 86, child: _HistoryHead('SEASON')),
                  Expanded(flex: 4, child: _HistoryHead('PLAYER')),
                  Expanded(flex: 3, child: _HistoryHead('RESULT')),
                  SizedBox(width: 82, child: _HistoryHead('SHARE')),
                  Expanded(flex: 2, child: _HistoryHead('SOURCE')),
                ],
              ),
              const Divider(color: _aLine),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No canonical records are available for this filter.',
                    style: TextStyle(color: _aMuted),
                  ),
                ),
              for (final row in rows) ...[
                _AwardHistoryRow(row: row),
                const Divider(color: _aLine, height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AwardHistoryRow extends StatelessWidget {
  const _AwardHistoryRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final playerName = '${row['player_name'] ?? 'Unknown'}';
    final playerKey = '${row['player_key'] ?? ''}';
    final winner = _int(row['winner']) == 1;
    final rank = '${row['rank_text'] ?? ''}'.trim();
    final result = winner
        ? 'Winner'
        : rank.isNotEmpty
            ? 'Rank $rank'
            : '${row['team_text'] ?? row['award'] ?? 'Selection'}';
    final share = row['share'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              '${row['season_id'] ?? '—'}',
              style: const TextStyle(
                color: _aMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: playerKey.isEmpty
                  ? null
                  : () => openNbaPlayerPage(context, playerKey, playerName),
              child: Text(
                playerName,
                style: TextStyle(
                  color: playerKey.isEmpty ? _aText : _aBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  decoration: playerKey.isEmpty
                      ? TextDecoration.none
                      : TextDecoration.underline,
                  decorationColor: _aBlue,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              result,
              style: TextStyle(
                color: winner ? _aGreen : _aText,
                fontSize: 11,
                fontWeight: winner ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 82,
            child: Text(
              _share(share),
              style: const TextStyle(
                color: _aAmber,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${row['source_key'] ?? '—'}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _aMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwardPanel extends StatelessWidget {
  const _AwardPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _aPanel,
          border: Border.all(color: _aLine),
        ),
        child: child,
      );
}

class _AwardDrop extends StatelessWidget {
  const _AwardDrop({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: _aPanel2,
          border: Border.all(color: _aLine),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: values.contains(value) ? value : values.first,
            isExpanded: true,
            dropdownColor: _aPanel2,
            style: const TextStyle(color: _aText),
            items: [
              for (final item in values)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _AwardKpi extends StatelessWidget {
  const _AwardKpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 145,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: _aPanel2,
          border: Border.all(color: _aLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: _aMuted,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: _aText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _HistoryHead extends StatelessWidget {
  const _HistoryHead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _aMuted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _aAmber,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _aPanel2,
          border: Border.all(color: _aLine),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _aMuted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _AuditChip extends StatelessWidget {
  const _AuditChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _aPanel2,
          border: Border.all(color: _aLine),
        ),
        child: Text(
          text,
          style: const TextStyle(color: _aMuted, fontSize: 9),
        ),
      );
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _share(Object? value) {
  if (value is num) {
    final number = value.toDouble();
    if (number.abs() <= 1.01) return '${(number * 100).toStringAsFixed(1)}%';
    return number.toStringAsFixed(1);
  }
  return value == null ? '—' : '$value';
}

String _seasonRange(Map<String, dynamic> award) {
  final first = '${award['first_season'] ?? ''}';
  final last = '${award['last_season'] ?? ''}';
  if (first.isEmpty && last.isEmpty) return 'No canonical records yet';
  if (first == last) return first;
  return '$first → $last';
}
