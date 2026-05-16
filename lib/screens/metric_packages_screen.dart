import '../data/metric_package_items.dart';
import 'registry_screen_factory.dart';

class MetricPackagesScreen extends RegistryScreenFactory {
  const MetricPackagesScreen({
    super.key,
  }) : super(
          title: 'Metric Packages',
          subtitle: 'Metric package roadmap for traditional stats, shooting efficiency, possession efficiency, availability, awards, and development context.',
          items: metricPackageItems,
          searchHint: 'Search metric package, stats, availability...',
          leadTitle: 'Metric Package Principle',
          leadBody: 'Stats should be grouped into coherent packages so screens can display useful sets of fields without mixing core, derived, and future metrics too early.',
        );
}
