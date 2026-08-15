import 'package:flutter/material.dart';

import '../services/nba_entity_intelligence_repository.dart';
import '../services/nba_season_source_context_engine.dart';

const _bg = Color(0xFF0F151C);
const _panel = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _amber = Color(0xFFE2B866);
const _green = Color(0xFF69C99A);

typedef NbaSeasonContextLoader = Future<Map<String, dynamic>> Function();

class NbaSeasonSourceContextPanel extends StatefulWidget {
  const NbaSeasonSourceContextPanel({
    super.key,
    required this.seasonId,
    required this.seasonType,
    this.league = 'NBA',
    this.loadContext,
    this.onOpenPlayer,
    this.onOpenTeam,
  });

  final String seasonId;
  final String seasonType;
  final String league;
  final NbaSeasonContextLoader? loadContext;
  final void Function(String playerId, String playerName)? onOpenPlayer;
  final ValueChanged<String>? onOpenTeam;

  @override
  State<NbaSeasonSourceContextPanel> createState() =>
      _NbaSeasonSourceContextPanelState();
}

class _NbaSeasonSourceContextPanelState
    extends State<NbaSeasonSourceContextPanel> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(NbaSeasonSourceContextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seasonId != widget.seasonId ||
        oldWidget.seasonType != widget.seasonType ||
        oldWidget.league != widget.league ||
        oldWidget.loadContext != widget.loadContext) {
      _future = _load();
    }
  }

  Future<Map<String, dynamic>> _load() => widget.loadContext?.call() ??
      const NbaEntityIntelligenceRepository().seasonCommand(
        widget.seasonId,
        league: widget.league,
        seasonType: _apiSeasonType(widget.seasonType),
        leaderLimit: 10,
      );

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('season-source-context-panel'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _bg, border: Border.all(color: _line)),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 8),
                  Text(
                    'Canonical historical Season context is unavailable: ${snapshot.error}',
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              );
            }
            final source = const NbaSeasonSourceContextEngine().build(
              snapshot.data!,
              seasonId: widget.seasonId,
              league: widget.league,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 4),
                const Text(
                  'Historical command context is displayed only from canonical source rows. Missing transaction coverage remains visibly unavailable rather than being reconstructed from news or roster changes.',
                  style: TextStyle(color: _muted, fontSize: 9, height: 1.4),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _chip('AWARDS', '${source.awards.length}'),
                    _chip('ALL-STAR', '${source.allStar.length}'),
                    _chip('DRAFT', '${source.draft.length}'),
                    _chip('COVERAGE', '${source.coverage.length}'),
                    _chip(
                      'TRANSACTIONS',
                      source.transactionCoverageAvailable
                          ? '${source.transactions.length}'
                          : 'NOT EXPOSED',
                      source.transactionCoverageAvailable ? _green : _amber,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, constraints) {
                  final awards = _awards(source);
                  final draft = _draft(source);
                  if (constraints.maxWidth < 980) {
                    return Column(children: [
                      awards,
                      const SizedBox(height: 10),
                      draft,
                    ]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: awards),
                      const SizedBox(width: 10),
                      Expanded(child: draft),
                    ],
                  );
                }),
                const SizedBox(height: 10),
                _coverageAndTransactions(source),
              ],
            );
          },
        ),
      );

  Widget _header() => const Text(
        'SEASON SOURCE CONTEXT',
        style: TextStyle(
          color: _amber,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .7,
        ),
      );

  Widget _awards(NbaSeasonSourceContext source) => _section(
        'AWARDS + ALL-STAR',
        source.awards.isEmpty && source.allStar.isEmpty
            ? const _Empty('No award or All-Star rows are exposed for this season.')
            : Column(
                children: [
                  for (final award in source.awards.take(10))
                    _entityRow(
                      leading: award.winner ? 'WIN' : (award.rankText.isEmpty ? '—' : award.rankText),
                      title: award.award,
                      subtitle: award.playerName.isEmpty ? 'Recipient unavailable' : award.playerName,
                      onTap: widget.onOpenPlayer == null || award.playerId.isEmpty
                          ? null
                          : () => widget.onOpenPlayer!(award.playerId, award.playerName),
                    ),
                  if (source.allStar.isNotEmpty) ...[
                    const Divider(color: _line),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ALL-STAR · ${source.allStar.length} source rows',
                        style: const TextStyle(color: _blue, fontSize: 8, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 5),
                    for (final player in source.allStar.take(8))
                      _entityRow(
                        leading: player.starter ? 'START' : 'SELECT',
                        title: player.playerName.isEmpty ? player.playerId : player.playerName,
                        subtitle: player.teamLabel,
                        onTap: widget.onOpenPlayer == null || player.playerId.isEmpty
                            ? null
                            : () => widget.onOpenPlayer!(player.playerId, player.playerName),
                      ),
                  ],
                ],
              ),
      );

  Widget _draft(NbaSeasonSourceContext source) => _section(
        'DRAFT CONTEXT',
        source.draft.isEmpty
            ? const _Empty('No canonical draft rows are exposed for this season context.')
            : Column(
                children: [
                  for (final row in source.draft.take(12))
                    _entityRow(
                      leading: row.pickNumber == null ? (row.roundText.isEmpty ? '—' : row.roundText) : '#${row.pickNumber}',
                      title: row.playerName.isEmpty ? row.playerId : row.playerName,
                      subtitle: [
                        if (row.draftYear != null) '${row.draftYear}',
                        if (row.teamLabel.isNotEmpty) row.teamLabel,
                      ].join(' · '),
                      onTap: widget.onOpenPlayer == null || row.playerId.isEmpty
                          ? null
                          : () => widget.onOpenPlayer!(row.playerId, row.playerName),
                      trailing: widget.onOpenTeam == null || row.teamId.isEmpty
                          ? null
                          : () => widget.onOpenTeam!(row.teamId),
                    ),
                ],
              ),
      );

  Widget _coverageAndTransactions(NbaSeasonSourceContext source) => _section(
        'COVERAGE + TRANSACTION BOUNDARY',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (source.coverage.isEmpty)
              const Text(
                'No canonical coverage-domain rows are exposed.',
                style: TextStyle(color: _muted, fontSize: 9),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final row in source.coverage)
                    _chip(
                      row.domain.toUpperCase(),
                      [
                        if (row.status.isNotEmpty) row.status.toUpperCase(),
                        if (row.rows != null) '${row.rows} ROWS',
                      ].join(' · '),
                    ),
                ],
              ),
            const SizedBox(height: 9),
            if (!source.transactionCoverageAvailable)
              const Text(
                'TRANSACTION DATASET NOT EXPOSED · The canonical Season command currently provides no transaction collection. Sports Terminal will not infer transactions from roster differences or prose.',
                key: ValueKey('season-transactions-not-exposed'),
                style: TextStyle(color: _amber, fontSize: 8, height: 1.4),
              )
            else if (source.transactions.isEmpty)
              const Text(
                'Transaction collection is exposed, but it contains no usable source rows for this season.',
                style: TextStyle(color: _muted, fontSize: 8),
              )
            else
              for (final row in source.transactions.take(20))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${row.date.isEmpty ? 'DATE —' : row.date} · ${row.type.isEmpty ? 'TRANSACTION' : row.type.toUpperCase()} · ${row.description}',
                    style: const TextStyle(color: _text, fontSize: 8),
                  ),
                ),
          ],
        ),
      );

  Widget _entityRow({
    required String leading,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    VoidCallback? trailing,
  }) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                leading,
                style: const TextStyle(color: _muted, fontSize: 7, fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: onTap == null ? _text : _blue, fontSize: 9, fontWeight: FontWeight.w800)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 8)),
                  ],
                ),
              ),
            ),
            if (trailing != null)
              IconButton(
                tooltip: 'Open team',
                onPressed: trailing,
                icon: const Icon(Icons.groups_rounded, color: _blue, size: 15),
              ),
          ],
        ),
      );

  Widget _section(String title, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _chip(String label, String value, [Color color = _text]) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: Text('$label $value', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(message, style: const TextStyle(color: _muted, fontSize: 9)),
      );
}

String _apiSeasonType(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('playoff')) return 'playoffs';
  if (normalized == 'all' || normalized.contains('combined')) return 'combined';
  return 'regular';
}
