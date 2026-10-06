import 'package:flutter/material.dart';

import 'product_trade_machine_video_screen.dart';

/// Stable public shell entry point for the Sports Terminal NBA Trade Machine.
///
/// The Trade Machine inherits the terminal's global theme. The terminal itself
/// defaults to dark mode, so this page opens dark by default and follows the
/// same light/dark toggle as every other customer-facing route.
class ProductTradeMachineScreen extends StatelessWidget {
  const ProductTradeMachineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tradeTheme = theme.copyWith(
      scaffoldBackgroundColor:
          dark ? const Color(0xFF0B111A) : const Color(0xFFF5F7FA),
      cardTheme: theme.cardTheme.copyWith(
        color: dark ? const Color(0xFF111A24) : Colors.white,
      ),
      dividerColor:
          dark ? const Color(0xFF2B3A49) : const Color(0xFFDCE4EE),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: dark ? const Color(0xFF111A24) : Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF314252) : const Color(0xFFD4DFEB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF314252) : const Color(0xFFD4DFEB),
          ),
        ),
      ),
    );

    return Theme(
      data: tradeTheme,
      child: ColoredBox(
        color: tradeTheme.scaffoldBackgroundColor,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: ProductTradeMachineVideoScreen(),
        ),
      ),
    );
  }
}
