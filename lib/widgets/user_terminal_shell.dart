import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/excel_like_workspace_screen.dart';
import '../screens/product_nba_entity_hub_screen.dart';
import '../screens/product_shell_screens.dart';

const _lightBackground = Color(0xFFF6F8FC);
const _darkBackground = Color(0xFF08111F);
const _navy = Color(0xFF102A56);
const _navyDeep = Color(0xFF081A33);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);

class UserTerminalShell extends StatefulWidget {
  const UserTerminalShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<UserTerminalShell> createState() => _UserTerminalShellState();
}

class _UserTerminalShellState extends State<UserTerminalShell> {
  int selectedIndex = 0;
  bool darkMode = false;

  List<_UserTab> get tabs => [
        _UserTab('Home', Icons.home_rounded, ProductHomeScreen(session: widget.session), 'Product'),
        const _UserTab('NBA', Icons.sports_basketball_rounded, ProductNbaEntityHubScreen(), 'Product'),
        const _UserTab('Fantasy', Icons.bolt_rounded, ProductFantasyScreen(), 'Product'),
        const _UserTab('Community', Icons.forum_rounded, ProductCommunityScreen(), 'Product'),
        const _UserTab('Articles', Icons.article_rounded, ProductArticlesScreen(), 'Product'),
        const _UserTab('Workspace', Icons.grid_on_rounded, ProductWorkspaceHubScreen(workspace: ExcelLikeWorkspaceScreen()), 'Product'),
        const _UserTab('Messages', Icons.chat_bubble_rounded, ProductMessagesScreen(), 'Product'),
        _UserTab('Profile', Icons.person_rounded, ProductProfileScreen(session: widget.session), 'Product'),
        _UserTab('Admin', Icons.admin_panel_settings_rounded, ProductAdminConsoleScreen(session: widget.session), 'Operator'),
        const _UserTab('Internal Lab', Icons.science_rounded, ProductInternalLabScreen(), 'Operator'),
        const _UserTab('About Us', Icons.info_outline_rounded, ProductLegalScreen(kind: 'about'), 'Legal', showInPrimaryNav: false),
        const _UserTab('Contact', Icons.mail_outline_rounded, ProductLegalScreen(kind: 'contact'), 'Legal', showInPrimaryNav: false),
        const _UserTab('Privacy Policy', Icons.privacy_tip_outlined, ProductLegalScreen(kind: 'privacy'), 'Legal', showInPrimaryNav: false),
        const _UserTab('Terms & Conditions', Icons.description_outlined, ProductLegalScreen(kind: 'terms'), 'Legal', showInPrimaryNav: false),
      ];

