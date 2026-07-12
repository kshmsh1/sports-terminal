import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/excel_like_workspace_screen.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_arena_home_screen.dart';
import '../screens/product_backend_sync_screen.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_fantasy_community_screens.dart';
import '../screens/product_front_office_scenario_screen.dart';
import '../screens/product_nba_entity_hub_screen.dart';
import '../screens/product_nba_stats_center_screen.dart';
import '../screens/product_profile_persisted_screen.dart';
import '../screens/product_python_dev_lab_screen.dart';
import '../screens/product_shell_screens.dart';
import '../screens/product_strategy_map_screen.dart';
import '../screens/product_team_blogs_screen.dart';
import '../screens/product_trade_machine_screen.dart';
import '../services/product_local_store.dart';

const _lightBackground = Color(0xFFF5F7FB);
const _darkBackground = Color(0xFF07111F);
const _navy = Color(0xFF102A56);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _lime = Color(0xFF8BEA7A);

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
  final ProductLocalStore localStore = const ProductLocalStore();
  int selectedIndex = 0;
  bool darkMode = false;

  List<_UserTab> get tabs => [
        _UserTab('Home', Icons.home_rounded, ProductArenaHomeScreen(session: widget.session), 'Product'),
        const _UserTab('Stats', Icons.leaderboard_rounded, ProductNbaStatsCenterScreen(), 'NBA'),
        const _UserTab('NBA', Icons.sports_basketball_rounded, ProductNbaEntityHubScreen(), 'NBA'),
        const _UserTab('Trade Machine', Icons.swap_horiz_rounded, ProductTradeMachineScreen(), 'Front Office'),
        const _UserTab('Advanced', Icons.analytics_rounded, ProductAdvancedNbaToolsScreen(), 'NBA'),
        const _UserTab('Front Office', Icons.account_tree_rounded, ProductFrontOfficeScenarioScreen(), 'Front Office'),
        const _UserTab('Strategy', Icons.radar_rounded, ProductStrategyMapScreen(), 'Product'),
        const _UserTab('Fantasy', Icons.bolt_rounded, ProductFantasyWarRoomScreen(), 'Product'),
        const _UserTab('Team Blogs', Icons.newspaper_rounded, ProductTeamBlogsScreen(), 'Content'),
        const _UserTab('Community', Icons.forum_rounded, ProductCommunityArenaScreen(), 'Product'),
        const _UserTab('Articles', Icons.article_rounded, ProductArticlesArenaScreen(), 'Content'),
        const _UserTab('Workspace', Icons.grid_on_rounded, ProductWorkspaceHubScreen(workspace: ExcelLikeWorkspaceScreen()), 'Tools'),
        const _UserTab('Python Lab', Icons.code_rounded, ProductPythonDevLabScreen(), 'Tools'),
        const _UserTab('Messages', Icons.chat_bubble_rounded, ProductMessagesArenaScreen(), 'Product'),
        _UserTab('Profile', Icons.person_rounded, ProductPersistedProfileScreen(session: widget.session), 'Product'),
        _UserTab('Admin', Icons.admin_panel_settings_rounded, ProductAdminOpsCenterScreen(session: widget.session), 'Operator'),
        _UserTab('Backend', Icons.cloud_sync_rounded, ProductBackendSyncScreen(session: widget.session), 'Operator', showInPrimaryNav: false),
        const _UserTab('Internal Lab', Icons.science_rounded, ProductInternalLabScreen(), 'Operator', showInPrimaryNav: false),
        const _UserTab('About Us', Icons.info_outline_rounded, ProductLegalScreen(kind: 'about'), 'Legal', showInPrimaryNav: false),
        const _UserTab('Contact', Icons.mail_outline_rounded, ProductLegalScreen(kind: 'contact'), 'Legal', showInPrimaryNav: false),
        const _UserTab('Privacy Policy', Icons.privacy_tip_outlined, ProductLegalScreen(kind: 'privacy'), 'Legal', showInPrimaryNav: false),
        const _UserTab('Terms & Conditions', Icons.description_outlined, ProductLegalScreen(kind: 'terms'), 'Legal', showInPrimaryNav: false),
      ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final savedDarkMode = await localStore.loadBool(ProductLocalStore.darkModeKey);
    if (mounted) setState(() => darkMode = savedDarkMode);
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => darkMode = value);
    await localStore.saveBool(ProductLocalStore.darkModeKey, value);
  }

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
        final compact = constraints.maxWidth < 920;
        return Scaffold(
          backgroundColor: palette.background,
          appBar: compact
              ? AppBar(
                  backgroundColor: palette.header,
                  foregroundColor: palette.text,
                  elevation: 0,
                  title: Row(children: const [_LogoMark(size: 34), SizedBox(width: 10), Text('Sports Terminal', style: TextStyle(fontWeight: FontWeight.w900))]),
                  actions: [_ThemeToggleButton(darkMode: darkMode, onPressed: () => _setDarkMode(!darkMode)), IconButton(tooltip: 'Sign out', onPressed: widget.onSignOut, icon: const Icon(Icons.logout_rounded))],
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
                      onThemeToggle: () => _setDarkMode(!darkMode),
                      onSelected: (index) {
                        setState(() => selectedIndex = index);
                        Navigator.of(context).pop();
                      },
                      onSignOut: widget.onSignOut,
                    ),
                  ),
                )
              : null,
          body: _AppBackdrop(
            palette: palette,
            child: Column(children: [
              if (!compact)
                _DesktopHeader(
                  tabs: currentTabs,
                  selectedIndex: selectedIndex,
                  session: widget.session,
                  palette: palette,
                  darkMode: darkMode,
                  onThemeToggle: () => _setDarkMode(!darkMode),
                  onSelected: (index) => setState(() => selectedIndex = index),
                  onSignOut: widget.onSignOut,
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(compact ? 16 : 24, compact ? 18 : 24, compact ? 16 : 24, 0),
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
          ),
        );
      }),
    );
  }

  void _selectByLabel(String label) {
    final index = tabs.indexWhere((tab) => tab.label == label);
    if (index >= 0) setState(() => selectedIndex = index);
  }
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop({required this.palette, required this.child});
  final _ShellPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: palette.backdropColors)),
        child: Stack(children: [
          Positioned(right: -110, top: 80, child: _BackdropOrb(size: 260, color: palette.orbOne)),
          Positioned(left: -140, bottom: -120, child: _BackdropOrb(size: 320, color: palette.orbTwo)),
          Positioned(right: 260, bottom: 90, child: _BackdropOrb(size: 90, color: palette.orbThree)),
          child,
        ]),
      );
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)));
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
    final primaryItems = <({int index, _UserTab tab})>[for (var i = 0; i < tabs.length; i++) if (tabs[i].showInPrimaryNav) (index: i, tab: tabs[i])];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(color: palette.header.withOpacity(darkMode ? 0.78 : 0.92), borderRadius: BorderRadius.circular(28), border: Border.all(color: palette.line), boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 30, offset: const Offset(0, 14))]),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onSelected(0),
          child: Row(children: [
            const _LogoMark(size: 42),
            const SizedBox(width: 11),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sports Terminal', style: TextStyle(color: palette.text, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.2)), Text('NBA-first intelligence platform', style: TextStyle(color: palette.muted, fontSize: 11, fontWeight: FontWeight.w700))]),
          ]),
        ),
        const SizedBox(width: 22),
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final item in primaryItems) ...[_NavChip(tab: item.tab, selected: item.index == selectedIndex, palette: palette, onTap: () => onSelected(item.index)), const SizedBox(width: 8)]]))),
        const SizedBox(width: 14),
        _CommandSearchPill(palette: palette),
        const SizedBox(width: 10),
        _ThemeToggleButton(darkMode: darkMode, onPressed: onThemeToggle),
        const SizedBox(width: 8),
        _UserBadge(session: session, palette: palette),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Sign out', onPressed: onSignOut, icon: Icon(Icons.logout_rounded, color: palette.muted)),
      ]),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_orange, _blue]), borderRadius: BorderRadius.circular(size * 0.38), boxShadow: const [BoxShadow(color: Color(0x33FF7A1A), blurRadius: 18, offset: Offset(0, 8))]), child: const Icon(Icons.sports_basketball_rounded, color: Colors.white));
}

