import 'package:flutter/material.dart';

import '../data/action_surface_items.dart';
import '../data/export_builder_stage_items.dart';
import '../data/export_template_items.dart';
import '../data/report_library_items.dart';
import '../data/saved_view_items.dart';
import '../models/registry_item.dart';
import '../widgets/terminal_primitives.dart';

class ExportCenterScreen extends StatefulWidget {
  const ExportCenterScreen({super.key});

  @override
  State<ExportCenterScreen> createState() => _ExportCenterScreenState();
}

class _ExportCenterScreenState extends State<ExportCenterScreen> {
  String selectedCategory = 'All';
  String selectedStatus = 'All';
  String selectedStageCategory = 'All';
  String selectedTemplate = exportTemplateItems.first.title;
  String selectedFormat = 'CSV / Table';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...exportTemplateItems.map((item) => item.category).toSet().toList()..sort()];
    final statuses = ['All', ...exportTemplateItems.map((item) => item.status).toSet().toList()..sort()];
    final stageCategories = ['All', ...exportBuilderStageItems.map((item) => item.category).toSet().toList()..sort()];
    final filteredTemplates = exportTemplateItems.where((item) {
      final normalized = query.trim().toLowerCase();
      return (selectedCategory == 'All' || item.category == selectedCategory) &&
          (selectedStatus == 'All' || item.status == selectedStatus) &&
          (normalized.isEmpty || item.title.toLowerCase().contains(normalized) || item.category.toLowerCase().contains(normalized) || item.description.toLowerCase().contains(normalized) || item.inputs.toLowerCase().contains(normalized) || item.nextStep.toLowerCase().contains(normalized));
    }).toList();
    final filteredStages = exportBuilderStageItems.where((item) => selectedStageCategory == 'All' || item.category == selectedStageCategory).toList();
    final selected = exportTemplateItems.firstWhere((item) => item.title == selectedTemplate, orElse: () => exportTemplateItems.first);
    final selectedFormatSpec = _formats.firstWhere((item) => item.name == selectedFormat);
    final planned = exportTemplateItems.where((item) => item.status == 'Planned').length;
    final future = exportTemplateItems.where((item) => item.status == 'Future').length;
    final p0Stages = exportBuilderStageItems.where((item) => item.priority == 'P0').length;
    final p1Stages = exportBuilderStageItems.where((item) => item.priority == 'P1').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Export Center', subtitle: 'Output governance cockpit for exporting reports, saved views, workspaces, comparisons, source audits, QA packets, fantasy boards, community objects, and product roadmap materials without losing source context.'),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(crossAxisCount: isWide ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: isWide ? 2.0 : 1.5, children: [
          _ExportMetric(label: 'Export Templates', value: '${exportTemplateItems.length}', detail: '$planned planned / $future future'),
          _ExportMetric(label: 'Builder Stages', value: '${exportBuilderStageItems.length}', detail: '$p0Stages P0 / $p1Stages P1'),
          _ExportMetric(label: 'Source Inputs', value: '${reportLibraryItems.length + savedViewItems.length}', detail: 'Reports + saved views'),
          _ExportMetric(label: 'Action Hooks', value: '${actionSurfaceItems.length}', detail: 'Action Center verbs'),
        ]);
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 340, child: TextField(onChanged: (value) => setState(() => query = value), style: const TextStyle(color: Colors.white), cursorColor: terminalAccent, decoration: _inputDecoration('Search exports, inputs, outputs, source rules...'))),
        _FilterDropdown(label: 'Category', value: selectedCategory, values: categories, onChanged: (value) => setState(() => selectedCategory = value)),
        _FilterDropdown(label: 'Status', value: selectedStatus, values: statuses, onChanged: (value) => setState(() => selectedStatus = value)),
        _FilterDropdown(label: 'Stage Category', value: selectedStageCategory, values: stageCategories, onChanged: (value) => setState(() => selectedStageCategory = value)),
        _FilterDropdown(label: 'Template', value: selectedTemplate, values: exportTemplateItems.map((item) => item.title).toList(), onChanged: (value) => setState(() => selectedTemplate = value), wide: true),
        _FilterDropdown(label: 'Format', value: selectedFormat, values: _formats.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedFormat = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final left = _SelectedExportCard(template: selected, format: selectedFormatSpec);
        final right = const _ExportGovernancePanel();
        if (constraints.maxWidth < 1050) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 22),
      const _ExportPipelinePanel(),
      const SizedBox(height: 22),
      const _ExportFormatMatrix(),
      const SizedBox(height: 22),
      _ExportTemplateTable(items: filteredTemplates, selectedTitle: selected.title, onSelected: (item) => setState(() => selectedTemplate = item.title)),
      const SizedBox(height: 22),
      _ExportBuilderStageTable(items: filteredStages),
    ]);
  }
}

class _ExportFormat { const _ExportFormat(this.name, this.status, this.primaryUse, this.blockers); final String name; final String status; final String primaryUse; final String blockers; }

