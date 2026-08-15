import '../models/terminal_action.dart';

class TerminalCommandEntry {
  const TerminalCommandEntry({
    required this.id,
    required this.label,
    required this.kind,
    this.aliases = const [],
    this.subtitle = '',
    this.payload = const {},
  });

  final String id;
  final String label;
  final String kind;
  final List<String> aliases;
  final String subtitle;
  final Map<String, dynamic> payload;

  Iterable<String> get searchable => [id, label, kind, subtitle, ...aliases];
}

class TerminalCommandResult {
  const TerminalCommandResult({
    required this.raw,
    required this.mode,
    this.operation = '',
    this.query = '',
    this.entry,
    this.action,
  });

  final String raw;
  final String mode;
  final String operation;
  final String query;
  final TerminalCommandEntry? entry;
  final TerminalAction? action;
}

class TerminalCommandEngine {
  const TerminalCommandEngine();

  static const operationMap = <String, TerminalActionKind>{
    'COMPARE': TerminalActionKind.compare,
    'CHART': TerminalActionKind.chart,
    'WATCH': TerminalActionKind.watch,
    'QUERY': TerminalActionKind.query,
    'MODEL': TerminalActionKind.model,
    'EXPORT': TerminalActionKind.export,
    'LAB': TerminalActionKind.lab,
    'SOURCE': TerminalActionKind.source,
    'BOARD': TerminalActionKind.board,
    'SHARE': TerminalActionKind.share,
    'DISCUSS': TerminalActionKind.discuss,
  };

  List<TerminalCommandEntry> search(
    String raw,
    List<TerminalCommandEntry> entries, {
    int limit = 12,
  }) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return entries.take(limit).toList(growable: false);
    final scored = <(int, TerminalCommandEntry)>[];
    for (final entry in entries) {
      var score = 0;
      for (final field in entry.searchable) {
        final candidate = field.toLowerCase();
        if (candidate == query) score = score < 100 ? 100 : score;
        if (candidate.startsWith(query)) score = score < 70 ? 70 : score;
        if (candidate.contains(query)) score = score < 40 ? 40 : score;
      }
      if (score > 0) scored.add((score, entry));
    }
    scored.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0 ? byScore : a.$2.label.compareTo(b.$2.label);
    });
    return scored.take(limit).map((item) => item.$2).toList(growable: false);
  }

  TerminalCommandResult interpret(
    String raw,
    List<TerminalCommandEntry> entries,
  ) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return const TerminalCommandResult(raw: '', mode: 'empty');
    }
    final pieces = normalized.split(RegExp(r'\s+'));
    final operation = pieces.first.toUpperCase();
    final kind = operationMap[operation];
    if (kind != null) {
      final query = pieces.skip(1).join(' ').trim();
      final action = TerminalAction.standard.firstWhere((item) => item.kind == kind);
      return TerminalCommandResult(
        raw: normalized,
        mode: 'operation',
        operation: operation,
        query: query,
        action: action,
      );
    }

    final matches = search(normalized, entries, limit: 1);
    if (matches.isNotEmpty) {
      return TerminalCommandResult(
        raw: normalized,
        mode: 'entity',
        query: normalized,
        entry: matches.first,
      );
    }

    return TerminalCommandResult(
      raw: normalized,
      mode: 'query',
      query: normalized,
      action: TerminalAction.standard.firstWhere(
        (item) => item.kind == TerminalActionKind.query,
      ),
    );
  }
}
