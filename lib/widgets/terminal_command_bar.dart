import 'package:flutter/material.dart';

import '../design/terminal_design_system.dart';
import '../models/terminal_action.dart';
import '../services/terminal_command_engine.dart';

export '../services/terminal_command_engine.dart'
    show TerminalCommandEntry, TerminalCommandResult;

class TerminalCommandBar extends StatefulWidget {
  const TerminalCommandBar({
    super.key,
    required this.entries,
    required this.onResult,
    this.actions = const [],
  });

  final List<TerminalCommandEntry> entries;
  final ValueChanged<TerminalCommandResult> onResult;
  final List<TerminalAction> actions;

  @override
  State<TerminalCommandBar> createState() => _TerminalCommandBarState();
}

class _TerminalCommandBarState extends State<TerminalCommandBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _engine = const TerminalCommandEngine();
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final result = _engine.interpret(raw, widget.entries);
    widget.onResult(result);
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = TerminalDesignTokens.of(context);
    final suggestions = _engine.search(_controller.text, widget.entries, limit: 8);
    return Material(
      color: tokens.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: EdgeInsets.symmetric(horizontal: tokens.space3, vertical: tokens.space2),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.line))),
            child: Row(
              children: [
                Text('ST', style: tokens.sectionStyle.copyWith(color: tokens.accent, fontSize: 16)),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onTap: () => setState(() => _expanded = true),
                    onChanged: (_) => setState(() => _expanded = true),
                    onSubmitted: _submit,
                    style: tokens.bodyStyle,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search / Ask / Command — LeBron James, GAME BOS@NYK, COMPARE Jokic, QUERY guards PPG > 25',
                      hintStyle: tokens.captionStyle,
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: IconButton(
                        tooltip: 'Run command',
                        onPressed: () => _submit(_controller.text),
                        icon: const Icon(Icons.keyboard_return_rounded, size: 18),
                      ),
                      filled: true,
                      fillColor: tokens.canvas,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: tokens.line),
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: tokens.line),
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      ),
                    ),
                  ),
                ),
                if (widget.actions.isNotEmpty) ...[
                  SizedBox(width: tokens.space2),
                  PopupMenuButton<TerminalAction>(
                    tooltip: 'Terminal actions',
                    onSelected: (action) => widget.onResult(
                      TerminalCommandResult(
                        raw: action.label,
                        mode: 'operation',
                        operation: action.label,
                        action: action,
                      ),
                    ),
                    itemBuilder: (_) => [
                      for (final action in widget.actions)
                        PopupMenuItem(
                          value: action,
                          enabled: action.enabled,
                          child: Text(action.label),
                        ),
                    ],
                    icon: const Icon(Icons.bolt_rounded),
                  ),
                ],
              ],
            ),
          ),
          if (_expanded && suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: tokens.canvas,
                border: Border(bottom: BorderSide(color: tokens.line)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final item = suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(item.label, style: tokens.bodyStyle),
                    subtitle: item.subtitle.isEmpty ? null : Text(item.subtitle, style: tokens.captionStyle),
                    leading: Text(item.kind.toUpperCase(), style: tokens.captionStyle.copyWith(color: tokens.accent)),
                    onTap: () {
                      _controller.text = item.label;
                      widget.onResult(TerminalCommandResult(
                        raw: item.label,
                        mode: 'entity',
                        query: item.label,
                        entry: item,
                      ));
                      setState(() => _expanded = false);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
