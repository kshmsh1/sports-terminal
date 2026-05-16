import 'package:flutter/material.dart';

import '../screens/compare_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/players_screen.dart';
import '../screens/teams_screen.dart';

class TerminalShell extends StatefulWidget {
  const TerminalShell({super.key});

  @override
  State<TerminalShell> createState() => _TerminalShellState();
}

class _TerminalShellState extends State<TerminalShell> {
  int selectedIndex = 0;

  final tabs = const [
    _TerminalTab(label: 'Dashboard', icon: Icons.dashboard_outlined),
    _TerminalTab(label: 'Players', icon: Icons.person_search_outlined),
    _TerminalTab(label: 'Teams', icon: Icons.groups_outlined),
    _TerminalTab(label: 'Compare', icon: Icons.compare_arrows_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Row(
        children: [
          Container(
            width: 248,
            decoration: const BoxDecoration(
              color: Color(0xFF111820),
              border: Border(right: BorderSide(color: Color(0xFF263241))),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 28),
                    for (var i = 0; i < tabs.length; i++)
                      _NavButton(
                        label: tabs[i].label,
                        icon: tabs[i].icon,
                        isSelected: selectedIndex == i,
                        onTap: () => setState(() => selectedIndex = i),
                      ),
                    const Spacer(),
                    const _SidebarFooter(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(title: tabs[selectedIndex].label),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _ScreenBody(index: selectedIndex),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalTab {
  const _TerminalTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF152235),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B3B52)),
          ),
          child: const Icon(Icons.sports_basketball, color: Color(0xFF8AB4F8)),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sports Terminal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'NBA Historical Build',
              style: TextStyle(color: Color(0xFF8794A5), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B2A3F) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF385A86) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF8AB4F8) : const Color(0xFF8794A5),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFB6C0CC),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1218),
        border: Border(bottom: BorderSide(color: Color(0xFF263241))),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            width: 340,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF121A23),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF263241)),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Color(0xFF8794A5), size: 18),
                SizedBox(width: 10),
                Text(
                  'Search players, teams, seasons, reports...',
                  style: TextStyle(color: Color(0xFF8794A5), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1218),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: const Text(
        'Historical-first. NBA-first. Real data only; blanks until sources are connected.',
        style: TextStyle(color: Color(0xFF8794A5), fontSize: 12, height: 1.35),
      ),
    );
  }
}

class _ScreenBody extends StatelessWidget {
  const _ScreenBody({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 1:
        return const PlayersScreen();
      case 2:
        return const TeamsScreen();
      case 3:
        return const CompareScreen();
      default:
        return const DashboardScreen();
    }
  }
}
