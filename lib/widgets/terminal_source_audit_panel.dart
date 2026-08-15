import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';
import '../models/data_rights_envelope.dart';

class TerminalSourceFieldAudit {
  const TerminalSourceFieldAudit({
    required this.field,
    required this.valueLabel,
    required this.envelope,
    this.quality = 'unknown',
    this.correctionCount = 0,
  });

  final String field;
  final String valueLabel;
  final DataRightsEnvelope envelope;
  final String quality;
  final int correctionCount;
}

class TerminalSourceAuditPanel extends StatelessWidget {
  const TerminalSourceAuditPanel({
    super.key,
    required this.fields,
    this.dataset = '',
    this.freshness = '',
    this.expectedLatency = '',
    this.coverage = '',
    this.knownOmissions = const [],
    this.incident = '',
  });

  final List<TerminalSourceFieldAudit> fields;
  final String dataset;
  final String freshness;
  final String expectedLatency;
  final String coverage;
  final List<String> knownOmissions;
  final String incident;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    return TerminalPanel(
      title: 'SOURCE AUDIT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: tokens.space3,
            runSpacing: tokens.space2,
            children: [
              if (dataset.isNotEmpty) _Meta(label: 'DATASET', value: dataset),
              if (freshness.isNotEmpty) _Meta(label: 'FRESHNESS', value: freshness),
              if (expectedLatency.isNotEmpty) _Meta(label: 'LATENCY', value: expectedLatency),
              if (coverage.isNotEmpty) _Meta(label: 'COVERAGE', value: coverage),
              if (incident.isNotEmpty) _Meta(label: 'INCIDENT', value: incident),
            ],
          ),
          if (knownOmissions.isNotEmpty) ...[
            SizedBox(height: tokens.space3),
            Text('KNOWN OMISSIONS', style: tokens.captionStyle),
            SizedBox(height: tokens.space1),
            for (final omission in knownOmissions)
              Text('• $omission', style: tokens.bodyStyle),
          ],
          SizedBox(height: tokens.space3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 36,
              columns: const [
                DataColumn(label: Text('FIELD')),
                DataColumn(label: Text('VALUE')),
                DataColumn(label: Text('SOURCE CLASS')),
                DataColumn(label: Text('SOURCE')),
                DataColumn(label: Text('DISPLAY')),
                DataColumn(label: Text('EXPORT')),
                DataColumn(label: Text('API')),
                DataColumn(label: Text('REDISTRIBUTE')),
                DataColumn(label: Text('QUALITY')),
                DataColumn(label: Text('CORRECTIONS')),
              ],
              rows: [
                for (final field in fields)
                  DataRow(cells: [
                    DataCell(Text(field.field)),
                    DataCell(Text(field.valueLabel)),
                    DataCell(Text(field.envelope.licenseClass.name)),
                    DataCell(Text(field.envelope.sourceId)),
                    DataCell(Text(field.envelope.display.name)),
                    DataCell(Text(field.envelope.export.name)),
                    DataCell(Text(field.envelope.api.name)),
                    DataCell(Text(field.envelope.redistribution.name)),
                    DataCell(Text(field.quality)),
                    DataCell(Text('${field.correctionCount}')),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 260),
      padding: EdgeInsets.all(tokens.space2),
      decoration: BoxDecoration(
        color: tokens.panelRaised,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tokens.captionStyle),
          Text(value, style: tokens.bodyStyle.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
