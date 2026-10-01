import 'dart:convert';

import 'product_local_store.dart';

class TradeMachineSavedTrade {
  const TradeMachineSavedTrade({
    required this.id,
    required this.savedAtIso,
    required this.teams,
    required this.routes,
    required this.routeLabels,
    required this.cashAmounts,
    required this.cashDestinations,
    required this.signAndTradeDestinations,
    required this.signAndTradeSalaries,
    this.acquisitionMechanisms = const {},
    this.renouncedFreeAgentRights = const [],
    required this.incomingAssets,
    required this.passed,
    required this.restrictionMode,
  });

  final String id;
  final String savedAtIso;
  final List<String> teams;
  final Map<String, String> routes;
  final Map<String, String> routeLabels;
  final Map<String, double> cashAmounts;
  final Map<String, String> cashDestinations;
  final Map<String, String> signAndTradeDestinations;
  final Map<String, double> signAndTradeSalaries;
  final Map<String, String> acquisitionMechanisms;
  final List<String> renouncedFreeAgentRights;
  final Map<String, List<String>> incomingAssets;
  final bool passed;
  final String restrictionMode;

  Map<String, dynamic> toJson() => {
        'id': id,
        'saved_at_iso': savedAtIso,
        'teams': teams,
        'routes': routes,
        'route_labels': routeLabels,
        'cash_amounts': cashAmounts,
        'cash_destinations': cashDestinations,
        'sign_and_trade_destinations': signAndTradeDestinations,
        'sign_and_trade_salaries': signAndTradeSalaries,
        'acquisition_mechanisms': acquisitionMechanisms,
        'renounced_free_agent_rights': renouncedFreeAgentRights,
        'incoming_assets': incomingAssets,
        'passed': passed,
        'restriction_mode': restrictionMode,
      };

  factory TradeMachineSavedTrade.fromJson(Map<String, dynamic> json) {
    Map<String, String> stringMap(Object? value) {
      if (value is! Map) return {};
      return value.map(
        (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
      );
    }

    Map<String, double> doubleMap(Object? value) {
      if (value is! Map) return {};
      final result = <String, double>{};
      for (final entry in value.entries) {
        final parsed = entry.value is num
            ? (entry.value as num).toDouble()
            : double.tryParse('${entry.value}');
        if (parsed != null) result['${entry.key}'] = parsed;
      }
      return result;
    }

    Map<String, List<String>> listMap(Object? value) {
      if (value is! Map) return {};
      final result = <String, List<String>>{};
      for (final entry in value.entries) {
        if (entry.value is List) {
          result['${entry.key}'] =
              (entry.value as List).map((item) => '$item').toList();
        }
      }
      return result;
    }

    return TradeMachineSavedTrade(
      id: '${json['id'] ?? ''}',
      savedAtIso: '${json['saved_at_iso'] ?? ''}',
      teams: json['teams'] is List
          ? (json['teams'] as List).map((item) => '$item').toList()
          : const [],
      routes: stringMap(json['routes']),
      routeLabels: stringMap(json['route_labels']),
      cashAmounts: doubleMap(json['cash_amounts']),
      cashDestinations: stringMap(json['cash_destinations']),
      signAndTradeDestinations:
          stringMap(json['sign_and_trade_destinations']),
      signAndTradeSalaries: doubleMap(json['sign_and_trade_salaries']),
      acquisitionMechanisms: stringMap(json['acquisition_mechanisms']),
      renouncedFreeAgentRights: json['renounced_free_agent_rights'] is List
          ? (json['renounced_free_agent_rights'] as List)
              .map((item) => '$item')
              .toList()
          : const [],
      incomingAssets: listMap(json['incoming_assets']),
      passed: json['passed'] == true,
      restrictionMode: '${json['restriction_mode'] ?? 'on'}',
    );
  }
}

class TradeMachineSavedTradeStore {
  const TradeMachineSavedTradeStore({
    this.store = const ProductLocalStore(),
  });

  static const key = 'sports_terminal.trade_machine.saved_trades.v2';
  final ProductLocalStore store;

  Future<List<TradeMachineSavedTrade>> load() async {
    final encoded = await store.loadString(key);
    if (encoded.isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            TradeMachineSavedTrade.fromJson(item.cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<TradeMachineSavedTrade>> save(
    TradeMachineSavedTrade trade, {
    int limit = 40,
  }) async {
    final existing = await load();
    final updated = <TradeMachineSavedTrade>[
      trade,
      ...existing.where((item) => item.id != trade.id),
    ];
    final trimmed = updated.take(limit).toList(growable: false);
    await store.saveString(
      key,
      jsonEncode([for (final item in trimmed) item.toJson()]),
    );
    return trimmed;
  }

  Future<List<TradeMachineSavedTrade>> delete(String id) async {
    final existing = await load();
    final updated =
        existing.where((item) => item.id != id).toList(growable: false);
    await store.saveString(
      key,
      jsonEncode([for (final item in updated) item.toJson()]),
    );
    return updated;
  }

  Future<void> clear() => store.remove(key);
}
