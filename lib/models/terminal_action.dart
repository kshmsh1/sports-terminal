enum TerminalActionKind {
  compare,
  chart,
  watch,
  query,
  model,
  export,
  lab,
  source,
  board,
  share,
  discuss,
}

class TerminalAction {
  const TerminalAction({
    required this.kind,
    required this.label,
    required this.routeTarget,
    this.enabled = true,
    this.reason = '',
  });

  final TerminalActionKind kind;
  final String label;
  final String routeTarget;
  final bool enabled;
  final String reason;

  static const standard = <TerminalAction>[
    TerminalAction(kind: TerminalActionKind.compare, label: 'COMPARE', routeTarget: 'Compare'),
    TerminalAction(kind: TerminalActionKind.chart, label: 'CHART', routeTarget: 'Dashboard'),
    TerminalAction(kind: TerminalActionKind.watch, label: 'WATCH', routeTarget: 'Alerts'),
    TerminalAction(kind: TerminalActionKind.query, label: 'QUERY', routeTarget: 'Search'),
    TerminalAction(kind: TerminalActionKind.model, label: 'MODEL', routeTarget: 'Python Lab'),
    TerminalAction(kind: TerminalActionKind.export, label: 'EXPORT', routeTarget: 'Export'),
    TerminalAction(kind: TerminalActionKind.lab, label: 'LAB', routeTarget: 'Python Lab'),
    TerminalAction(kind: TerminalActionKind.source, label: 'SOURCE', routeTarget: 'Source Audit'),
    TerminalAction(kind: TerminalActionKind.board, label: 'BOARD', routeTarget: 'Dashboard'),
    TerminalAction(kind: TerminalActionKind.share, label: 'SHARE', routeTarget: 'Reports'),
    TerminalAction(kind: TerminalActionKind.discuss, label: 'DISCUSS', routeTarget: 'Action Center'),
  ];

  TerminalAction copyWith({bool? enabled, String? reason}) => TerminalAction(
        kind: kind,
        label: label,
        routeTarget: routeTarget,
        enabled: enabled ?? this.enabled,
        reason: reason ?? this.reason,
      );
}

class TerminalActionPolicy {
  const TerminalActionPolicy._();

  static List<TerminalAction> forObject({
    required bool hasStructuredData,
    required bool hasSource,
    required bool canDiscuss,
  }) {
    return [
      for (final action in TerminalAction.standard)
        switch (action.kind) {
          TerminalActionKind.compare ||
          TerminalActionKind.chart ||
          TerminalActionKind.query ||
          TerminalActionKind.model ||
          TerminalActionKind.export ||
          TerminalActionKind.lab => action.copyWith(
              enabled: hasStructuredData,
              reason: hasStructuredData ? '' : 'Structured data required',
            ),
          TerminalActionKind.source => action.copyWith(
              enabled: hasSource,
              reason: hasSource ? '' : 'Source metadata unavailable',
            ),
          TerminalActionKind.discuss => action.copyWith(
              enabled: canDiscuss,
              reason: canDiscuss ? '' : 'Discussion unavailable for this object',
            ),
          _ => action,
        },
    ];
  }
}
