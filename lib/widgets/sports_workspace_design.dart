import 'package:flutter/material.dart';

/// Sports Terminal / Workspace design language.
///
/// Product chrome is deliberately neutral; league/team/player colors remain
/// available for real data. Bright chartreuse is reserved for navigation and
/// actions, never for "positive performance" or statistical meaning.
abstract final class SportsWorkspaceDesign {
  static const canvasDark = Color(0xFF0D1215);
  static const sidebarDark = Color(0xFF11181A);
  static const surfaceDark = Color(0xFF182023);
  static const strokeDark = Color(0xFF303A3C);
  static const textDark = Color(0xFFF2F3EC);
  static const secondaryDark = Color(0xFFABB9B5);
  static const accentDark = Color(0xFFC7EF77);

  static const canvasLight = Color(0xFFF4F5F0);
  static const sidebarLight = Color(0xFFEAEEE7);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const strokeLight = Color(0xFFD6DCD4);
  static const textLight = Color(0xFF17241E);
  static const secondaryLight = Color(0xFF52645B);
  static const accentLight = Color(0xFF3F6322);

  static Color canvas(bool dark) => dark ? canvasDark : canvasLight;
  static Color sidebar(bool dark) => dark ? sidebarDark : sidebarLight;
  static Color surface(bool dark) => dark ? surfaceDark : surfaceLight;
  static Color stroke(bool dark) => dark ? strokeDark : strokeLight;

  static ThemeData theme(bool dark) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    final accent = dark ? accentDark : accentLight;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: accent,
      ),
    );
    final colors = base.colorScheme.copyWith(
      primary: accent,
      onPrimary: dark ? canvasDark : Colors.white,
      surface: surface(dark),
      onSurface: dark ? textDark : textLight,
      onSurfaceVariant: dark ? secondaryDark : secondaryLight,
      outline: stroke(dark),
      surfaceContainer: sidebar(dark),
      surfaceContainerHigh:
          dark ? const Color(0xFF222D2F) : const Color(0xFFE5EBE4),
    );
    final outline = OutlineInputBorder(
      borderSide: BorderSide(color: colors.outline),
      borderRadius: BorderRadius.circular(11),
    );
    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: canvas(dark),
      dividerColor: colors.outline,
      textTheme: base.textTheme.apply(
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      ).copyWith(
        headlineLarge: const TextStyle(
          fontSize: 38, height: 1.09, fontWeight: FontWeight.w800,
          letterSpacing: -1.35,
        ),
        headlineMedium: const TextStyle(
          fontSize: 30, height: 1.15, fontWeight: FontWeight.w800,
          letterSpacing: -.75,
        ),
        titleLarge: const TextStyle(
          fontSize: 21, height: 1.25, fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
        labelLarge: const TextStyle(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(width: 2, color: colors.primary),
        ),
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor:
            WidgetStatePropertyAll(colors.surfaceContainerHigh),
        dataTextStyle: TextStyle(
          fontSize: 13, color: colors.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: .45,
          color: colors.onSurfaceVariant,
        ),
        dividerThickness: .7,
        horizontalMargin: 16,
        columnSpacing: 22,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outline),
        ),
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant),
      visualDensity: VisualDensity.standard,
    );
  }

  /// Workspaces can opt into denser content without widening every page.
  static double maxContentWidth(String id) {
    switch (id) {
      case 'trade':
      case 'front-office':
        return 1620;
      case 'visualizations':
        return 1900;
      case 'player-compare':
      case 'team-compare':
        return 1820;
      case 'stats':
      case 'advanced':
        return 1720;
      default:
        return 1420;
    }
  }

  static EdgeInsets gutters(double width, String route) {
    final value = width < 600 ? 14.0 : width < 1100 ? 22.0 : 32.0;
    return EdgeInsets.fromLTRB(
      value,
      route == 'trade' ? 18 : 26,
      value,
      width < 600 ? 42 : 64,
    );
  }
}

class WorkspaceSectionLabel extends StatelessWidget {
  const WorkspaceSectionLabel(this.value, {super.key});
  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      letterSpacing: 1.6,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class WorkspaceSurface extends StatelessWidget {
  const WorkspaceSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(22),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}
