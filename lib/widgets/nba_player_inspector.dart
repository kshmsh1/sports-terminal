import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../screens/website_nba_entity_pages.dart';
import '../services/nba_stats_workstation_engine.dart';

/// Contextual player profile shown alongside the sortable Stats tables.
class NbaPlayerInspector extends StatelessWidget {
  const NbaPlayerInspector({
    super.key,
    required this.player,
    required this.session,
    required this.season,
    required this.onClose,
  });

  final NbaStatsRow player;
  final AppSession session;
  final String season;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const engine = NbaStatsWorkstationEngine();
    final headline = [
      ('PPG', 'pts'), ('RPG', 'reb'), ('APG', 'ast'),
    ];
    final measures = [
      ('GP', 'gp'), ('MPG', 'min'), ('FG%', 'fg_pct'),
      ('3P%', 'three_pct'), ('FT%', 'ft_pct'), ('TS%', 'ts_pct'),
      ('SPG', 'stl'), ('BPG', 'blk'), ('TPG', 'tov'),
      ('PER', 'per'), ('BPM', 'bpm'), ('VORP', 'vorp'),
      ('USG%', 'usage'), ('ORTG', 'ortg'), ('DRTG', 'drtg'),
    ];
    String display(String key) {
      final value = player.value(key) ?? (player.raw[key] is num
          ? (player.raw[key] as num).toDouble()
          : double.tryParse(player.raw[key]?.toString() ?? ''));
      return engine.formatValue(key, value);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_search_rounded, size: 19),
              const SizedBox(width: 7),
              const Expanded(child: Text('PLAYER PROFILE',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.3,
                      fontWeight: FontWeight.w900))),
              IconButton(
                tooltip: 'Close profile',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
            const Divider(),
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 30,
              backgroundColor: colors.primaryContainer,
              child: Text(player.player.split(' ').map((part) =>
                  part.isEmpty ? '' : part[0]).take(2).join(),
                  style: TextStyle(color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w900, fontSize: 21)),
            ),
            const SizedBox(height: 13),
            Text(player.player,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('${player.team}  ·  ${player.position}  ·  $season',
                style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 18),
            Row(children: [
              for (final metric in headline)
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: colors.primaryContainer.withValues(alpha: .32),
                    ),
                    child: Column(children: [
                      Text(display(metric.$2), style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: colors.primary)),
                      Text(metric.$1, style: TextStyle(
                          fontSize: 11, color: colors.onSurfaceVariant)),
                    ]),
                  ),
                )),
            ]),
            const SizedBox(height: 22),
            Text('SEASON SNAPSHOT',
                style: TextStyle(fontWeight: FontWeight.w800,
                    color: colors.onSurfaceVariant, letterSpacing: 1,
                    fontSize: 11)),
            const SizedBox(height: 8),
            for (var i = 0; i < measures.length; i += 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  for (final metric in measures.skip(i).take(2))
                    Expanded(child: Row(children: [
                      Expanded(child: Text(metric.$1,
                          style: TextStyle(fontSize: 12,
                              color: colors.onSurfaceVariant))),
                      Text(display(metric.$2), style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(width: 12),
                    ])),
                ]),
              ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Full player profile'),
                onPressed: () => openWebsiteNbaPlayerPage(context,
                    session: session, playerKey: player.playerId,
                    playerName: player.player),
              ),
            ),
            const SizedBox(height: 8),
            Text('Source-backed values only · Arcside',
                style: TextStyle(color: colors.onSurfaceVariant,
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
