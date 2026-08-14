import 'package:flutter/material.dart';

import '../services/nba_game_schedule_engine.dart';
import '../services/nba_terminal_seed_repository.dart';

const _panel = Color(0xFF0F151C);
const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _amber = Color(0xFFE2B866);

typedef NbaGameDiscoveryOpenCallback = void Function(
  String gameId,
  String gameLabel,
);

class NbaGameDiscoveryPanel extends StatelessWidget {
  const NbaGameDiscoveryPanel({
    super.key,
    required this.seed,
    required this.query,
    required this.seasonType,
    required this.onOpenGame,
    required this.onOpenTeam,
    required this.onOpenSchedule,
    this.limit = 8,
  });

  final NbaTerminalSeedSnapshot seed;
  final String query;
  final String seasonType;
  final NbaGameDiscoveryOpenCallback onOpenGame;
  final ValueChanged<String> onOpenTeam;
  final VoidCallback onOpenSchedule;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const SizedBox.shrink();

    final result = const NbaGameScheduleEngine().build(
      seed,
      query: normalizedQuery,
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GAME DISCOVERY',
                        style: TextStyle(
                          color: _amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.rows.length} canonical games match “$normalizedQuery”.',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('hub-open-game-search-schedule'),
                  onPressed: onOpenSchedule,
                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text('All matches'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: Text(
                'No canonical games match this query in the active season-type scope.',
                style: TextStyle(color: _muted),
              ),
            )
          else
            for (final row in rows)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _line, width: .5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        row.gameDate.isEmpty ? '—' : row.gameDate,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _teamLink(row.awayTeamId, row.awayTeamAbbreviation),
                          const Text('@', style: TextStyle(color: _muted)),
                          _teamLink(row.homeTeamId, row.homeTeamAbbreviation),
                          if (row.hasScore)
                            Text(
                              row.scoreLabel,
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          if (row.status.isNotEmpty)
                            Text(
                              row.status,
                              style: const TextStyle(color: _amber, fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      key: ValueKey('hub-discovery-game-${row.gameId}'),
                      onPressed: () => onOpenGame(row.gameId, row.matchupLabel),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text('Open'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _teamLink(String teamId, String label) => InkWell(
        onTap: teamId.isEmpty ? null : () => onOpenTeam(teamId),
        child: Text(
          label.isEmpty ? (teamId.isEmpty ? '—' : teamId) : label,
          style: TextStyle(
            color: teamId.isEmpty ? _text : _blue,
            fontWeight: FontWeight.w900,
            decoration: teamId.isEmpty ? null : TextDecoration.underline,
            decorationColor: _blue,
          ),
        ),
      );
}
