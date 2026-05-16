import '../data/alert_evaluation_items.dart';
import 'registry_screen_factory.dart';

class AlertEvaluationScreen extends RegistryScreenFactory {
  const AlertEvaluationScreen({
    super.key,
  }) : super(
          title: 'Alert Evaluation',
          subtitle: 'Evaluation design for alert rule lifecycle, coverage checks, entity scope, baselines, trigger results, notifications, and privacy boundaries.',
          items: alertEvaluationItems,
          searchHint: 'Search alert evaluation, trigger, scope, coverage...',
          leadTitle: 'Alert Evaluation Principle',
          leadBody: 'Alerts should not fire unless their required datasets are source-backed, their entity scope is clear, and their result can be explained with source metadata.',
        );
}
