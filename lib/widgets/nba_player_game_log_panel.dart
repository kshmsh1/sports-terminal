import 'package:flutter/material.dart';

import '../services/nba_player_game_log_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'nba_game_navigation.dart';
import 'nba_player_trend_panel.dart';

const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);

typedef NbaPlayerGameOpenCallback = void Function(
  String gameId,
  String gameLabel,
);

class NbaPlayerGameLogPanel extends StatelessWidget {
  const NbaPlayerGameLogPanel({
    super.key,
    required this.seed,
    required this.playerId,
    required this.playerName,
    required this.seasonType,
    required this.onOpenGame,
    required this.onOpenTeam,
    this.limit = 20,
  });

  final NbaTerminalSeedSnapshot seed;
  final String playerId;
  final String playerName;
  final String seasonType;
  final NbaPlayerGameOpenCallback onOpenGame;
  final ValueChanged<String> onOpenTeam;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final result = const NbaPlayerGameLogEngine().build(
      seed,
      playerId: playerId,
      playerName: playerName,
      seasonType: seasonType,
      limit: limit,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: _panel, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GAME LOG',
                        style: TextStyle(
                          color: _amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Canonical game-linked player performance. Missing game joins remain visible rather than being synthesized.',
                        style: TextStyle(color: _muted, fontSize: 10, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    _pill('${result.rows.length} ROWS', _blue),
                    _pill('${result.linkedRows} LINKED', _green),
                    if (result.unlinkedRows > 0)
                      _pill('${result.unlinkedRows} UNLINKED', _amber),
                    if (result.historicalContext) _pill('HISTORICAL', _blue),
                    if (result.usedFallbackDataset) _pill('FALLBACK', _amber),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          if (seed.supportedSeason.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
              child: OutlinedButton.icon(
                key: ValueKey('player-open-season-$playerId'),
                onPressed: () => openNbaSeasonPage(
                  context,
                  seasonId: seed.supportedSeason,
                  loadSeed: () async => seed,
                  onOpenTeam: onOpenTeam,
                ),
                icon: const Icon(Icons.calendar_view_month_rounded, size: 15),
                label: Text('OPEN ${seed.supportedSeason} SEASON'),
              ),
            ),
          if (result.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 34),
              child: Center(
                child: Text(
                  'No player game-log rows are available in the active season-type scope.',
                  style: TextStyle(color: _muted),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_panel2),
                headingTextStyle: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: const TextStyle(color: _text, fontSize: 10),
                columnSpacing: 22,
                columns: const [
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('MATCHUP')),
                  DataColumn(label: Text('RESULT')),
                  DataColumn(label: Text('MIN')),
                  DataColumn(label: Text('PTS')),
                  DataColumn(label: Text('REB')),
                  DataColumn(label: Text('AST')),
                  DataColumn(label: Text('STL')),
                  DataColumn(label: Text('BLK')),
                  DataColumn(label: Text('TOV')),
                  DataColumn(label: Text('FG')),
                  DataColumn(label: Text('3PT')),
                  DataColumn(label: Text('FT')),
                  DataColumn(label: Text('+/-')),
                  DataColumn(label: Text('GAME')),
                ],
                rows: [
                  for (final row in result.rows)
                    DataRow(
                      key: ValueKey('player-game-log-${row.gameId.isEmpty ? row.gameDate : row.gameId}'),
                      cells: [
                        DataCell(Text(row.gameDate.isEmpty ? '—' : row.gameDate)),
                        DataCell(_matchup(row)),
                        DataCell(
                          Text(
                            row.resultLabel,
                            style: TextStyle(
                              color: row.won
                                  ? _green
                                  : row.lost
                                      ? _amber
                                      : _text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        DataCell(Text(row.minutes.isEmpty ? '—' : row.minutes)),
                        DataCell(Text(_stat(row.points))),
                        DataCell(Text(_stat(row.rebounds))),
                        DataCell(Text(_stat(row.assists))),
                        DataCell(Text(_stat(row.steals))),
                        DataCell(Text(_stat(row.blocks))),
                        DataCell(Text(_stat(row.turnovers))),
                        DataCell(Text(_madeAttempted(row.fieldGoalsMade, row.fieldGoalsAttempted))),
                        DataCell(Text(_madeAttempted(row.threePointersMade, row.threePointersAttempted))),
                        DataCell(Text(_madeAttempted(row.freeThrowsMade, row.freeThrowsAttempted))),
                        DataCell(Text(_signed(row.plusMinus))),
                        DataCell(
                          TextButton.icon(
                            key: row.gameId.isEmpty
                                ? null
                                : ValueKey('player-open-game-${row.gameId}'),
                            onPressed: row.linkedCanonicalGame && row.gameId.isNotEmpty
                                ? () => onOpenGame(
                                      row.gameId,
                                      '${row.team.abbreviation} ${row.matchupLabel}',
                                    )
                                : null,
                            icon: const Icon(Icons.open_in_new_rounded, size: 15),
                            label: Text(row.linkedCanonicalGame ? 'Open' : 'Unlinked'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: NbaPlayerTrendPanel(
              seed: seed,
              playerId: playerId,
              playerName: playerName,
              seasonType: seasonType,
              onOpenGame: onOpenGame,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              'Dataset ${result.datasetStatus} · validation ${result.validationStatus}',
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchup(NbaPlayerGameLogRow row) {
    final opponentId = row.opponent.id;
    final label = row.matchupLabel;
    if (opponentId.isEmpty) return Text(label);
    return InkWell(
      key: ValueKey('player-game-opponent-$opponentId-${row.gameId}'),
      onTap: () => onOpenTeam(opponentId),
      child: Text(
        label,
        style: const TextStyle(
          color: _blue,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.underline,
          decorationColor: _blue,
        ),
      ),
    );
  }

  static String _stat(num? value) => value?.toString() ?? '—';

  static String _madeAttempted(int? made, int? attempted) {
    if (made == null && attempted == null) return '—';
    return '${made ?? '—'}-${attempted ?? '—'}';
  }

  static String _signed(num? value) {
    if (value == null) return '—';
    if (value > 0) return '+$value';
    return value.toString();
  }

  static Widget _pill(String label, Color color) => Container(
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
}
