import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/product_local_store.dart';

const _arPanel = Color(0xFF0F151C);
const _arPanel2 = Color(0xFF141C25);
const _arLine = Color(0xFF263342);
const _arText = Color(0xFFE8EDF3);
const _arMuted = Color(0xFF8895A5);
const _arBlue = Color(0xFF63A9FF);
const _arAmber = Color(0xFFE2B866);
const _arGreen = Color(0xFF69C99A);

const _articleSections = <String>[
  'For You', 'NBA', 'WNBA', 'NFL', 'NHL', 'MLB', 'NCAAM', 'NCAAW',
  'College Football', 'Tennis', 'MLS', 'Premier League', 'Champions League',
  'Formula 1', 'Golf',
];

class ProductArticlesV2Screen extends StatefulWidget {
  const ProductArticlesV2Screen({super.key});

  @override
  State<ProductArticlesV2Screen> createState() => _ProductArticlesV2ScreenState();
}

class _ProductArticlesV2ScreenState extends State<ProductArticlesV2Screen> {
  static const _savedKey = 'sports_terminal.articles.saved.v2';
  static const _followedAuthorsKey = 'sports_terminal.articles.followed_authors.v2';
  final ProductLocalStore _store = const ProductLocalStore();
  final TextEditingController _search = TextEditingController();
  String _section = 'For You';
  String _filter = 'Latest';
  Set<String> _saved = {};
  Set<String> _followedAuthors = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final saved = await _store.loadStringSet(_savedKey);
    final authors = await _store.loadStringSet(_followedAuthorsKey);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _followedAuthors = authors;
      _loaded = true;
    });
  }

  Future<void> _toggleSaved(String id) async {
    setState(() {
      if (!_saved.add(id)) _saved.remove(id);
    });
    await _store.saveStringSet(_savedKey, _saved);
  }

  Future<void> _toggleAuthor(String author) async {
    setState(() {
      if (!_followedAuthors.add(author)) _followedAuthors.remove(author);
    });
    await _store.saveStringSet(_followedAuthorsKey, _followedAuthors);
  }

  List<_Article> get _visible {
    final query = _search.text.trim().toLowerCase();
    var rows = _articles.where((article) {
      final sectionMatch = _section == 'For You' || article.section == _section;
      final queryMatch = query.isEmpty || '${article.title} ${article.dek} ${article.author} ${article.section} ${article.tags.join(' ')}'.toLowerCase().contains(query);
      return sectionMatch && queryMatch;
    }).toList();
    if (_filter == 'Most Read') rows.sort((a, b) => b.readScore.compareTo(a.readScore));
    if (_filter == 'Long-form') rows = rows.where((item) => item.minutes >= 8).toList();
    if (_filter == 'Analysis') rows = rows.where((item) => item.tags.contains('Analysis') || item.tags.contains('Data')).toList();
    if (_filter == 'Saved') rows = rows.where((item) => _saved.contains(item.id)).toList();
    if (_filter == 'Following') rows = rows.where((item) => _followedAuthors.contains(item.author)).toList();
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _ArticlePanel(child: Center(child: CircularProgressIndicator()));
    final rows = _visible;
    final feature = rows.isNotEmpty ? rows.first : null;
    final secondary = rows.skip(1).take(4).toList();
    final rest = rows.skip(5).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Masthead(saved: _saved.length, following: _followedAuthors.length),
      const SizedBox(height: 12),
      _SectionNavigation(selected: _section, onSelected: (value) => setState(() => _section = value)),
      const SizedBox(height: 12),
      _DiscoveryBar(
        search: _search,
        filter: _filter,
        onSearch: (_) => setState(() {}),
        onFilter: (value) => setState(() => _filter = value),
      ),
      const SizedBox(height: 12),
      if (feature == null)
        const _ArticlePanel(child: Text('No stories match this section/filter yet.', style: TextStyle(color: _arMuted)))
      else ...[
        _LeadPackage(
          feature: feature,
          secondary: secondary,
          saved: _saved,
          followedAuthors: _followedAuthors,
          onSave: _toggleSaved,
          onAuthor: _toggleAuthor,
        ),
        const SizedBox(height: 14),
        _TopicRail(section: _section),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1050;
          final latest = _ArticleList(title: _section == 'For You' ? 'Latest across sports' : 'Latest in $_section', rows: rest.isEmpty ? rows.skip(1).toList() : rest, saved: _saved, followedAuthors: _followedAuthors, onSave: _toggleSaved, onAuthor: _toggleAuthor);
          final rail = Column(children: [
            _MostRead(rows: [...rows]..sort((a, b) => b.readScore.compareTo(a.readScore)), onOpen: _openArticle),
            const SizedBox(height: 12),
            _Writers(followed: _followedAuthors, onToggle: _toggleAuthor),
            const SizedBox(height: 12),
            const _EditorialStandards(),
          ]);
          if (!wide) return Column(children: [rail, const SizedBox(height: 14), latest]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: latest), const SizedBox(width: 14), Expanded(flex: 3, child: rail)]);
        }),
        const SizedBox(height: 14),
        _NewsletterAndAudio(section: _section),
      ],
    ]);
  }

  Future<void> _openArticle(_Article article) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFF07111F),
          appBar: AppBar(
            backgroundColor: _arPanel,
            foregroundColor: Colors.white,
            leading: IconButton(onPressed: () => Navigator.of(dialogContext).pop(), icon: const Icon(Icons.close_rounded)),
            title: Text(article.section),
            actions: [IconButton(onPressed: () => _toggleSaved(article.id), icon: Icon(_saved.contains(article.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded))],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 80),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: _ArticleReader(article: article, followed: _followedAuthors.contains(article.author), onAuthor: () => _toggleAuthor(article.author)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.saved, required this.following});
  final int saved;
  final int following;
  @override
  Widget build(BuildContext context) => _ArticlePanel(
        child: LayoutBuilder(builder: (context, constraints) {
          final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SPORTS TERMINAL', style: TextStyle(color: _arBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
            const SizedBox(height: 5),
            const Text('Articles', style: TextStyle(color: _arText, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 7),
            const Text('Reported stories, sharp analysis and data-native sports writing across leagues—designed as a premium editorial product that remains connected to the rest of Sports Terminal.', style: TextStyle(color: _arMuted, height: 1.45)),
          ]);
          final status = Wrap(spacing: 7, runSpacing: 7, children: [_Tag('$saved SAVED', _arAmber), _Tag('$following WRITERS FOLLOWED', _arGreen), const _Tag('MULTI-SPORT', _arBlue)]);
          if (constraints.maxWidth < 800) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 12), status]);
          return Row(children: [Expanded(child: copy), const SizedBox(width: 20), status]);
        }),
      );
}

