import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nba_research_query_engine.dart';
import '../services/website_nba_api_service.dart';

/// A restrained, conversation-inspired research surface. Results remain
/// deterministic and strictly confined to published Arcside static data.
class NbaResearchQueryPanel extends StatefulWidget {
  const NbaResearchQueryPanel({super.key, required this.seasons});
  final List<WebsiteNbaSeason> seasons;

  @override
  State<NbaResearchQueryPanel> createState() => _NbaResearchQueryPanelState();
}

class _ResearchTurn {
  const _ResearchTurn(this.question, this.answer);
  final String question;
  final ArcsideResearchAnswer answer;
}

class _NbaResearchQueryPanelState extends State<NbaResearchQueryPanel> {
  static const _pageSize = 40;
  static const _ink = Color(0xFFE7E9EE);
  static const _sub = Color(0xFF9B9EA8);
  static const _line = Color(0xFF303239);
  static const _accent = Color(0xFFAFB8FF);
  final _input = TextEditingController();
  final _engine = const ArcsideResearchQueryEngine();
  final _history = <_ResearchTurn>[];

  String _season = '2025-26';
  bool _playoffs = false;
  bool _busy = false;
  String? _notice;
  int _active = -1;
  int _page = 0;

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
        !widget.seasons.any((entry) => entry.id == _season)) {
      _season = widget.seasons.first.id;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _newResearch() => setState(() {
    _active = -1;
    _page = 0;
    _notice = null;
    _input.clear();
  });

  Future<void> _submit() async {
    if (_busy || widget.seasons.isEmpty) return;
    final question = _input.text.trim();
    if (question.isEmpty) return;
    if (question.length > ArcsideResearchQueryEngine.maxQuestionChars) {
      setState(() => _notice = 'Question exceeds the 4,096-character browser limit.');
      return;
    }
    setState(() { _busy = true; _notice = null; _page = 0; });
    try {
      final answer = await _engine.ask(question,
          defaultSeason: _season, defaultPlayoffs: _playoffs);
      if (!mounted) return;
      setState(() {
        _history.add(_ResearchTurn(question, answer));
        _active = _history.length - 1;
        _input.clear();
      });
    } catch (_) {
      if (mounted) setState(() =>
          _notice = 'This Arcside dataset could not be loaded. No answer was generated.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _example(String question) => setState(() {
    _input.text = question;
    _input.selection = TextSelection.collapsed(offset: question.length);
    _notice = null;
  });

  @override
  Widget build(BuildContext context) {
    final season = widget.seasons.any((s) => s.id == _season)
        ? _season : (widget.seasons.isEmpty ? null : widget.seasons.first.id);
    return LayoutBuilder(builder: (context, bounds) {
      final wide = bounds.maxWidth >= 980;
      final sidebar = _sidebar();
      final main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Text('RESEARCH HISTORY', style: TextStyle(
                  fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                TextButton.icon(onPressed: _newResearch,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New query')),
              ]),
            ),
          ],
          if (_active < 0) _landing(context),
          if (_active >= 0 && _active < _history.length)
            _answer(context, _history[_active]),
          const SizedBox(height: 30),
          _composer(context, season),
        ],
      );
      if (!wide) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          child: main,
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 226, child: sidebar),
          const SizedBox(width: 30),
          Expanded(child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 34, 18, 40),
                child: main,
              ),
            ),
          )),
        ],
      );
    });
  }

  Widget _sidebar() => Container(
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: _line)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 26, 14, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('Recent research', style: TextStyle(
            color: _sub, fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            tooltip: 'New research',
            onPressed: _newResearch,
            icon: const Icon(Icons.add_rounded, size: 20, color: _ink)),
        ]),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 42, horizontal: 14),
            child: Text('Your queries will appear here during this session.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _sub, fontSize: 12, height: 1.5)),
          ),
        for (var i = _history.length - 1; i >= 0; i--)
          Material(
            color: _active == i ? _line : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() { _active = i; _page = 0; }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Text(_history[i].question,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _ink)),
              ),
            ),
          ),
        const SizedBox(height: 32),
        const Divider(color: _line),
        const SizedBox(height: 12),
        const Text('Arcside data only', style: TextStyle(
          fontWeight: FontWeight.w700, color: _ink, fontSize: 12)),
        const SizedBox(height: 7),
        const Text('No external AI. No API billing. '
            'Queries stay in your browser and are not stored on our servers.',
            style: TextStyle(color: _sub, height: 1.5, fontSize: 11)),
      ]),
    ),
  );

  Widget _landing(BuildContext context) {
    const examples = [
      'Youngest players to average 25+ PPG and 5+ APG in a season',
      'Top 50 scorers in 2025-26',
      'Which players led the league in TS% in 2024-25?',
      'Compare Stephen Curry vs James Harden 2015-16 points',
      '2018 NBA draft picks',
    ];
    return Column(children: [
      const SizedBox(height: 72),
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _accent.withValues(alpha: .13),
          border: Border.all(color: _accent.withValues(alpha: .30))),
        child: const Icon(Icons.query_stats_rounded,
          color: _accent, size: 35),
      ),
      const SizedBox(height: 22),
      const Text('Research Hub', style: TextStyle(
        color: _ink, fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 9),
      const Text('Explore historical NBA data, straight from Arcside.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _sub, fontSize: 14)),
      const SizedBox(height: 23),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _ModeTag('Historical', selected: true),
        SizedBox(width: 8),
        _ModeTag('Arcside NBA'),
        SizedBox(width: 8),
        _ModeTag('Free queries'),
      ]),
      const SizedBox(height: 48),
      for (final example in examples)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Material(
            color: const Color(0xFF22252B),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _example(example),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Text(example, style: const TextStyle(
                    color: _ink, fontSize: 13)),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _composer(BuildContext context, String? season) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xFF22252B),
      border: Border.all(color: _line)),
    padding: const EdgeInsets.fromLTRB(16, 12, 13, 9),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _input,
        minLines: 2,
        maxLines: 5,
        maxLength: ArcsideResearchQueryEngine.maxQuestionChars,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: _ink, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Ask about NBA statistics...',
          hintStyle: TextStyle(color: _sub),
          border: InputBorder.none,
          counterStyle: TextStyle(color: _sub, fontSize: 10),
          isDense: true,
        ),
      ),
      if (_notice != null)
        Padding(padding: const EdgeInsets.only(bottom: 9),
          child: Text(_notice!, style: const TextStyle(color: Color(0xFFF08E8E)))),
      Row(children: [
        SizedBox(width: 139, child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: season,
            isExpanded: true,
            dropdownColor: const Color(0xFF22252B),
            style: const TextStyle(color: _ink, fontSize: 12),
            items: [
              for (final item in widget.seasons)
                DropdownMenuItem(value: item.id, child: Text(item.id)),
            ],
            onChanged: (value) => setState(() => _season = value ?? _season),
          ),
        )),
        const SizedBox(width: 10),
        ChoiceChip(
          label: Text(_playoffs ? 'Playoffs' : 'Regular Season'),
          selected: _playoffs,
          onSelected: (_) => setState(() => _playoffs = !_playoffs),
          visualDensity: VisualDensity.compact),
        const Spacer(),
        const Text('NBA · ARCSIDE', style: TextStyle(
            fontSize: 10, color: _sub, letterSpacing: .6)),
        const SizedBox(width: 12),
        IconButton.filled(
          tooltip: 'Submit research query',
          onPressed: _busy || widget.seasons.isEmpty || _input.text.trim().isEmpty
              ? null : _submit,
          icon: _busy
              ? const SizedBox(width: 17, height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.arrow_upward_rounded)),
      ]),
    ]),
  );

  Widget _answer(BuildContext context, _ResearchTurn turn) {
    final answer = turn.answer;
    final hits = answer.hits;
    final pageCount = hits.isEmpty ? 0 : (hits.length + _pageSize - 1) ~/ _pageSize;
    final page = _page.clamp(0, pageCount == 0 ? 0 : pageCount - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, hits.length);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 16),
      Align(alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF282B33),
            borderRadius: BorderRadius.circular(14)),
          child: Text(turn.question, style: const TextStyle(
              fontSize: 14, color: _ink)),
        )),
      const SizedBox(height: 28),
      Text(answer.title, style: const TextStyle(
        fontWeight: FontWeight.w800, fontSize: 22, color: _ink)),
      const SizedBox(height: 11),
      Text(answer.message, style: const TextStyle(
        color: _ink, fontSize: 14, height: 1.6)),
      if (hits.isNotEmpty) ...[
        const SizedBox(height: 22),
        Row(children: [
          Text('${start + 1}–$end of ${hits.length}',
            style: const TextStyle(fontSize: 12, color: _sub)),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy results'),
            onPressed: () => Clipboard.setData(ClipboardData(
              text: '${answer.title}\n${answer.message}\n${answer.source}\n'
                '${hits.map((hit) => '${hit.name} | ${hit.team} | ${hit.value}').join('\n')}')),
          ),
        ]),
        const Divider(color: _line),
        for (var i = start; i < end; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              SizedBox(width: 36,
                child: Text('${i + 1}.',
                  style: const TextStyle(color: _sub, fontSize: 12))),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hits[i].name, style: const TextStyle(
                    color: _ink, fontWeight: FontWeight.w600)),
                  if (hits[i].team.isNotEmpty || hits[i].detail.isNotEmpty)
                    Text([hits[i].team, hits[i].detail]
                        .where((v) => v.isNotEmpty).join(' · '),
                        style: const TextStyle(fontSize: 11, color: _sub)),
                ],
              )),
              const SizedBox(width: 12),
              Text(hits[i].value,
                style: const TextStyle(color: _accent,
                    fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
          ),
        if (pageCount > 1)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(
              onPressed: page == 0 ? null : () => setState(() => _page = page - 1),
              icon: const Icon(Icons.chevron_left_rounded)),
            Text('Page ${page + 1} / $pageCount',
              style: const TextStyle(fontSize: 12, color: _sub)),
            IconButton(
              onPressed: page + 1 >= pageCount ? null :
                  () => setState(() => _page = page + 1),
              icon: const Icon(Icons.chevron_right_rounded)),
          ]),
      ],
      const Divider(color: _line, height: 25),
      Row(children: [
        const Icon(Icons.dataset_outlined, color: _sub, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(answer.source,
          style: const TextStyle(fontSize: 11, color: _sub))),
      ]),
    ]);
  }
}

class _ModeTag extends StatelessWidget {
  const _ModeTag(this.label, {this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: selected
          ? const Color(0xFFADB7FF) : const Color(0xFF31343A)),
      borderRadius: BorderRadius.circular(11)),
    child: Text(label, style: TextStyle(
      color: selected ? const Color(0xFFADB7FF) : const Color(0xFFA3A5AE),
      fontSize: 11)),
  );
}
