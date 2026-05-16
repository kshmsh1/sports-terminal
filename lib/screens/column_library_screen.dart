import '../data/column_library_items.dart';
import 'registry_screen_factory.dart';

class ColumnLibraryScreen extends RegistryScreenFactory {
  const ColumnLibraryScreen({
    super.key,
  }) : super(
          title: 'Column Library',
          subtitle: 'Column planning for identity, source metadata, availability, production, team context, workflows, and reports.',
          items: columnLibraryItems,
          searchHint: 'Search columns, identity, source, stats...',
          leadTitle: 'Column Principle',
          leadBody: 'Every table should use consistent identity, source, status, and workflow columns so the terminal remains readable as the number of screens grows.',
        );
}