  @override
  Widget build(BuildContext context) {
    final currentTabs = tabs;
    if (selectedIndex >= currentTabs.length) selectedIndex = 0;
    final selected = currentTabs[selectedIndex];
    final palette = _ShellPalette(darkMode);

    return Theme(
      data: ThemeData(
        brightness: darkMode ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: _navy, brightness: darkMode ? Brightness.dark : Brightness.light),
        useMaterial3: true,
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Scaffold(
          backgroundColor: palette.background,
          appBar: compact
              ? AppBar(
                  backgroundColor: palette.header,
                  foregroundColor: palette.text,
                  elevation: 0,
                  title: Row(children: [
                    CircleAvatar(radius: 17, backgroundColor: palette.logoBackground, child: const Icon(Icons.sports_basketball_rounded, color: _orange, size: 19)),
                    const SizedBox(width: 10),
                    const Text('Sports Terminal', style: TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                  actions: [
                    _ThemeToggleButton(darkMode: darkMode, onPressed: () => setState(() => darkMode = !darkMode)),
                    IconButton(tooltip: 'Sign out', onPressed: widget.onSignOut, icon: const Icon(Icons.logout_rounded)),
                  ],
                )
              : null,
          drawer: compact
              ? Drawer(
                  backgroundColor: palette.panel,
                  child: SafeArea(
                    child: _MobileNavigation(
                      tabs: currentTabs,
                      selectedIndex: selectedIndex,
                      palette: palette,
                      darkMode: darkMode,
                      onThemeToggle: () => setState(() => darkMode = !darkMode),
                      onSelected: (index) {
                        setState(() => selectedIndex = index);
                        Navigator.of(context).pop();
                      },
                      onSignOut: widget.onSignOut,
                    ),
                  ),
                )
              : null,
          body: Column(children: [
            if (!compact)
              _DesktopHeader(
                tabs: currentTabs,
                selectedIndex: selectedIndex,
                session: widget.session,
                palette: palette,
                darkMode: darkMode,
                onThemeToggle: () => setState(() => darkMode = !darkMode),
                onSelected: (index) => setState(() => selectedIndex = index),
                onSignOut: widget.onSignOut,
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1260),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 24, compact ? 16 : 24, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _PageLabel(tab: selected, palette: palette),
                        const SizedBox(height: 18),
                        selected.screen,
                        _Footer(
                          palette: palette,
                          onOpenAbout: () => _selectByLabel('About Us'),
                          onOpenContact: () => _selectByLabel('Contact'),
                          onOpenPrivacy: () => _selectByLabel('Privacy Policy'),
                          onOpenTerms: () => _selectByLabel('Terms & Conditions'),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _selectByLabel(String label) {
    final index = tabs.indexWhere((tab) => tab.label == label);
    if (index >= 0) setState(() => selectedIndex = index);
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.tabs, required this.selectedIndex, required this.session, required this.palette, required this.darkMode, required this.onThemeToggle, required this.onSelected, required this.onSignOut});

  final List<_UserTab> tabs;
  final int selectedIndex;
  final AppSession session;
  final _ShellPalette palette;
  final bool darkMode;
  final VoidCallback onThemeToggle;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final primaryItems = <({int index, _UserTab tab})>[
      for (var i = 0; i < tabs.length; i++)
        if (tabs[i].showInPrimaryNav) (index: i, tab: tabs[i]),
    ];

    return Container(
      decoration: BoxDecoration(color: palette.header, border: Border(bottom: BorderSide(color: palette.line))),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onSelected(0),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: palette.logoBackground, child: const Icon(Icons.sports_basketball_rounded, color: _orange)),
            const SizedBox(width: 10),
            Text('Sports Terminal', style: TextStyle(color: palette.text, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final item in primaryItems) ...[
                _NavChip(tab: item.tab, selected: item.index == selectedIndex, palette: palette, onTap: () => onSelected(item.index)),
                const SizedBox(width: 8),
              ],
            ]),
          ),
        ),
        const SizedBox(width: 14),
        _ThemeToggleButton(darkMode: darkMode, onPressed: onThemeToggle),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: palette.softPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.text, fontWeight: FontWeight.w900, fontSize: 12)),
            Text(session.role.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Sign out', onPressed: onSignOut, icon: Icon(Icons.logout_rounded, color: palette.muted)),
      ]),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.tabs, required this.selectedIndex, required this.palette, required this.darkMode, required this.onThemeToggle, required this.onSelected, required this.onSignOut});

