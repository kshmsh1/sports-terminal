import 'package:flutter/material.dart';

import '../services/nba_player_career_comparison_state_store.dart';
import 'nba_player_career_comparison_navigation.dart';

Future<void> showNbaPlayerCareerComparisonHistory(
  BuildContext context, {
  String league = 'NBA',
  String playerKey = '',
  NbaPlayerCareerComparisonStateStore store =
      const NbaPlayerCareerComparisonStateStore(),
  void Function(String playerKey, String playerName)? onOpenPlayer,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ComparisonHistoryDialog(
      league: league,
      playerKey: playerKey,
      store: store,
      onOpenPlayer: onOpenPlayer,
    ),
  );
}

class _ComparisonHistoryDialog extends StatefulWidget {
  const _ComparisonHistoryDialog({
    required this.league,
    required this.playerKey,
    required this.store,
    this.onOpenPlayer,
  });

  final String league;
  final String playerKey;
  final NbaPlayerCareerComparisonStateStore store;
  final void Function(String playerKey, String playerName)? onOpenPlayer;

  @override
  State<_ComparisonHistoryDialog> createState() => _ComparisonHistoryDialogState();
}

class _ComparisonHistoryDialogState extends State<_ComparisonHistoryDialog> {
  late Future<NbaPlayerCareerComparisonState> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.load();
  }

  List<NbaPlayerCareerComparisonStateItem> _filter(
    List<NbaPlayerCareerComparisonStateItem> source,
  ) {
    final key = widget.playerKey.trim();
    if (key.isEmpty) return source;
    return source
        .where(
          (item) =>
              item.leftPlayerKey == key || item.rightPlayerKey == key,
        )
        .toList();
  }

  Future<void> _open(NbaPlayerCareerComparisonStateItem item) async {
    Navigator.of(context).pop();
    await openNbaPlayerCareerComparisonPage(
      context,
      leftPlayerKey: item.leftPlayerKey,
      leftPlayerName: item.leftPlayerName,
      rightPlayerKey: item.rightPlayerKey,
      rightPlayerName: item.rightPlayerName,
      league: widget.league,
      initialSeasonType: item.seasonType,
      initialAlignment: item.alignment,
      initialMetric: item.metric,
      onOpenPlayer: widget.onOpenPlayer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F151C),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'CAREER COMPARISON HISTORY',
                      style: TextStyle(
                        color: Color(0xFFE2B866),
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.playerKey.trim().isEmpty
                    ? 'Saved and recent canonical Player Career comparisons.'
                    : 'Saved and recent comparisons involving this canonical Player.',
                style: const TextStyle(
                  color: Color(0xFF8895A5),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<NbaPlayerCareerComparisonState>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final state = snapshot.data ??
                        const NbaPlayerCareerComparisonState();
                    final saved = _filter(state.saved);
                    final recent = _filter(state.recents);
                    if (saved.isEmpty && recent.isEmpty) {
                      return const Center(
                        child: Text(
                          'No matching saved or recent career comparisons.',
                          style: TextStyle(color: Color(0xFF8895A5)),
                        ),
                      );
                    }
                    return ListView(
                      children: [
                        if (saved.isNotEmpty) ...[
                          const _SectionLabel('SAVED'),
                          for (final item in saved)
                            _ComparisonHistoryRow(
                              item: item,
                              saved: true,
                              onOpen: () => _open(item),
                            ),
                          const SizedBox(height: 10),
                        ],
                        if (recent.isNotEmpty) ...[
                          const _SectionLabel('RECENT'),
                          for (final item in recent)
                            _ComparisonHistoryRow(
                              item: item,
                              saved: false,
                              onOpen: () => _open(item),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF63A9FF),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      );
}

class _ComparisonHistoryRow extends StatelessWidget {
  const _ComparisonHistoryRow({
    required this.item,
    required this.saved,
    required this.onOpen,
  });

  final NbaPlayerCareerComparisonStateItem item;
  final bool saved;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListTile(
        key: ValueKey(
          'career-comparison-history-${saved ? 'saved' : 'recent'}-${item.signature}',
        ),
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          saved ? Icons.bookmark_rounded : Icons.history_rounded,
          color: saved
              ? const Color(0xFFE2B866)
              : const Color(0xFF63A9FF),
        ),
        title: Text(
          '${item.leftPlayerName} vs ${item.rightPlayerName}',
          style: const TextStyle(
            color: Color(0xFFE8EDF3),
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${item.seasonType.toUpperCase()} · ${item.alignment.label} · ${item.metric.label}${item.sharedOnly ? ' · SHARED' : ''}',
          style: const TextStyle(color: Color(0xFF8895A5), fontSize: 9),
        ),
        trailing: TextButton(
          onPressed: onOpen,
          child: const Text('OPEN'),
        ),
      );
}