class _SectionNavigation extends StatelessWidget {
  const _SectionNavigation({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => _ArticlePanel(
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            itemCount: _articleSections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 3),
            itemBuilder: (context, index) {
              final value = _articleSections[index];
              return ChoiceChip(label: Text(value), selected: selected == value, onSelected: (_) => onSelected(value));
            },
          ),
        ),
      );
}

class _DiscoveryBar extends StatelessWidget {
  const _DiscoveryBar({required this.search, required this.filter, required this.onSearch, required this.onFilter});
  final TextEditingController search;
  final String filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onFilter;
  @override
  Widget build(BuildContext context) => _ArticlePanel(
        padding: const EdgeInsets.all(9),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 300, child: TextField(controller: search, onChanged: onSearch, decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search_rounded), hintText: 'Search stories, writers, teams…', border: OutlineInputBorder()))),
          for (final value in const ['Latest', 'Most Read', 'Analysis', 'Long-form', 'Saved', 'Following'])
            ChoiceChip(label: Text(value), selected: filter == value, onSelected: (_) => onFilter(value)),
        ]),
      );
}

class _LeadPackage extends StatelessWidget {
  const _LeadPackage({required this.feature, required this.secondary, required this.saved, required this.followedAuthors, required this.onSave, required this.onAuthor});
  final _Article feature;
  final List<_Article> secondary;
  final Set<String> saved;
  final Set<String> followedAuthors;
  final ValueChanged<String> onSave;
  final ValueChanged<String> onAuthor;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final primary = _FeatureArticle(article: feature, saved: saved.contains(feature.id), followed: followedAuthors.contains(feature.author), onSave: () => onSave(feature.id), onAuthor: () => onAuthor(feature.author));
        final side = _ArticlePanel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < secondary.length; i++)
              _SecondaryArticle(article: secondary[i], saved: saved.contains(secondary[i].id), onSave: () => onSave(secondary[i].id), last: i == secondary.length - 1),
          ]),
        );
        if (constraints.maxWidth < 980) return Column(children: [primary, const SizedBox(height: 12), side]);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 6, child: primary), const SizedBox(width: 12), Expanded(flex: 4, child: side)]);
      });
}