class _CommandSearchPill extends StatelessWidget {
  const _CommandSearchPill({required this.palette});
  final _ShellPalette palette;

  @override
  Widget build(BuildContext context) => Container(constraints: const BoxConstraints(maxWidth: 230), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: palette.softPanel, borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.line)), child: Row(children: [Icon(Icons.search_rounded, color: palette.muted, size: 17), const SizedBox(width: 7), Expanded(child: Text('Search players, tools...', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700, fontSize: 12)))]));
}

class _UserBadge extends StatelessWidget {
  const _UserBadge({required this.session, required this.palette});
  final AppSession session;
  final _ShellPalette palette;

  @override
  Widget build(BuildContext context) => Container(constraints: const BoxConstraints(maxWidth: 240), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: palette.softPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.line)), child: Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 15, backgroundColor: palette.logoBackground, child: Text(session.displayName.isEmpty ? 'U' : session.displayName[0].toUpperCase(), style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 12))), const SizedBox(width: 8), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(session.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.text, fontWeight: FontWeight.w900, fontSize: 12)), Text(session.role.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 11))]))]));
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const _LogoMark(size: 40), const SizedBox(width: 10), Expanded(child: Text('Sports Terminal', style: TextStyle(color: palette.text, fontWeight: FontWeight.w900, fontSize: 18))), _ThemeToggleButton(darkMode: darkMode, onPressed: onThemeToggle)]),
          const SizedBox(height: 18),
          Expanded(child: ListView.separated(itemCount: tabs.length, separatorBuilder: (context, index) => const SizedBox(height: 6), itemBuilder: (context, index) => _DrawerEntry(tab: tabs[index], selected: index == selectedIndex, palette: palette, onTap: () => onSelected(index)))),
          Divider(color: palette.line),
          _DrawerEntry(tab: const _UserTab('Sign out', Icons.logout_rounded, SizedBox.shrink(), 'Account'), selected: false, palette: palette, onTap: onSignOut),
        ]),
      );
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.darkMode, required this.onPressed});
  final bool darkMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(message: darkMode ? 'Switch to light mode' : 'Switch to dark mode', child: OutlinedButton.icon(onPressed: onPressed, style: OutlinedButton.styleFrom(foregroundColor: darkMode ? Colors.white : _navy, side: BorderSide(color: darkMode ? const Color(0xFF334155) : const Color(0xFFBFD0EA)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), backgroundColor: darkMode ? const Color(0x331E293B) : const Color(0xFFF8FAFC)), icon: Icon(darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 17), label: Text(darkMode ? 'Dark' : 'Light', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))));
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.tab, required this.selected, required this.palette, required this.onTap});
  final _UserTab tab;
  final bool selected;
  final _ShellPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(color: selected ? palette.selected : Colors.transparent, borderRadius: BorderRadius.circular(999), child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? Colors.transparent : palette.line.withOpacity(0.75))), child: Row(children: [Icon(tab.icon, size: 17, color: selected ? Colors.white : palette.muted), const SizedBox(width: 7), Text(tab.label, style: TextStyle(color: selected ? Colors.white : palette.text, fontWeight: selected ? FontWeight.w900 : FontWeight.w700, fontSize: 13))]))));
}

