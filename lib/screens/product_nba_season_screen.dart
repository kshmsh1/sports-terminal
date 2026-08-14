import 'package:flutter/material.dart';

import '../services/nba_season_intelligence_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _bg = Color(0xFF090D12);
const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);

typedef NbaSeasonGameOpenCallback = void Function(
  String gameId,
  String gameLabel,
);

class ProductNbaSeasonScreen extends StatefulWidget {
  const ProductNbaSeasonScreen({
    super.key,
    required this.seasonId,
    this.loadSeed,
    this.onOpenGame,
    this.onOpenTeam,
    this.onOpenSchedule,
  });

  final String seasonId;
  final Future<NbaTerminalSeedSnapshot> Function()? loadSeed;
  final NbaSeasonGameOpenCallback? onOpenGame;
  final ValueChanged<String>? onOpenTeam;
  final VoidCallback? onOpenSchedule;

  @override
  State<ProductNbaSeasonScreen> createState() => _ProductNbaSeasonScreenState();
}

class _ProductNbaSeasonScreenState extends State<ProductNbaSeasonScreen> {
  late Future<NbaTerminalSeedSnapshot> _seedFuture;
  String _seasonType = 'All';

  @override
  void initState() {
    super.initState();
    _seedFuture = _load();
  }

  @override
  void didUpdateWidget(ProductNbaSeasonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seasonId != widget.seasonId ||
        oldWidget.loadSeed != widget.loadSeed) {
      _seedFuture = _load();
    }
  }

  Future<NbaTerminalSeedSnapshot> _load() =>
      widget.loadSeed?.call() ?? const NbaTerminalSeedRepository().load();

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: _seedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _Panel(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Panel(
              child: Text(
                'Season unavailable: ${snapshot.error}',
                style: const TextStyle(color: _muted),
              ),
            );
          }
          final season = const NbaSeasonIntelligenceEngine().build(
            snapshot.data!,
            seasonId: widget.seasonId,
            seasonType: _seasonType,
          );
          return Column(
            key: ValueKey('nba-season-${widget.seasonId}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(
                title: '${widget.seasonId} NBA Season',
                body:
                    'Canonical season spine for schedule/results and scored-game-derived standings. Scheduled games never alter records, and every visible game/team remains a permanent entity link.',
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      key: const ValueKey('season-type-filter'),
                      value: _seasonType,
                      dropdownColor: _panel2,
                      style: const TextStyle(color: _text, fontSize: 10),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All games')),
                        DropdownMenuItem(
                          value: 'Regular Season',
                          child: Text('Regular Season'),
                        ),
                        DropdownMenuItem(value: 'Playoffs', child: Text('Playoffs')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _seasonType = value);
                      },
                    ),
                    _kpi('GAMES', '${season.gameCount}'),
                    _kpi('COMPLETED', '${season.completedGames}'),
                    _kpi('SCHEDULED', '${season.scheduledGames}'),
                    _kpi('TEAMS', '${season.teamCount}'),
                    _kpi('DATES', season.dateRangeLabel),
                    if (widget.onOpenSchedule != null)
                      OutlinedButton.icon(
                        key: const ValueKey('season-open-schedule'),
                        onPressed: widget.onOpenSchedule,
                        icon: const Icon(Icons.calendar_month_rounded, size: 16),
                        label: const Text('OPEN FULL SCHEDULE'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _standings(season),
              const SizedBox(height: 12),
              _games(season),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _pill(season.datasetStatus.toUpperCase(), _green),
                  _pill(
                    'VALIDATION ${season.validationStatus.toUpperCase()}',
                    _green,
                  ),
                  if (season.historicalContext) _pill('HISTORICAL', _blue),
                  if (season.usedFallbackDataset) _pill('FALLBACK', _amber),
                ],
              ),
            ],
          );
        },
      );

  Widget _standings(NbaSeasonIntelligenceSnapshot season) => _Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'SEASON STANDINGS',
                style: TextStyle(
                  color: _amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
            const Divider(height: 1, color: _line),
            if (season.standings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(26),
                child: Text(
                  'No team standings can be derived in this season scope.',
                  style: TextStyle(color: _muted),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_panel2),
                  headingTextStyle: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                  dataTextStyle: const TextStyle(color: _text, fontSize: 9),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('TEAM')),
                    DataColumn(label: Text('W-L')),
                    DataColumn(label: Text('WIN%')),
                    DataColumn(label: Text('PF/G')),
                    DataColumn(label: Text('PA/G')),
                    DataColumn(label: Text('DIFF')),
                  ],
                  rows: [
                    for (var index = 0;
                        index < season.standings.length;
                        index++)
                      DataRow(cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          TextButton(
                            key: ValueKey(
                              'season-team-${season.standings[index].teamId}',
                            ),
                            onPressed: widget.onOpenTeam == null
                                ? null
                                : () => widget.onOpenTeam!(
                                      season.standings[index].teamId,
                                    ),
                            child: Text(
                              season.standings[index].abbreviation.isEmpty
                                  ? season.standings[index].teamId
                                  : season.standings[index].abbreviation,
                            ),
                          ),
                        ),
                        DataCell(Text(season.standings[index].recordLabel)),
                        DataCell(Text(
                          season.standings[index].winPct.toStringAsFixed(3),
                        )),
                        DataCell(Text(
                          season.standings[index].averagePointsFor
                              .toStringAsFixed(1),
                        )),
                        DataCell(Text(
                          season.standings[index].averagePointsAgainst
                              .toStringAsFixed(1),
                        )),
                        DataCell(Text(_signed(
                          season.standings[index].averageDifferential,
                        ))),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _games(NbaSeasonIntelligenceSnapshot season) => _Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SEASON GAME INVENTORY',
                      style: TextStyle(
                        color: _amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  Text(
                    '${season.regularSeasonGames} regular · ${season.playoffGames} playoffs',
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            if (!season.hasGames)
              const Padding(
                padding: EdgeInsets.all(26),
                child: Text(
                  'No canonical games exist in the selected season scope.',
                  style: TextStyle(color: _muted),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_panel2),
                  headingTextStyle: const TextStyle(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                  dataTextStyle: const TextStyle(color: _text, fontSize: 9),
                  columns: const [
                    DataColumn(label: Text('DATE')),
                    DataColumn(label: Text('TYPE')),
                    DataColumn(label: Text('MATCHUP')),
                    DataColumn(label: Text('SCORE')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('GAME')),
                  ],
                  rows: [
                    for (final game in season.games.reversed.take(40))
                      DataRow(cells: [
                        DataCell(Text(
                          game.gameDate.isEmpty ? '—' : game.gameDate,
                        )),
                        DataCell(Text(
                          game.seasonType.isEmpty ? '—' : game.seasonType,
                        )),
                        DataCell(Text(game.matchupLabel)),
                        DataCell(Text(game.scoreLabel)),
                        DataCell(Text(game.status.isEmpty ? '—' : game.status)),
                        DataCell(
                          TextButton(
                            key: ValueKey('season-game-${game.gameId}'),
                            onPressed: widget.onOpenGame == null
                                ? null
                                : () => widget.onOpenGame!(
                                      game.gameId,
                                      game.matchupLabel,
                                    ),
                            child: const Text('Open'),
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NBA / SEASON',
              style: TextStyle(
                color: _amber,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(color: _muted, fontSize: 10, height: 1.45),
            ),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
        child: child,
      );
}

Widget _kpi(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 8),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(color: _muted)),
            TextSpan(
              text: value,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );

Widget _pill(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );

String _signed(num value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}';

// Retained here for route wrappers that want a canonical season background.
const nbaSeasonBackground = _bg;
