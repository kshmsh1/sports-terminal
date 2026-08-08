import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/route_payload_controller.dart';
import '../models/app_session.dart';
import '../models/route_payload.dart';
import '../services/product_local_store.dart';
import '../services/python_runtime_service.dart';

const _nBg = Color(0xFF090D12);
const _nPanel = Color(0xFF0F151C);
const _nPanel2 = Color(0xFF141C25);
const _nLine = Color(0xFF263342);
const _nText = Color(0xFFE8EDF3);
const _nMuted = Color(0xFF8895A5);
const _nBlue = Color(0xFF63A9FF);
const _nGreen = Color(0xFF69C99A);
const _nAmber = Color(0xFFE2B866);

class ProductConnectedDataStudioScreen extends StatefulWidget {
  const ProductConnectedDataStudioScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<ProductConnectedDataStudioScreen> createState() => _ProductConnectedDataStudioScreenState();
}

class _NotebookCell {
  _NotebookCell({required this.id, required String code}) : controller = TextEditingController(text: code);
  final String id;
  final TextEditingController controller;
  String output = '';
  String status = 'Not run';
  int durationMs = 0;
}

class _ProductConnectedDataStudioScreenState extends State<ProductConnectedDataStudioScreen> {
  final store = const ProductLocalStore();
  final runtime = const PythonRuntimeService();
  final cells = <_NotebookCell>[];
  bool loaded = false;
  bool runningAll = false;
  Map<String,dynamic>? capabilities;
  int nextId = 1;

  @override
  void initState() { super.initState(); _restore(); _loadCapabilities(); }
  @override
  void dispose() { for (final cell in cells) cell.controller.dispose(); super.dispose(); }

  Future<void> _restore() async {
    final raw = await store.loadString(ProductLocalStore.pythonNotebookCodeKey);
    var codes = <String>[];
    if (raw.trim().startsWith('[')) {
      try { final decoded = jsonDecode(raw); if (decoded is List) codes = decoded.map((v) => v.toString()).toList(); } catch (_) {}
    }
    if (codes.isEmpty) codes = [raw.trim().isEmpty ? _starter : raw];
    for (final code in codes) cells.add(_NotebookCell(id: 'cell-${nextId++}', code: code));
    if (!mounted) return;
    setState(() => loaded = true);
  }

  Future<void> _loadCapabilities() async {
    final value = await runtime.capabilities();
    if (!mounted) return;
    setState(() => capabilities = value);
  }

  Future<void> _persist() => store.saveString(ProductLocalStore.pythonNotebookCodeKey, jsonEncode([for (final cell in cells) cell.controller.text]));

  void _addCell({String code = ''}) {
    setState(() => cells.add(_NotebookCell(id: 'cell-${nextId++}', code: code)));
    _persist();
  }

  void _removeCell(_NotebookCell cell) {
    if (cells.length == 1) return;
    setState(() { cells.remove(cell); cell.controller.dispose(); });
    _persist();
  }

  Future<void> _runCell(_NotebookCell cell, RoutePayload? payload) async {
    setState(() { cell.status = 'Running'; cell.output = 'Submitting to isolated Python runtime…'; });
    final result = await runtime.execute(code: cell.controller.text, payload: payload);
    if (!mounted) return;
    final lines = <String>[];
    if (result.completed) {
      if (result.stdout.trim().isNotEmpty) lines.add(result.stdout.trimRight());
      if (result.result != null) {
        if (lines.isNotEmpty) lines.add('');
        lines.add(const JsonEncoder.withIndent('  ').convert(result.result));
      }
      if (lines.isEmpty) lines.add('Cell completed with no display output.');
    } else {
      lines.add(result.available ? 'CELL REJECTED' : 'PYTHON RUNTIME OFFLINE');
      lines.add(result.error);
    }
    setState(() { cell.status = result.completed ? 'Completed' : result.available ? 'Rejected' : 'Offline'; cell.durationMs = result.durationMs; cell.output = lines.join('\n'); });
    await _persist();
  }

  Future<void> _runAll(RoutePayload? payload) async {
    setState(() => runningAll = true);
    for (final cell in cells) { await _runCell(cell, payload); if (!mounted) return; }
    if (mounted) setState(() => runningAll = false);
  }

