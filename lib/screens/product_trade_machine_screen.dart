import 'package:flutter/material.dart';

import 'product_trade_machine_video_screen.dart';

/// Stable public shell entry point for the Sports Terminal NBA Trade Machine.
class ProductTradeMachineScreen extends StatelessWidget {
  const ProductTradeMachineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1769AA),
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      dividerColor: const Color(0xFFDCE4EE),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: const Color(0xFF24364B),
            displayColor: const Color(0xFF24364B),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD4DFEB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD4DFEB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF4B8FC8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF28689F),
          side: const BorderSide(color: Color(0xFFD5E0EB)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1769AA),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );

    return Theme(
      data: base,
      child: Container(
        color: const Color(0xFFF4F7FB),
        padding: const EdgeInsets.all(2),
        child: const ProductTradeMachineVideoScreen(),
      ),
    );
  }
}
