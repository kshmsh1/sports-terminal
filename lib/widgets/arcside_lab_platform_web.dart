import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registered = <String>{};

Widget labFrame(String lab) {
  final kind = lab == 'python' ? 'python' : 'sheets';
  final viewType = 'arcside-independent-$kind';
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final frame = web.HTMLIFrameElement();
      frame.src = Uri.base.resolve('labs/$kind/index.html').toString();
      frame.style.width = '100%';
      frame.style.height = '100%';
      frame.style.border = '0';
      frame.setAttribute('title', kind == 'python'
          ? 'Arcside Python Lab' : 'Arcside Excel Workspace');
      frame.setAttribute('allow', 'clipboard-read; clipboard-write');
      return frame;
    });
  }
  return HtmlElementView(viewType: viewType);
}
