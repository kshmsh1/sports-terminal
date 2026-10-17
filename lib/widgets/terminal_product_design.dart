import 'package:flutter/material.dart';

/// One visual language for all customer-facing Sports Terminal routes.
/// Feature-specific player/team colors remain owned by their data visualizations.
abstract final class TerminalProductDesign {
  static const Color brand = Color(0xFF8E9CF7);
  static const Color darkCanvas = Color(0xFF0B111A);
  static const Color darkSurface = Color(0xFF141C27);
  static const Color darkElevated = Color(0xFF192330);
  static const Color darkStroke = Color(0xFF303C4D);
  static const Color lightCanvas = Color(0xFFF5F7FB);
  static const Color lightStroke = Color(0xFFD9E0EB);

  static ThemeData theme({required bool dark}) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand,
        brightness: brightness,
      ),
    );
    final colors = base.colorScheme.copyWith(
      primary: dark ? const Color(0xFFACB7FF) : const Color(0xFF4253AA),
      surface: dark ? darkSurface : Colors.white,
      onSurface: dark ? const Color(0xFFE8ECF5) : const Color(0xFF182334),
      onSurfaceVariant:
          dark ? const Color(0xFFADBACD) : const Color(0xFF506076),
      outline: dark ? darkStroke : lightStroke,
    );
    final stroke = dark ? darkStroke : lightStroke;
    final radius = BorderRadius.circular(12);

    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: dark ? darkCanvas : lightCanvas,
      dividerColor: stroke,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: stroke),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? darkElevated : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? darkSurface : Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.error),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          dark ? darkElevated : const Color(0xFFF0F3F9),
        ),
        headingTextStyle: TextStyle(
          fontSize: 12,
          letterSpacing: .3,
          fontWeight: FontWeight.w800,
          color: colors.onSurfaceVariant,
        ),
        dataTextStyle: TextStyle(fontSize: 13, color: colors.onSurface),
        dividerThickness: .65,
        horizontalMargin: 18,
        columnSpacing: 22,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        preferBelow: true,
        textStyle: TextStyle(
          color: dark ? Colors.white : const Color(0xFF142133),
          fontSize: 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  /// Common responsive gutter. Workspaces retain their individual max widths.
  static EdgeInsets pagePadding({
    required double viewportWidth,
    required String route,
  }) {
    final narrow = viewportWidth < 680;
    final medium = viewportWidth < 1100;
    final gutter = narrow ? 12.0 : medium ? 20.0 : 28.0;
    return EdgeInsets.fromLTRB(
      gutter,
      route == 'trade' ? 18 : 24,
      gutter,
      narrow ? 36 : 52,
    );
  }
}

/// Reusable data-state component: do not transform missing observations to 0.
class TerminalEmptyState extends StatelessWidget {
  const TerminalEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.onRetry,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: colors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant)),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Header composition used as screens migrate to the shared design system.
class TerminalPageHeading extends StatelessWidget {
  const TerminalPageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.6,
              )),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.35)),
            ],
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
