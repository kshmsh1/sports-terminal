import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Source-backed, searchable entity choice shared by both comparison labs.
class ComparisonSearchOption {
  const ComparisonSearchOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.disabled = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool disabled;
}

Future<String?> showComparisonSearch(
  BuildContext context, {
  required String title,
  required List<ComparisonSearchOption> options,
  required Color accent,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ComparisonSearchDialog(
    title: title,
    options: options,
    accent: accent,
  ),
);

class _ComparisonSearchDialog extends StatefulWidget {
  const _ComparisonSearchDialog({
    required this.title,
    required this.options,
    required this.accent,
  });

  final String title;
  final List<ComparisonSearchOption> options;
  final Color accent;

  @override
  State<_ComparisonSearchDialog> createState() => _ComparisonSearchDialogState();
}

class _ComparisonSearchDialogState extends State<_ComparisonSearchDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final filtered = [
      for (final item in widget.options)
        if (query.isEmpty ||
            item.title.toLowerCase().contains(query) ||
            item.subtitle.toLowerCase().contains(query))
          item,
    ];
    final available = filtered.where((item) => !item.disabled).length;
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: math.min(620.0, screen.width - 32),
        height: math.min(650.0, screen.height * .82),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.manage_search_rounded, color: widget.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'Close search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search by name or team',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty ? null : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
              child: Text('$available available · ${widget.options.length} total',
                style: TextStyle(
                  color: colors.onSurfaceVariant, fontSize: 12)),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No matches. Try a different name or abbreviation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant)),
                    ))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final initials = item.title.trim().split(RegExp(r'\s+'))
                            .where((part) => part.isNotEmpty)
                            .take(2).map((part) => part[0]).join();
                        return ListTile(
                          enabled: !item.disabled,
                          onTap: item.disabled
                              ? null : () => Navigator.pop(context, item.id),
                          leading: CircleAvatar(
                            backgroundColor: widget.accent.withValues(alpha: .15),
                            child: Text(initials.toUpperCase(),
                              style: TextStyle(color: widget.accent,
                                fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                          title: Text(item.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(item.disabled
                              ? '${item.subtitle} · Already selected for this season'
                              : item.subtitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: item.disabled
                              ? const Icon(Icons.check_rounded, size: 18)
                              : const Icon(Icons.chevron_right_rounded),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ComparisonDuelMetric {
  const ComparisonDuelMetric({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    required this.leftDisplay,
    required this.rightDisplay,
    required this.higherIsBetter,
    this.percent = false,
  });

  final String label;
  final double? leftValue;
  final double? rightValue;
  final String leftDisplay;
  final String rightDisplay;
  final bool higherIsBetter;
  final bool percent;
}

/// Focused 2-way comparison. Delta is an absolute gap (percentage-point
/// gap for percentages), never a fabricated combined player rating.
class ComparisonHeadToHead extends StatelessWidget {
  const ComparisonHeadToHead({
    super.key,
    required this.leftName,
    required this.rightName,
    required this.leftContext,
    required this.rightContext,
    required this.leftColor,
    required this.rightColor,
    required this.metrics,
  });

  final String leftName;
  final String rightName;
  final String leftContext;
  final String rightContext;
  final Color leftColor;
  final Color rightColor;
  final List<ComparisonDuelMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('HEAD-TO-HEAD', textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 11,
                    letterSpacing: 1.5, color: colors.onSurfaceVariant)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _DuelHeading(
                      name: leftName, contextText: leftContext,
                      color: leftColor, align: TextAlign.center)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('VS', style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w900)),
                    ),
                    Expanded(child: _DuelHeading(
                      name: rightName, contextText: rightContext,
                      color: rightColor, align: TextAlign.center)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                for (final metric in metrics)
                  _ComparisonDuelRow(
                    metric: metric,
                    leftColor: leftColor,
                    rightColor: rightColor,
                  ),
                const SizedBox(height: 8),
                Text('Highlighted values lead this metric. Δ is the absolute gap; percentages use percentage points.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant, fontSize: 12),
                  textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DuelHeading extends StatelessWidget {
  const _DuelHeading({
    required this.name,
    required this.contextText,
    required this.color,
    required this.align,
  });
  final String name;
  final String contextText;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(name, textAlign: align, maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color, fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(contextText, textAlign: align,
        style: TextStyle(fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ],
  );
}

class _ComparisonDuelRow extends StatelessWidget {
  const _ComparisonDuelRow({
    required this.metric,
    required this.leftColor,
    required this.rightColor,
  });

  final ComparisonDuelMetric metric;
  final Color leftColor;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    final a = metric.leftValue;
    final b = metric.rightValue;
    final valid = a != null && b != null && a.isFinite && b.isFinite;
    final gap = valid ? (a - b).abs() : 0.0;
    final tied = valid && gap < .000001;
    final leftWins = valid && !tied &&
        (metric.higherIsBetter ? a > b : a < b);
    final rightWins = valid && !tied && !leftWins;
    final gapText = valid
        ? (tied ? 'TIE' :
          'Δ ${(gap * (metric.percent ? 100 : 1)).toStringAsFixed(1)}${metric.percent ? ' pp' : ''}')
        : '—';
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(9)),
        child: Row(
          children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: leftWins ? leftColor.withValues(alpha: .14) : null,
                borderRadius: BorderRadius.circular(8)),
              child: Text(metric.leftDisplay,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17,
                  fontWeight: leftWins ? FontWeight.w900 : FontWeight.w600,
                  color: leftWins ? leftColor : null,
                  fontFeatures: const [FontFeature.tabularFigures()])))),
            SizedBox(
              width: 130,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(metric.label, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(gapText, textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant, fontSize: 10.5)),
                ],
              ),
            ),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: rightWins ? rightColor.withValues(alpha: .14) : null,
                borderRadius: BorderRadius.circular(8)),
              child: Text(metric.rightDisplay,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17,
                  fontWeight: rightWins ? FontWeight.w900 : FontWeight.w600,
                  color: rightWins ? rightColor : null,
                  fontFeatures: const [FontFeature.tabularFigures()])))),
          ],
        ),
      ),
    );
  }
}

