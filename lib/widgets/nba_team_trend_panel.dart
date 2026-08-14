import 'package:flutter/material.dart';

import '../services/nba_team_trend_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'nba_terminal_trend_chart.dart';

const _panel2 = Color(0xFF141C25);
const _line = Color(0xFF263342);
const _text = Color(0xFFE8EDF3);
const _muted = Color(0xFF8895A5);
const _blue = Color(0xFF63A9FF);
const _green = Color(0xFF69C99A);
const _amber = Color(0xFFE2B866);

typedef NbaTeamTrendGameOpenCallback = void Function(
  String gameId,
  String gameLabel,
);

class NbaTeamTrendPanel extends StatefulWidget {
  const NbaTeamTrendPanel({
    super.key,
    required this.seed,
    required this.teamId,
    required this.seasonType,
    required this.onOpenGame,
  });

  final NbaTerminalSeedSnapshot seed;
  final String teamId;
  final String seasonType;
  final NbaTeamTrendGameOpenCallback onOpenGame;

  @override
  State<NbaTeamTrendPanel> createState() => _NbaTeamTrendPanelState();
}

class _NbaTeamTrendPanelState extends State<NbaTeamTrendPanel> {
  NbaTeamTrendMetric _metric = NbaTeamTrendMetric.differential;
  int _rollingWindow = 5;

  @override
  Widget build(BuildContext context) {
    final result = const NbaTeamTrendEngine().build(
      widget.seed,
      teamId: widget.teamId,
      seasonType: widget.seasonType,
      metric: _metric,
      rollingWindow: _rollingWindow,
      maxGames: 20,
    );
    return Container(
      key: ValueKey('team-trend-panel-${widget.teamId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panel2, border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'TEAM TREND LAB',
                style: TextStyle(
                  color: _amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6,
                ),
              ),
              DropdownButton<NbaTeamTrendMetric>(
                key: const ValueKey('team-trend-metric'),
                value: _metric,
                dropdownColor: _panel2,
                style: const TextStyle(color: _text, fontSize: 9),
                items: [
                  for (final metric in NbaTeamTrendMetric.values)
                    DropdownMenuItem(value: metric, child: Text(metric.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _metric = value);
                },
              ),
              DropdownButton<int>(
                key: const ValueKey('team-trend-window'),
                value: _rollingWindow,
                dropdownColor: _panel2,
                style: const TextStyle(color: _text, fontSize: 9),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3-game rolling')),
                  DropdownMenuItem(value: 5, child: Text('5-game rolling')),
                  DropdownMenuItem(value: 10, child: Text('10-game rolling')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _rollingWindow = value);
                },
              ),
              _kpi('GAMES', '${result.completedGames}'),
              _kpi('AVG', _number(result.average)),
              _kpi('LAST 5', result.recentRecord),
              _kpi('LAST 5 DIFF', _signed(result.recentAverageDifferential)),
              _pill('STREAK ${result.currentStreak}', _streakColor(result.currentStreak)),
            ],
          ),
          const SizedBox(height: 10),
          NbaTerminalTrendChart(
            points: [
              for (final row in result.observations)
                NbaTerminalTrendPoint(
                  label: row.gameDate,
                  value: row.value,
                  rollingValue: row.rollingAverage,
                  gameId: row.gameId,
                ),
            ],
            metricLabel: _metric.label,
          ),
          if (result.observations.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 30,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                headingTextStyle: const TextStyle(
                  color: _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: const TextStyle(color: _text, fontSize: 9),
                columns: const [
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('MATCHUP')),
                  DataColumn(label: Text('RESULT')),
                  DataColumn(label: Text('VALUE')),
                  DataColumn(label: Text('ROLLING')),
                  DataColumn(label: Text('GAME')),
                ],
                rows: [
                  for (final row in result.observations.reversed.take(8))
                    DataRow(cells: [
                      DataCell(Text(row.gameDate.isEmpty ? '—' : row.gameDate)),
                      DataCell(Text(row.matchupLabel)),
                      DataCell(
                        Text(
                          row.resultLabel,
                          style: TextStyle(
                            color: row.won ? _green : row.lost ? _amber : _text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      DataCell(Text(_number(row.value))),
                      DataCell(Text(_number(row.rollingAverage))),
                      DataCell(
                        TextButton(
                          key: ValueKey('team-trend-open-${row.gameId}'),
                          onPressed: () => widget.onOpenGame(
                            row.gameId,
                            '${widget.teamId} ${row.matchupLabel}',
                          ),
                          child: const Text('Open'),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Dataset ${result.datasetStatus} · validation ${result.validationStatus} · completed scored games only',
            style: const TextStyle(color: _muted, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

Widget _kpi(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: _line)),
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

String _number(num? value) => value == null ? '—' : value.toStringAsFixed(1);
String _signed(num? value) {
  if (value == null) return '—';
  return '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}';
}

Color _streakColor(String streak) {
  if (streak.startsWith('W')) return _green;
  if (streak.startsWith('L')) return _amber;
  return _blue;
}
