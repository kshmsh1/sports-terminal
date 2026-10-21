import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import 'sports_workspace_design.dart';

/// Task-oriented navigation outside the original horizontal feature bar.
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _collapseRail = false;

  WorkspaceNavItem get _active => widget.items.firstWhere(
    (item) => item.id == widget.selected,
    orElse: () => widget.items.first,
  );

  void _go(String id) {
    if (!widget.items.any((item) => item.id == id && item.enabled)) return;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    widget.onSelect(id);
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
      child: LayoutBuilder(builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final useRail = viewport >= 980;
        final collapsed = viewport < 1280 || _collapseRail;
        return Scaffold(
          key: _scaffoldKey,
          drawer: useRail ? null : Drawer(
            width: 290,
            child: SafeArea(
              child: _WorkspaceNavigation(
                items: widget.items,
                selected: widget.selected,
                condensed: false,
                onSelect: _go,
                onCollapse: null,
              ),
            ),
          ),
          body: SafeArea(
            child: Row(children: [
              if (useRail)
                SizedBox(
                  width: collapsed ? 76 : 252,
                  child: _WorkspaceNavigation(
                    items: widget.items,
                    selected: widget.selected,
                    condensed: collapsed,
                    onSelect: _go,
                    onCollapse: viewport < 1280
                        ? null : () => setState(
                          () => _collapseRail = !_collapseRail),
                  ),
                ),
              Expanded(
                child: Column(children: [
                  _WorkspaceTopbar(
                    active: _active,
                    compact: viewport < 690,
                    hasPersistentNav: useRail,
                    onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                    onCommand: _command,
                    onSearch: widget.onSearchPeople,
                    onTheme: widget.onTheme,
                    dark: widget.darkMode,
                    session: widget.session,
                    onSelect: _go,
                    onSignOut: widget.onSignOut,
                  ),
                  Expanded(child: widget.child),
                ]),
              ),
            ]),
          ),
        );
      }),
    ),
  );
}

const _navGroups = <String>[
  'Start',
  'Basketball',
  'Research & analysis',
  'Front office',
  'Community',
  'More',
];

class _WorkspaceNavigation extends StatelessWidget {
  const _WorkspaceNavigation({
    required this.items,
    required this.selected,
    required this.condensed,
    required this.onSelect,
    required this.onCollapse,
  });

  final List<WorkspaceNavItem> items;
  final String selected;
  final bool condensed;
  final ValueChanged<String> onSelect;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: SportsWorkspaceDesign.sidebar(dark),
        border: Border(right: BorderSide(color: colors.outline)),
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(condensed ? 14 : 18, 16, 10, 12),
          child: Row(children: [
            InkWell(
              onTap: () => onSelect('sports'),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                height: 42,
                width: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('ST',
                  style: TextStyle(color: colors.onPrimary,
                    fontSize: 14, fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
              ),
            ),
            if (!condensed) ...[
              const SizedBox(width: 10),
              Expanded(child: Text('SPORTS\nTERMINAL',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.05,
                  color: colors.onSurface,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w900,
                ))),
            ],
            if (onCollapse != null)
              IconButton(
                tooltip: condensed ? 'Expand sidebar' : 'Collapse sidebar',
                icon: Icon(condensed
                    ? Icons.keyboard_double_arrow_right_rounded
                    : Icons.keyboard_double_arrow_left_rounded),
                onPressed: onCollapse,
              ),
          ]),
        ),
        const Divider(height: 12),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
          children: [
            for (final group in _navGroups)
              if (items.any((item) => item.group == group)) ...[
                if (!condensed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 17, 8, 8),
                    child: WorkspaceSectionLabel(group),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                      color: colors.outline.withValues(alpha: .7),
                      height: 1),
                  ),
                for (final item in items)
                  if (item.group == group)
                    Tooltip(
                      message: condensed ? item.label : '',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Material(
                          color: selected == item.id
                              ? colors.primary.withValues(alpha: .13)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: item.enabled
                                ? () => onSelect(item.id) : null,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: condensed ? 0 : 13,
                                  vertical: 10),
                                child: Row(
                                  mainAxisAlignment: condensed
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                                  children: [
                                    Icon(item.icon, size: 20,
                                      color: !item.enabled
                                          ? colors.onSurfaceVariant
                                              .withValues(alpha: .45)
                                          : selected == item.id
                                            ? colors.primary
                                            : colors.onSurfaceVariant),
                                    if (!condensed) ...[
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: !item.enabled
                                              ? colors.onSurfaceVariant
                                                  .withValues(alpha: .55)
                                              : selected == item.id
                                                  ? colors.primary
                                                  : colors.onSurface,
                                          fontWeight: selected == item.id
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ))),
                                      if (!item.enabled)
                                        Icon(Icons.lock_outline_rounded,
                                          size: 14,
                                          color: colors.onSurfaceVariant),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
          ],
        )),
        if (!condensed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Historical data · Source-aware',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
              )),
          ),
      ]),
    );
  }
}

class _WorkspaceTopbar extends StatelessWidget {
  const _WorkspaceTopbar({
    required this.active,
    required this.compact,
    required this.hasPersistentNav,
    required this.onOpenDrawer,
    required this.onCommand,
    required this.onSearch,
    required this.onTheme,
    required this.dark,
    required this.session,
    required this.onSelect,
    required this.onSignOut,
  });

  final WorkspaceNavItem active;
  final bool compact;
  final bool hasPersistentNav;
  final VoidCallback onOpenDrawer;
  final VoidCallback onCommand;
  final VoidCallback onSearch;
  final VoidCallback onTheme;
  final bool dark;
  final AppSession session;
  final ValueChanged<String> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 66,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 20),
      child: Row(children: [
        if (!hasPersistentNav)
          IconButton(
            tooltip: 'Open navigation',
            onPressed: onOpenDrawer,
            icon: const Icon(Icons.menu_rounded),
          ),
        if (!compact) ...[
          Text(active.group.toUpperCase(),
            style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: colors.onSurfaceVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.chevron_right,
              size: 17, color: colors.onSurfaceVariant),
          ),
        ],
        Flexible(child: Text(active.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 15 : 17,
          ),
        )),
        const Spacer(),
        if (compact)
          IconButton(
            tooltip: 'Jump to workspace (Cmd/Ctrl + K)',
            onPressed: onCommand,
            icon: const Icon(Icons.grid_view_rounded),
          )
        else
          Tooltip(
            message: 'Jump to workspace (Cmd/Ctrl + K)',
            child: OutlinedButton.icon(
              onPressed: onCommand,
              icon: const Icon(Icons.grid_view_rounded, size: 17),
              label: const Text('Jump to workspace  ⌘K'),
            ),
          ),
        const SizedBox(width: 6),
        if (compact)
          IconButton(
            tooltip: 'Search players & teams',
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          )
        else
          TextButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Search players & teams'),
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
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary.withValues(alpha: .2),
              child: Text(_initials(session.displayName),
                style: TextStyle(
                  color: colors.primary, fontWeight: FontWeight.w900,
                  fontSize: 10)),
            ),
          ),
        ),
      ]),
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
