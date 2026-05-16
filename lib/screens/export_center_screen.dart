import '../data/export_template_items.dart';
import 'registry_screen_factory.dart';

class ExportCenterScreen extends RegistryScreenFactory {
  const ExportCenterScreen({
    super.key,
  }) : super(
          title: 'Export Center',
          subtitle: 'Export planning center for reports, comparisons, coverage reviews, QA checklists, and source decision packets.',
          items: exportTemplateItems,
          searchHint: 'Search export, report, source, criteria...',
          leadTitle: 'Export Principle',
          leadBody: 'Exports should preserve source metadata, show missing-data flags, and avoid redistributing restricted source content. The MVP can design export formats before implementing download behavior.',
        );
}
