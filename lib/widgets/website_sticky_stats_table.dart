import 'dart:math' as math;

import 'package:flutter/material.dart';

class WebsiteStickyStatsColumn {
  const WebsiteStickyStatsColumn({
    required this.label,
    required this.width,
    this.numeric = false,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  final Widget label;
  final double width;
  final bool numeric;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
}

/// A stats table that keeps horizontal scrolling local to the table while
/// allowing vertical scrolling to remain owned by the website page.
///
/// The first column is frozen horizontally. The header row follows the page
/// viewport while the table itself remains in view, so choosing 10, 50 or 100
/// rows produces exactly that many page rows instead of a second vertical
/// scroll area inside the table.
class WebsiteStickyStatsTable extends StatefulWidget {
  const WebsiteStickyStatsTable({
    super.key,
    required this.columns,
    required this.rows,
    this.headerHeight = 46,
    this.rowHeight = 46,
    this.maxBodyHeight = 560,
    this.firstColumnWidth = 185,
  });

  final List<WebsiteStickyStatsColumn> columns;
  final List<List<Widget>> rows;
  final double headerHeight;
  final double rowHeight;

  /// Retained for API compatibility. Vertical height is intentionally no
  /// longer capped; the parent website owns vertical scrolling.
  final double maxBodyHeight;
  final double firstColumnWidth;

  @override
  State<WebsiteStickyStatsTable> createState() => _WebsiteStickyStatsTableState();
}

class _WebsiteStickyStatsTableState extends State<WebsiteStickyStatsTable> {
  final _horizontal = ScrollController();
  ScrollableState? _pageScrollable;
  ScrollPosition? _pagePosition;
  double _stickyOffset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable?.position;
    if (identical(position, _pagePosition)) return;
    _pagePosition?.removeListener(_scheduleStickyUpdate);
    _pageScrollable = scrollable;
    _pagePosition = position;
    _pagePosition?.addListener(_scheduleStickyUpdate);
    _scheduleStickyUpdate();
  }

  @override
  void didUpdateWidget(covariant WebsiteStickyStatsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows.length != widget.rows.length ||
        oldWidget.headerHeight != widget.headerHeight ||
        oldWidget.rowHeight != widget.rowHeight) {
      _scheduleStickyUpdate();
    }
  }

  @override
  void dispose() {
    _pagePosition?.removeListener(_scheduleStickyUpdate);
    _horizontal.dispose();
    super.dispose();
  }

  void _scheduleStickyUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateStickyOffset());
  }

  void _updateStickyOffset() {
    if (!mounted) return;
    final tableBox = context.findRenderObject();
    final viewportBox = _pageScrollable?.context.findRenderObject();
    if (tableBox is! RenderBox ||
        viewportBox is! RenderBox ||
        !tableBox.hasSize ||
        !viewportBox.hasSize) {
      return;
    }
    final tableTop = tableBox.localToGlobal(Offset.zero).dy;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final totalHeight = widget.headerHeight + widget.rows.length * widget.rowHeight;
    final maxOffset = math.max(0.0, totalHeight - widget.headerHeight);
    final next = (viewportTop - tableTop).clamp(0.0, maxOffset);
    if ((next - _stickyOffset).abs() < .5) return;
    setState(() => _stickyOffset = next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.columns.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final card = theme.cardTheme.color ?? theme.colorScheme.surface;
    final header = theme.colorScheme.surfaceContainerHighest;
    final divider = theme.dividerColor.withValues(alpha: .45);
    final remaining = widget.columns.skip(1).toList();
    final remainingWidth = remaining.fold<double>(0, (sum, item) => sum + item.width);
    final totalHeight = widget.headerHeight + widget.rows.length * widget.rowHeight;

    Widget cell({
      required Widget child,
      required double width,
      required double height,
      required bool headerCell,
      Color? backgroundColor,
      Alignment alignment = Alignment.centerLeft,
      VoidCallback? onTap,
    }) {
      final content = Container(
        width: width,
        height: height,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: backgroundColor ?? (headerCell ? header : card),
          border: headerCell ? Border(bottom: BorderSide(color: divider)) : null,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontWeight: headerCell ? FontWeight.w800 : FontWeight.w500,
            fontSize: headerCell ? 13 : 13,
          ),
          child: child,
        ),
      );
      return onTap == null ? content : InkWell(onTap: onTap, child: content);
    }

    Widget frozenColumn() => SizedBox(
          width: widget.firstColumnWidth,
          height: totalHeight,
          child: Stack(
            children: [
              Positioned.fill(
                top: widget.headerHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final row in widget.rows)
                      cell(
                        child: row.first,
                        width: widget.firstColumnWidth,
                        height: widget.rowHeight,
                        headerCell: false,
                      ),
                  ],
                ),
              ),
              Positioned(
                top: _stickyOffset,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  elevation: _stickyOffset > 0 ? 2 : 0,
                  child: cell(
                    child: widget.columns.first.label,
                    width: widget.firstColumnWidth,
                    height: widget.headerHeight,
                    headerCell: true,
                    backgroundColor: widget.columns.first.backgroundColor,
                    onTap: widget.columns.first.onTap,
                  ),
                ),
              ),
            ],
          ),
        );

    Widget scrollingColumns() => Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: remainingWidth,
              height: totalHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: widget.headerHeight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final row in widget.rows)
                          Row(
                            children: [
                              for (var index = 1; index < row.length; index++)
                                cell(
                                  child: row[index],
                                  width: widget.columns[index].width,
                                  height: widget.rowHeight,
                                  headerCell: false,
                                  backgroundColor: widget.columns[index].backgroundColor,
                                  alignment: widget.columns[index].numeric
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: _stickyOffset,
                    left: 0,
                    right: 0,
                    child: Material(
                      color: Colors.transparent,
                      elevation: _stickyOffset > 0 ? 2 : 0,
                      child: Row(
                        children: [
                          for (final column in remaining)
                            cell(
                              child: column.label,
                              width: column.width,
                              height: widget.headerHeight,
                              headerCell: true,
                              backgroundColor: column.backgroundColor,
                              alignment: column.numeric ? Alignment.centerRight : Alignment.centerLeft,
                              onTap: column.onTap,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    return Card(
      clipBehavior: Clip.hardEdge,
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            frozenColumn(),
            Expanded(child: scrollingColumns()),
          ],
        ),
      ),
    );
  }
}
