import 'package:flutter/material.dart';

import 'arcside_lab_platform_stub.dart'
    if (dart.library.js_interop) 'arcside_lab_platform_web.dart' as platform;

/// Self-contained research applications are loaded only when selected.
class ArcsideLabWebView extends StatefulWidget {
  const ArcsideLabWebView({super.key, required this.lab});

  final String lab;

  @override
  State<ArcsideLabWebView> createState() => _ArcsideLabWebViewState();
}

class _ArcsideLabWebViewState extends State<ArcsideLabWebView> {
  @override
  void initState() {
    super.initState();
    platform.registerLab(widget.lab);
  }

  @override
  Widget build(BuildContext context) {
    final python = widget.lab == 'python';
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
              TextButton.icon(
                onPressed: () => platform.openLab(widget.lab),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open full workspace'),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.82)
                .clamp(720.0, 1400.0),
            child: platform.labFrame(widget.lab),
          ),
        ),
      ],
    );
  }
}
