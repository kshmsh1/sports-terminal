enum TerminalWatchOperator {
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  equal,
  notEqual,
  increaseBy,
  decreaseBy,
  absoluteChangeBy,
}

extension TerminalWatchOperatorLabel on TerminalWatchOperator {
  String get label => switch (this) {
        TerminalWatchOperator.greaterThan => '>',
        TerminalWatchOperator.greaterThanOrEqual => '>=',
        TerminalWatchOperator.lessThan => '<',
        TerminalWatchOperator.lessThanOrEqual => '<=',
        TerminalWatchOperator.equal => '=',
        TerminalWatchOperator.notEqual => '!=',
        TerminalWatchOperator.increaseBy => 'increase by >=',
        TerminalWatchOperator.decreaseBy => 'decrease by >=',
        TerminalWatchOperator.absoluteChangeBy => 'absolute change >=',
      };

  bool get requiresPrevious => switch (this) {
        TerminalWatchOperator.increaseBy ||
        TerminalWatchOperator.decreaseBy ||
        TerminalWatchOperator.absoluteChangeBy => true,
        _ => false,
      };
}

class TerminalWatchRule {
  const TerminalWatchRule({
    required this.id,
    required this.title,
    required this.metricKey,
    required this.op,
    required this.threshold,
    required this.createdAtIso,
    this.objectType = '',
    this.objectId = '',
    this.sourceRelease = '',
    this.enabled = true,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String metricKey;
  final TerminalWatchOperator op;
  final double threshold;
  final String createdAtIso;
  final String objectType;
  final String objectId;
  final String sourceRelease;
  final bool enabled;
  final List<String> tags;

  String get scopeLabel => objectType.isEmpty
      ? 'Any object'
      : objectId.isEmpty
          ? objectType
          : '$objectType · $objectId';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'metricKey': metricKey,
        'operator': op.name,
        'threshold': threshold,
        'createdAtIso': createdAtIso,
        'objectType': objectType,
        'objectId': objectId,
        'sourceRelease': sourceRelease,
        'enabled': enabled,
        'tags': tags,
      };

  factory TerminalWatchRule.fromJson(Map<String, dynamic> json) => TerminalWatchRule(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Untitled Watch',
        metricKey: json['metricKey']?.toString() ?? '',
        op: _watchOperator(json['operator']?.toString()),
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
        createdAtIso: json['createdAtIso']?.toString() ?? '',
        objectType: json['objectType']?.toString() ?? '',
        objectId: json['objectId']?.toString() ?? '',
        sourceRelease: json['sourceRelease']?.toString() ?? '',
        enabled: json['enabled'] != false,
        tags: json['tags'] is List
            ? [for (final value in json['tags'] as List) value.toString()]
            : const [],
      );
}

TerminalWatchOperator _watchOperator(String? raw) {
  for (final value in TerminalWatchOperator.values) {
    if (value.name == raw) return value;
  }
  return TerminalWatchOperator.greaterThan;
}

enum TerminalWatchEvaluationState { triggered, notTriggered, unavailable }

class TerminalWatchEvaluation {
  const TerminalWatchEvaluation({
    required this.ruleId,
    required this.state,
    required this.reason,
    required this.evaluatedAtIso,
    this.currentValue,
    this.previousValue,
  });

  final String ruleId;
  final TerminalWatchEvaluationState state;
  final String reason;
  final String evaluatedAtIso;
  final double? currentValue;
  final double? previousValue;

  bool get triggered => state == TerminalWatchEvaluationState.triggered;

  Map<String, dynamic> toJson() => {
        'ruleId': ruleId,
        'state': state.name,
        'reason': reason,
        'evaluatedAtIso': evaluatedAtIso,
        'currentValue': currentValue,
        'previousValue': previousValue,
      };
}