class ComparisonFingerprintEntry {
  const ComparisonFingerprintEntry({
    required this.label,
    required this.color,
    required this.value,
  });
  final String label;
  final Color color;
  final double? value;
}

class ComparisonFingerprintRow {
  const ComparisonFingerprintRow({
    required this.metric,
    required this.entries,
  });
  final String metric;
  final List<ComparisonFingerprintEntry> entries;
}

/// Equal-width columns actually fill the footprint, rather than stopping at
/// 180px and leaving most of the card empty on wide monitors.
class ComparisonFingerprintPanel extends StatelessWidget {
  const ComparisonFingerprintPanel({
    super.key,
    required this.title,
    required this.description,
    required this.rows,
  });

  final String title;
  final String description;
  final List<ComparisonFingerprintRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final count = rows.first.entries.length;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: count == 2 ? 1050 : 1800),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(
                  fontSize: 12, color: colors.onSurfaceVariant)),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final width = math.max(constraints.maxWidth,
                    94 + count * 120.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          for (final row in rows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 94,
                                    child: Text(row.metric,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12))),
                                  for (final item in row.entries)
                                    Expanded(child: Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Semantics(
                                        label: '${item.label}, ${row.metric}, ${item.value?.round() ?? 'unavailable'} percentile',
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${item.label} · ${item.value?.round() ?? '—'}p',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 6),
                                            LinearProgressIndicator(
                                              value: (item.value?.clamp(0, 100) ?? 0) / 100,
                                              minHeight: 8,
                                              borderRadius: BorderRadius.circular(5),
                                              backgroundColor: item.color.withValues(alpha: .10),
                                              valueColor: AlwaysStoppedAnimation(item.color),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
