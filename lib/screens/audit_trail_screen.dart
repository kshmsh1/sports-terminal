import '../data/audit_trail_items.dart';
import 'registry_screen_factory.dart';

class AuditTrailScreen extends RegistryScreenFactory {
  const AuditTrailScreen({
    super.key,
  }) : super(
          title: 'Audit Trail',
          subtitle: 'Planning surface for source decisions, import runs, schema changes, release reviews, and future workspace change records.',
          items: auditTrailItems,
          searchHint: 'Search source, import, schema, release...',
          leadTitle: 'Audit Trail Principle',
          leadBody: 'Trust improves when important product and data decisions can be traced back to source context, validation steps, and release decisions.',
        );
}
