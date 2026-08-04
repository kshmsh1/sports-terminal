import 'package:flutter/material.dart';

import 'product_nba_stats_workstation_screen.dart';

class ProductNbaStatsCenterScreen extends StatelessWidget {
  const ProductNbaStatsCenterScreen({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1180) {
            return const ProductNbaStatsWorkstationScreen();
          }
          return const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1180,
              child: ProductNbaStatsWorkstationScreen(),
            ),
          );
        },
      );
}
