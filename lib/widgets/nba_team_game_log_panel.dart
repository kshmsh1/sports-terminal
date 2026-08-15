import 'package:flutter/material.dart';

import '../services/nba_game_schedule_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'nba_game_navigation.dart';
import 'nba_team_trend_panel.dart';

const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);

typedef NbaTeamGameOpenCallback = void Function(
  String gameId,
  String gameLabel,
);

class NbaTeamGameLogPanel extends StatelessWidget {
  const NbaTeamGameLogPanel({
    super.key,
    required this.seed,
    required this.teamId,
    required this.seasonType,
    required this.onOpenGame,
    required this.onOpenTeam,
    required this.onOpenSchedule,
    this.limit = 15,
  });

  final NbaTerminalSeedSnapshot seed;
  final String teamId;
  final String seasonType;
  final NbaTeamGameOpenCallback onOpenGame;
  final ValueChanged<String> onOpenTeam;
  final VoidCallback onOpenSchedule;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final result = const NbaGameScheduleEngine().build(
      seed,
      teamId: teamId,
      seasonType: seasonType,
      ascending: false,
    );
    final rows = result.rows.take(limit).toList(growable: false);

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEAM GAMES',
                        style: TextStyle(
                          color: _amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.rows.length} canonical games in the active ${seasonType.toLowerCase()} scope.',
                        style: const TextStyle(color: _muted, fontSize: 10, height: 1.35),
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
                    if (seed.supportedSeason.trim().isNotEmpty)
                      TextButton.icon(
                        key: ValueKey('team-open-season-$teamId'),
                        onPressed: () => openNbaSeasonPage(
                          context,
                          seasonId: seed.supportedSeason,
                          loadSeed: () async => seed,
                          onOpenTeam: onOpenTeam,
                        ),
                        icon: const Icon(Icons.calendar_view_month_rounded, size: 16),
                        label: Text('${seed.supportedSeason} Season'),
                      ),
                    TextButton.icon(
                      key: ValueKey('team-open-schedule-$teamId'),
                      onPressed: onOpenSchedule,
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: const Text('Full schedule'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 34),
              child: Center(
                child: Text(
                  'No canonical team games are available in the active season-type scope.',
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
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('MATCHUP')),
                  DataColumn(label: Text('RESULT')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('LOCATION')),
                  DataColumn(label: Text('GAME')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      key: ValueKey('team-game-row-${row.gameId}'),
                      cells: [
                        DataCell(Text(row.gameDate.isEmpty ? '—' : row.gameDate)),
                        DataCell(_matchup(row)),
                        DataCell(_result(row)),
                        DataCell(Text(row.status.isEmpty ? '—' : row.status)),
                        DataCell(
                          SizedBox(
                            width: 190,
                            child: Text(
                              row.locationLabel.isEmpty ? '—' : row.locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          TextButton.icon(
                            key: ValueKey('team-open-game-${row.gameId}'),
                            onPressed: () => onOpenGame(row.gameId, row.matchupLabel),
                            icon: const Icon(Icons.open_in_new_rounded, size: 15),
                            label: const Text('Open'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: NbaTeamTrendPanel(
              seed: seed,
              teamId: teamId,
              seasonType: seasonType,
              onOpenGame: onOpenGame,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill(result.datasetStatus.toUpperCase(), _green),
                _pill('VALIDATION ${result.validationStatus.toUpperCase()}', _green),
                if (result.historicalContext) _pill('HISTORICAL', _blue),
                if (result.usedFallbackDataset) _pill('FALLBACK', _amber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchup(NbaGameScheduleRow row) {
    final normalized = teamId.trim().toUpperCase();
    final home = row.homeTeamId.trim().toUpperCase() == normalized;
    final opponentId = home ? row.awayTeamId : row.homeTeamId;
    final opponentLabel = home ? row.awayTeamAbbreviation : row.homeTeamAbbreviation;
    final prefix = home ? 'vs' : '@';
    return InkWell(
      onTap: opponentId.isEmpty ? null : () => onOpenTeam(opponentId),
      child: Text(
        '$prefix ${opponentLabel.isEmpty ? opponentId : opponentLabel}',
        style: TextStyle(
          color: opponentId.isEmpty ? _text : _blue,
          fontWeight: FontWeight.w900,
          decoration: opponentId.isEmpty ? null : TextDecoration.underline,
          decorationColor: _blue,
        ),
      ),
    );
  }

  Widget _result(NbaGameScheduleRow row) {
    final normalized = teamId.trim().toUpperCase();
    final home = row.homeTeamId.trim().toUpperCase() == normalized;
    final teamScore = home ? row.homeScore : row.awayScore;
    final opponentScore = home ? row.awayScore : row.homeScore;
    if (teamScore == null || opponentScore == null) {
      return const Text('—', style: TextStyle(color: _muted));
    }
    final won = teamScore > opponentScore;
    final lost = teamScore < opponentScore;
    return Text(
      '${won ? 'W' : lost ? 'L' : 'T'} $teamScore–$opponentScore',
      style: TextStyle(
        color: won ? _green : lost ? _amber : _text,
        fontWeight: FontWeight.w900,
      ),
    );
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
