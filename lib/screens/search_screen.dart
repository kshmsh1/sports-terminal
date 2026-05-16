import 'package:flutter/material.dart';

import '../data/search_index_items.dart';
import '../widgets/terminal_primitives.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final results = normalizedQuery.isEmpty
        ? terminalSearchItems
        : terminalSearchItems.where((item) {
            return item.title.toLowerCase().contains(normalizedQuery) ||
                item.category.toLowerCase().contains(normalizedQuery) ||
                item.target.toLowerCase().contains(normalizedQuery) ||
                item.description.toLowerCase().contains(normalizedQuery) ||
                item.status.toLowerCase().contains(normalizedQuery);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Search',
          subtitle: 'Early command-search surface for teams, seasons, datasets, governance pages, architecture pages, and future player records.',
        ),
        const SizedBox(height: 22),
        TerminalCard(
          child: TextField(
            autofocus: false,
            onChanged: (value) => setState(() => query = value),
            style: const TextStyle(color: Colors.white),
            cursorColor: terminalAccent,
            decoration: InputDecoration(
              hintText: 'Search teams, seasons, schema, roadmap, source policy...',
              hintStyle: const TextStyle(color: terminalTextMuted),
              prefixIcon: const Icon(Icons.search, color: terminalTextMuted),
              filled: true,
              fillColor: terminalPanelDark,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: terminalBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: terminalAccent),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 2.0 : 1.5,
              children: [
                _SearchMetric(label: 'Indexed Items', value: '${terminalSearchItems.length}', detail: 'Initial search map'),
                _SearchMetric(label: 'Results', value: '${results.length}', detail: normalizedQuery.isEmpty ? 'Showing all' : 'Filtered'),
                const _SearchMetric(label: 'Mode', value: 'Local', detail: 'No backend required'),
                const _SearchMetric(label: 'Future', value: 'Command', detail: 'Jump navigation later'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        TerminalCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Text(
                      'Search Results',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text('${results.length} results', style: const TextStyle(color: terminalTextMuted)),
                  ],
                ),
              ),
              const Divider(height: 1, color: terminalBorder),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(terminalPanelDark),
                  headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
                  dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
                  columnSpacing: 30,
                  columns: const [
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Target')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Description')),
                  ],
                  rows: [
                    for (final item in results)
                      DataRow(
                        cells: [
                          DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
                          DataCell(Text(item.category)),
                          DataCell(Text(item.target)),
                          DataCell(InfoPill(label: item.status)),
                          DataCell(SizedBox(width: 650, child: Text(item.description))),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchMetric extends StatelessWidget {
  const _SearchMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
        ],
      ),
    );
  }
}
