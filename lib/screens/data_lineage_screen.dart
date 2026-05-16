import '../data/data_lineage_items.dart';
import 'registry_screen_factory.dart';

class DataLineageScreen extends RegistryScreenFactory {
  const DataLineageScreen({
    super.key,
  }) : super(
          title: 'Data Lineage',
          subtitle: 'Lineage planning from raw source reference to snapshot, normalization, validation, published asset, and screen consumption.',
          items: dataLineageItems,
          searchHint: 'Search lineage, source, snapshot, validation...',
          leadTitle: 'Lineage Principle',
          leadBody: 'Every real record should eventually explain where it came from, when it was captured, how it was normalized, how it was validated, and where it is consumed.',
        );
}
