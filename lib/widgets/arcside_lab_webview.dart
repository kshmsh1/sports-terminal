import 'package:flutter/material.dart';

import 'arcside_lab_platform_stub.dart'
    if (dart.library.js_interop) 'arcside_lab_platform_web.dart' as platform;

/// Self-contained research applications are loaded only when selected.
class ArcsideLabWebView extends StatelessWidget {
  const ArcsideLabWebView({super.key, required this.lab});

  final String lab;

  @override
  Widget build(BuildContext context) {
    final python = lab == 'python';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(python ? Icons.terminal_rounded : Icons.table_chart_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  python ? 'Python Lab' : 'Excel Workspace',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const Text('Independent browser workspace',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(height: 800, child: platform.labFrame(lab)),
        ),
      ],
    );
  }
}
