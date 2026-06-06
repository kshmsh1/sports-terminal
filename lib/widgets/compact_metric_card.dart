import 'package:flutter/material.dart';

import 'terminal_primitives.dart';

class CompactMetricCard extends StatelessWidget {
  const CompactMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    this.valueFontSize = 22,
  });

  final String label;
  final String value;
  final String detail;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: terminalPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: terminalBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalTextMuted, fontSize: 11)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(color: Colors.white, fontSize: valueFontSize, fontWeight: FontWeight.w900))),
          const Spacer(),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalAccent, fontSize: 10)),
        ]),
      );
}
