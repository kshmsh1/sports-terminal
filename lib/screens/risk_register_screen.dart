import '../data/risk_register_items.dart';
import 'registry_screen_factory.dart';

class RiskRegisterScreen extends RegistryScreenFactory {
  const RiskRegisterScreen({
    super.key,
  }) : super(
          title: 'Risk Register',
          subtitle: 'Risk tracking for data rights, trust, navigation sprawl, schema drift, asset loading, product focus, data gaps, and future scale.',
          items: riskRegisterItems,
          searchHint: 'Search risk, source, UX, schema, performance...',
          leadTitle: 'Risk Principle',
          leadBody: 'The fastest way to build this terminal safely is to make risks explicit while they are still design decisions, not production failures.',
        );
}
