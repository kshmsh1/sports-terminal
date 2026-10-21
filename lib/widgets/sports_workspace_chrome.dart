import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import 'sports_workspace_design.dart';

/// The application is organized by *task*, but navigation lives at the top.
/// Grouped menus retain every existing workspace and disabled destinations.
class WorkspaceNavItem {
  const WorkspaceNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
    this.enabled = true,
  });

  final String id;
  final String label;
  final String group;
  final IconData icon;
  final bool enabled;
}

const workspaceGroups = <String>[
  'Start',
  'Basketball',
  'Research & analysis',
  'Front office',
  'Community',
  'More',
];

class SportsWorkspaceChrome extends StatefulWidget {
  const SportsWorkspaceChrome({
    super.key,
    required this.session,
    required this.items,
    required this.selected,
    required this.darkMode,
    required this.onSelect,
    required this.onTheme,
    required this.onSearchPeople,
    required this.onSignOut,
    required this.child,
  });

  final AppSession session;
  final List<WorkspaceNavItem> items;
  final String selected;
  final bool darkMode;
  final ValueChanged<String> onSelect;
  final VoidCallback onTheme;
  final VoidCallback onSearchPeople;
  final VoidCallback onSignOut;
  final Widget child;

  @override
  State<SportsWorkspaceChrome> createState() => _SportsWorkspaceChromeState();
}

class _SportsWorkspaceChromeState extends State<SportsWorkspaceChrome> {
  WorkspaceNavItem get _active => widget.items.firstWhere(
    (item) => item.id == widget.selected, orElse: () => widget.items.first,
  );

  void _go(String id) {
    if (widget.items.any((item) => item.id == id && item.enabled)) {
      widget.onSelect(id);
    }
  }

  void _command() {
    showDialog<void>(
      context: context,
      builder: (_) => _WorkspaceCommandDialog(
        items: widget.items,
        activeId: widget.selected,
        onSelect: _go,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _command,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): _command,
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        body: SafeArea(child: Column(children: [
          _WorkspaceTopNavigation(
            session: widget.session,
            items: widget.items,
            selected: widget.selected,
            active: _active,
            dark: widget.darkMode,
            onSelect: _go,
            onCommand: _command,
            onSearch: widget.onSearchPeople,
            onTheme: widget.onTheme,
            onSignOut: widget.onSignOut,
          ),
          Expanded(child: widget.child),
        ])),
      ),
    ),
  );
}

class _WorkspaceTopNavigation extends StatelessWidget {
  const _WorkspaceTopNavigation({
    required this.session,
    required this.items,
    required this.selected,
    required this.active,
    required this.dark,
    required this.onSelect,
    required this.onCommand,
    required this.onSearch,
    required this.onTheme,
    required this.onSignOut,
  });

  final AppSession session;
  final List<WorkspaceNavItem> items;
  final String selected;
  final WorkspaceNavItem active;
  final bool dark;
  final ValueChanged<String> onSelect;
  final VoidCallback onCommand;
  final VoidCallback onSearch;
  final VoidCallback onTheme;
  final VoidCallback onSignOut;

