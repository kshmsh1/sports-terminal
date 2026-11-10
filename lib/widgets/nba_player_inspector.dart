import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../screens/website_nba_entity_pages.dart';
import '../services/nba_player_profile_presentation.dart';
import '../services/nba_stats_metric_catalog.dart';
import '../services/nba_stats_workstation_engine.dart';

/// The table-adjacent preview is intentionally a concise physical profile.
/// Full career statistics, contracts and honors live on the full player page.
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
    const resolver = NbaTerminalMetricResolver();
    const engine = NbaStatsWorkstationEngine();

    String measure(String key) {
      final value = resolver.value(player, key);
      return value == null ? '—' : resolver.format(player, key);
    }

    String sourceText(String key) {
      final item = player.raw[key]?.toString().trim() ?? '';
      return item.isEmpty || item.toLowerCase() == 'null' ? '—' : item;
    }

    String headlineValue(String key) {
      if (key == 'height') return measure('height');
      if (key == 'weight') return measure('weight');
      return measure('age');
    }

    final physical = [
      ('College', sourceText('bio_college')),
      ('Country', sourceText('bio_country')),
      ('Draft year', measure('draft_year')),
      ('Draft round', measure('draft_round')),
      ('Draft pick', measure('draft_number')),
    ];
    final highlights = [
      ('PPG', 'pts'), ('RPG', 'reb'), ('APG', 'ast'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.person_outline_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 7),
          const Expanded(child: Text('PLAYER PROFILE',
            style: TextStyle(fontWeight: FontWeight.w900,
              letterSpacing: 1.0, fontSize: 10))),
          IconButton(
            tooltip: 'Close player preview',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 6),
        Row(children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: colors.primaryContainer,
            child: Text(player.player.split(' ').where((s) => s.isNotEmpty)
              .map((s) => s[0]).take(2).join(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                color: colors.onPrimaryContainer)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(player.player, style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${player.team} · ${nbaOrderedPositions(player.position)} · $season',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
            ],
          )),
        ]),
        const SizedBox(height: 21),
        Text('PHYSICAL PROFILE', style: TextStyle(fontSize: 10,
          letterSpacing: 1, fontWeight: FontWeight.w900,
          color: colors.onSurfaceVariant)),
        const SizedBox(height: 9),
        Row(children: [
          for (final item in const [
            ('Height', 'height'),
            ('Weight', 'weight'),
            ('Age', 'age'),
          ])
            Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1, style: TextStyle(fontSize: 11,
                    color: colors.onSurfaceVariant)),
                  const SizedBox(height: 5),
                  Text(headlineValue(item.$2), style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w900)),
                ],
              ),
            )),
        ]),
        const SizedBox(height: 15),
        for (final entry in physical)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(child: Text(entry.$1, style: TextStyle(
                fontSize: 12, color: colors.onSurfaceVariant))),
              Flexible(child: Text(entry.$2, textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
          ),
        const SizedBox(height: 18),
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 8),
        Text('SEASON HIGHLIGHTS', style: TextStyle(fontSize: 10,
          letterSpacing: 1, fontWeight: FontWeight.w900,
          color: colors.onSurfaceVariant)),
        const SizedBox(height: 9),
        Row(children: [
          for (final item in highlights)
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(engine.formatValue(item.$2, player.value(item.$2)),
                  style: TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 17, color: colors.primary)),
                Text(item.$1, style: TextStyle(fontSize: 11,
                  color: colors.onSurfaceVariant)),
              ],
            )),
        ]),
        const SizedBox(height: 19),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Full player profile'),
            onPressed: () => openWebsiteNbaPlayerPage(context,
              session: session, playerKey: player.playerId,
              playerName: player.player),
          ),
        ),
        const SizedBox(height: 8),
        Text('Arcside · Published measurements only',
          style: TextStyle(fontSize: 10,
            color: colors.onSurfaceVariant)),
      ]),
    );
  }
}
