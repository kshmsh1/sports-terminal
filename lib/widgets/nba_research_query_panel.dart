import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/nba_research_query_engine.dart';
import '../services/website_nba_api_service.dart';

/// A limited, no-login NBA data query interface. Quotas are local UI controls,
/// not tamper-proof server rate limits. No AI inference or remote model calls.
class NbaResearchQueryPanel extends StatefulWidget {
  const NbaResearchQueryPanel({super.key, required this.seasons});

  final List<WebsiteNbaSeason> seasons;

  @override
  State<NbaResearchQueryPanel> createState() => _NbaResearchQueryPanelState();
}

class _NbaResearchQueryPanelState extends State<NbaResearchQueryPanel> {
  static const _maxDaily = 8;
  static const _cooldown = Duration(seconds: 15);
  static const _maxChars = 180;
  static const _dayKey = 'arcside.research.query.day.v1';
  static const _countKey = 'arcside.research.query.count.v1';
  static const _lastKey = 'arcside.research.query.last.v1';

  final _input = TextEditingController();
  final _engine = const ArcsideResearchQueryEngine();
  String _season = '2025-26';
  bool _playoffs = false;
  int _used = 0;
  bool _busy = false;
  String? _notice;
  ArcsideResearchAnswer? _answer;

  @override
  void initState() {
    super.initState();
    _loadQuota();
    if (widget.seasons.isNotEmpty &&
        !widget.seasons.any((season) => season.id == _season)) {
      _season = widget.seasons.first.id;
    }
  }

