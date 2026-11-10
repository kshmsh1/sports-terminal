import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_research_query_engine.dart';
import '../services/website_nba_api_service.dart';

/// Research is an open, browser-only query surface, not a chain of dashboard
/// cards or a remotely hosted chatbot. Session history is never uploaded.
class NbaResearchQueryPanel extends StatefulWidget {
  const NbaResearchQueryPanel({super.key, required this.seasons});
  final List<WebsiteNbaSeason> seasons;

  @override
  State<NbaResearchQueryPanel> createState() => _NbaResearchQueryPanelState();
}

class _ResearchExchange {
  const _ResearchExchange(this.question, this.answer);
  final String question;
  final ArcsideResearchAnswer answer;
}

class _NbaResearchQueryPanelState extends State<NbaResearchQueryPanel> {
  static const _pageSize = 40;
  final _input = TextEditingController();
  final _engine = const ArcsideResearchQueryEngine();
  final _history = <_ResearchExchange>[];
  String _season = '2025-26';
  bool _playoffs = false;
  bool _busy = false;
  String? _notice;
  ArcsideResearchAnswer? _answer;
  int _page = 0;

  static const _examples = <String>[
    'Top 50 scorers in 2025-26',
    'Who led in assists in the 2024-25 playoffs?',
    'Compare Stephen Curry vs James Harden 2015-16 points',
    '2018 NBA draft picks',
  ];

  @override
  void initState() {
    super.initState();
    _chooseSeason();
  }

  @override
  void didUpdateWidget(covariant NbaResearchQueryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _chooseSeason();
  }

  void _chooseSeason() {
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

  void _newQuery() => setState(() {
    _input.clear();
    _answer = null;
    _notice = null;
    _page = 0;
  });

  void _usePrompt(String value) {
    _input.text = value;
    _input.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _notice = null);
  }

