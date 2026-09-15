import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../widgets/nba_x_timeline_stub.dart'
    if (dart.library.js_interop) '../widgets/nba_x_timeline_web.dart';

class WebsiteNbaMediaFeedScreen extends StatefulWidget {
  const WebsiteNbaMediaFeedScreen({super.key});

  @override
  State<WebsiteNbaMediaFeedScreen> createState() =>
      _WebsiteNbaMediaFeedScreenState();
}

class _WebsiteNbaMediaFeedScreenState
    extends State<WebsiteNbaMediaFeedScreen> {
  String _selectedHandle = _insiders.first.handle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = _insiders.firstWhere(
      (item) => item.handle == _selectedHandle,
      orElse: () => _insiders.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Media Feed',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
            Chip(
              avatar: const Icon(Icons.bolt_rounded, size: 17),
              label: Text(kIsWeb ? 'Live X embed' : 'Web live-feed ready'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'A live NBA news desk centered on the league’s highest-signal reporters. Select an insider to switch the embedded X timeline without leaving Sports Terminal.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            final timeline = _TimelinePanel(insider: selected);
            final sources = _InsiderPanel(
              selectedHandle: _selectedHandle,
              onSelect: (handle) => setState(() => _selectedHandle = handle),
            );
            if (stacked) {
              return Column(
                children: [
                  sources,
                  const SizedBox(height: 14),
                  timeline,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: timeline),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: sources),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.insider});
  final _Insider insider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    insider.initials,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insider.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '@${insider.handle} · ${insider.outlet}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Chip(label: Text('X / Twitter')),
              ],
            ),
            const SizedBox(height: 14),
            NbaXTimeline(
              key: ValueKey(insider.handle),
              handle: insider.handle,
              displayName: insider.name,
              height: 760,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsiderPanel extends StatelessWidget {
  const _InsiderPanel({
    required this.selectedHandle,
    required this.onSelect,
  });

  final String selectedHandle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NBA insider watchlist',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Switch sources instantly. The embedded timeline itself is served by X and updates independently of the static Sports Terminal history corpus.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                for (final insider in _insiders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: selectedHandle == insider.handle
                          ? colors.primaryContainer.withValues(alpha: .55)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        selected: selectedHandle == insider.handle,
                        onTap: () => onSelect(insider.handle),
                        leading: CircleAvatar(child: Text(insider.initials)),
                        title: Text(
                          insider.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('@${insider.handle} · ${insider.outlet}'),
                        trailing: selectedHandle == insider.handle
                            ? const Icon(Icons.radio_button_checked_rounded)
                            : const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Feed policy',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(
                  'Sports Terminal does not copy, cache or fabricate posts. This page embeds the selected public X timeline in real time. If X blocks embeds, changes access policy or the user is offline, the feed can be unavailable even though the rest of the terminal continues to work.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Insider {
  const _Insider({
    required this.name,
    required this.handle,
    required this.outlet,
  });

  final String name;
  final String handle;
  final String outlet;

  String get initials {
    final parts = name.split(' ');
    if (parts.length < 2) return name.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

const _insiders = <_Insider>[
  _Insider(name: 'Shams Charania', handle: 'ShamsCharania', outlet: 'ESPN'),
  _Insider(name: 'Chris Haynes', handle: 'ChrisBHaynes', outlet: 'NBA insider'),
  _Insider(name: 'Marc Stein', handle: 'TheSteinLine', outlet: 'The Stein Line'),
  _Insider(name: 'Jake Fischer', handle: 'JakeLFischer', outlet: 'NBA insider'),
  _Insider(name: 'Bobby Marks', handle: 'BobbyMarks42', outlet: 'ESPN'),
  _Insider(name: 'Tim Bontemps', handle: 'TimBontemps', outlet: 'ESPN'),
  _Insider(name: 'Brian Windhorst', handle: 'WindhorstESPN', outlet: 'ESPN'),
  _Insider(name: 'Michael Scotto', handle: 'MikeAScotto', outlet: 'HoopsHype'),
];
