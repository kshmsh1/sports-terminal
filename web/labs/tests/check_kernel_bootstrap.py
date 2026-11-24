"""Syntax-check the Python bootstrap inside the browser worker."""
from pathlib import Path

worker = Path(__file__).resolve().parents[1] / "python" / "kernel.worker.js"
source = worker.read_text(encoding="utf-8")
start_marker = "py.runPython(String.raw" + chr(96)
end_marker = chr(96) + ");"
start = source.index(start_marker) + len(start_marker)
end = source.index(end_marker, start)
bootstrap = source[start:end]
compile(bootstrap, "<arcside-pyodide-bootstrap>", "exec")
assert "_arcside_execute" in bootstrap
assert "_arcside_analyze" in bootstrap
print("Python worker bootstrap parses successfully")
