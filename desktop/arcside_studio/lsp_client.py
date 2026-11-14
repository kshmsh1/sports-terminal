"""Optional local Python Language Server Protocol client (python-lsp-server).

Uses one QProcess for stdio JSON-RPC; no cloud service, telemetry or keys.
Supports diagnostics and completion only when pylsp is installed in the chosen
Python interpreter. Failures do not prevent local Python execution.
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from PySide6.QtCore import QObject, QProcess, Signal

try:
    from .jsonrpc import encode, extract
except ImportError:
    from jsonrpc import encode, extract


class PylspClient(QObject):
    ready = Signal()
    diagnostics = Signal(str, list)
    completions = Signal(list)
    notice = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.process: QProcess | None = None
        self.buffer = bytearray()
        self.counter = 0
        self.initialized = False
        self.pending: dict[int, str] = {}
        self.opened: dict[str, int] = {}
        self.root: Path | None = None

    def start(self, python: str, project: Path):
        self.stop()
        self.root = project
        self.buffer.clear()
        self.counter = 0
        self.initialized = False
        self.opened.clear()
        self.pending.clear()
        self.process = QProcess(self)
        self.process.setProgram(python)
        self.process.setArguments(["-m", "pylsp"])
        self.process.setWorkingDirectory(str(project))
        self.process.readyReadStandardOutput.connect(self._receive)
        self.process.readyReadStandardError.connect(self._stderr)
        self.process.started.connect(self._initialize)
        self.process.errorOccurred.connect(self._failure)
        self.process.start()

    def stop(self):
        if self.process and self.process.state() == QProcess.Running:
            try:
                self._notify("exit", {})
            except Exception:
                pass
            self.process.terminate()
            if not self.process.waitForFinished(800):
                self.process.kill()
        self.process = None
        self.initialized = False

    def _failure(self, error):
        self.notice.emit("Language server unavailable; syntax checks and local runs still work.")

    def _stderr(self):
        if not self.process: return
        message = bytes(self.process.readAllStandardError()).decode(
            "utf-8", errors="replace").strip()
        if message and "No module named" in message:
            self.notice.emit("Install python-lsp-server in this interpreter for LSP completion.")

    def _send(self, payload: dict[str, Any]):
        if self.process and self.process.state() == QProcess.Running:
            self.process.write(encode(payload))

    def _request(self, method: str, params: dict) -> int:
        self.counter += 1
        request_id = self.counter
        self.pending[request_id] = method
        self._send({"jsonrpc": "2.0", "id": request_id,
                    "method": method, "params": params})
        return request_id

    def _notify(self, method: str, params: dict):
        self._send({"jsonrpc": "2.0", "method": method, "params": params})

    def _initialize(self):
        if self.root is None: return
        self._request("initialize", {
            "processId": os.getpid(),
            "rootUri": self.root.resolve().as_uri(),
            "capabilities": {
                "textDocument": {
                    "publishDiagnostics": {},
                    "completion": {"completionItem": {"snippetSupport": False}},
                },
            },
            "workspaceFolders": [
                {"uri": self.root.resolve().as_uri(),
                 "name": self.root.name}
            ],
            "trace": "off",
        })

    def _receive(self):
        if self.process is None: return
        self.buffer.extend(bytes(self.process.readAllStandardOutput()))
        try:
            messages = extract(self.buffer)
        except (ValueError, UnicodeError, Exception) as error:
            self.notice.emit(f"Language-server protocol error: {error}")
            self.buffer.clear()
            return
        for message in messages:
            method = message.get("method")
            if method == "textDocument/publishDiagnostics":
                params = message.get("params", {})
                self.diagnostics.emit(params.get("uri", ""),
                                      params.get("diagnostics", []))
            elif "id" in message:
                request_id = message["id"]
                original = self.pending.pop(request_id, "")
                if original == "initialize":
                    if "error" not in message:
                        self.initialized = True
                        self._notify("initialized", {})
                        self.ready.emit()
                elif original == "textDocument/completion":
                    response = message.get("result") or []
                    items = response.get("items", []) if isinstance(response, dict) else response
                    labels = [str(item.get("label", ""))
                              for item in items if isinstance(item, dict)]
                    self.completions.emit([label for label in labels if label][:100])

    def open_document(self, path: Path, text: str):
        if not self.initialized: return
        uri = path.resolve().as_uri()
        if uri in self.opened:
            self.change_document(path, text)
            return
        self.opened[uri] = 1
        self._notify("textDocument/didOpen", {
            "textDocument": {"uri": uri, "languageId": "python",
                             "version": 1, "text": text},
        })

    def change_document(self, path: Path, text: str):
        if not self.initialized: return
        uri = path.resolve().as_uri()
        if uri not in self.opened:
            self.open_document(path, text)
            return
        version = self.opened[uri] + 1
        self.opened[uri] = version
        self._notify("textDocument/didChange", {
            "textDocument": {"uri": uri, "version": version},
            "contentChanges": [{"text": text}],
        })

    def close_document(self, path: Path):
        uri = path.resolve().as_uri()
        if uri not in self.opened: return
        self.opened.pop(uri)
        self._notify("textDocument/didClose", {
            "textDocument": {"uri": uri},
        })

    def request_completion(self, path: Path, line: int, character: int):
        if not self.initialized: return
        uri = path.resolve().as_uri()
        if uri in self.opened:
            self._request("textDocument/completion", {
                "textDocument": {"uri": uri},
                "position": {"line": line, "character": character},
                "context": {"triggerKind": 1},
            })