class _FeatureArticle extends StatelessWidget {
  const _FeatureArticle({required this.article, required this.saved, required this.followed, required this.onSave, required this.onAuthor});
  final _Article article;
  final bool saved;
  final bool followed;
  final VoidCallback onSave;
  final VoidCallback onAuthor;
  @override
  Widget build(BuildContext context) => _ArticlePanel(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _openFromContext(context, article),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 280, width: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [article.accent.withValues(alpha: .8), _arPanel2])), child: Stack(children: [
              Positioned(left: 22, top: 20, child: _Tag(article.section.toUpperCase(), Colors.white)),
              Positioned(right: 18, top: 14, child: IconButton(onPressed: onSave, icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Colors.white))),
              Positioned(left: 22, right: 22, bottom: 24, child: Text(article.visualLabel.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: .2), fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2))),
            ])),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 5, children: [for (final tag in article.tags.take(3)) _Tag(tag.toUpperCase(), tag == 'Exclusive' ? _arAmber : _arBlue)]),
                const SizedBox(height: 10),
                Text(article.title, style: const TextStyle(color: _arText, fontSize: 30, fontWeight: FontWeight.w900, height: 1.08, letterSpacing: -.4)),
                const SizedBox(height: 9),
                Text(article.dek, style: const TextStyle(color: _arMuted, fontSize: 14, height: 1.45)),
                const SizedBox(height: 12),
                Row(children: [
                  InkWell(onTap: onAuthor, child: Text(article.author, style: const TextStyle(color: _arBlue, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 6),
                  Text(followed ? 'Following · ' : ' · ', style: const TextStyle(color: _arGreen, fontSize: 9)),
                  Text('${article.minutes} min read · ${article.published}', style: const TextStyle(color: _arMuted, fontSize: 9)),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

class _SecondaryArticle extends StatelessWidget {
  const _SecondaryArticle({required this.article, required this.saved, required this.onSave, required this.last});
  final _Article article;
  final bool saved;
  final VoidCallback onSave;
  final bool last;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _openFromContext(context, article),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border(bottom: last ? BorderSide.none : const BorderSide(color: _arLine, width: .5))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 95, height: 78, alignment: Alignment.center, decoration: BoxDecoration(color: article.accent.withValues(alpha: .22), borderRadius: BorderRadius.circular(7)), child: Text(article.section.substring(0, article.section.length.clamp(0, 4)).toUpperCase(), style: TextStyle(color: article.accent, fontWeight: FontWeight.w900))),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(article.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _arText, fontSize: 14, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 5),
              Text('${article.author} · ${article.minutes} min', style: const TextStyle(color: _arMuted, fontSize: 9)),
            ])),
            IconButton(onPressed: onSave, icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved ? _arAmber : _arMuted, size: 18)),
          ]),
        ),
      );
}

class _TopicRail extends StatelessWidget {
  const _TopicRail({required this.section});
  final String section;
  @override
  Widget build(BuildContext context) {
    final topics = switch (section) {
      'NBA' => const ['Trade Market', 'Free Agency', 'Draft', 'Playoffs', 'Salary Cap', 'Awards', 'Analytics', 'Team Rankings'],
      'NFL' => const ['Training Camp', 'Quarterbacks', 'Fantasy', 'Draft', 'Playoffs', 'Contracts', 'Film Room'],
      'MLB' => const ['Trade Deadline', 'Prospects', 'Pitching', 'Statcast', 'Postseason', 'Free Agency'],
      'Premier League' => const ['Transfer Window', 'Tactics', 'Title Race', 'Relegation', 'Champions League', 'Analytics'],
      _ => const ['Breaking News', 'Analysis', 'Rankings', 'Transactions', 'Features', 'Data', 'Interviews'],
    };
    return _ArticlePanel(
      padding: const EdgeInsets.all(10),
      child: Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [const Text('TRENDING', style: TextStyle(color: _arAmber, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8)), for (final topic in topics) ActionChip(label: Text(topic), onPressed: () {})]),
    );
  }
}

