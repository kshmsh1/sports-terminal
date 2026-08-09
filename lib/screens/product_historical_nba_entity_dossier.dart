import 'package:flutter/material.dart';

import '../services/historical_nba_repository.dart';
import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';

const _hBg = Color(0xFF090D12);
const _hPanel = Color(0xFF0F151C);
const _hPanel2 = Color(0xFF141C25);
const _hLine = Color(0xFF263342);
const _hText = Color(0xFFE8EDF3);
const _hMuted = Color(0xFF8895A5);
const _hBlue = Color(0xFF63A9FF);
const _hGreen = Color(0xFF69C99A);
const _hAmber = Color(0xFFE2B866);

class ProductHistoricalPlayerDossier extends StatefulWidget {
  const ProductHistoricalPlayerDossier({
    super.key,
    required this.playerKeyOrId,
    required this.playerName,
  });

  final String playerKeyOrId;
  final String playerName;

  @override
  State<ProductHistoricalPlayerDossier> createState() =>
      _ProductHistoricalPlayerDossierState();
}

class _ProductHistoricalPlayerDossierState
    extends State<ProductHistoricalPlayerDossier> {
  final HistoricalNbaRepository repository = const HistoricalNbaRepository();
  final Set<String> expanded = <String>{};
  String familyId = 'basic';
  NbaStatsBasis basis = NbaStatsBasis.perGame;
  NbaStatsSeasonType seasonType = NbaStatsSeasonType.regular;
  late Future<_HistoricalPlayerBundle> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<_HistoricalPlayerBundle> _load() async {
    var key = widget.playerKeyOrId;
    Map<String, dynamic>? identity;
    try {
      identity = await repository.player(key);
    } catch (_) {
      final matches = await repository.searchPlayers(widget.playerName, limit: 50);
      final normalized = widget.playerName.trim().toLowerCase();
      Map<String, dynamic>? match;
      for (final candidate in matches) {
        final name = '${candidate['canonical_name'] ?? ''}'.trim().toLowerCase();
        final nbaId = '${candidate['nba_id'] ?? ''}'.trim();
        final brefId = '${candidate['bref_id'] ?? ''}'.trim();
        if (name == normalized ||
            nbaId == widget.playerKeyOrId ||
            brefId == widget.playerKeyOrId) {
          match = candidate;
          break;
        }
      }
      match ??= matches.isEmpty ? null : matches.first;
      if (match == null) rethrow;
      key = '${match['player_key']}';
      identity = await repository.player(key);
    }
    final career = await repository.career(
      key,
      seasonType: seasonType == NbaStatsSeasonType.playoffs
          ? 'playoffs'
          : 'regular',
    );
    return _HistoricalPlayerBundle(
      playerKey: key,
      identity: identity,
      rows: _rows(career['rows']),
    );
  }

  void _reloadSegment(NbaStatsSeasonType value) {
    setState(() {
      seasonType = value;
      future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HistoricalPlayerBundle>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _HistoricalPanel(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _HistoricalPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CANONICAL HISTORICAL PLAYER',
                  style: TextStyle(
                    color: _hAmber,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.playerName,
                  style: const TextStyle(
                    color: _hText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'The player is not present in the active release and the canonical historical warehouse could not resolve this identity: ${snapshot.error}',
                  style: const TextStyle(color: _hMuted, height: 1.45),
                ),
              ],
            ),
          );
        }
        final bundle = snapshot.data!;
        final identity = bundle.identity;
        final family = nbaTerminalFamily(familyId);
        final familyKeys = nbaVisibleMetricKeys(family, expanded);
        final populatedKeys = familyKeys
            .where((key) => bundle.rows.any((row) => _historicalValue(row, key, basis) != null))
            .toList();
        final awards = identity['awards'] is List ? identity['awards'] as List : const [];
        final allStar = identity['all_star'] is List ? identity['all_star'] as List : const [];
        final draft = identity['draft'] is List ? identity['draft'] as List : const [];
        final seasons = [...bundle.rows]
          ..sort((left, right) =>
              '${right['season_id'] ?? ''}'.compareTo('${left['season_id'] ?? ''}'));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HistoricalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NBA / HISTORICAL PLAYER DOSSIER',
                    style: TextStyle(
                      color: _hBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${identity['canonical_name'] ?? widget.playerName}',
                    style: const TextStyle(
                      color: _hText,
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${identity['primary_position'] ?? '—'} · ${identity['active_from'] ?? '—'} to ${identity['active_to'] ?? '—'} · canonical key ${bundle.playerKey}',
                    style: const TextStyle(color: _hMuted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _Pill('${seasons.length} SEASON ROWS', _hBlue),
                      _Pill('${awards.length} AWARD ROWS', _hAmber),
                      _Pill('${allStar.length} ALL-STAR', _hGreen),
                      if ('${identity['nba_id'] ?? ''}'.isNotEmpty)
                        _Pill('NBA ID ${identity['nba_id']}', _hMuted),
                      if ('${identity['bref_id'] ?? ''}'.isNotEmpty)
                        _Pill('BREF ${identity['bref_id']}', _hMuted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _HistoricalPanel(
              child: Wrap(
                spacing: 9,
                runSpacing: 9,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FamilyDrop(
                    value: familyId,
                    onChanged: (value) => setState(() {
                      familyId = value;
                      expanded.clear();
                    }),
                  ),
                  _EnumDrop<NbaStatsBasis>(
                    value: basis,
                    values: NbaStatsBasis.values,
                    label: (value) => value.label,
                    onChanged: (value) => setState(() => basis = value),
                  ),
                  _EnumDrop<NbaStatsSeasonType>(
                    value: seasonType,
                    values: const [
                      NbaStatsSeasonType.regular,
                      NbaStatsSeasonType.playoffs,
                    ],
                    label: (value) => value.label,
                    onChanged: _reloadSegment,
                  ),
                  _Pill(
                    '${populatedKeys.length}/${familyKeys.length} FAMILY METRICS AVAILABLE',
                    populatedKeys.isEmpty ? _hAmber : _hGreen,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (populatedKeys.isEmpty)
              _HistoricalPanel(
                child: Text(
                  '${family.label} does not have authoritative canonical fields for this player/era. The category remains visible so Sports Terminal never implies that modern tracking or model data exists historically when it does not.',
                  style: const TextStyle(color: _hMuted, height: 1.5),
                ),
              )
            else
              _HistoricalCareerTable(
                rows: seasons,
                family: family,
                metricKeys: familyKeys,
                basis: basis,
                expanded: expanded,
                onExpand: (key) => setState(() {
                  if (!expanded.add(key)) expanded.remove(key);
                }),
              ),
            const SizedBox(height: 12),
            _HistoricalHonors(
              awards: awards,
              allStar: allStar,
              draft: draft,
            ),
            const SizedBox(height: 12),
            _HistoricalGlossary(family: family),
          ],
        );
      },
    );
  }
}

class ProductHistoricalTeamDossier extends StatefulWidget {
  const ProductHistoricalTeamDossier({
    super.key,
    required this.teamKeyOrQuery,
    required this.teamName,
  });

  final String teamKeyOrQuery;
  final String teamName;

  @override
  State<ProductHistoricalTeamDossier> createState() =>
      _ProductHistoricalTeamDossierState();
}

class _ProductHistoricalTeamDossierState extends State<ProductHistoricalTeamDossier> {
  final HistoricalNbaRepository repository = const HistoricalNbaRepository();
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    try {
      return await repository.teamHistory(widget.teamKeyOrQuery);
    } catch (_) {
      final matches = await repository.searchTeams(widget.teamName, limit: 50);
      Map<String, dynamic>? match;
      final needle = widget.teamName.toLowerCase().trim();
      for (final candidate in matches) {
        final name = '${candidate['canonical_name'] ?? ''}'.toLowerCase();
        final abbreviation = '${candidate['abbreviation'] ?? ''}'.toLowerCase();
        if (name == needle ||
            abbreviation == needle ||
            '${candidate['team_key'] ?? ''}' == widget.teamKeyOrQuery) {
          match = candidate;
          break;
        }
      }
      match ??= matches.isEmpty ? null : matches.first;
      if (match == null) rethrow;
      return repository.teamHistory('${match['team_key']}');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _HistoricalPanel(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _HistoricalPanel(
              child: Text(
                'Historical team identity unavailable: ${snapshot.error}',
                style: const TextStyle(color: _hMuted),
              ),
            );
          }
          final team = snapshot.data!['team'] is Map
              ? (snapshot.data!['team'] as Map)
                  .map((key, value) => MapEntry(key.toString(), value))
              : <String, dynamic>{};
          final rows = _rows(snapshot.data!['rows']).reversed.toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoricalPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NBA / HISTORICAL TEAM DOSSIER',
                      style: TextStyle(
                        color: _hBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${team['canonical_name'] ?? widget.teamName}',
                      style: const TextStyle(
                        color: _hText,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${team['abbreviation'] ?? '—'} · ${team['league_id'] ?? '—'} · ${team['first_season'] ?? '—'} to ${team['last_season'] ?? '—'}',
                      style: const TextStyle(color: _hMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _HistoricalPanel(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 920,
                    child: Table(
                      border: const TableBorder(
                        horizontalInside: BorderSide(color: _hLine, width: .5),
                      ),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: _hPanel2),
                          children: [
                            _TH('SEASON'),
                            _TH('LEAGUE'),
                            _TH('TYPE'),
                            _TH('G'),
                            _TH('W'),
                            _TH('L'),
                            _TH('W%'),
                            _TH('PTS'),
                            _TH('OPP PTS'),
                          ],
                        ),
                        for (final row in rows)
                          TableRow(
                            children: [
                              _TC('${row['season_id'] ?? '—'}'),
                              _TC('${row['league_id'] ?? '—'}'),
                              _TC('${row['season_type'] ?? '—'}'),
                              _TC(_plain(row['games'])),
                              _TC(_plain(row['wins'])),
                              _TC(_plain(row['losses'])),
                              _TC(_percent(row['win_pct'])),
                              _TC(_plain(row['pts'] ?? row['points'])),
                              _TC(_plain(row['opp_pts'] ?? row['opponent_points'])),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _HistoricalPanel(
                child: Text(
                  'This route uses canonical franchise/team-season evidence from the historical warehouse. Relocations and name changes remain explicit in the canonical identity layer rather than being rewritten into a present-day team label.',
                  style: TextStyle(color: _hMuted, height: 1.5),
                ),
              ),
            ],
          );
        },
      );
}

class _HistoricalPlayerBundle {
  const _HistoricalPlayerBundle({
    required this.playerKey,
    required this.identity,
    required this.rows,
  });

  final String playerKey;
  final Map<String, dynamic> identity;
  final List<Map<String, dynamic>> rows;
}

class _HistoricalCareerTable extends StatelessWidget {
  const _HistoricalCareerTable({
    required this.rows,
    required this.family,
    required this.metricKeys,
    required this.basis,
    required this.expanded,
    required this.onExpand,
  });

  final List<Map<String, dynamic>> rows;
  final NbaTerminalStatFamily family;
  final List<String> metricKeys;
  final NbaStatsBasis basis;
  final Set<String> expanded;
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) {
    final visibleKeys = metricKeys
        .where((key) => rows.any((row) => _historicalValue(row, key, basis) != null))
        .toList();
    return _HistoricalPanel(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(82),
          columnWidths: const {
            0: FixedColumnWidth(92),
            1: FixedColumnWidth(64),
            2: FixedColumnWidth(72),
          },
          border: const TableBorder(
            horizontalInside: BorderSide(color: _hLine, width: .5),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: _hPanel2),
              children: [
                const _TH('SEASON'),
                const _TH('TEAM'),
                const _TH('LEAGUE'),
                for (final key in visibleKeys)
                  _MetricHeader(
                    keyName: key,
                    expanded: expanded.contains(key),
                    expandable: _isExpandable(family, key),
                    onTap: _isExpandable(family, key) ? () => onExpand(key) : null,
                  ),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  _TC('${row['season_id'] ?? '—'}'),
                  _TC('${row['team_abbreviation'] ?? '—'}'),
                  _TC('${row['league_id'] ?? '—'}'),
                  for (final key in visibleKeys)
                    _TC(_historicalFormat(row, key, basis)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricHeader extends StatelessWidget {
  const _MetricHeader({
    required this.keyName,
    required this.expanded,
    required this.expandable,
    this.onTap,
  });

  final String keyName;
  final bool expanded;
  final bool expandable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final metric = nbaTerminalMetricByKey[keyName];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expandable)
              Icon(
                expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 15,
                color: _hAmber,
              ),
            Flexible(
              child: Text(
                metric?.shortLabel ?? keyName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _hMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricalHonors extends StatelessWidget {
  const _HistoricalHonors({
    required this.awards,
    required this.allStar,
    required this.draft,
  });

  final List awards;
  final List allStar;
  final List draft;

  @override
  Widget build(BuildContext context) => _HistoricalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HONORS / DRAFT',
              style: TextStyle(
                color: _hAmber,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 8),
            if (draft.isNotEmpty)
              for (final item in draft.take(3))
                Text(
                  'Draft ${_m(item, 'draft_year')} · Rd ${_m(item, 'round_text')} · Pick ${_m(item, 'pick_number')} · ${_m(item, 'drafting_team_text')}',
                  style: const TextStyle(color: _hText, height: 1.5),
                ),
            if (awards.isNotEmpty) ...[
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final item in awards.reversed.take(16))
                    _Pill(
                      '${_m(item, 'season_id')} · ${_m(item, 'award')}',
                      _m(item, 'winner') == '1' ? _hGreen : _hAmber,
                    ),
                ],
              ),
            ],
            if (allStar.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                '${allStar.length} canonical All-Star selection record${allStar.length == 1 ? '' : 's'}',
                style: const TextStyle(color: _hBlue, fontWeight: FontWeight.w800),
              ),
            ],
            if (draft.isEmpty && awards.isEmpty && allStar.isEmpty)
              const Text(
                'No canonical award, All-Star or draft rows are attached to this identity yet.',
                style: TextStyle(color: _hMuted),
              ),
          ],
        ),
      );
}

class _HistoricalGlossary extends StatelessWidget {
  const _HistoricalGlossary({required this.family});
  final NbaTerminalStatFamily family;

  @override
  Widget build(BuildContext context) => _HistoricalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${family.label.toUpperCase()} GLOSSARY',
              style: const TextStyle(
                color: _hAmber,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final key in <String>{
              ...family.metrics,
              for (final parent in family.metrics)
                ...(family.expansionOverrides[parent] ??
                    nbaTerminalMetricByKey[parent]?.children ??
                    const <String>[]),
            })
              if (nbaTerminalMetricByKey[key] case final metric?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(color: _hMuted, fontSize: 10, height: 1.4),
                      children: [
                        TextSpan(
                          text: '${metric.shortLabel} — ',
                          style: const TextStyle(
                            color: _hText,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: metric.description),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
}

class _HistoricalPanel extends StatelessWidget {
  const _HistoricalPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: _hPanel,
          border: Border.all(color: _hLine),
        ),
        child: child,
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _hPanel2,
          border: Border.all(color: color.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _TH extends StatelessWidget {
  const _TH(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _hMuted,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _TC extends StatelessWidget {
  const _TC(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _hText,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _FamilyDrop extends StatelessWidget {
  const _FamilyDrop({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: 230,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: _hPanel2, border: Border.all(color: _hLine)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: _hPanel2,
            items: [
              for (final family in nbaTerminalStatFamilies)
                DropdownMenuItem(value: family.id, child: Text(family.label)),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

class _EnumDrop<T> extends StatelessWidget {
  const _EnumDrop({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: 160,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: _hPanel2, border: Border.all(color: _hLine)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: _hPanel2,
            items: [
              for (final item in values)
                DropdownMenuItem(value: item, child: Text(label(item))),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      );
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

bool _isExpandable(NbaTerminalStatFamily family, String key) {
  return (family.expansionOverrides[key]?.isNotEmpty ?? false) ||
      (nbaTerminalMetricByKey[key]?.children.isNotEmpty ?? false);
}

double? _historicalValue(
  Map<String, dynamic> row,
  String metricKey,
  NbaStatsBasis basis,
) {
  final metric = nbaTerminalMetricByKey[metricKey];
  if (metric == null) return null;
  final candidates = <String>{
    metricKey,
    if (metric.engineKey != null) metric.engineKey!,
    ...metric.rawAliases,
    ...?_historicalAliases[metricKey],
  };
  double? value;
  for (final candidate in candidates) {
    value = _num(row[candidate]);
    if (value != null) break;
  }
  value ??= switch (metricKey) {
    'ast_to' => _ratio(_num(row['ast']), _num(row['tov'])),
    'pps' => _ratio(_num(row['pts']), _num(row['fga'])),
    'net_rating' => _subtract(_num(row['ortg']), _num(row['drtg'])),
    _ => null,
  };
  if (value == null) return null;
  if (metric.format == NbaTerminalMetricFormat.percent ||
      const {'per', 'ws48', 'obpm', 'dbpm', 'bpm', 'vorp', 'ortg', 'drtg', 'ast_to'}
          .contains(metricKey)) {
    return value;
  }
  if (metricKey == 'gp' || basis == NbaStatsBasis.totals) return value;
  final games = _num(row['games']) ?? 0;
  final minutes = _num(row['minutes']) ?? 0;
  if (basis == NbaStatsBasis.perGame) {
    return games > 0 ? value / games : null;
  }
  if (basis == NbaStatsBasis.per36) {
    return minutes > 0 ? value * 36 / minutes : null;
  }
  if (basis == NbaStatsBasis.per48) {
    return minutes > 0 ? value * 48 / minutes : null;
  }
  final possessions = (_num(row['fga']) ?? 0) +
      .44 * (_num(row['fta']) ?? 0) -
      (_num(row['orb']) ?? 0) +
      (_num(row['tov']) ?? 0);
  if (possessions <= 0) return null;
  if (basis == NbaStatsBasis.per75) return value * 75 / possessions;
  if (basis == NbaStatsBasis.per100) return value * 100 / possessions;
  return value;
}

String _historicalFormat(
  Map<String, dynamic> row,
  String metricKey,
  NbaStatsBasis basis,
) {
  final metric = nbaTerminalMetricByKey[metricKey];
  final value = _historicalValue(row, metricKey, basis);
  if (metric == null || value == null || !value.isFinite) return '—';
  return switch (metric.format) {
    NbaTerminalMetricFormat.integer => value.round().toString(),
    NbaTerminalMetricFormat.percent =>
      '${(value.abs() <= 1.5 ? value * 100 : value).toStringAsFixed(metric.decimals)}%',
    NbaTerminalMetricFormat.signed =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(metric.decimals)}',
    NbaTerminalMetricFormat.seconds => '${value.toStringAsFixed(metric.decimals)}s',
    NbaTerminalMetricFormat.inches => '${value.toStringAsFixed(metric.decimals)} in',
    NbaTerminalMetricFormat.pounds => '${value.toStringAsFixed(metric.decimals)} lb',
    NbaTerminalMetricFormat.decimal => value.toStringAsFixed(metric.decimals),
  };
}

const Map<String, List<String>> _historicalAliases = {
  'gp': ['games'],
  'mpg': ['minutes'],
  'ppg': ['pts'],
  'rpg': ['reb'],
  'oreb': ['orb'],
  'dreb': ['drb'],
  'apg': ['ast'],
  'spg': ['stl'],
  'bpg': ['blk'],
  'tpg': ['tov'],
  'personal_fouls': ['pf'],
  'usage': ['usg_pct'],
};

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}');
}

double? _ratio(double? numerator, double? denominator) {
  if (numerator == null || denominator == null || denominator == 0) return null;
  return numerator / denominator;
}

double? _subtract(double? left, double? right) {
  if (left == null || right == null) return null;
  return left - right;
}

String _m(Object? item, String key) {
  if (item is Map) return '${item[key] ?? '—'}';
  return '—';
}

String _plain(Object? value) {
  final numeric = _num(value);
  if (numeric == null) return '—';
  return numeric == numeric.roundToDouble()
      ? numeric.round().toString()
      : numeric.toStringAsFixed(1);
}

String _percent(Object? value) {
  final numeric = _num(value);
  if (numeric == null) return '—';
  return '${(numeric.abs() <= 1.5 ? numeric * 100 : numeric).toStringAsFixed(1)}%';
}
