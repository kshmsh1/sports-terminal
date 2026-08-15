import 'dart:convert';

import '../models/terminal_board.dart';
import 'product_local_store.dart';

class TerminalBoardStore {
  const TerminalBoardStore({this.store = const ProductLocalStore()});

  static const storageKey = 'sports_terminal.boards.v1';
  final ProductLocalStore store;

  Future<List<TerminalBoard>> loadAll() async {
    final raw = await store.loadString(storageKey);
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final boards = <TerminalBoard>[];
      for (final item in decoded) {
        if (item is Map) {
          boards.add(TerminalBoard.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      }
      boards.sort((a, b) => b.updatedAtIso.compareTo(a.updatedAtIso));
      return boards;
    } catch (_) {
      return const [];
    }
  }

  Future<TerminalBoard?> getById(String boardId) async {
    for (final board in await loadAll()) {
      if (board.id == boardId) return board;
    }
    return null;
  }

  Future<void> save(TerminalBoard board) async {
    final boards = (await loadAll()).toList();
    final index = boards.indexWhere((item) => item.id == board.id);
    final next = board.copyWith(updatedAtIso: DateTime.now().toUtc().toIso8601String());
    if (index >= 0) {
      boards[index] = next;
    } else {
      boards.insert(0, next);
    }
    await _write(boards.take(50).toList(growable: false));
  }

  Future<TerminalBoard> appendPanel({
    required String boardId,
    required String boardTitle,
    required TerminalBoardPanel panel,
    String description = '',
    bool replaceIfExists = false,
  }) async {
    final existing = await getById(boardId);
    final panels = [...?existing?.panels];
    final index = panels.indexWhere((item) => item.id == panel.id);
    if (index >= 0) {
      if (replaceIfExists) panels[index] = panel;
    } else {
      panels.add(panel);
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final next = (existing ??
            TerminalBoard(
              id: boardId,
              title: boardTitle,
              updatedAtIso: now,
              description: description,
            ))
        .copyWith(
      title: boardTitle,
      description: description.isEmpty ? existing?.description : description,
      panels: panels,
      updatedAtIso: now,
    );
    await save(next);
    return next;
  }

  Future<TerminalBoard> cloneBoard(
    TerminalBoard source, {
    required String newId,
    required String newTitle,
  }) async {
    final clone = TerminalBoard(
      id: newId,
      title: newTitle,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      description: source.description,
      sport: source.sport,
      filters: Map<String, dynamic>.from(source.filters),
      panels: [
        for (final panel in source.panels)
          TerminalBoardPanel(
            id: '${newId}-${panel.id}',
            kind: panel.kind,
            title: panel.title,
            payload: Map<String, dynamic>.from(panel.payload),
            column: panel.column,
            row: panel.row,
            width: panel.width,
            height: panel.height,
          ),
      ],
      collaborators: const [],
      liveRefresh: false,
    );
    await save(clone);
    return clone;
  }

  Future<void> delete(String boardId) async {
    final boards = (await loadAll()).where((item) => item.id != boardId).toList();
    await _write(boards);
  }

  Future<void> _write(List<TerminalBoard> boards) => store.saveString(
        storageKey,
        jsonEncode([for (final board in boards) board.toJson()]),
      );
}