class _ArticleList extends StatelessWidget {
  const _ArticleList({required this.title, required this.rows, required this.saved, required this.followedAuthors, required this.onSave, required this.onAuthor});
  final String title;
  final List<_Article> rows;
  final Set<String> saved;
  final Set<String> followedAuthors;
  final ValueChanged<String> onSave;
  final ValueChanged<String> onAuthor;
  @override
  Widget build(BuildContext context) => _ArticlePanel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(color: _arText, fontSize: 22, fontWeight: FontWeight.w900))),
          for (final article in rows)
            InkWell(
              onTap: () => _openFromContext(context, article),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _arLine, width: .5))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 118, height: 92, alignment: Alignment.center, decoration: BoxDecoration(gradient: LinearGradient(colors: [article.accent.withValues(alpha: .55), _arPanel2]), borderRadius: BorderRadius.circular(7)), child: Text(article.visualLabel.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [_Tag(article.section.toUpperCase(), _arBlue), if (article.tags.contains('Exclusive')) ...[const SizedBox(width: 5), const _Tag('EXCLUSIVE', _arAmber)]]),
                    const SizedBox(height: 7),
                    Text(article.title, style: const TextStyle(color: _arText, fontSize: 17, fontWeight: FontWeight.w900, height: 1.2)),
                    const SizedBox(height: 5),
                    Text(article.dek, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _arMuted, fontSize: 11, height: 1.35)),
                    const SizedBox(height: 7),
                    Wrap(spacing: 5, children: [InkWell(onTap: () => onAuthor(article.author), child: Text(article.author, style: TextStyle(color: followedAuthors.contains(article.author) ? _arGreen : _arBlue, fontSize: 9, fontWeight: FontWeight.w900))), Text('· ${article.minutes} min · ${article.published}', style: const TextStyle(color: _arMuted, fontSize: 9))]),
                  ])),
                  IconButton(onPressed: () => onSave(article.id), icon: Icon(saved.contains(article.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved.contains(article.id) ? _arAmber : _arMuted)),
                ]),
              ),
            ),
        ]),
      );
}

class _MostRead extends StatelessWidget {
  const _MostRead({required this.rows, required this.onOpen});
  final List<_Article> rows;
  final ValueChanged<_Article> onOpen;
  @override
  Widget build(BuildContext context) => _ArticlePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MOST READ', style: TextStyle(color: _arAmber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.take(5).length; i++)
            InkWell(onTap: () => onOpen(rows[i]), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _arLine, width: .5))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 26, child: Text('${i + 1}', style: const TextStyle(color: _arAmber, fontSize: 18, fontWeight: FontWeight.w900))), Expanded(child: Text(rows[i].title, style: const TextStyle(color: _arText, fontSize: 11, fontWeight: FontWeight.w800, height: 1.25)))]))),
        ]),
      );
}

class _Writers extends StatelessWidget {
  const _Writers({required this.followed, required this.onToggle});
  final Set<String> followed;
  final ValueChanged<String> onToggle;
  @override
  Widget build(BuildContext context) {
    final authors = _articles.map((item) => item.author).toSet().take(6).toList();
    return _ArticlePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('WRITERS', style: TextStyle(color: _arBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
        const SizedBox(height: 8),
        for (final author in authors)
          Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [CircleAvatar(radius: 14, backgroundColor: _arPanel2, child: Text(_initials(author), style: const TextStyle(color: _arBlue, fontSize: 8, fontWeight: FontWeight.w900))), const SizedBox(width: 8), Expanded(child: Text(author, style: const TextStyle(color: _arText, fontSize: 10, fontWeight: FontWeight.w800))), TextButton(onPressed: () => onToggle(author), child: Text(followed.contains(author) ? 'Following' : 'Follow'))])),
      ]),
    );
  }
}

