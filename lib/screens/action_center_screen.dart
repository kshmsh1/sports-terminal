import '../data/action_surface_items.dart';
import 'registry_screen_factory.dart';

class ActionCenterScreen extends RegistryScreenFactory {
  const ActionCenterScreen({super.key}) : super(
    title: 'Action Center',
    subtitle: 'Universal action layer for moving from lookup into work: workspace, compare, report, save view, source audit, and future monitoring actions.',
    items: actionSurfaceItems,
    searchHint: 'Search workspace, compare, report, save, source...',
    leadTitle: 'Action Center Principle',
    leadBody: 'Sports Terminal should not only show information. Every important object should expose actions that let users work with the data: add it to a workspace, compare it, generate a report, save the view, or audit the source.',
  );
}
