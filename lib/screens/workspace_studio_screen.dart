import '../data/workspace_studio_items.dart';
import 'registry_screen_factory.dart';

class WorkspaceStudioScreen extends RegistryScreenFactory {
  const WorkspaceStudioScreen({super.key}) : super(
    title: 'Workspace Studio',
    subtitle: 'Excel-like analysis workspace plan for dataset selection, columns, formulas, joins, pivots, charts, exports, scenarios, and audit trails.',
    items: workspaceStudioItems,
    searchHint: 'Search formulas, joins, charts, export...',
    leadTitle: 'Workspace Studio Principle',
    leadBody: 'The terminal becomes powerful when users can do work inside it. Workspace Studio should let users create table views, formulas, custom columns, joins, filters, charts, saved models, reports, and exports from source-backed sports datasets.',
  );
}
