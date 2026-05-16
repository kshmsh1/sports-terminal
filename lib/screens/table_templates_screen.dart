import '../data/table_template_items.dart';
import 'registry_screen_factory.dart';

class TableTemplatesScreen extends RegistryScreenFactory {
  const TableTemplatesScreen({
    super.key,
  }) : super(
          title: 'Table Templates',
          subtitle: 'Reusable table designs for entity directories, registries, stats, timelines, comparisons, and source decisions.',
          items: tableTemplateItems,
          searchHint: 'Search table, stats, timeline, comparison...',
          leadTitle: 'Table Principle',
          leadBody: 'Tables are the main working surface of a terminal. Shared table patterns keep the app consistent while preserving room for specialized analytical tables later.',
        );
}