  final List<_UserTab> tabs;
  final int selectedIndex;
  final _ShellPalette palette;
  final bool darkMode;
  final VoidCallback onThemeToggle;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: palette.logoBackground, child: const Icon(Icons.sports_basketball_rounded, color: _orange)),
          const SizedBox(width: 10),
          Expanded(child: Text('Sports Terminal', style: TextStyle(color: palette.text, fontWeight: FontWeight.w900, fontSize: 18))),
          _ThemeToggleButton(darkMode: darkMode, onPressed: onThemeToggle),
        ]),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            itemCount: tabs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              return _DrawerEntry(tab: tab, selected: index == selectedIndex, palette: palette, onTap: () => onSelected(index));
            },
          ),
        ),
        Divider(color: palette.line),
        _DrawerEntry(tab: const _UserTab('Sign out', Icons.logout_rounded, SizedBox.shrink(), 'Account'), selected: false, palette: palette, onTap: onSignOut),
      ]),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.darkMode, required this.onPressed});
  final bool darkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: darkMode ? 'Switch to light mode' : 'Switch to dark mode',
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: darkMode ? Colors.white : _navy,
          side: BorderSide(color: darkMode ? const Color(0xFF334155) : const Color(0xFFBFD0EA)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        ),
        icon: Icon(darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 17),
        label: Text(darkMode ? 'Dark' : 'Light', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.tab, required this.selected, required this.palette, required this.onTap});

  final _UserTab tab;
  final bool selected;
  final _ShellPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? palette.selected : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(children: [
            Icon(tab.icon, size: 17, color: selected ? Colors.white : palette.muted),
            const SizedBox(width: 7),
            Text(tab.label, style: TextStyle(color: selected ? Colors.white : palette.text, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _DrawerEntry extends StatelessWidget {
  const _DrawerEntry({required this.tab, required this.selected, required this.palette, required this.onTap});

  final _UserTab tab;
  final bool selected;
  final _ShellPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? palette.selectedSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(children: [
            Icon(tab.icon, color: selected ? palette.selected : palette.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(tab.label, style: TextStyle(color: selected ? palette.selected : palette.text, fontWeight: selected ? FontWeight.w900 : FontWeight.w700))),
            Text(tab.group, style: TextStyle(color: palette.muted, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _PageLabel extends StatelessWidget {
  const _PageLabel({required this.tab, required this.palette});
  final _UserTab tab;
  final _ShellPalette palette;

  @override
  Widget build(BuildContext context) {
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: palette.panel, border: Border.all(color: palette.line), borderRadius: BorderRadius.circular(999)), child: Text(tab.group, style: TextStyle(color: palette.selected, fontWeight: FontWeight.w900, fontSize: 12))),
      Text(tab.label, style: TextStyle(color: palette.pageTitle, fontSize: 26, fontWeight: FontWeight.w900)),
    ]);
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.palette, required this.onOpenAbout, required this.onOpenContact, required this.onOpenPrivacy, required this.onOpenTerms});

  final _ShellPalette palette;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenContact;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.line))),
      child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, children: [
        SizedBox(
          width: 420,
          child: Text('Sports Terminal is an NBA-first sports intelligence, fantasy, community, and workspace platform under active development.', style: TextStyle(color: palette.muted, height: 1.4)),
        ),
        Wrap(spacing: 10, runSpacing: 4, children: [
          TextButton(onPressed: onOpenAbout, child: const Text('About Us')),
          TextButton(onPressed: onOpenContact, child: const Text('Contact the Team')),
          TextButton(onPressed: onOpenPrivacy, child: const Text('Privacy Policy')),
          TextButton(onPressed: onOpenTerms, child: const Text('Terms & Conditions')),
        ]),
      ]),
    );
  }
}

class _ShellPalette {
  const _ShellPalette(this.darkMode);
  final bool darkMode;

  Color get background => darkMode ? _darkBackground : _lightBackground;
  Color get header => darkMode ? _navyDeep : Colors.white;
  Color get panel => darkMode ? const Color(0xFF0F1D33) : Colors.white;
  Color get softPanel => darkMode ? const Color(0xFF132642) : const Color(0xFFF8FAFC);
  Color get text => darkMode ? Colors.white : _ink;
  Color get pageTitle => darkMode ? Colors.white : _navy;
  Color get muted => darkMode ? const Color(0xFFB7C4D6) : _muted;
  Color get line => darkMode ? const Color(0xFF243B5C) : _line;
  Color get selected => darkMode ? _orange : _navy;
  Color get selectedSoft => darkMode ? const Color(0xFF2B2545) : const Color(0xFFEFF6FF);
  Color get logoBackground => darkMode ? const Color(0xFF1C2F4C) : const Color(0xFFFFF0E6);
}

class _UserTab {
  const _UserTab(this.label, this.icon, this.screen, this.group, {this.showInPrimaryNav = true});

  final String label;
  final IconData icon;
  final Widget screen;
  final String group;
  final bool showInPrimaryNav;
}