const _formats = <_ExportFormat>[
  _ExportFormat('CSV / Table', 'First', 'Structured row exports for saved views, coverage reviews, QA tables, source audits, and workspace tables.', 'Requires standardized table state.'),
  _ExportFormat('Workbook Packet', 'Planned', 'Multi-tab exports for reports, appendices, source metadata, QA notes, and model outputs.', 'Requires export manifest and multi-table payloads.'),
  _ExportFormat('Markdown Brief', 'Planned', 'Lightweight report sections, source notes, action summaries, and product planning packets.', 'Requires report block formatting.'),
  _ExportFormat('PDF / Doc Packet', 'Future', 'Formal reports for player, team, draft, award, source audit, or investor-style product packets.', 'Requires document rendering layer.'),
  _ExportFormat('Terminal Snapshot', 'Future', 'Shareable internal object preserving source-as-of state, selected rows, formulas, and chart configs.', 'Requires persistence and object snapshots.'),
  _ExportFormat('Community Embed', 'Future', 'Embedded saved views, charts, report blocks, and source notes for creator posts or private rooms.', 'Requires accounts, permissions, and moderation.'),
];

class _SelectedExportCard extends StatelessWidget {
  const _SelectedExportCard({required this.template, required this.format});
  final RegistryItem template;
  final _ExportFormat format;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(template.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))), const SizedBox(width: 10), InfoPill(label: template.status)]),
    const SizedBox(height: 8),
    Text(template.description, style: const TextStyle(color: terminalTextSoft, height: 1.45)),
    const SizedBox(height: 16),
    _DetailLine(label: 'Category', value: template.category),
    _DetailLine(label: 'Priority', value: template.priority),
    _DetailLine(label: 'Inputs', value: template.inputs),
    _DetailLine(label: 'Next Step', value: template.nextStep),
    _DetailLine(label: 'Format', value: '${format.name}: ${format.primaryUse}'),
    _DetailLine(label: 'Format Gate', value: '${format.status}. ${format.blockers}'),
  ]));
}

class _ExportGovernancePanel extends StatelessWidget { const _ExportGovernancePanel(); @override Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Export Governance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), SizedBox(height: 12), Text('Exports should never strip away trust context. Every output should preserve source metadata, missing-data flags, rights posture, selected filters, selected columns, row count, source-as-of state, and generation audit details.', style: TextStyle(color: terminalTextSoft, height: 1.45)), SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Source snapshot'), InfoPill(label: 'Rights gate'), InfoPill(label: 'Missing-data flags'), InfoPill(label: 'Selected filters'), InfoPill(label: 'Audit manifest'), InfoPill(label: 'No fake zeros')]) ])); }
class _ExportPipelinePanel extends StatelessWidget { const _ExportPipelinePanel(); @override Widget build(BuildContext context) { final steps = ['Choose intent', 'Bind object', 'Capture rows', 'Capture columns', 'Snapshot sources', 'Check rights', 'Preview output', 'Export or block']; return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Export Builder Pipeline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')])])); } }
class _ExportFormatMatrix extends StatelessWidget { const _ExportFormatMatrix(); @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.all(18), child: Text('Export Format Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Format')), DataColumn(label: Text('Status')), DataColumn(label: Text('Primary Use')), DataColumn(label: Text('Blockers'))], rows: [for (final item in _formats) DataRow(cells: [DataCell(SizedBox(width: 220, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.primaryUse))), DataCell(SizedBox(width: 480, child: Text(item.blockers)))])]))])); }

class _ExportTemplateTable extends StatelessWidget { const _ExportTemplateTable({required this.items, required this.selectedTitle, required this.onSelected}); final List<RegistryItem> items; final String selectedTitle; final ValueChanged<RegistryItem> onSelected; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Export Template Library', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} templates', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Template')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(selected: item.title == selectedTitle, onSelectChanged: (_) => onSelected(item), cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 600, child: Text(item.description))), DataCell(SizedBox(width: 420, child: Text(item.inputs))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])]))])); }
class _ExportBuilderStageTable extends StatelessWidget { const _ExportBuilderStageTable({required this.items}); final List<RegistryItem> items; @override Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Export Builder Stage Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${items.length} stages', style: const TextStyle(color: terminalTextMuted))])), const Divider(height: 1, color: terminalBorder), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowColor: WidgetStateProperty.all(terminalPanelDark), headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700), dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)), columnSpacing: 30, columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Stage')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Inputs')), DataColumn(label: Text('Next Step'))], rows: [for (final item in items) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 250, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 560, child: Text(item.description))), DataCell(SizedBox(width: 360, child: Text(item.inputs))), DataCell(SizedBox(width: 460, child: Text(item.nextStep)))])]))])); }

InputDecoration _inputDecoration(String hintText) => InputDecoration(hintText: hintText, hintStyle: const TextStyle(color: terminalTextMuted), prefixIcon: const Icon(Icons.search, color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)));
class _FilterDropdown extends StatelessWidget { const _FilterDropdown({required this.label, required this.value, required this.values, required this.onChanged, this.wide = false}); final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; final bool wide; @override Widget build(BuildContext context) => SizedBox(width: wide ? 320 : 230, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); }
class _DetailLine extends StatelessWidget { const _DetailLine({required this.label, required this.value}); final String label; final String value; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))])); }
class _ExportMetric extends StatelessWidget { const _ExportMetric({required this.label, required this.value, required this.detail}); final String label; final String value; final String detail; @override Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))])); }