class _EditorialStandards extends StatelessWidget {
  const _EditorialStandards();
  @override
  Widget build(BuildContext context) => const _ArticlePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EDITORIAL STANDARDS', style: TextStyle(color: _arGreen, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          SizedBox(height: 7),
          Text('Sports Terminal editorial should separate reporting, analysis, opinion and sponsored material; cite or describe sourcing; correct material errors; disclose relevant conflicts; label model-generated analysis; and never fabricate quotations or reporting.', style: TextStyle(color: _arMuted, fontSize: 9.5, height: 1.45)),
        ]),
      );
}

class _NewsletterAndAudio extends StatelessWidget {
  const _NewsletterAndAudio({required this.section});
  final String section;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final newsletter = const _ArticlePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('THE MORNING TERMINAL', style: TextStyle(color: _arAmber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)), SizedBox(height: 6), Text('The most important sports developments, analysis and data context in one concise daily briefing.', style: TextStyle(color: _arText, fontSize: 16, fontWeight: FontWeight.w900, height: 1.25)), SizedBox(height: 10), TextField(decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder())), SizedBox(height: 8), FilledButton(onPressed: null, child: Text('Newsletter signup placeholder'))]));
        final audio = _ArticlePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('AUDIO & CONVERSATION', style: TextStyle(color: _arBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)), const SizedBox(height: 6), Text('$section briefing: reporters, analysts and data researchers discuss what matters beyond the headline.', style: const TextStyle(color: _arText, fontSize: 16, fontWeight: FontWeight.w900, height: 1.25)), const SizedBox(height: 10), const Row(children: [Icon(Icons.play_circle_fill_rounded, color: _arBlue, size: 34), SizedBox(width: 9), Expanded(child: Text('Podcast and live-room infrastructure placeholder', style: TextStyle(color: _arMuted)))]) ]));
        if (constraints.maxWidth < 760) return Column(children: [newsletter, const SizedBox(height: 12), audio]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: newsletter), const SizedBox(width: 12), Expanded(child: audio)]);
      });
}

class _ArticleReader extends StatelessWidget {
  const _ArticleReader({required this.article, required this.followed, required this.onAuthor});
  final _Article article;
  final bool followed;
  final VoidCallback onAuthor;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Tag(article.section.toUpperCase(), _arBlue),
        const SizedBox(height: 14),
        Text(article.title, style: const TextStyle(color: _arText, fontSize: 42, fontWeight: FontWeight.w900, height: 1.03, letterSpacing: -.8)),
        const SizedBox(height: 14),
        Text(article.dek, style: const TextStyle(color: _arMuted, fontSize: 18, height: 1.5)),
        const SizedBox(height: 16),
        Row(children: [CircleAvatar(backgroundColor: article.accent.withValues(alpha: .22), child: Text(_initials(article.author), style: TextStyle(color: article.accent, fontWeight: FontWeight.w900))), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(article.author, style: const TextStyle(color: _arText, fontWeight: FontWeight.w900)), Text('${article.published} · ${article.minutes} min read', style: const TextStyle(color: _arMuted, fontSize: 10))])), TextButton(onPressed: onAuthor, child: Text(followed ? 'Following' : 'Follow writer'))]),
        const SizedBox(height: 18),
        Container(height: 360, width: double.infinity, alignment: Alignment.center, decoration: BoxDecoration(gradient: LinearGradient(colors: [article.accent.withValues(alpha: .6), _arPanel2]), borderRadius: BorderRadius.circular(10)), child: Text(article.visualLabel.toUpperCase(), style: const TextStyle(color: Colors.white30, fontSize: 56, fontWeight: FontWeight.w900))),
        const SizedBox(height: 24),
        for (final paragraph in article.body) ...[
          SelectableText(paragraph, style: const TextStyle(color: _arText, fontSize: 17, height: 1.75)),
          const SizedBox(height: 18),
        ],
        const Divider(color: _arLine),
        const SizedBox(height: 14),
        const Text('Editor’s note: These seeded stories demonstrate the product architecture and editorial reading experience. They are not represented as live reporting.', style: TextStyle(color: _arAmber, fontSize: 10, height: 1.4)),
      ]);
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .4)));
}

