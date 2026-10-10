import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Shared, responsive comparison workspace. Cards wrap at readable widths
/// instead of becoming unreachable inside an unlabelled horizontal carousel.
class ComparisonSelectionLayout extends StatelessWidget {
  const ComparisonSelectionLayout({
    super.key,
    required this.children,
    this.minimumCardWidth = 255,
    this.gap = 14,
  });

  final List<Widget> children;
  final double minimumCardWidth;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final columns = math.max(
            1,
            math.min(children.length,
                ((available + gap) / (minimumCardWidth + gap)).floor()),
          );
          final width = (available - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children)
                SizedBox(width: width, child: child),
            ],
          );
        },
      );
}

class ComparisonMetricPill extends StatelessWidget {
  const ComparisonMetricPill({
    super.key,
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: colors.surfaceContainerHighest.withValues(alpha: .32),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: .50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
              fontSize: 11, letterSpacing: .45, fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            )),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(
              color: accent ?? colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
          ],
        ),
      ),
    );
  }
}

class ComparisonEmptyState extends StatelessWidget {
  const ComparisonEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
                  const SizedBox(height: 5),
                  Text(message, style: TextStyle(color: colors.onSurfaceVariant)),
                  if (action != null) ...[
                    const SizedBox(height: 12),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Table width is derived from its own viewport, never from the browser width.
/// Two columns expand to the viewport; five remain scrollable where necessary.
class ComparisonTableViewport extends StatelessWidget {
  const ComparisonTableViewport({
    super.key,
    required this.participants,
    required this.builder,
  });
  final int participants;
  final Widget Function(double width) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(
            constraints.maxWidth - 32,
            155.0 + participants * 165.0,
          );
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: SizedBox(width: width, child: builder(width)),
              ),
            ),
          );
        },
      );
}
