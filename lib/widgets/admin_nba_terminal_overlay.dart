import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../screens/product_nba_terminal_screen.dart';

class AdminNbaTerminalOverlay extends StatelessWidget {
  const AdminNbaTerminalOverlay({
    super.key,
    required this.session,
    required this.child,
  });

  final AppSession session;
  final Widget child;

  Future<void> _open(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFF06101B),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D1A28),
            foregroundColor: Colors.white,
            title: const Text('Sports Terminal · NBA'),
            leading: IconButton(
              tooltip: 'Close NBA Terminal',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: ProductNbaTerminalScreen(session: session),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          right: 18,
          bottom: 18,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'admin-nba-terminal',
              onPressed: () => _open(context),
              backgroundColor: const Color(0xFF071A33),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.terminal_rounded),
              label: const Text(
                'NBA Terminal',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