  @override
  void didUpdateWidget(covariant NbaResearchQueryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seasons.isNotEmpty &&
        !widget.seasons.any((season) => season.id == _season)) {
      _season = widget.seasons.first.id;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  static String _today(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getString(_dayKey) == _today(DateTime.now())
        ? prefs.getInt(_countKey) ?? 0
        : 0;
    if (mounted) setState(() => _used = count);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final prompt = _input.text.trim();
    if (prompt.isEmpty) {
      setState(() => _notice = 'Enter a question about an NBA player-season statistic.');
      return;
    }
    if (prompt.length > _maxChars) {
      setState(() => _notice = 'Keep your question to $_maxChars characters.');
      return;
    }

    // Persist the small browser-side quota before fetching one static shard.
    // This protects ordinary accidental overuse, not deliberate circumvention.
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _today(now);
    final used = prefs.getString(_dayKey) == today
        ? prefs.getInt(_countKey) ?? 0
        : 0;
    final last = prefs.getInt(_lastKey) ?? 0;
    if (used >= _maxDaily) {
      if (mounted) {
        setState(() {
          _used = used;
          _notice = 'Daily limit reached. Come back tomorrow.';
        });
      }
      return;
    }
    final elapsed = now.millisecondsSinceEpoch - last;
    if (elapsed >= 0 && elapsed < _cooldown.inMilliseconds) {
      if (mounted) {
        setState(() => _notice =
            'Please wait ${((_cooldown.inMilliseconds - elapsed) / 1000).ceil()} seconds before the next query.');
      }
      return;
    }
    await prefs.setString(_dayKey, today);
    await prefs.setInt(_countKey, used + 1);
    await prefs.setInt(_lastKey, now.millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() {
      _busy = true;
      _used = used + 1;
      _notice = null;
      _answer = null;
    });
    final answer = await _engine.ask(
      prompt,
      defaultSeason: _season,
      defaultPlayoffs: _playoffs,
    );
    if (!mounted) return;
    setState(() {
      _answer = answer;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final seasons = widget.seasons;
    final season = seasons.any((item) => item.id == _season)
        ? _season : (seasons.isEmpty ? _season : seasons.first.id);
    const examples = [
      'Top 5 scorers in 2025-26',
      'Who led in assists in 2024-25?',
      'Stephen Curry 2015-16 points per game',
      'Michael Jordan 1995-96 stats',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.search_rounded, size: 23, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Ask Arcside',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900))),
              Tooltip(
                message: 'Queries use your published NBA data, not ChatGPT or an AI model.',
                child: Icon(Icons.verified_outlined,
                  color: colors.onSurfaceVariant, size: 18),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Ask a question about NBA player statistics. Answers come directly from Arcside\'s historical data, without an account or AI subscription.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 18),
            TextField(
              controller: _input,
              maxLength: _maxChars,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() => _notice = null),
              decoration: InputDecoration(
                hintText: 'e.g. Top 5 scorers in 2025-26',
                labelText: 'Research question',
                prefixIcon: const Icon(Icons.manage_search_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: _input.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear question',
                        onPressed: () => setState(() {
                          _input.clear();
                          _answer = null;
                          _notice = null;
                        }),
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 9, runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 146, child: DropdownButtonFormField<String>(
                key: ValueKey('research-season-$season'),
                initialValue: seasons.isEmpty ? null : season,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Default season', isDense: true),
                items: [
                  for (final item in seasons)
                    DropdownMenuItem(value: item.id, child: Text(item.id)),
                ],
                onChanged: (next) => setState(() {
                  _season = next ?? _season;
                  _answer = null;
                }),
              )),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Regular')),
                  ButtonSegment(value: true, label: Text('Playoffs')),
                ],
                showSelectedIcon: false,
                selected: {_playoffs},
                onSelectionChanged: (value) => setState(() {
                  _playoffs = value.first;
                  _answer = null;
                }),
              ),
              FilledButton.icon(
                onPressed: _busy || _used >= _maxDaily || seasons.isEmpty ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 15, height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_upward_rounded, size: 17),
                label: Text(_busy ? 'Searching data' : 'Ask'),
              ),
              Text('${_maxDaily - _used < 0 ? 0 : _maxDaily - _used}/$_maxDaily today',
                style: TextStyle(fontSize: 12,
                  color: colors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 13),
            Text('TRY A QUESTION', style: TextStyle(fontSize: 10,
              color: colors.onSurfaceVariant, fontWeight: FontWeight.w900,
              letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final example in examples)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(example, style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() {
                    _input.text = example;
                    _notice = null;
                  }),
                ),
            ]),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Text(_notice!, style: TextStyle(color: colors.error)),
            ],
            if (_answer != null) ...[
              const Divider(height: 34),
              _ResultPanel(answer: _answer!),
            ],
            const SizedBox(height: 13),
            Text('Strict scope: NBA history only · $_maxChars characters · $_maxDaily questions per browser per day · 15-second cooldown · No uploads · No chat memory. Browser limits can be reset locally; they are not server-side security controls.',
              style: TextStyle(fontSize: 11,
                color: colors.onSurfaceVariant, height: 1.35)),
            const SizedBox(height: 7),
            Text('ARCSIDE · Deterministic data search, not an OpenAI or ChatGPT integration.',
              style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w800,
                color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.answer});

  final ArcsideResearchAnswer answer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(answer.supported ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
              size: 18, color: answer.supported
                  ? colors.primary : colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(answer.title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 9),
        Text(answer.message, style: const TextStyle(height: 1.4)),
        if (answer.hits.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (var index = 0; index < answer.hits.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${index + 1}.',
                  style: TextStyle(color: colors.onSurfaceVariant))),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(answer.hits[index].name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (answer.hits[index].team.isNotEmpty ||
                        answer.hits[index].detail.isNotEmpty)
                      Text([
                        answer.hits[index].team,
                        answer.hits[index].detail,
                      ].where((item) => item.isNotEmpty).join(' · '),
                        style: TextStyle(fontSize: 11,
                          color: colors.onSurfaceVariant)),
                  ],
                )),
                const SizedBox(width: 8),
                Text(answer.hits[index].value,
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w900, color: colors.primary)),
              ]),
            ),
        ],
        const Divider(height: 25),
        Row(children: [
          Icon(Icons.dataset_outlined, size: 15,
              color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(answer.source,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant))),
        ]),
      ]),
    );
  }
}
