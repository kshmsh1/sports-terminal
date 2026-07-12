import 'package:flutter/material.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF6F8FC);

class ProductPythonDevLabScreen extends StatefulWidget {
  const ProductPythonDevLabScreen({super.key});

  @override
  State<ProductPythonDevLabScreen> createState() => _ProductPythonDevLabScreenState();
}

class _ProductPythonDevLabScreenState extends State<ProductPythonDevLabScreen> {
  late final TextEditingController controller;
  String console = 'Ready. This embedded notebook shell is the product UI scaffold; real Python execution should be powered by Pyodide in-browser or a sandboxed backend kernel.';

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: _starterCode);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _runDemo() {
    setState(() {
      console = 'Demo run complete.\n\nLoaded resource: NBA 2024-25 generated seed assets\nExample dataframe: player_season_totals\nExample chart: PPG trend placeholder\n\nNext implementation: attach Pyodide or a sandboxed Python kernel, expose pandas/matplotlib helpers, and allow workbook/table exports.';
    });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _HeroBand(),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final editor = _Editor(controller: controller, onRun: _runDemo);
          final resources = _Resources(console: console);
          if (compact) return Column(children: [editor, const SizedBox(height: 18), resources]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: editor), const SizedBox(width: 18), Expanded(flex: 2, child: resources)]);
        }),
        const SizedBox(height: 18),
        const _DocsPanel(),
      ]);
}

class _HeroBand extends StatelessWidget {
  const _HeroBand();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: const LinearGradient(colors: [_navy, _blue, _orange]), boxShadow: const [BoxShadow(color: Color(0x24071A33), blurRadius: 32, offset: Offset(0, 16))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('PYTHON DEV LAB', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
          SizedBox(height: 12),
          Text('A built-in analytics notebook for sports data.', style: TextStyle(color: Colors.white, fontSize: 39, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          SizedBox(height: 12),
          SizedBox(width: 880, child: Text('The long-term Sports Terminal should include an embedded Python environment with pandas-style dataframes, matplotlib-style charts, saved notebooks, table imports from NBA pages, and exports back to the Excel-like workspace.', style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
          SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [_GlassChip('PYTHON'), _GlassChip('PANDAS'), _GlassChip('CHARTS'), _GlassChip('WORKBOOK EXPORT'), _GlassChip('DOCUMENTATION')]),
        ]),
      );
}

class _Editor extends StatelessWidget {
  const _Editor({required this.controller, required this.onRun});
  final TextEditingController controller;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: _SectionHeader('Notebook editor', 'Prototype editor with starter code and a demo run path.')), FilledButton.icon(onPressed: onRun, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Run demo'))]),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            maxLines: 20,
            style: const TextStyle(fontFamily: 'monospace', color: _ink, fontSize: 13, height: 1.35),
            decoration: InputDecoration(filled: true, fillColor: const Color(0xFF0B1220), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), hintText: 'Write Python here...'),
          ),
        ]),
      );
}

class _Resources extends StatelessWidget {
  const _Resources({required this.console});
  final String console;

  @override
  Widget build(BuildContext context) => Column(children: [
        _Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionHeader('Console', 'Execution output, errors, chart links, and exported datasets will appear here.'),
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0B1220), borderRadius: BorderRadius.circular(18)), child: Text(console, style: const TextStyle(color: Color(0xFFEAF2FF), fontFamily: 'monospace', height: 1.35))),
          ]),
        ),
        const SizedBox(height: 18),
        const _Surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionHeader('Available data resources', 'Product-level resources the notebook should eventually expose.'),
            SizedBox(height: 12),
            _ResourceRow('player_season_totals', 'Season player summaries and stat columns'),
            _ResourceRow('team_game_logs', 'Team-by-game results and scoring context'),
            _ResourceRow('player_game_logs_top', 'Top player game rows and recent form analysis'),
            _ResourceRow('play_by_play_events', 'Possession/event analysis and lineup tools'),
            _ResourceRow('workbook_tables', 'User-created tables from the Excel-like workspace'),
          ]),
        ),
      ]);
}

class _DocsPanel extends StatelessWidget {
  const _DocsPanel();

  @override
  Widget build(BuildContext context) => const _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionHeader('How users should use the Python lab', 'Documentation built into the product, not hidden in a repo README.'),
          SizedBox(height: 12),
          _ChecklistItem('Start from a table imported from NBA Stats, Player Dashboard, Trade Machine, or Workspace.'),
          _ChecklistItem('Use pandas-style transforms to filter, rank, group, and calculate custom metrics.'),
          _ChecklistItem('Create matplotlib-style visuals for trends, shot profiles, lineup changes, and player comparisons.'),
          _ChecklistItem('Export results back into the workbook, attach them to an article, or share the output to a community thread.'),
          _ChecklistItem('Execution must eventually be sandboxed, quota-limited, and safe before being available to public users.'),
        ]),
      );
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow(this.name, this.description);
  final String name;
  final String description;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))), child: Row(children: [Expanded(child: Text(name, style: const TextStyle(color: _ink, fontFamily: 'monospace', fontWeight: FontWeight.w900))), Expanded(child: Text(description, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)))]));
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_rounded, color: _green, size: 18), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700)))]));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600))]);
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.26))), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)));
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 22, offset: Offset(0, 10))]), child: child);
}

const _starterCode = '''# Sports Terminal Python Lab starter notebook
# Future execution target: Pyodide in-browser or sandboxed backend kernel

import pandas as pd
import matplotlib.pyplot as plt

players = st.load_table("player_season_totals")
leaders = (
    players
    .query("points_per_game > 15")
    .sort_values("points_per_game", ascending=False)
    .head(20)
)

st.display(leaders)
st.plot_bar(leaders, x="player_label", y="points_per_game", title="Top scoring targets")
st.export_to_workspace(leaders, sheet="Scoring Board")
''';
