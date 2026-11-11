import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../screens/website_nba_entity_pages.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_player_profile_format.dart';

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
    const catalog = NbaTerminalMetricResolver();
    const engine = NbaStatsWorkstationEngine();
    final physical = <(String, String)>[
      ('Age', 'age'),
      ('Height', 'height'),
      ('Weight', 'weight'),
      ('Wingspan', 'wingspan'),
      ('Standing Reach', 'standing_reach'),
      ('Max Vert', 'max_vertical_jump'),
      ('Standing Vert', 'standing_jump'),
      ('Draft Year', 'draft_year'),
      ('Draft Round', 'draft_round'),
      ('Draft Pick', 'draft_number'),
    ];
    String getPhysical(String key) {
      final metric = nbaTerminalMetricByKey[key];
      if (metric != null) {
        return catalog.format(player, key);
      }
      return engine.formatValue(key, player.value(key));
    }
    final valid = physical.where((item) {
      final metric = nbaTerminalMetricByKey[item.$2];
      return metric != null && catalog.value(player, item.$2) != null;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.person_outline_rounded, size: 19),
          const SizedBox(width: 8),
          const Expanded(child: Text('PLAYER PROFILE', style: TextStyle(
            letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w900))),
          IconButton(
            tooltip: 'Close profile',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded)),
        ]),
        const Divider(height: 25),
        Row(children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: colors.primaryContainer,
            child: Text(player.player.split(' ').where((p) => p.isNotEmpty)
              .take(2).map((p) => p[0]).join(),
              style: TextStyle(color: colors.onPrimaryContainer,
                fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(player.player, style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${player.team} · ${nbaOrderedPositions(player.position)} · $season',
                style: TextStyle(fontSize: 12,
                  color: colors.onSurfaceVariant)),
            ],
          )),
        ]),
        const SizedBox(height: 22),
        Text('PHYSICAL PROFILE', style: TextStyle(
          fontSize: 11, letterSpacing: 1.1,
          color: colors.onSurfaceVariant, fontWeight: FontWeight.w800)),
        const SizedBox(height: 11),
        if (valid.isEmpty)
          Text('No physical measurements are published for this player-season.',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant))
        else
          for (var i = 0; i < valid.length; i += 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                for (final item in valid.skip(i).take(2))
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.$1, style: TextStyle(fontSize: 11,
                          color: colors.onSurfaceVariant)),
                        const SizedBox(height: 3),
                        Text(getPhysical(item.$2), style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  )),
                if (valid.length - i == 1) const Expanded(child: SizedBox()),
              ]),
            ),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Full player profile'),
          onPressed: () => openWebsiteNbaPlayerPage(context,
            session: session, playerKey: player.playerId,
            playerName: player.player),
        )),
        const SizedBox(height: 8),
        Text('Source-backed measurements only · Arcside',
          style: TextStyle(fontSize: 10,
            color: colors.onSurfaceVariant)),
      ]),
    );
  }
}
