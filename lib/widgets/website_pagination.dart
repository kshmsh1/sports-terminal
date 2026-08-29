import 'dart:math' as math;

import 'package:flutter/material.dart';

class WebsitePagination extends StatelessWidget {
  const WebsitePagination({
    super.key,
    required this.totalItems,
    required this.pageSize,
    required this.currentPage,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.customPageSize,
    this.onCustomPageSizeChanged,
  });

  final int totalItems;
  final int pageSize;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  /// Retained for compatibility with older callers. The website intentionally
  /// exposes the four predictable row counts requested for stats surfaces.
  final int? customPageSize;
  final ValueChanged<int>? onCustomPageSizeChanged;

  int get pageCount => math.max(1, (totalItems / pageSize).ceil());

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final safePage = currentPage.clamp(1, pageCount);
    final start = totalItems == 0 ? 0 : ((safePage - 1) * pageSize) + 1;
    final end = totalItems == 0 ? 0 : math.min(totalItems, safePage * pageSize);
    final pages = _pageWindow(safePage, pageCount);

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          totalItems == 0 ? 'No rows' : '$start–$end of $totalItems',
          style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 2),
        for (final size in const [10, 20, 50, 100])
          ChoiceChip(
            label: Text('$size'),
            selected: pageSize == size,
            onSelected: (_) => onPageSizeChanged(size),
          ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Previous page',
          onPressed: safePage > 1 ? () => onPageChanged(safePage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        for (final page in pages)
          page == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('…'),
                )
              : TextButton(
                  onPressed: page == safePage ? null : () => onPageChanged(page),
                  style: TextButton.styleFrom(
                    foregroundColor: page == safePage ? colors.onPrimaryContainer : colors.primary,
                    backgroundColor: page == safePage ? colors.primaryContainer : null,
                    minimumSize: const Size(38, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text('$page', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
        IconButton(
          tooltip: 'Next page',
          onPressed: safePage < pageCount ? () => onPageChanged(safePage + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

List<int?> _pageWindow(int current, int count) {
  if (count <= 7) return [for (var i = 1; i <= count; i++) i];
  final values = <int?>[1];
  final start = math.max(2, current - 1);
  final end = math.min(count - 1, current + 1);
  if (start > 2) values.add(null);
  for (var i = start; i <= end; i++) values.add(i);
  if (end < count - 1) values.add(null);
  values.add(count);
  return values;
}
