import 'package:flutter/material.dart';

import '../models/app_session.dart';
import 'product_trade_machine_v2_screen.dart';

/// Backward-compatible entrypoint for the NBA Trade Machine.
///
/// V2 owns a single document-flow workspace with two-to-five-team routing,
/// editable salaries, picks/exceptions/rights, CBA validation and portable share
/// payloads. The platform shell remains the only vertical page scroll.
class ProductTradeMachineScreen extends StatelessWidget {
  const ProductTradeMachineScreen({
    super.key,
    required this.session,
    required this.organizationMode,
  });

  final AppSession session;
  final bool organizationMode;

  @override
  Widget build(BuildContext context) => ProductTradeMachineV2Screen(
        session: session,
        organizationMode: organizationMode,
      );
}
