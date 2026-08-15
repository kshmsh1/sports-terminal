import 'package:flutter/material.dart';

import '../models/generated_terminal_report.dart';
import '../models/route_payload.dart';
import '../services/route_payload_report_generator.dart';
import 'terminal_primitives.dart';

enum _GeneratedReportView {
  preview,
  markdown,
  json,
  tsv,
}

class RoutePayloadGeneratedReportPanel extends StatefulWidget {
  const RoutePayloadGeneratedReportPanel({
    super.key,
    required this.payload,
    this.generator = const RoutePayloadReportGenerator(),
  });

  final RoutePayload payload;
  final RoutePayloadReportGenerator generator;

  @override
  State<RoutePayloadGeneratedReportPanel> createState() =>
      _RoutePayloadGeneratedReportPanelState();
}

class _RoutePayloadGeneratedReportPanelState
    extends State<RoutePayloadGeneratedReportPanel> {
  _GeneratedReportView _view = _GeneratedReportView.preview;

  @override
  Widget build(BuildContext context) {
    final report = widget.generator.generate(widget.payload);
    return Container(
      key: const ValueKey('route-payload-generated-report-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: terminalPanelDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: terminalBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Generated Report Shell',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              InfoPill(label: report.coverage.label),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The report below is generated from the active structured RoutePayload. It preserves source provenance, blockers, exact row values, and missing-data gaps instead of drafting unsupported sports claims.',
            style: TextStyle(color: terminalTextSoft, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoPill(label: report.sourceObjectType),
              InfoPill(label: '${report.rowCount} structured row(s)'),
              InfoPill(label: '${report.columnCount} column(s)'),
              InfoPill(label: 'RoutePayload v${report.schemaVersion}'),
              InfoPill(
                label: report.blockers.isEmpty
                    ? 'No declared blockers'
                    : '${report.blockers.length} blocker(s)',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('generated-report-view-preview'),
                label: const Text('PREVIEW'),
                selected: _view == _GeneratedReportView.preview,
                onSelected: (_) =>
                    setState(() => _view = _GeneratedReportView.preview),
              ),
              ChoiceChip(
                key: const ValueKey('generated-report-view-markdown'),
                label: const Text('MARKDOWN'),
                selected: _view == _GeneratedReportView.markdown,
                onSelected: (_) =>
                    setState(() => _view = _GeneratedReportView.markdown),
              ),
              ChoiceChip(
                key: const ValueKey('generated-report-view-json'),
                label: const Text('JSON'),
                selected: _view == _GeneratedReportView.json,
                onSelected: (_) =>
                    setState(() => _view = _GeneratedReportView.json),
              ),
              ChoiceChip(
                key: const ValueKey('generated-report-view-tsv'),
                label: const Text('TSV'),
                selected: _view == _GeneratedReportView.tsv,
                onSelected: (_) =>
                    setState(() => _view = _GeneratedReportView.tsv),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_view == _GeneratedReportView.preview)
            _GeneratedReportPreview(report: report)
          else
            _GeneratedReportOutput(report: report, view: _view),
        ],
      ),
    );
  }
}

class _GeneratedReportPreview extends StatelessWidget {
  const _GeneratedReportPreview({required this.report});

  final GeneratedTerminalReport report;

  @override
  Widget build(BuildContext context) {
    final shownColumns = report.columns.take(8).toList(growable: false);
    final shownRows = report.rows.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.title,
          key: const ValueKey('generated-report-title'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          report.subtitle,
          style: const TextStyle(color: terminalTextSoft, height: 1.4),
        ),
        const SizedBox(height: 14),
        _ReportLine(
          label: 'Source',
          value: report.sourceSnapshot.isEmpty
              ? 'Unavailable'
              : report.sourceSnapshot,
        ),
        _ReportLine(
          label: 'Filter',
          value: report.filterSummary.isEmpty
              ? 'None declared'
              : report.filterSummary,
        ),
        _ReportLine(
          label: 'Created',
          value: report.createdAtIso.isEmpty
              ? 'Unspecified'
              : report.createdAtIso,
        ),
        _ReportLine(
          label: 'Blockers',
          value: report.blockers.isEmpty
              ? 'None declared'
              : report.blockers.join(', '),
        ),
        const SizedBox(height: 8),
        Text(
          report.methodNote,
          key: const ValueKey('generated-report-method-note'),
          style: const TextStyle(color: terminalTextMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        if (!report.hasStructuredData)
          const Text(
            'No structured rows were supplied. The report remains an explicit source/provenance shell and does not reconstruct data from selected-row labels.',
            key: ValueKey('generated-report-empty-data'),
            style: TextStyle(color: terminalTextSoft, height: 1.4),
          )
        else ...[
          Row(
            children: [
              const Text(
                'Structured Data Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                'showing ${shownRows.length}/${report.rowCount} rows · ${shownColumns.length}/${report.columnCount} columns',
                style: const TextStyle(
                  color: terminalTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanel),
              headingTextStyle: const TextStyle(
                color: terminalTextMuted,
                fontWeight: FontWeight.w800,
              ),
              dataTextStyle: const TextStyle(color: terminalTextSoft),
              columnSpacing: 26,
              columns: [
                for (final column in shownColumns)
                  DataColumn(label: Text(column.label)),
              ],
              rows: [
                for (final row in shownRows)
                  DataRow(
                    cells: [
                      for (final column in shownColumns)
                        DataCell(Text(_display(row[column.key]))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GeneratedReportOutput extends StatelessWidget {
  const _GeneratedReportOutput({required this.report, required this.view});

  final GeneratedTerminalReport report;
  final _GeneratedReportView view;

  @override
  Widget build(BuildContext context) {
    final output = switch (view) {
      _GeneratedReportView.markdown => report.toMarkdown(),
      _GeneratedReportView.json => report.encodeJson(),
      _GeneratedReportView.tsv => report.toTsv(),
      _GeneratedReportView.preview => report.toMarkdown(),
    };
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 420),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1016),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: terminalBorder),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          output.isEmpty ? 'No structured tabular output is available.' : output,
          key: const ValueKey('generated-report-output'),
          style: const TextStyle(
            color: Color(0xFFDDE6F1),
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(
                  color: terminalTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: terminalTextSoft,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
}

String _display(dynamic value) {
  if (value == null) return '—';
  if (value is String && value.trim().isEmpty) return '—';
  return value.toString();
}