  Future<void> _submit() async {
    if (_busy || widget.seasons.isEmpty) return;
    final question = _input.text.trim();
    if (question.isEmpty) {
      setState(() => _notice = 'Enter a question about published Arcside data.');
      return;
    }
    if (question.length > ArcsideResearchQueryEngine.maxQuestionChars) {
      setState(() => _notice = 'The question exceeds the 4,096-character limit.');
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
      _page = 0;
    });
    try {
      final result = await _engine.ask(question,
        defaultSeason: _season, defaultPlayoffs: _playoffs);
      if (!mounted) return;
      setState(() {
        _answer = result;
        _history.insert(0, _ResearchExchange(question, result));
      });
    } catch (_) {
      if (mounted) {
        setState(() => _notice =
          'The requested published Arcside data could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 920;
      return Container(
        height: wide ? 760 : 740,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
            bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: .45)),
          ),
        ),
        child: Row(children: [
          if (wide) ...[
            SizedBox(width: 214, child: _sidebar(colors)),
            VerticalDivider(width: 1, thickness: 1,
              color: colors.outlineVariant.withValues(alpha: .45)),
          ],
          Expanded(child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 28 : 12, vertical: 14),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(children: [
                if (!wide) Row(children: [
                  Text('Research Hub', style: Theme.of(context)
                    .textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _newQuery,
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('New'),
                  ),
                ]),
                Expanded(child: _answer == null
                    ? _landing(colors)
                    : _answerView(colors)),
                const SizedBox(height: 8),
                _composer(colors),
              ]),
            )),
          )),
        ]),
      );
    });
  }

  Widget _sidebar(ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(13, 17, 8, 12),
        child: Row(children: [
          const Expanded(child: Text('Recent queries',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          IconButton(
            tooltip: 'New research query',
            onPressed: _newQuery,
            icon: const Icon(Icons.add_rounded),
          ),
        ]),
      ),
      Expanded(child: _history.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 42),
              child: Text('Queries from this session will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12,
                  color: colors.onSurfaceVariant)),
            )
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                return ListTile(
                  dense: true,
                  selected: identical(_answer, item.answer),
                  title: Text(item.question,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                  onTap: () => setState(() {
                    _input.text = item.question;
                    _answer = item.answer;
                    _page = 0;
                    _notice = null;
                  }),
                );
              },
            )),
      Divider(height: 1, color: colors.outlineVariant),
      Padding(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          Icon(Icons.dataset_outlined, size: 15,
            color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text('Arcside published data',
            style: TextStyle(fontSize: 11,
              color: colors.onSurfaceVariant))),
        ]),
      ),
    ],
  );

  Widget _landing(ColorScheme colors) => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: bounds.maxHeight),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colors.primaryContainer.withValues(alpha: .46),
            child: Icon(Icons.query_stats_rounded, size: 38,
              color: colors.primary),
          ),
          const SizedBox(height: 19),
          Text('Research Hub',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900, letterSpacing: -.7)),
          const SizedBox(height: 9),
          Text('Ask about historical NBA players, statistics, teams and games.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 17),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _modeChip(colors, 'Historical', selected: true),
            const SizedBox(width: 7),
            Tooltip(
              message: 'Live data is not available in the published archive.',
              child: _modeChip(colors, 'Live · unavailable'),
            ),
          ]),
          const SizedBox(height: 42),
          Align(alignment: Alignment.centerLeft, child: Text(
            'SUGGESTED RESEARCH',
            style: TextStyle(color: colors.onSurfaceVariant,
              fontSize: 10, letterSpacing: 1.2,
              fontWeight: FontWeight.w900))),
          const SizedBox(height: 10),
          for (final prompt in _examples)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _usePrompt(prompt),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: .8)),
                  ),
                  child: Text(prompt, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text('No subscription · No daily quota · Source-backed answers',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11,
              color: colors.onSurfaceVariant)),
        ]),
      ),
    ),
  );

  Widget _modeChip(ColorScheme colors, String label,
      {bool selected = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color:
        selected ? colors.primary : colors.outlineVariant),
      color: selected ? colors.primary.withValues(alpha: .12) : null,
    ),
    child: Text(label, style: TextStyle(
      color: selected ? colors.primary : colors.onSurfaceVariant,
      fontSize: 11, fontWeight: FontWeight.w700)),
  );

  Widget _answerView(ColorScheme colors) {
    final answer = _answer!;
    final hits = answer.hits;
    final count = hits.isEmpty ? 0 : ((hits.length - 1) ~/ _pageSize) + 1;
    final page = _page.clamp(0, count == 0 ? 0 : count - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, hits.length);
    final visible = hits.sublist(start, end);
    return ListView(children: [
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: Text(answer.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900))),
        IconButton(
          onPressed: _newQuery, tooltip: 'New query',
          icon: const Icon(Icons.add_rounded),
        ),
      ]),
      const SizedBox(height: 9),
      Text(answer.message, style: const TextStyle(height: 1.5)),
      const SizedBox(height: 12),
      Text(answer.source, style: TextStyle(
        color: colors.onSurfaceVariant, fontSize: 11)),
      const SizedBox(height: 14),
      if (hits.isNotEmpty) ...[
        Row(children: [
          Expanded(child: Text('${start + 1}–$end of ${hits.length} results',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11))),
          TextButton.icon(
            icon: const Icon(Icons.copy_all_rounded, size: 15),
            label: const Text('Copy all'),
            onPressed: () => Clipboard.setData(ClipboardData(text:
              '${answer.title}\n${answer.message}\n${answer.source}\n'
              '${hits.map((hit) =>
                '${hit.name} | ${hit.team} | ${hit.value} | ${hit.detail}')
                .join('\n')}',
            )),
          ),
        ]),
        const Divider(height: 1),
        for (var index = 0; index < visible.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              SizedBox(width: 38, child: Text('${start + index + 1}.',
                style: TextStyle(color: colors.onSurfaceVariant,
                  fontSize: 12))),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(visible[index].name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (visible[index].team.isNotEmpty ||
                      visible[index].detail.isNotEmpty)
                    Text([visible[index].team, visible[index].detail]
                      .where((v) => v.isNotEmpty).join(' · '),
                      style: TextStyle(color: colors.onSurfaceVariant,
                        fontSize: 11)),
                ],
              )),
              const SizedBox(width: 10),
              Text(visible[index].value, style: TextStyle(
                fontWeight: FontWeight.w900, color: colors.primary,
                fontSize: 15)),
            ]),
          ),
        if (count > 1)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
              tooltip: 'Previous results',
              onPressed: page == 0 ? null
                  : () => setState(() => _page = page - 1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text('Page ${page + 1} of $count',
              style: const TextStyle(fontSize: 12)),
            IconButton(
              tooltip: 'Next results',
              onPressed: page >= count - 1 ? null
                  : () => setState(() => _page = page + 1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
      ],
      if (!answer.supported) ...[
        const SizedBox(height: 9),
        Text('Only recorded Arcside data is used. Missing information '
          'is never filled in by an AI model.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
      ],
      const SizedBox(height: 20),
    ]);
  }

  Widget _composer(ColorScheme colors) {
    final seasons = widget.seasons;
    final selectedSeason = seasons.any((s) => s.id == _season)
        ? _season : (seasons.isEmpty ? null : seasons.first.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_notice != null) ...[
        Padding(padding: const EdgeInsets.only(bottom: 5),
          child: Text(_notice!,
            style: TextStyle(color: colors.error, fontSize: 12))),
      ],
      Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 8),
        child: Column(children: [
          TextField(
            controller: _input,
            minLines: 2,
            maxLines: 4,
            maxLength: ArcsideResearchQueryEngine.maxQuestionChars,
            style: const TextStyle(fontSize: 14),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() => _notice = null),
            decoration: const InputDecoration(
              hintText: 'Ask about NBA history...',
              border: InputBorder.none,
              counterText: '',
              isDense: true,
            ),
          ),
          Wrap(spacing: 10, runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 123, child: DropdownButtonFormField<String>(
                key: ValueKey('research-season-$selectedSeason'),
                initialValue: selectedSeason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Season', isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 7, horizontal: 9),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in seasons)
                    DropdownMenuItem(value: item.id, child: Text(item.id)),
                ],
                onChanged: (value) => setState(() {
                  _season = value ?? _season;
                }),
              )),
              SegmentedButton<bool>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                selected: {_playoffs},
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Regular')),
                  ButtonSegment(value: true, label: Text('Playoffs')),
                ],
                onSelectionChanged: (value) =>
                    setState(() => _playoffs = value.first),
              ),
              const SizedBox(width: 6),
              Text('NBA · Published data', style: TextStyle(
                color: colors.onSurfaceVariant, fontSize: 11)),
              if (_busy)
                const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton.filled(
                tooltip: 'Ask Arcside',
                onPressed: _busy || seasons.isEmpty ? null : _submit,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ]),
        ]),
      ),
      const SizedBox(height: 7),
      Text('Arcside · Unlimited browser-side queries · No external AI',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10)),
    ]);
  }
}
