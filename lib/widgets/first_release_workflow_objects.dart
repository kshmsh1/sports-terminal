import 'package:flutter/material.dart';

import 'first_release_route_engine.dart';
import 'first_release_route_outputs.dart';
import 'terminal_primitives.dart';

class FirstReleaseWorkflowObjects extends StatelessWidget {
  const FirstReleaseWorkflowObjects({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('First-Release Workflow Objects', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 10),
        Text('This panel consolidates the first working objects: selected Teams, selected Seasons, operations payloads, generated route outputs, report shells, saved-view previews, export manifests, alert previews, dashboard cards, search route objects, and Action Center payloads.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
      ])),
      SizedBox(height: 18),
      FirstReleaseRouteEngine(),
      SizedBox(height: 18),
      FirstReleaseRouteOutputs(),
    ]);
  }
}
