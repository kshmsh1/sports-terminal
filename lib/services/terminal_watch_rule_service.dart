import 'dart:convert';

import '../models/terminal_watch_rule.dart';
import 'product_local_store.dart';
import 'terminal_metric_registry.dart';

class TerminalWatchRuleService {
  const TerminalWatchRuleService({
    this.store = const ProductLocalStore(),
    this.metricRegistry = const TerminalMetricRegistry(),
  });

  static const storageKey = 'sports_terminal.watch.rules.v1';
  static const evaluationHistoryKey = 'sports_terminal.watch.evaluations.v1';

  final ProductLocalStore store;
  final TerminalMetricRegistry metricRegistry;

  Future<List<TerminalWatchRule>> loadAll() async {
    final raw = await store.loadString(storageKey);
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final rules = <TerminalWatchRule>[];
      for (final item in decoded) {
        if (item is Map) {
          rules.add(TerminalWatchRule.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      }
      rules.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));
      return rules;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(TerminalWatchRule rule) async {
    if (rule.id.trim().isEmpty) throw ArgumentError('Watch rule id is required.');
    if (rule.metricKey.trim().isEmpty) throw ArgumentError('Watch metric key is required.');
    if (metricRegistry.resolve(rule.metricKey) == null) {
      throw ArgumentError('Watch metric is not registered: ${rule.metricKey}');
    }
    final rules = (await loadAll()).toList();
    final index = rules.indexWhere((item) => item.id == rule.id);
    if (index >= 0) {
      rules[index] = rule;
    } else {
      rules.insert(0, rule);
    }
    await store.saveString(
      storageKey,
      jsonEncode([for (final item in rules.take(200)) item.toJson()]),
    );
  }

  Future<void> delete(String id) async {
    final rules = (await loadAll()).where((item) => item.id != id).toList();
    await store.saveString(
      storageKey,
      jsonEncode([for (final item in rules) item.toJson()]),
    );
  }

  TerminalWatchEvaluation evaluate(
    TerminalWatchRule rule, {
    required num? currentValue,
    num? previousValue,
    String? evaluatedAtIso,
  }) {
    final evaluatedAt = evaluatedAtIso ?? DateTime.now().toUtc().toIso8601String();
    if (!rule.enabled) {
      return TerminalWatchEvaluation(
        ruleId: rule.id,
        state: TerminalWatchEvaluationState.unavailable,
        reason: 'Rule is disabled.',
        evaluatedAtIso: evaluatedAt,
      );
    }
    if (currentValue == null) {
      return TerminalWatchEvaluation(
        ruleId: rule.id,
        state: TerminalWatchEvaluationState.unavailable,
        reason: 'Current numeric observation is unavailable; the rule fails closed.',
        evaluatedAtIso: evaluatedAt,
      );
    }
    if (rule.op.requiresPrevious && previousValue == null) {
      return TerminalWatchEvaluation(
        ruleId: rule.id,
        state: TerminalWatchEvaluationState.unavailable,
        reason: 'This change operator requires an explicit previous observation.',
        evaluatedAtIso: evaluatedAt,
        currentValue: currentValue.toDouble(),
      );
    }

    final current = currentValue.toDouble();
    final previous = previousValue?.toDouble();
    final threshold = rule.threshold;
    final triggered = switch (rule.op) {
      TerminalWatchOperator.greaterThan => current > threshold,
      TerminalWatchOperator.greaterThanOrEqual => current >= threshold,
      TerminalWatchOperator.lessThan => current < threshold,
      TerminalWatchOperator.lessThanOrEqual => current <= threshold,
      TerminalWatchOperator.equal => current == threshold,
      TerminalWatchOperator.notEqual => current != threshold,
      TerminalWatchOperator.increaseBy => current - previous! >= threshold,
      TerminalWatchOperator.decreaseBy => previous! - current >= threshold,
      TerminalWatchOperator.absoluteChangeBy => (current - previous!).abs() >= threshold,
    };

    return TerminalWatchEvaluation(
      ruleId: rule.id,
      state: triggered
          ? TerminalWatchEvaluationState.triggered
          : TerminalWatchEvaluationState.notTriggered,
      reason: triggered
          ? 'Explicit observation satisfied ${rule.op.label} $threshold.'
          : 'Explicit observation did not satisfy ${rule.op.label} $threshold.',
      evaluatedAtIso: evaluatedAt,
      currentValue: current,
      previousValue: previous,
    );
  }

  Future<void> recordEvaluation(TerminalWatchEvaluation evaluation) async {
    final history = await loadEvaluationHistory();
    final next = [evaluation, ...history].take(500).toList(growable: false);
    await store.saveString(
      evaluationHistoryKey,
      jsonEncode([for (final item in next) item.toJson()]),
    );
  }

  Future<List<TerminalWatchEvaluation>> loadEvaluationHistory() async {
    final raw = await store.loadString(evaluationHistoryKey);
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map) _evaluationFromJson(item),
      ];
    } catch (_) {
      return const [];
    }
  }

  TerminalWatchEvaluation _evaluationFromJson(Map<dynamic, dynamic> json) {
    final stateRaw = json['state']?.toString();
    final state = TerminalWatchEvaluationState.values.firstWhere(
      (value) => value.name == stateRaw,
      orElse: () => TerminalWatchEvaluationState.unavailable,
    );
    return TerminalWatchEvaluation(
      ruleId: json['ruleId']?.toString() ?? '',
      state: state,
      reason: json['reason']?.toString() ?? '',
      evaluatedAtIso: json['evaluatedAtIso']?.toString() ?? '',
      currentValue: (json['currentValue'] as num?)?.toDouble(),
      previousValue: (json['previousValue'] as num?)?.toDouble(),
    );
  }
}
