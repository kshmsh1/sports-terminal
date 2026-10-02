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
      ).copyWith(
        primary: const Color(0xFF1769AA),
        onPrimary: Colors.white,
        surface: Colors.white,
        surfaceContainerLow: const Color(0xFFF7F9FC),
        surfaceContainer: const Color(0xFFF1F5F9),
        surfaceContainerHighest: const Color(0xFFE7EDF4),
        onSurface: const Color(0xFF24364B),
        onSurfaceVariant: const Color(0xFF607388),
        outline: const Color(0xFFCBD7E3),
        outlineVariant: const Color(0xFFE0E7EF),
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
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFFF6F9FC),
        selectedColor: Color(0xFFE6F1FA),
        disabledColor: Color(0xFFF0F3F6),
        side: BorderSide(color: Color(0xFFD6E0EA)),
        labelStyle: TextStyle(
          color: Color(0xFF334C64),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: TextStyle(
          color: Color(0xFF1769AA),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF7B8997),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF1769AA)
              : const Color(0xFFDCE3EA),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFF2A6EA7),
        inactiveTrackColor: Color(0xFFDCE5ED),
        thumbColor: Color(0xFF2A6EA7),
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