  List<WorkspaceNavItem> group(String name) =>
      items.where((item) => item.group == name).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SportsWorkspaceDesign.sidebar(dark),
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final full = box.maxWidth >= 1350;
        final medium = box.maxWidth >= 820;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: medium ? 24 : 12),
          child: Row(children: [
            InkWell(
              onTap: () => onSelect('sports'),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 39, height: 39,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10)),
                    child: Text('ST', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      letterSpacing: -.6, color: colors.onPrimary)),
                  ),
                  if (box.maxWidth >= 550) ...[
                    const SizedBox(width: 10),
                    Text('Sports Terminal', style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900,
                      letterSpacing: -.4, color: colors.onSurface)),
                  ],
                ]),
              ),
            ),
            if (full) ...[
              const SizedBox(width: 30),
              _TopNavLink('Overview', 'sports',
                active: selected == 'sports', onSelect: onSelect),
              _TopNavMenu('NBA', group('Basketball'), selected, onSelect),
              _TopNavMenu('Analyze', group('Research & analysis'),
                selected, onSelect),
              _TopNavLink('Trade Machine', 'trade',
                active: selected == 'trade', onSelect: onSelect),
              _TopNavMenu('More', [
                ...group('Front office').where((item) => item.id != 'trade'),
                ...group('Community'), ...group('More'),
              ], selected, onSelect),
            ] else if (medium) ...[
              const SizedBox(width: 18),
              _TopNavLink('Overview', 'sports',
                active: selected == 'sports', onSelect: onSelect),
              _TopNavMenu('NBA', group('Basketball'), selected, onSelect),
              _TopNavMenu('Analyze', group('Research & analysis'),
                selected, onSelect),
              _TopNavMenu('More', [
                ...group('Front office'), ...group('Community'),
                ...group('More'),
              ], selected, onSelect),
            ] else ...[
              const SizedBox(width: 10),
              _CompactNavMenu(items: items, selected: selected,
                onSelect: onSelect),
            ],
            const Spacer(),
            if (box.maxWidth >= 1050)
              SizedBox(width: full ? 220 : 166, height: 40,
                child: OutlinedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded, size: 17),
                  label: Text(full ? 'Players & teams' : 'Search',
                    overflow: TextOverflow.ellipsis),
                ),
              )
            else
              IconButton(
                tooltip: 'Search players & teams',
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
            const SizedBox(width: 5),
            IconButton(
              tooltip: 'Jump to workspace (Cmd/Ctrl + K)',
              onPressed: onCommand,
              icon: const Icon(Icons.grid_view_rounded),
            ),
            IconButton(
              tooltip: dark ? 'Light mode' : 'Dark mode',
              onPressed: onTheme,
              icon: Icon(dark
                  ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: session.displayName,
              onSelected: (value) {
                if (value == 'profile') onSelect('profile');
                if (value == 'sign-out') onSignOut();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'profile', child: Text('Profile')),
                PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
              ],
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colors.primary.withValues(alpha: .18),
                child: Text(_initials(session.displayName),
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class _TopNavLink extends StatelessWidget {
  const _TopNavLink(this.label, this.route, {
    required this.active, required this.onSelect,
  });
  final String label;
  final String route;
  final bool active;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () => onSelect(route),
      style: TextButton.styleFrom(
        foregroundColor: active ? colors.primary : colors.onSurface,
      ),
      child: Text(label,
        style: TextStyle(fontWeight: active
            ? FontWeight.w900 : FontWeight.w650, fontSize: 13)),
    );
  }
}

class _TopNavMenu extends StatelessWidget {
  const _TopNavMenu(this.label, this.items, this.selected, this.onSelect);
  final String label;
  final List<WorkspaceNavItem> items;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = items.any((item) => item.id == selected);
    return PopupMenuButton<String>(
      tooltip: 'Open $label navigation',
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<String>(
            value: item.id,
            enabled: item.enabled,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              enabled: item.enabled,
              leading: Icon(item.icon, size: 20),
              title: Text(item.label),
              trailing: item.id == selected
                  ? Icon(Icons.check_rounded, color: colors.primary)
                  : !item.enabled ? const Icon(Icons.lock_outline, size: 16)
                    : null,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            color: active ? colors.primary : colors.onSurface,
            fontSize: 13, fontWeight: active
                ? FontWeight.w900 : FontWeight.w650)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
            size: 17, color: active ? colors.primary : colors.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _CompactNavMenu extends StatelessWidget {
  const _CompactNavMenu({
    required this.items, required this.selected, required this.onSelect,
  });
  final List<WorkspaceNavItem> items;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Navigation',
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final group in workspaceGroups)
          if (items.any((item) => item.group == group)) ...[
            PopupMenuItem<String>(
              enabled: false,
              child: Text(group.toUpperCase(),
                style: TextStyle(
                  color: color.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
            ),
            for (final item in items.where((item) => item.group == group))
              PopupMenuItem<String>(
                value: item.id, enabled: item.enabled,
                child: Row(children: [
                  Icon(item.icon, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item.label)),
                  if (item.id == selected)
                    Icon(Icons.check_rounded, color: color.primary, size: 18),
                ]),
              ),
          ],
      ],
      icon: const Icon(Icons.menu_rounded),
    );
  }
}

class _WorkspaceCommandDialog extends StatefulWidget {
  const _WorkspaceCommandDialog({
    required this.items,
    required this.activeId,
    required this.onSelect,
  });
  final List<WorkspaceNavItem> items;
  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  State<_WorkspaceCommandDialog> createState() =>
      _WorkspaceCommandDialogState();
}

class _WorkspaceCommandDialogState extends State<_WorkspaceCommandDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final query = _search.text.trim().toLowerCase();
    final filtered = widget.items.where((item) =>
      item.label.toLowerCase().contains(query) ||
      item.group.toLowerCase().contains(query)).toList(growable: false);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: (size.width - 32).clamp(0.0, 590.0).toDouble(),
        height: (size.height * .75).clamp(200.0, 650.0).toDouble(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.grid_view_rounded),
              const SizedBox(width: 10),
              const Expanded(child: Text('Jump to workspace',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search tools and workspaces',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('No matching workspaces.',
                      style: TextStyle(color: colors.onSurfaceVariant)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          leading: Icon(item.icon),
                          title: Text(item.label),
                          subtitle: Text(item.group),
                          enabled: item.enabled,
                          trailing: item.id == widget.activeId
                              ? Icon(Icons.check_circle_rounded,
                                  color: colors.primary)
                              : item.enabled
                                  ? const Icon(Icons.arrow_forward_rounded)
                                  : const Icon(Icons.lock_outline_rounded),
                          onTap: !item.enabled ? null : () {
                            Navigator.pop(context);
                            widget.onSelect(item.id);
                          },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty).take(2);
  final result = words.map((word) => word[0].toUpperCase()).join();
  return result.isEmpty ? 'ST' : result;
}
