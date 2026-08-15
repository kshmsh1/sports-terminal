import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_player_career_comparison_export_service.dart';

class NbaPlayerCareerComparisonExportPanel extends StatelessWidget {
  const NbaPlayerCareerComparisonExportPanel({
    super.key,
    required this.bundle,
  });

  final NbaPlayerCareerComparisonExportBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('career-comparison-export-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151C),
        border: Border.all(color: const Color(0xFF263342)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STRUCTURED EVIDENCE EXPORT',
            style: TextStyle(
              color: Color(0xFFE2B866),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${bundle.rows.length} rows · ${bundle.columns.length} columns · scope frozen at export construction',
            style: const TextStyle(color: Color(0xFF8895A5), fontSize: 10),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('career-comparison-copy-tsv'),
                onPressed: () => _copy(context, bundle.tsv, 'TSV'),
                icon: const Icon(Icons.table_rows_outlined, size: 16),
                label: const Text('COPY TSV'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('career-comparison-copy-csv'),
                onPressed: () => _copy(context, bundle.csv, 'CSV'),
                icon: const Icon(Icons.grid_on_outlined, size: 16),
                label: const Text('COPY CSV'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('career-comparison-copy-json'),
                onPressed: () => _copy(context, bundle.json, 'JSON'),
                icon: const Icon(Icons.data_object_rounded, size: 16),
                label: const Text('COPY JSON'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Exports preserve nulls and exact left/right season IDs. They do not re-query data, broaden the scope, or add normalized comparison values.',
            style: TextStyle(color: Color(0xFF8895A5), fontSize: 9, height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('$label comparison evidence copied.')),
    );
  }
}
