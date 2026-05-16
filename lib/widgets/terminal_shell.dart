import 'package:flutter/material.dart';

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
              'NBA MVP Shell',
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
                  'Search players, teams, reports...',
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
        'Local mock data only. No paid APIs, no backend, no database.',
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
        return const _PlaceholderScreen(
          eyebrow: 'NBA PLAYER DATABASE',
          title: 'Players page coming next',
          body: 'This will become a sortable player table with scoring, efficiency, usage, minutes, health, contracts, and custom tags.',
        );
      case 2:
        return const _PlaceholderScreen(
          eyebrow: 'NBA TEAM DATABASE',
          title: 'Teams page coming next',
          body: 'This will become the team command center with records, ratings, roster context, schedule strength, and transaction history.',
        );
      case 3:
        return const _PlaceholderScreen(
          eyebrow: 'PLAYER COMPARISON',
          title: 'Comparison tool coming next',
          body: 'This will let us compare players side by side across box score production, efficiency, role, team context, and availability.',
        );
      default:
        return const _DashboardScreen();
    }
  }
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NBA Command Center',
          style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'A zero-cost MVP shell for building the Bloomberg Terminal of sports.',
          style: TextStyle(color: Color(0xFF9AA7B6), fontSize: 15),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 1.8 : 1.5,
              children: const [
                _MetricCard(label: 'Tracked Players', value: '6', detail: 'Mock player records'),
                _MetricCard(label: 'Tracked Teams', value: '6', detail: 'Mock team records'),
                _MetricCard(label: 'Data Cost', value: r'$0', detail: 'Static local data'),
                _MetricCard(label: 'Current Sport', value: 'NBA', detail: 'MVP focus area'),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _TerminalPanel(
          title: 'Build Priorities',
          lines: [
            '1. Replace Flutter starter app with a professional dashboard shell.',
            '2. Add static player and team data models.',
            '3. Build sortable tables for players and teams.',
            '4. Add a lightweight comparison workflow.',
            '5. Only then consider real data ingestion.',
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8794A5), fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(detail, style: const TextStyle(color: Color(0xFF8AB4F8), fontSize: 12)),
        ],
      ),
    );
  }
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: const TextStyle(color: Color(0xFFB6C0CC), height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.eyebrow, required this.title, required this.body});

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF263241)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: const TextStyle(color: Color(0xFF8AB4F8), fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(color: Color(0xFFB6C0CC), fontSize: 15, height: 1.45)),
        ],
      ),
    );
  }
}
