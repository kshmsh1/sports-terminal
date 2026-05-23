import '../data/source_backed_nba_data_wave_items.dart';
import 'registry_screen_factory.dart';

class SourceBackedDataWaveScreen extends RegistryScreenFactory {
  const SourceBackedDataWaveScreen({super.key}) : super(
    title: 'Source-Backed NBA Data Wave',
    subtitle: 'Execution sequence for moving from first route payloads into player identity, traditional stats, standings, playoffs, MVP voting, games, rosters, draft, transactions, and later expansion layers.',
    items: sourceBackedNbaDataWaveItems,
    searchHint: 'Search data wave, source path, stats, MVP, games...',
    leadTitle: 'Data Wave Principle',
    leadBody: 'Freeze route payloads first, then import player identity, then traditional stats, then context and awards. Do not fake rows while sources are pending.',
  );
}
