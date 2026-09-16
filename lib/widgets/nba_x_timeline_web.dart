import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class NbaXTimeline extends StatefulWidget {
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
  State<NbaXTimeline> createState() => _NbaXTimelineState();
}

class _NbaXTimelineState extends State<NbaXTimeline> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(covariant NbaXTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle) _register();
  }

  void _register() {
    final token = '${widget.handle}-${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'sports-terminal-x-$token';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final wrapper = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '${widget.height}px'
        ..style.overflow = 'auto'
        ..style.backgroundColor = 'transparent';

      final anchor = web.HTMLAnchorElement()
        ..href = 'https://twitter.com/${widget.handle}'
        ..className = 'twitter-timeline'
        ..textContent = 'Posts by ${widget.displayName}'
        ..setAttribute('data-theme', 'dark')
        ..setAttribute('data-chrome', 'nofooter')
        ..setAttribute('data-dnt', 'true');
      wrapper.append(anchor);

      final script = web.HTMLScriptElement()
        ..src = 'https://platform.twitter.com/widgets.js'
        ..async = true
        ..charset = 'utf-8';
      wrapper.append(script);
      return wrapper;
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        key: ValueKey(_viewType),
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: HtmlElementView(viewType: _viewType),
        ),
      );
}
