import 'package:flutter/material.dart';

import 'product_trade_machine_workbench_screen.dart';

/// Public implementation entry point retained for route and test compatibility.
///
/// The workbench screen owns the video-directed team picker, asset browser,
/// acquisition cards, multi-team routing and CBA validation experience.
class ProductTradeMachineCompleteScreen extends StatelessWidget {
  const ProductTradeMachineCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProductTradeMachineWorkbenchScreen();
  }
}
