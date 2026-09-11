import 'package:flutter/material.dart';

import 'product_trade_machine_live_screen.dart';

/// Public shell entry point for the Sports Terminal NBA Trade Machine.
///
/// The implementation lives in [ProductTradeMachineLiveScreen]. Keeping this
/// class name stable avoids breaking existing navigation while the underlying
/// trade machine can evolve independently.
class ProductTradeMachineScreen extends StatelessWidget {
  const ProductTradeMachineScreen({super.key});

  @override
  Widget build(BuildContext context) => const ProductTradeMachineLiveScreen();
}
