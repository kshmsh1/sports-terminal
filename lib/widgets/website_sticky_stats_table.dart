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

/// Conventional, borderless website statistics table.
///
/// The page owns all vertical scrolling: choosing 10, 20, 50 or 100 rows makes
/// the document grow to exactly that many rows. The table owns horizontal
/// scrolling only. The first column stays frozen horizontally and the header
/// follows the page while the table remains in view.
///
/// There are deliberately no per-cell divider rules. Dense tables use a very
/// light zebra surface instead, which keeps long leaderboards legible without
/// the spreadsheet-like white grid that the traditional Sports Terminal UI is
/// moving away from.
class WebsiteStickyStatsTable extends StatefulWidget {
  const WebsiteStickyStatsTable({
    super.key,
    required this.columns,
    required this.rows,
    this.headerHeight = 46,
    this.rowHeight = 46,
    this.maxBodyHeight = 560,
    this.firstColumnWidth = 185,
    this.stripeRows = true,
    this.borderRadius = 14,
  });

  final List<WebsiteStickyStatsColumn> columns;
  final List<List<Widget>> rows;
  final double headerHeight;
  final double rowHeight;

  /// Retained for source compatibility with older callers. Vertical height is
  /// deliberately never capped.
  final double maxBodyHeight;
  final double firstColumnWidth;
  final bool stripeRows;
  final double borderRadius;

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
    final colors = theme.colorScheme;
    final bodySurface = theme.cardTheme.color ?? colors.surface;
    final headerSurface = colors.surfaceContainerHighest;
    final alternateSurface = Color.alphaBlend(
      colors.onSurface.withValues(alpha: theme.brightness == Brightness.dark ? .025 : .018),
      bodySurface,
    );
    final remaining = widget.columns.skip(1).toList();
    final remainingWidth = remaining.fold<double>(0, (sum, item) => sum + item.width);
    final totalHeight = widget.headerHeight + widget.rows.length * widget.rowHeight;

    Color bodyColor(int rowIndex, Color? explicit) {
      if (explicit != null) return explicit;
      if (!widget.stripeRows || rowIndex.isEven) return bodySurface;
      return alternateSurface;
    }

    Widget cell({
      required Widget child,
      required double width,
      required double height,
      required bool headerCell,
      int rowIndex = 0,
      Color? backgroundColor,
      Color? foregroundColor,
      Alignment alignment = Alignment.centerLeft,
      VoidCallback? onTap,
    }) {
      final content = Container(
        width: width,
        height: height,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        color: headerCell
            ? (backgroundColor ?? headerSurface)
            : bodyColor(rowIndex, backgroundColor),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: foregroundColor,
            fontWeight: headerCell ? FontWeight.w800 : FontWeight.w500,
            fontSize: 13,
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
                    for (var rowIndex = 0; rowIndex < widget.rows.length; rowIndex++)
                      cell(
                        child: widget.rows[rowIndex].first,
                        width: widget.firstColumnWidth,
                        height: widget.rowHeight,
                        headerCell: false,
                        rowIndex: rowIndex,
                        backgroundColor: widget.columns.first.backgroundColor,
                        foregroundColor: widget.columns.first.foregroundColor,
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
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  child: cell(
                    child: widget.columns.first.label,
                    width: widget.firstColumnWidth,
                    height: widget.headerHeight,
                    headerCell: true,
                    backgroundColor: widget.columns.first.backgroundColor,
                    foregroundColor: widget.columns.first.foregroundColor,
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
                        for (var rowIndex = 0; rowIndex < widget.rows.length; rowIndex++)
                          Row(
                            children: [
                              for (var index = 1; index < widget.rows[rowIndex].length; index++)
                                cell(
                                  child: widget.rows[rowIndex][index],
                                  width: widget.columns[index].width,
                                  height: widget.rowHeight,
                                  headerCell: false,
                                  rowIndex: rowIndex,
                                  backgroundColor: widget.columns[index].backgroundColor,
                                  foregroundColor: widget.columns[index].foregroundColor,
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
                      elevation: 0,
                      surfaceTintColor: Colors.transparent,
                      child: Row(
                        children: [
                          for (final column in remaining)
                            cell(
                              child: column.label,
                              width: column.width,
                              height: widget.headerHeight,
                              headerCell: true,
                              backgroundColor: column.backgroundColor,
                              foregroundColor: column.foregroundColor,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: ColoredBox(
        color: bodySurface,
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
      ),
    );
  }
}
