import 'package:flutter/material.dart';

class WebsiteNbaMediaFeedScreen extends StatelessWidget {
  const WebsiteNbaMediaFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Media Sources',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
            ),
            const Chip(
              avatar: Icon(Icons.inventory_2_outlined, size: 17),
              label: Text('Static directory'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'A reference directory of high-signal NBA reporting sources. Sports Terminal does not embed, poll, fetch, cache, or reproduce third-party social feeds at runtime.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 3
                : constraints.maxWidth >= 680
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final insider in _insiders)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                insider.initials,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    insider.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '@${insider.handle} · ${insider.outlet}',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Static-data policy: this directory is descriptive metadata only. Current posts, breaking news, live timelines, and other mutable third-party content are intentionally not fetched by the application.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
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
