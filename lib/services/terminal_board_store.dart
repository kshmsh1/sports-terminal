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

  Future<void> delete(String boardId) async {
    final boards = (await loadAll()).where((item) => item.id != boardId).toList();
    await _write(boards);
  }

  Future<void> _write(List<TerminalBoard> boards) => store.saveString(
        storageKey,
        jsonEncode([for (final board in boards) board.toJson()]),
      );
}