class _DrawerEntry extends StatelessWidget {
  const _DrawerEntry({required this.tab, required this.selected, required this.palette, required this.onTap});
  final _UserTab tab;
  final bool selected;
  final _ShellPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(color: selected ? palette.selectedSoft : Colors.transparent, borderRadius: BorderRadius.circular(16), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Row(children: [Icon(tab.icon, color: selected ? palette.selected : palette.muted, size: 20), const SizedBox(width: 12), Expanded(child: Text(tab.label, style: TextStyle(color: selected ? palette.selected : palette.text, fontWeight: selected ? FontWeight.w900 : FontWeight.w700))), Text(tab.group, style: TextStyle(color: palette.muted, fontSize: 10, fontWeight: FontWeight.w700))]))));
}

class _PageLabel extends StatelessWidget {
  const _PageLabel({required this.tab, required this.palette});
  final _UserTab tab;
  final _ShellPalette palette;

  @override
  Widget build(BuildContext context) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: palette.panel.withOpacity(0.86), border: Border.all(color: palette.line), borderRadius: BorderRadius.circular(999)), child: Text(tab.group, style: TextStyle(color: palette.selected, fontWeight: FontWeight.w900, fontSize: 12))), Text(tab.label, style: TextStyle(color: palette.pageTitle, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: palette.livePill, borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.line)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.circle, color: _lime, size: 9), const SizedBox(width: 7), Text('Product mode', style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w800))]))]);
}

