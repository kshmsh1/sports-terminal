import 'package:flutter/material.dart';

import 'product_trade_machine_complete_screen.dart';

/// Stable public shell entry point for the Sports Terminal NBA Trade Machine.
class ProductTradeMachineScreen extends StatelessWidget {
  const ProductTradeMachineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 8,
          ),
          hintStyle: theme.textTheme.bodySmall,
        ),
      ),
      child: const ProductTradeMachineCompleteScreen(),
    );
  }
}
