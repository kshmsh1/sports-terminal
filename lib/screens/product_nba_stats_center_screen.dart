import 'package:flutter/material.dart';

import 'product_nba_basic_stats_screen.dart';

/// Primary user-facing NBA statistics page.
///
/// This surface is deliberately basic and participates in the platform shell's
/// single vertical document flow. The complete 187-metric workstation and deeper
/// research infrastructure live under Advanced Stats.
class ProductNbaStatsCenterScreen extends StatelessWidget {
  const ProductNbaStatsCenterScreen({super.key});

  @override
  Widget build(BuildContext context) => const ProductNbaBasicStatsScreen();
}
