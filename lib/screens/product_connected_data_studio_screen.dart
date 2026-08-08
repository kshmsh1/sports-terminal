import 'package:flutter/material.dart';

import '../models/app_session.dart';
import 'product_python_lab_v2_screen.dart';

/// Backward-compatible entrypoint for the connected Data & Code Studio.
///
/// The v2 notebook keeps code and output in one vertical document flow so the
/// platform shell owns scrolling at every viewport width.
class ProductConnectedDataStudioScreen extends StatelessWidget {
  const ProductConnectedDataStudioScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) => ProductPythonLabV2Screen(session: session);
}
