import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/internal_spreadsheet_screen.dart';
import '../screens/product_shell_screens.dart';

const _pageBackground = Color(0xFFF6F8FC);
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

  List<_UserTab> get tabs => [
        _UserTab('Home', Icons.home_rounded, ProductHomeScreen(session: widget.session), 'Product'),
        const _UserTab('NBA', Icons.sports_basketball_rounded, ProductNbaHubScreen(), 'Product'),
        const _UserTab('Fantasy', Icons.bolt_rounded, ProductFantasyScreen(), 'Product'),
        const _UserTab('Community', Icons.forum_rounded, ProductCommunityScreen(), 'Product'),
        const _UserTab('Articles', Icons.article_rounded, ProductArticlesScreen(), 'Product'),
        _UserTab(
          'Workspace',
          Icons.grid_on_rounded,
          ProductWorkspaceHubScreen(
            workspace: InternalSpreadsheetScreen(
              session: widget.session,
              workspaceController: widget.workspaceController,
            ),
          ),
          'Product',
        ),
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

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      return Scaffold(
        backgroundColor: _pageBackground,
        appBar: compact
            ? AppBar(
                backgroundColor: Colors.white,
                foregroundColor: _ink,
                elevation: 0,
                title: Row(children: const [
                  Icon(Icons.sports_basketball_rounded, color: _orange),
                  SizedBox(width: 10),
                  Text('Sports Terminal', style: TextStyle(fontWeight: FontWeight.w900)),
                ]),
                actions: [IconButton(tooltip: 'Sign out', onPressed: widget.onSignOut, icon: const Icon(Icons.logout_rounded))],
              )
            : null,
        drawer: compact
            ? Drawer(
                backgroundColor: Colors.white,
                child: SafeArea(
                  child: _MobileNavigation(
                    tabs: currentTabs,
                    selectedIndex: selectedIndex,
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
                      _PageLabel(tab: selected),
                      const SizedBox(height: 18),
                      selected.screen,
                      _Footer(
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
    });
  }

  void _selectByLabel(String label) {
    final index = tabs.indexWhere((tab) => tab.label == label);
    if (index >= 0) setState(() => selectedIndex = index);
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.tabs, required this.selectedIndex, required this.session, required this.onSelected, required this.onSignOut});

  final List<_UserTab> tabs;
  final int selectedIndex;
  final AppSession session;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final primaryItems = <({int index, _UserTab tab})>[
      for (var i = 0; i < tabs.length; i++)
        if (tabs[i].showInPrimaryNav) (index: i, tab: tabs[i]),
    ];

    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _line))),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onSelected(0),
          child: Row(children: const [
            CircleAvatar(radius: 20, backgroundColor: Color(0xFFFFF0E6), child: Icon(Icons.sports_basketball_rounded, color: _orange)),
            SizedBox(width: 10),
            Text('Sports Terminal', style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final item in primaryItems) ...[
                _NavChip(tab: item.tab, selected: item.index == selectedIndex, onTap: () => onSelected(item.index)),
                const SizedBox(width: 8),
              ],
            ]),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          constraints: const BoxConstraints(maxWidth: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 12)),
            Text(session.role.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Sign out', onPressed: onSignOut, icon: const Icon(Icons.logout_rounded, color: _muted)),
      ]),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.tabs, required this.selectedIndex, required this.onSelected, required this.onSignOut});

  final List<_UserTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          CircleAvatar(radius: 20, backgroundColor: Color(0xFFFFF0E6), child: Icon(Icons.sports_basketball_rounded, color: _orange)),
          SizedBox(width: 10),
          Expanded(child: Text('Sports Terminal', style: TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18))),
        ]),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            itemCount: tabs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              return _DrawerEntry(tab: tab, selected: index == selectedIndex, onTap: () => onSelected(index));
            },
          ),
        ),
        const Divider(color: _line),
        _DrawerEntry(tab: const _UserTab('Sign out', Icons.logout_rounded, SizedBox.shrink(), 'Account'), selected: false, onTap: onSignOut),
      ]),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.tab, required this.selected, required this.onTap});

  final _UserTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _blue : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(children: [
            Icon(tab.icon, size: 17, color: selected ? Colors.white : _muted),
            const SizedBox(width: 7),
            Text(tab.label, style: TextStyle(color: selected ? Colors.white : _ink, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _DrawerEntry extends StatelessWidget {
  const _DrawerEntry({required this.tab, required this.selected, required this.onTap});

  final _UserTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(children: [
            Icon(tab.icon, color: selected ? _blue : _muted, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(tab.label, style: TextStyle(color: selected ? _blue : _ink, fontWeight: selected ? FontWeight.w900 : FontWeight.w700))),
            Text(tab.group, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _PageLabel extends StatelessWidget {
  const _PageLabel({required this.tab});
  final _UserTab tab;

  @override
  Widget build(BuildContext context) {
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(999)), child: Text(tab.group, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 12))),
      Text(tab.label, style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w900)),
    ]);
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onOpenAbout, required this.onOpenContact, required this.onOpenPrivacy, required this.onOpenTerms});

  final VoidCallback onOpenAbout;
  final VoidCallback onOpenContact;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
      child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, children: [
        const SizedBox(
          width: 420,
          child: Text('Sports Terminal is an NBA-first sports intelligence, fantasy, community, and workspace platform under active development.', style: TextStyle(color: _muted, height: 1.4)),
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

class _UserTab {
  const _UserTab(this.label, this.icon, this.screen, this.group, {this.showInPrimaryNav = true});

  final String label;
  final IconData icon;
  final Widget screen;
  final String group;
  final bool showInPrimaryNav;
}
