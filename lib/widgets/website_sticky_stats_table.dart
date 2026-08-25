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
  final double maxBodyHeight;
  final double firstColumnWidth;

  @override
  State<WebsiteStickyStatsTable> createState() => _WebsiteStickyStatsTableState();
}

class _WebsiteStickyStatsTableState extends State<WebsiteStickyStatsTable> {
  final _horizontal = ScrollController();
  final _bodyVertical = ScrollController();
  final _frozenVertical = ScrollController();
  bool _syncingVertical = false;

  @override
  void initState() {
    super.initState();
    _bodyVertical.addListener(_syncFromBody);
    _frozenVertical.addListener(_syncFromFrozen);
  }

  @override
  void dispose() {
    _bodyVertical.removeListener(_syncFromBody);
    _frozenVertical.removeListener(_syncFromFrozen);
    _horizontal.dispose();
    _bodyVertical.dispose();
    _frozenVertical.dispose();
    super.dispose();
  }

  void _syncFromBody() {
    if (_syncingVertical || !_frozenVertical.hasClients) return;
    _syncingVertical = true;
    _frozenVertical.jumpTo(
      _bodyVertical.offset.clamp(
        _frozenVertical.position.minScrollExtent,
        _frozenVertical.position.maxScrollExtent,
      ),
    );
    _syncingVertical = false;
  }

  void _syncFromFrozen() {
    if (_syncingVertical || !_bodyVertical.hasClients) return;
    _syncingVertical = true;
    _bodyVertical.jumpTo(
      _frozenVertical.offset.clamp(
        _bodyVertical.position.minScrollExtent,
        _bodyVertical.position.maxScrollExtent,
      ),
    );
    _syncingVertical = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.columns.isEmpty) return const SizedBox.shrink();
    final border = Theme.of(context).dividerColor;
    final card = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final header = Theme.of(context).colorScheme.surfaceContainerHighest;
    final remaining = widget.columns.skip(1).toList();
    final remainingWidth = remaining.fold<double>(0, (sum, item) => sum + item.width);
    final totalBodyHeight = widget.rows.length * widget.rowHeight;
    final bodyHeight = totalBodyHeight.clamp(0, widget.maxBodyHeight).toDouble();

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
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: backgroundColor ?? (headerCell ? header : card),
          border: Border(
            right: BorderSide(color: border),
            bottom: BorderSide(color: border),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontWeight: headerCell ? FontWeight.w800 : FontWeight.w500),
          child: child,
        ),
      );
      return onTap == null ? content : InkWell(onTap: onTap, child: content);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: widget.headerHeight + bodyHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: widget.firstColumnWidth,
              child: Column(
                children: [
                  cell(
                    child: widget.columns.first.label,
                    width: widget.firstColumnWidth,
                    height: widget.headerHeight,
                    headerCell: true,
                    backgroundColor: widget.columns.first.backgroundColor,
                    onTap: widget.columns.first.onTap,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _frozenVertical,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
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
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _horizontal,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: remainingWidth,
                    child: Column(
                      children: [
                        Row(
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
                        Expanded(
                          child: Scrollbar(
                            controller: _bodyVertical,
                            thumbVisibility: totalBodyHeight > bodyHeight,
                            child: SingleChildScrollView(
                              controller: _bodyVertical,
                              physics: const ClampingScrollPhysics(),
                              child: Column(
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
                                            alignment: widget.columns[index].numeric ? Alignment.centerRight : Alignment.centerLeft,
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