class _Footer extends StatelessWidget {
  const _Footer({required this.palette, required this.onOpenAbout, required this.onOpenContact, required this.onOpenPrivacy, required this.onOpenTerms});
  final _ShellPalette palette;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenContact;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 24), padding: const EdgeInsets.symmetric(vertical: 24), decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.line))), child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, children: [SizedBox(width: 480, child: Text('Sports Terminal is an NBA-first sports intelligence, fantasy, community, workspace, trade, and development platform under active development.', style: TextStyle(color: palette.muted, height: 1.4, fontWeight: FontWeight.w600))), Wrap(spacing: 10, runSpacing: 4, children: [TextButton(onPressed: onOpenAbout, child: const Text('About Us')), TextButton(onPressed: onOpenContact, child: const Text('Contact the Team')), TextButton(onPressed: onOpenPrivacy, child: const Text('Privacy Policy')), TextButton(onPressed: onOpenTerms, child: const Text('Terms & Conditions'))])]);
}

class _ShellPalette {
  const _ShellPalette(this.darkMode);
  final bool darkMode;
  Color get background => darkMode ? _darkBackground : _lightBackground;
  Color get header => darkMode ? const Color(0xDD06162B) : Colors.white;
  Color get panel => darkMode ? const Color(0xFF0F1D33) : Colors.white;
  Color get softPanel => darkMode ? const Color(0xFF132642) : const Color(0xFFF8FAFC);
  Color get text => darkMode ? Colors.white : _ink;
  Color get pageTitle => darkMode ? Colors.white : _navy;
  Color get muted => darkMode ? const Color(0xFFB7C4D6) : _muted;
  Color get line => darkMode ? const Color(0xFF243B5C) : _line;
  Color get selected => darkMode ? _orange : _navy;
  Color get selectedSoft => darkMode ? const Color(0xFF2B2545) : const Color(0xFFEFF6FF);
  Color get logoBackground => darkMode ? const Color(0xFF1C2F4C) : const Color(0xFFFFF0E6);
  Color get livePill => darkMode ? const Color(0xFF10233F) : Colors.white;
  Color get shadow => darkMode ? const Color(0x44000000) : const Color(0x16071A33);
  Color get orbOne => darkMode ? _orange.withOpacity(0.08) : _orange.withOpacity(0.12);
  Color get orbTwo => darkMode ? _blue.withOpacity(0.09) : _blue.withOpacity(0.10);
  Color get orbThree => darkMode ? _lime.withOpacity(0.06) : _lime.withOpacity(0.10);
  List<Color> get backdropColors => darkMode ? const [Color(0xFF07111F), Color(0xFF0C1E37), Color(0xFF07111F)] : const [Color(0xFFF8FBFF), Color(0xFFEFF6FF), Color(0xFFFFF7ED)];
}

class _UserTab {
  const _UserTab(this.label, this.icon, this.screen, this.group, {this.showInPrimaryNav = true});
  final String label;
  final IconData icon;
  final Widget screen;
  final String group;
  final bool showInPrimaryNav;
}
