import '../data/saved_view_lifecycle_items.dart';
import 'registry_screen_factory.dart';

class SavedViewLifecycleScreen extends RegistryScreenFactory {
  const SavedViewLifecycleScreen({
    super.key,
  }) : super(
          title: 'Saved View Lifecycle',
          subtitle: 'Lifecycle planning for preset views, user-created views, validation, sharing, exports, and alert bindings.',
          items: savedViewLifecycleItems,
          searchHint: 'Search saved view lifecycle, validation, export...',
          leadTitle: 'Saved View Principle',
          leadBody: 'Saved views should become repeatable user workflows, but the MVP should keep them as presets until local persistence and privacy controls are designed.',
        );
}
