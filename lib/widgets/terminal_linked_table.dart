import 'package:flutter/material.dart';

import 'terminal_primitives.dart';

class TerminalLinkedColumn {
  const TerminalLinkedColumn({
    required this.key,
    required this.label,
    this.numeric = false,
    this.width,
  });

  final String key;
  final String label;
  final bool numeric;
  final double? width;
}

class TerminalLinkedCell {
  const TerminalLinkedCell({
    required this.display,
    this.sortValue,
    this.onTap,
  });

  final String display;
  final Object? sortValue;
  final VoidCallback? onTap;
}

class TerminalLinkedRow {
  const TerminalLinkedRow({required this.id, required this.cells});

  final String id;
  final Map<String, TerminalLinkedCell> cells;
}

class TerminalLinkedTable extends StatefulWidget {
  const TerminalLinkedTable({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No rows are available.',
    this.initialSortKey,
    this.initialSortAscending = true,
    this.maxRows = 1000,
  });

  final String title;
  final List<TerminalLinkedColumn> columns;
  final List<TerminalLinkedRow> rows;
  final String emptyMessage;
  final String? initialSortKey;
  final bool initialSortAscending;
  final int maxRows;

  @override
  State<TerminalLinkedTable> createState() => _TerminalLinkedTableState();
}

class _TerminalLinkedTableState extends State<TerminalLinkedTable> {
  String? sortKey;
  late bool sortAscending = widget.initialSortAscending;

  @override
  void initState() {
    super.initState();
    sortKey = widget.initialSortKey;
  }

  @override
  void didUpdateWidget(covariant TerminalLinkedTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (sortKey != null && !widget.columns.any((column) => column.key == sortKey)) {
      sortKey = widget.initialSortKey;
      sortAscending = widget.initialSortAscending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = [...widget.rows];
    final activeSortKey = sortKey;
    if (activeSortKey != null) {
      rows.sort((a, b) {
        final result = _compare(
          a.cells[activeSortKey]?.sortValue ?? a.cells[activeSortKey]?.display,
          b.cells[activeSortKey]?.sortValue ?? b.cells[activeSortKey]?.display,
        );
        return sortAscending ? result : -result;
      });
    }
    final visibleRows = rows.take(widget.maxRows).toList(growable: false);
    final sortColumnIndex = activeSortKey == null
        ? null
        : widget.columns.indexWhere((column) => column.key == activeSortKey);

    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${widget.rows.length} rows',
                  style: const TextStyle(color: terminalTextMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          if (visibleRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                widget.emptyMessage,
                style: const TextStyle(color: terminalTextSoft),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: sortColumnIndex != null && sortColumnIndex >= 0
                    ? sortColumnIndex
                    : null,
                sortAscending: sortAscending,
                headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                headingTextStyle: const TextStyle(
                  color: terminalTextMuted,
                  fontWeight: FontWeight.w800,
                ),
                dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                columns: [
                  for (final column in widget.columns)
                    DataColumn(
                      label: Text(column.label),
                      numeric: column.numeric,
                      onSort: (_, ascending) {
                        setState(() {
                          sortKey = column.key;
                          sortAscending = ascending;
                        });
                      },
                    ),
                ],
                rows: [
                  for (final row in visibleRows)
                    DataRow(
                      cells: [
                        for (final column in widget.columns)
                          DataCell(
                            _LinkedCellView(
                              cell: row.cells[column.key] ??
                                  const TerminalLinkedCell(display: '—'),
                              width: column.width,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    if (a is num && b is num) return a.compareTo(b);
    return '$a'.toLowerCase().compareTo('$b'.toLowerCase());
  }
}

class _LinkedCellView extends StatelessWidget {
  const _LinkedCellView({required this.cell, required this.width});

  final TerminalLinkedCell cell;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      cell.display,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final content = cell.onTap == null
        ? text
        : TextButton(
            style: TextButton.styleFrom(
              foregroundColor: terminalAccent,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: cell.onTap,
            child: Align(alignment: Alignment.centerLeft, child: text),
          );
    if (width == null) return content;
    return SizedBox(width: width, child: content);
  }
}
