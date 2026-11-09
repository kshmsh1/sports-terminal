import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_research_query_engine.dart';
import '../services/website_nba_api_service.dart';

/// No-login, zero-inference-cost research powered by published Arcside data.
/// No browser quota, stored conversations, external AI provider or credentials.
class NbaResearchQueryPanel extends StatefulWidget {
  const NbaResearchQueryPanel({super.key, required this.seasons});

  final List<WebsiteNbaSeason> seasons;

  @override
  State<NbaResearchQueryPanel> createState() => _NbaResearchQueryPanelState();
}

class _NbaResearchQueryPanelState extends State<NbaResearchQueryPanel> {
  static const _pageSize = 40;
  final _input = TextEditingController();
  final _engine = const ArcsideResearchQueryEngine();

  String _season = '2025-26';
  bool _playoffs = false;
  bool _busy = false;
  String? _notice;
  ArcsideResearchAnswer? _answer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _chooseAvailableSeason();
  }

  @override
  void didUpdateWidget(covariant NbaResearchQueryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _chooseAvailableSeason();
  }

  void _chooseAvailableSeason() {
    if (widget.seasons.isNotEmpty &&
        !widget.seasons.any((item) => item.id == _season)) {
      _season = widget.seasons.first.id;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || widget.seasons.isEmpty) return;
    final prompt = _input.text.trim();
    if (prompt.isEmpty) {
      setState(() => _notice = 'Ask a question about Arcside NBA data.');
      return;
    }
    if (prompt.length > ArcsideResearchQueryEngine.maxQuestionChars) {
      setState(() => _notice = 'Keep the question within ${ArcsideResearchQueryEngine.maxQuestionChars} characters.');
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
      _answer = null;
      _page = 0;
    });
    try {
      final answer = await _engine.ask(
        prompt, defaultSeason: _season, defaultPlayoffs: _playoffs);
      if (!mounted) return;
      setState(() => _answer = answer);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = 'Arcside could not load the requested published data.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _example(String value) {
    setState(() {
      _input.text = value;
      _input.selection = TextSelection.collapsed(offset: value.length);
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final seasons = widget.seasons;
    final season = seasons.any((item) => item.id == _season)
        ? _season : (seasons.isEmpty ? null : seasons.first.id);

    const examples = [
      'Top 50 scorers in 2025-26',
      'Top 100 TS% in 2024-25 minimum 20 games',
      'Top 30 deflections in 2023-24',
      'Stephen Curry 2015-16 all stats',
      'Compare Stephen Curry vs James Harden 2015-16',
      'Team standings 2024-25',
      'NBA MVP 2024-25',
      '2018 NBA draft picks',
      'Games on 2023-06-12',
      'Top 25 ORTG 2024-25 team:BOS',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.manage_search_rounded, color: colors.primary, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text('Ask Arcside',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900))),
            Tooltip(
              message: 'Answers are determined solely by published Arcside records.',
              child: Icon(Icons.verified_outlined,
                size: 20, color: colors.onSurfaceVariant),
            ),
          ]),
          const SizedBox(height: 7),
          Text('Search Arcside’s own historical NBA statistics, games, teams, drafts and awards. '
            'The results come from published Arcside records—not ChatGPT or the internet.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            minLines: 2,
            maxLines: 6,
            maxLength: ArcsideResearchQueryEngine.maxQuestionChars,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() => _notice = null),
            decoration: InputDecoration(
              labelText: 'Research question',
              hintText: 'e.g. Top 100 TS% in 2024-25 minimum 20 games',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              suffixIcon: _input.text.isEmpty ? null : IconButton(
                tooltip: 'Clear',
                onPressed: () => setState(() {
                  _input.clear();
                  _answer = null;
                  _notice = null;
                }),
                icon: const Icon(Icons.clear_rounded),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 10, runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 160, child: DropdownButtonFormField<String>(
                key: ValueKey('research-season-$season'),
                initialValue: season,
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
                onPressed: _busy || seasons.isEmpty ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_upward_rounded, size: 18),
                label: Text(_busy ? 'Searching' : 'Search Arcside'),
              ),
              const Chip(
                avatar: Icon(Icons.all_inclusive_rounded, size: 17),
                label: Text('No daily query limit'),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text('EXAMPLE QUERIES', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w900,
            color: colors.onSurfaceVariant, letterSpacing: 1)),
          const SizedBox(height: 7),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final example in examples)
              ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(example, style: const TextStyle(fontSize: 11)),
                onPressed: () => _example(example),
              ),
          ]),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Text(_notice!, style: TextStyle(color: colors.error)),
          ],
          if (_answer != null) ...[
            const Divider(height: 34),
            _result(context, _answer!),
          ],
          const SizedBox(height: 15),
          Text('Free by design: no AI calls, paid APIs, user account, browser quota '
              'or server-side query processing. Questions are limited to '
              '${ArcsideResearchQueryEngine.maxQuestionChars} characters to protect browser performance. '
              'Result pages show $_pageSize rows at a time; all matching rows remain accessible.',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant,
              height: 1.5)),
          const SizedBox(height: 8),
          Text('ARCSIDE · PUBLISHED DATA ONLY · NO EXTERNAL AI',
            style: TextStyle(color: colors.onSurfaceVariant,
              fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _result(BuildContext context, ArcsideResearchAnswer answer) {
    final colors = Theme.of(context).colorScheme;
    final hits = answer.hits;
    final pageCount = hits.isEmpty ? 0 : ((hits.length - 1) ~/ _pageSize) + 1;
    final page = _page.clamp(0, pageCount == 0 ? 0 : pageCount - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, hits.length);
    final visible = hits.sublist(start, end);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
        color: colors.surfaceContainerHighest.withValues(alpha: .30),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(answer.supported ? Icons.check_circle_outline_rounded :
              Icons.info_outline_rounded, color: answer.supported ?
              colors.primary : colors.onSurfaceVariant, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(answer.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 9),
        Text(answer.message, style: const TextStyle(height: 1.4)),
        if (hits.isNotEmpty) ...[
          const SizedBox(height: 13),
          Row(children: [
            Expanded(child: Text(
              '${start + 1}–$end of ${hits.length} results',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant))),
            TextButton.icon(
              icon: const Icon(Icons.copy_all_rounded, size: 15),
              label: const Text('Copy all results'),
              onPressed: () => Clipboard.setData(ClipboardData(text:
                '${answer.title}\n${answer.message}\n${answer.source}\n' +
                hits.map((hit) =>
                  '${hit.name} | ${hit.team} | ${hit.value} | ${hit.detail}')
                  .join('\n'),
              )),
            ),
          ]),
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 42, child: Text('${start + i + 1}.',
                    style: TextStyle(fontSize: 12,
                      color: colors.onSurfaceVariant))),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visible[i].name, style: const TextStyle(
                        fontWeight: FontWeight.w800)),
                    if (visible[i].team.isNotEmpty ||
                        visible[i].detail.isNotEmpty)
                      Text([
                        visible[i].team, visible[i].detail,
                      ].where((item) => item.isNotEmpty).join(' · '),
                        style: TextStyle(fontSize: 11,
                          color: colors.onSurfaceVariant)),
                  ],
                )),
                const SizedBox(width: 10),
                Text(visible[i].value, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: colors.primary)),
              ]),
            ),
          if (pageCount > 1)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                tooltip: 'Previous results',
                onPressed: page <= 0 ? null :
                    () => setState(() => _page = page - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('Page ${page + 1} of $pageCount',
                style: const TextStyle(fontSize: 12)),
              IconButton(
                tooltip: 'Next results',
                onPressed: page >= pageCount - 1 ? null :
                    () => setState(() => _page = page + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ]),
        ],
        const Divider(height: 26),
        Row(children: [
          Icon(Icons.dataset_outlined, size: 15,
            color: colors.onSurfaceVariant),
          const SizedBox(width: 7),
          Expanded(child: Text(answer.source, style: TextStyle(
              fontSize: 11, color: colors.onSurfaceVariant))),
        ]),
      ]),
    );
  }
}
