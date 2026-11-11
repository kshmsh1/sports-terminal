"""Minimal local Language Server Protocol client for Arcside Python Lab.

Optional dependency: pip install python-lsp-server
No network sockets; communicates with local pylsp through stdio JSON-RPC.
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

from PySide6.QtCore import QObject, QProcess, Signal


class LocalPythonLanguageServer(QObject):
    diagnostics = Signal(str, object)
    completions = Signal(object)
    status = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.process: QProcess | None = None
        self.buffer = bytearray()
        self.next_id = 1
        self.pending: dict[int, str] = {}
        self.open_documents: dict[str, int] = {}
        self.ready = False

    def start(self, interpreter: str, root: Path):
        self.stop()
        exe = Path(interpreter)
        candidates = [
            exe.parent / ("pylsp.exe" if exe.suffix == ".exe" else "pylsp"),
        ]
        fallback = shutil.which("pylsp")
        if fallback:
            candidates.append(Path(fallback))
        command = next((path for path in candidates if path.is_file()), None)
        if command is None:
            self.status.emit(
                "Optional python-lsp-server unavailable. Install it in the "
                "selected interpreter to enable local language intelligence."
            )
            return
        self.buffer.clear()
        self.open_documents.clear()
        self.next_id = 1
        self.pending.clear()
        self.ready = False
        proc = QProcess(self)
        proc.setWorkingDirectory(str(root))
        proc.readyReadStandardOutput.connect(self._receive)
        proc.errorOccurred.connect(
            lambda _: self.status.emit("Python language server could not start.")
        )
        proc.start(str(command), [])
        self.process = proc
        self._request("initialize", {
            "processId": None,
            "rootUri": root.resolve().as_uri(),
            "rootPath": str(root.resolve()),
            "capabilities": {
                "textDocument": {
                    "synchronization": {"didSave": True},
                    "completion": {"completionItem": {"snippetSupport": False}},
                    "publishDiagnostics": {}
                }
            },
            "workspaceFolders": [
                {"uri": root.resolve().as_uri(), "name": root.name}
            ],
        }, purpose="initialize")

    def stop(self):
        if self.process is not None:
            if self.process.state() == QProcess.ProcessState.Running:
                self._notify("exit", {})
                self.process.terminate()
                if not self.process.waitForFinished(800):
                    self.process.kill()
            self.process.deleteLater()
        self.process = None
        self.ready = False

    def _send(self, message: dict):
        proc = self.process
        if proc is None:
            return
        data = json.dumps(message, separators=(",", ":")).encode("utf-8")
        proc.write(f"Content-Length: {len(data)}\r\n\r\n".encode() + data)

    def _request(self, method: str, params: dict, purpose: str):
        request_id = self.next_id
        self.next_id += 1
        self.pending[request_id] = purpose
        self._send({
            "jsonrpc": "2.0", "id": request_id,
            "method": method, "params": params,
        })

    def _notify(self, method: str, params: dict):
        self._send({"jsonrpc": "2.0", "method": method, "params": params})

    def _receive(self):
        if self.process is None:
            return
        self.buffer.extend(bytes(self.process.readAllStandardOutput()))
        while True:
            end = self.buffer.find(b"\r\n\r\n")
            if end < 0:
                break
            header = bytes(self.buffer[:end]).decode("ascii", errors="replace")
            size = None
            for line in header.split("\r\n"):
                if line.lower().startswith("content-length:"):
                    try:
                        size = int(line.split(":", 1)[1].strip())
                    except ValueError:
                        size = None
            if size is None or size > 10_000_000 or size < 0:
                self.buffer.clear()
                self.status.emit("Malformed LSP message rejected.")
                return
            if len(self.buffer) < end + 4 + size:
                break
            blob = bytes(self.buffer[end + 4:end + 4 + size])
            del self.buffer[:end + 4 + size]
            try:
                self._message(json.loads(blob))
            except (ValueError, TypeError):
                self.status.emit("Invalid language server JSON response.")

    def _message(self, message):
        if "id" in message:
            purpose = self.pending.pop(message["id"], "")
            if purpose == "initialize":
                self.ready = True
                self._notify("initialized", {})
                self.status.emit("Local Python LSP ready.")
            elif purpose == "completion":
                result = message.get("result")
                if isinstance(result, dict):
                    result = result.get("items", [])
                if isinstance(result, list):
                    self.completions.emit(result)
            return
        if message.get("method") == "textDocument/publishDiagnostics":
            params = message.get("params") or {}
            self.diagnostics.emit(params.get("uri", ""),
                                  params.get("diagnostics", []))

    def open_or_change(self, path: Path, text: str):
        if not self.ready:
            return
        uri = path.resolve().as_uri()
        if uri not in self.open_documents:
            self.open_documents[uri] = 1
            self._notify("textDocument/didOpen", {
                "textDocument": {
                    "uri": uri, "languageId": "python",
                    "version": 1, "text": text
                }
            })
        else:
            self.open_documents[uri] += 1
            self._notify("textDocument/didChange", {
                "textDocument": {
                    "uri": uri, "version": self.open_documents[uri],
                },
                "contentChanges": [{"text": text}]
            })

    def close_document(self, path: Path):
        uri = path.resolve().as_uri()
        if self.open_documents.pop(uri, None) is not None:
            self._notify("textDocument/didClose", {
                "textDocument": {"uri": uri}
            })

    def request_completion(self, path: Path, line: int, character: int):
        if not self.ready:
            self.status.emit("Language server is not ready.")
            return
        self._request("textDocument/completion", {
            "textDocument": {"uri": path.resolve().as_uri()},
            "position": {"line": line, "character": character},
        }, purpose="completion")
