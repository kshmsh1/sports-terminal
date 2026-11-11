/* Python runs in this disposable Web Worker, never in Arcside's server.
 * The worker can be terminated if code stalls; normal browser resource
 * limits apply. A browser worker is NOT a hardened untrusted-code sandbox. */
const VERSION = '0.29.4';
const CDN = 'https://cdn.jsdelivr.net/pyodide/v' + VERSION + '/full/';
let python = null;
let activeId = null;
const send = (type, extra = {}) => self.postMessage({type, id: activeId, ...extra});

async function init() {
  try {
    importScripts(CDN + 'pyodide.js');
    python = await loadPyodide({indexURL: CDN});
    python.FS.mkdirTree('/home/pyodide/arcside');
    python.FS.chdir('/home/pyodide/arcside');
    python.setStdout({batched: message => send('stdout', {message: message + '\n'})});
    python.setStderr({batched: message => send('stderr', {message: message + '\n'})});
    send('ready', {version: python.runPython('import sys;sys.version.split()[0]')});
  } catch (error) {
    send('fatal', {error: String(error)});
  }
}
function writeProjectFiles(files) {
  for (const [name, text] of Object.entries(files || {})) {
    if (!/^[a-zA-Z0-9_][\w .-]{0,110}\.(py|csv|txt|json|md|tsv)$/i.test(name)) continue;
    python.FS.writeFile('/home/pyodide/arcside/' + name, text, {encoding: 'utf8'});
  }
}
function variableSummary() {
  try {
    return JSON.parse(python.runPython(
      "import json\n" +
      "def _arcside_safe_vars():\n" +
      " out = {}\n" +
      " for k,v in globals().items():\n" +
      "  if k.startswith('_') or k in ('json','sys','__builtins__'): continue\n" +
      "  try:\n" +
      "   if callable(v): continue\n" +
      "   s = repr(v)\n" +
      "   out[k] = {'type': type(v).__name__, 'value': s[:280] + ('…' if len(s)>280 else '')}\n" +
      "  except Exception: out[k] = {'type':'unknown','value':'<unavailable>'}\n" +
      " return json.dumps(dict(list(out.items())[:75]))\n" +
      "_arcside_safe_vars()"
    ));
  } catch (_) { return {}; }
}
function figureImages() {
  try {
    return JSON.parse(python.runPython(
      "import sys, json\n" +
      "def _arcside_figures():\n" +
      " if 'matplotlib.pyplot' not in sys.modules: return '[]'\n" +
      " import io, base64\n" +
      " plt = sys.modules['matplotlib.pyplot']\n" +
      " images = []\n" +
      " for num in plt.get_fignums()[:12]:\n" +
      "  buf=io.BytesIO()\n" +
      "  plt.figure(num).savefig(buf, format='png', dpi=115, bbox_inches='tight')\n" +
      "  images.append(base64.b64encode(buf.getvalue()).decode('ascii'))\n" +
      " plt.close('all')\n" +
      " return json.dumps(images)\n" +
      "_arcside_figures()"
    ));
  } catch (_) { return []; }
}
function beginTrace(breakpoints) {
  const source =
    "import sys, json\n" +
    "__arcside_trace = []\n" +
    "__arcside_lines = set(json.loads(__arcside_breakpoint_json))\n" +
    "def __arcside_trace_handler(frame,event,arg):\n" +
    " if event != 'line': return __arcside_trace_handler\n" +
    " if frame.f_code.co_filename not in ('<exec>','<string>','<arcside>'): return __arcside_trace_handler\n" +
    " if __arcside_lines and frame.f_lineno not in __arcside_lines: return __arcside_trace_handler\n" +
    " if len(__arcside_trace) >= 500: return __arcside_trace_handler\n" +
    " loc={}\n" +
    " for k,v in list(frame.f_locals.items())[:30]:\n" +
    "  if k.startswith('__'): continue\n" +
    "  try: loc[k]=repr(v)[:200]\n" +
    "  except Exception: loc[k]='<unavailable>'\n" +
    " __arcside_trace.append({'line':frame.f_lineno,'locals':loc})\n" +
    " return __arcside_trace_handler\n" +
    "sys.settrace(__arcside_trace_handler)\n";
  python.globals.set('__arcside_breakpoint_json', JSON.stringify(breakpoints || []));
  python.runPython(source);
}
function endTrace() {
  try {
    python.runPython('sys.settrace(None)');
    return JSON.parse(python.runPython(
      "json.dumps(__arcside_trace if '__arcside_trace' in globals() else [])"));
  } catch (_) { return []; }
}
async function handle(message) {
  activeId = message.id;
  const started = performance.now();
  try {
    if (!python) throw Error('Python runtime is not initialized');
    if (message.type === 'packages') {
      send('stdout', {message: 'Installing compatible scientific packages (browser download)…\n'});
      await python.loadPackage(['numpy', 'pandas', 'scipy', 'matplotlib', 'scikit-learn']);
      send('packagesReady');
      return;
    }
    if (message.type === 'syntax') {
      python.globals.set('__arcside_source', message.code || '');
      python.runPython("compile(__arcside_source, '<arcside>', 'exec')");
      send('syntax', {ok: true, elapsed: performance.now() - started});
      return;
    }
    if (message.type === 'execute') {
      const code = String(message.code || '');
      if (code.length > 400000) throw Error('File too large for the browser lab (400 KB per run).');
      writeProjectFiles(message.files);
      send('status', {message: 'Resolving browser packages…'});
      await python.loadPackagesFromImports(code);
      send('status', {message: message.trace ? 'Recording trace…' : 'Running…'});
      let traces = [];
      if (message.trace) beginTrace(message.breakpoints);
      try {
        const value = await python.runPythonAsync(code);
        if (value !== undefined && value !== null) {
          const repr = typeof value === 'object' ? String(value) : String(value);
          send('result', {message: repr.substring(0, 50000)});
        }
      } finally {
        if (message.trace) traces = endTrace();
      }
      send('done', {elapsed: performance.now() - started,
        variables: variableSummary(), figures: figureImages(), traces});
    }
  } catch (error) {
    // Reset a trace hook after exceptions, including SyntaxError and imported
    // library exceptions; retain the actual Python traceback in stderr.
    try { if (python) python.runPython('import sys;sys.settrace(None)'); } catch (_) {}
    send('error', {error: String(error), elapsed: performance.now() - started});
  }
}
self.onmessage = event => { void handle(event.data); };
void init();