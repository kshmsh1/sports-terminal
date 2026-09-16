import 'package:flutter/material.dart';

class NbaXTimeline extends StatelessWidget {
  const NbaXTimeline({
    super.key,
    required this.handle,
    required this.displayName,
    this.height = 720,
  });

  final String handle;
  final String displayName;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Card(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Live X timeline for @$handle is available in the Sports Terminal web build. $displayName remains in the insider watchlist on this platform.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