class _ArticlePanel extends StatelessWidget {
  const _ArticlePanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _arPanel, border: Border.all(color: _arLine), borderRadius: BorderRadius.circular(9)), child: child);
}

class _Article {
  const _Article({required this.id, required this.section, required this.title, required this.dek, required this.author, required this.minutes, required this.published, required this.tags, required this.readScore, required this.visualLabel, required this.accent, required this.body});
  final String id;
  final String section;
  final String title;
  final String dek;
  final String author;
  final int minutes;
  final String published;
  final List<String> tags;
  final int readScore;
  final String visualLabel;
  final Color accent;
  final List<String> body;
}

Future<void> _openFromContext(BuildContext context, _Article article) async {
  await showDialog<void>(context: context, builder: (dialogContext) => Dialog.fullscreen(child: Scaffold(backgroundColor: const Color(0xFF07111F), appBar: AppBar(backgroundColor: _arPanel, foregroundColor: Colors.white, leading: IconButton(onPressed: () => Navigator.of(dialogContext).pop(), icon: const Icon(Icons.close_rounded)), title: Text(article.section)), body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 28, 22, 80), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: _ArticleReader(article: article, followed: false, onAuthor: () {})))))));
}

String _initials(String value) => value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0].toUpperCase()).join();

const _bodyA = <String>[
  'Sports Terminal stories are designed to live beside the underlying data rather than on an island. A reader should be able to move from a claim in an article to the player, team, game, trade or model that supports the analysis.',
  'This seeded feature demonstrates the editorial reading system: a strong headline hierarchy, contextual byline, long-form typography, save/follow behavior, sport-specific discovery and room for attached charts or research objects.',
  'The production editorial system can replace this demonstration copy with reported stories, editor-reviewed analysis and authenticated author workflows without changing the reading architecture.',
];

