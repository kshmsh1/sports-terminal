import '../data/nba_stats_dataset_targets.dart';
import 'registry_screen_factory.dart';

class NbaStatsDatasetTargetsScreen extends RegistryScreenFactory {
  const NbaStatsDatasetTargetsScreen({
    super.key,
  }) : super(
          title: 'NBA Stats Dataset Targets',
          subtitle: 'Prioritized dataset targets for NBA.com/stats and adjacent official-source paths: player identity, player stats, team stats, standings, games, awards, draft, and rosters.',
          items: nbaStatsDatasetTargets,
          searchHint: 'Search dataset target, player stats, standings...',
          leadTitle: 'Dataset Target Principle',
          leadBody: 'The first working NBA prototype should not try to ingest everything at once. It should prioritize player identity, traditional player stats, team season context, standings, then deeper game, award, draft, and roster layers.',
        );
}