  void _clearOutputs() => setState(() { for (final cell in cells) { cell.output = ''; cell.status = 'Not run'; cell.durationMs = 0; } });

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const _NotebookPanel(child: Center(child: CircularProgressIndicator()));
    final payload = RoutePayloadScope.maybeOf(context)?.activePayload;
    return ColoredBox(color: _nBg, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _NotebookPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PYTHON LAB / NOTEBOOK', style: TextStyle(color:_nBlue,fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1)), SizedBox(height:6), Text('A persistent multi-cell sports analysis notebook', style: TextStyle(color:_nText,fontSize:27,fontWeight:FontWeight.w900))])),
          _Status(capabilities == null ? 'RUNTIME OFFLINE' : 'ISOLATED PYTHON', capabilities == null ? _nAmber : _nGreen),
        ]),
        const SizedBox(height:8),
        Text(payload == null ? 'No routed dataset is active. Cells can still run pure sandbox calculations.' : 'Active dataset: ${payload.displayLabel} · ${payload.rowCount} rows · ${payload.columnCount} columns', style: const TextStyle(color:_nMuted,height:1.4)),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:[
          FilledButton.icon(onPressed: runningAll ? null : () => _runAll(payload), icon: runningAll ? const SizedBox(width:15,height:15,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.play_arrow_rounded), label: const Text('Run all')),
          OutlinedButton.icon(onPressed: () => _addCell(), icon: const Icon(Icons.add_rounded), label: const Text('Add code cell')),
          OutlinedButton.icon(onPressed: () => _addCell(code:_analysisStarter), icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Add analysis starter')),
          OutlinedButton.icon(onPressed:_clearOutputs, icon: const Icon(Icons.cleaning_services_outlined), label: const Text('Clear outputs')),
        ]),
      ])),
      const SizedBox(height:12),
      for (var index=0; index<cells.length; index++) ...[
        _CodeCell(index:index+1, cell:cells[index], payload:payload, onRun:()=>_runCell(cells[index],payload), onRemove:()=>_removeCell(cells[index]), onChanged:_persist),
        const SizedBox(height:12),
      ],
      _NotebookPanel(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('NOTEBOOK ENVIRONMENT',style:TextStyle(color:_nText,fontSize:15,fontWeight:FontWeight.w900)), const SizedBox(height:7),
        const Text('The backend runtime is intentionally bounded: notebook code runs in an isolated server process with restricted syntax and without arbitrary filesystem, network, process or package-import access. Routed sports data is supplied as a structured payload. Approved helpers can be expanded deliberately rather than exposing the host environment.',style:TextStyle(color:_nMuted,height:1.5)),
        const SizedBox(height:9),
        Wrap(spacing:7,runSpacing:7,children:const [_Status('PERSISTENT CELLS',_nBlue),_Status('ROUTED DATA',_nBlue),_Status('STRUCTURED RESULTS',_nGreen),_Status('COPY OUTPUT',_nGreen),_Status('BOUNDED EXECUTION',_nAmber)]),
      ])),
    ]));
  }
}

class _CodeCell extends StatelessWidget {
  const _CodeCell({required this.index,required this.cell,required this.payload,required this.onRun,required this.onRemove,required this.onChanged});
  final int index; final _NotebookCell cell; final RoutePayload? payload; final VoidCallback onRun,onRemove; final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => _NotebookPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Text('In [$index]',style:const TextStyle(color:_nBlue,fontFamily:'monospace',fontWeight:FontWeight.w900)),const Spacer(),Text('${cell.status}${cell.durationMs>0?' · ${cell.durationMs} ms':''}',style:const TextStyle(color:_nMuted,fontSize:10)),IconButton(tooltip:'Run cell',onPressed:onRun,icon:const Icon(Icons.play_arrow_rounded,color:_nGreen)),IconButton(tooltip:'Delete cell',onPressed:onRemove,icon:const Icon(Icons.delete_outline_rounded,color:_nMuted))]),
    TextField(controller:cell.controller,minLines:8,maxLines:28,onChanged:(_)=>onChanged(),style:const TextStyle(color:Color(0xFFE6EDF7),fontFamily:'monospace',fontSize:12.5,height:1.5),decoration:const InputDecoration(filled:true,fillColor:Color(0xFF08111F),border:OutlineInputBorder(borderSide:BorderSide(color:_nLine)))),
    const SizedBox(height:10),
    Row(children:[const Text('Out',style:TextStyle(color:_nAmber,fontFamily:'monospace',fontWeight:FontWeight.w900)),const Spacer(),IconButton(tooltip:'Copy output',onPressed:cell.output.isEmpty?null:()=>Clipboard.setData(ClipboardData(text:cell.output)),icon:const Icon(Icons.copy_all_rounded,color:_nMuted))]),
    Container(width:double.infinity,constraints:const BoxConstraints(minHeight:90),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF08111F),border:Border.all(color:_nLine)),child:SelectableText(cell.output.isEmpty?'Run this cell to display its execution output here.':cell.output,style:TextStyle(color:cell.output.isEmpty?_nMuted:_nText,fontFamily:'monospace',fontSize:12,height:1.5))),
  ]));
}

class _NotebookPanel extends StatelessWidget { const _NotebookPanel({required this.child}); final Widget child; @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_nPanel,border:Border.all(color:_nLine)),child:child); }
class _Status extends StatelessWidget { const _Status(this.text,this.color); final String text; final Color color; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:_nPanel2,border:Border.all(color:color.withValues(alpha:.55)),borderRadius:BorderRadius.circular(999)),child:Text(text,style:TextStyle(color:color,fontSize:8,fontWeight:FontWeight.w900))); }

const _starter = """# Sports Terminal Python Lab\n# Routed rows are available through the sandbox data helpers.\nvalues = numeric('PTS')\nresult = {\n    'count': len(values),\n    'mean': mean(values) if values else None,\n    'median': median(values) if values else None,\n}\n""";
const _analysisStarter = """# Example grouped sports analysis\nresult = {\n    'rows': len(rows),\n    'columns': columns,\n}\n""";