const _articles = <_Article>[
  _Article(id:'nba-1',section:'NBA',title:'The next NBA roster-building edge is hidden in the middle of the cap sheet',dek:'Second-apron constraints are changing how front offices value mid-sized contracts, flexible roster spots and future optionality.',author:'Maya Chen',minutes:9,published:'Today',tags:['Analysis','Salary Cap','Exclusive'],readScore:99,visualLabel:'NBA CAP',accent:Color(0xFF63A9FF),body:_bodyA),
  _Article(id:'nba-2',section:'NBA',title:'What the league’s most versatile defenses are asking wings to do now',dek:'Tracking responsibilities, switching, screen navigation and weak-side reads are converging into a different kind of perimeter role.',author:'Jordan Ellis',minutes:7,published:'Today',tags:['Analysis','Data'],readScore:93,visualLabel:'DEFENSE',accent:Color(0xFF69C99A),body:_bodyA),
  _Article(id:'wnba-1',section:'WNBA',title:'The WNBA spacing revolution is creating new decisions for every help defender',dek:'A film-and-data look at how shooting range and pace are changing half-court geometry.',author:'Avery Brooks',minutes:8,published:'Today',tags:['Analysis','Data'],readScore:88,visualLabel:'WNBA',accent:Color(0xFFE2B866),body:_bodyA),
  _Article(id:'nfl-1',section:'NFL',title:'The quarterback development plans that survive real NFL pressure',dek:'Why the best organizations are coordinating protection, route structure and teaching progression instead of isolating the quarterback.',author:'Nate Coleman',minutes:11,published:'1h ago',tags:['Long-form','Analysis'],readScore:96,visualLabel:'NFL',accent:Color(0xFF8BC1FF),body:_bodyA),
  _Article(id:'nhl-1',section:'NHL',title:'Puck movement before the shot: the passing patterns driving modern NHL offense',dek:'The scoring chance often begins two decisions before the attempt itself.',author:'Elena Petrov',minutes:6,published:'2h ago',tags:['Analysis','Data'],readScore:78,visualLabel:'NHL',accent:Color(0xFF69C99A),body:_bodyA),
  _Article(id:'mlb-1',section:'MLB',title:'Why contender bullpens are being built around shapes, not just velocity',dek:'Pitch movement profiles and matchup flexibility are changing deadline valuation.',author:'Luis Ortega',minutes:10,published:'3h ago',tags:['Analysis','Data'],readScore:91,visualLabel:'MLB',accent:Color(0xFFE57D7D),body:_bodyA),
  _Article(id:'ncaam-1',section:'NCAAM',title:'College basketball’s transfer market has made continuity a competitive advantage again',dek:'The programs winning roster churn are developing repeatable systems, not simply accumulating talent.',author:'Samir Patel',minutes:7,published:'4h ago',tags:['Analysis','Roster'],readScore:74,visualLabel:'NCAAM',accent:Color(0xFF63A9FF),body:_bodyA),
  _Article(id:'ncaaw-1',section:'NCAAW',title:'How elite women’s programs are creating offense from defensive versatility',dek:'Transition opportunities increasingly begin with lineups that can switch and rebound without substitutions.',author:'Rachel Kim',minutes:8,published:'5h ago',tags:['Analysis','Data'],readScore:77,visualLabel:'NCAAW',accent:Color(0xFFE2B866),body:_bodyA),
  _Article(id:'cfb-1',section:'College Football',title:'The hidden roster math behind modern college football depth charts',dek:'Eligibility, transfers and position flexibility have made multi-year depth planning a front-office discipline.',author:'Nate Coleman',minutes:12,published:'Today',tags:['Long-form','Roster'],readScore:85,visualLabel:'CFB',accent:Color(0xFF69C99A),body:_bodyA),
  _Article(id:'tennis-1',section:'Tennis',title:'The return position battle is redefining who controls the first four shots',dek:'Serve speed matters, but court position and return height are changing the geometry of elite points.',author:'Isabel Martin',minutes:6,published:'Today',tags:['Analysis','Data'],readScore:70,visualLabel:'TENNIS',accent:Color(0xFF63A9FF),body:_bodyA),
  _Article(id:'mls-1',section:'MLS',title:'MLS clubs are building scouting models around role translation, not league labels',dek:'The challenge is less “Can he play here?” and more “What changes when his responsibilities change?”',author:'Diego Alvarez',minutes:9,published:'Yesterday',tags:['Scouting','Analysis'],readScore:71,visualLabel:'MLS',accent:Color(0xFF69C99A),body:_bodyA),
  _Article(id:'epl-1',section:'Premier League',title:'The Premier League transfer window is becoming a portfolio-management problem',dek:'Clubs are balancing age curves, resale value, squad rules and tactical fit in increasingly explicit models.',author:'Amelia Wright',minutes:10,published:'Today',tags:['Transfers','Analysis','Exclusive'],readScore:97,visualLabel:'PL',accent:Color(0xFFE2B866),body:_bodyA),
  _Article(id:'ucl-1',section:'Champions League',title:'Why Champions League knockout ties are decided by pressure escapes',dek:'The teams that survive elite pressing are creating numerical advantages before the final third.',author:'Amelia Wright',minutes:7,published:'Yesterday',tags:['Tactics','Analysis'],readScore:82,visualLabel:'UCL',accent:Color(0xFF63A9FF),body:_bodyA),
  _Article(id:'f1-1',section:'Formula 1',title:'The undercut is only the visible part of Formula 1’s strategy problem',dek:'Tire state, traffic probability and pit-loss distributions turn race strategy into a live optimization exercise.',author:'Theo Grant',minutes:9,published:'Yesterday',tags:['Analysis','Data'],readScore:80,visualLabel:'F1',accent:Color(0xFFE57D7D),body:_bodyA),
  _Article(id:'golf-1',section:'Golf',title:'Approach-shot dispersion is changing how elite golf is evaluated',dek:'Averages hide the shape of misses; contenders are increasingly separated by the quality of their bad outcomes.',author:'Claire Morgan',minutes:6,published:'2d ago',tags:['Analysis','Data'],readScore:65,visualLabel:'GOLF',accent:Color(0xFF69C99A),body:_bodyA),
];
