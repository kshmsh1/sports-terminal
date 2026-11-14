"""Arcside Python Lab — offline native Python IDE.

PySide6 code editor, project explorer, script execution, pytest, interactive
Python debugger (pdb), terminal, syntax diagnostics and Python environment
selection. Scripts run with the user's privileges on their own computer.
No hosted kernel, network service, LLM dependency or telemetry.
"""
from __future__ import annotations

import ast
import builtins
import keyword
import os
import re
import sys
from pathlib import Path

from PySide6.QtCore import QPoint, QRect, Qt, QProcess, QSize, Signal, QTimer, QStringListModel
from PySide6.QtGui import (
    QAction, QColor, QFont, QKeySequence, QPainter,
    QSyntaxHighlighter, QTextCharFormat, QTextCursor,
)
from PySide6.QtWidgets import (
    QApplication, QComboBox, QCompleter, QDockWidget, QFileDialog,
    QFileSystemModel, QHBoxLayout, QInputDialog, QLabel, QLineEdit,
    QMainWindow, QMessageBox, QPlainTextEdit, QSplitter, QTabWidget,
    QListWidget, QListWidgetItem, QTextEdit,
    QToolBar, QTreeView, QVBoxLayout, QWidget,
)

try:
    from .lsp_client import PylspClient
except ImportError:
    from lsp_client import PylspClient


class PythonHighlighter(QSyntaxHighlighter):
    def __init__(self, document):
        super().__init__(document)
        self._rules: list[tuple[re.Pattern, QTextCharFormat]] = []
        for pattern, color, weight in [
            (r"\b(?:" + "|".join(keyword.kwlist) + r")\b", "#c792ea", True),
            (r"\b(?:self|cls|True|False|None)\b", "#f78c6c", False),
            (r"\b(?:def|class)\s+([A-Za-z_]\w*)", "#82aaff", True),
            (r"\b(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?\b", "#f78c6c", False),
            (r"#.*$", "#637b71", False),
            (r"(?:[rbufRBUF]{0,2})(?:\"[^\"\\n]*\"|'[^'\\n]*')", "#c3e88d", False),
            (r"@[A-Za-z_][\w.]*", "#ffcb6b", False),
        ]:
            fmt = QTextCharFormat()
            fmt.setForeground(QColor(color))
            if weight: fmt.setFontWeight(QFont.Bold)
            self._rules.append((re.compile(pattern), fmt))

    def highlightBlock(self, text: str) -> None:
        for pattern, fmt in self._rules:
            for match in pattern.finditer(text):
                start, end = match.span(1) if match.lastindex else match.span()
                self.setFormat(start, end - start, fmt)


class Gutter(QWidget):
    def __init__(self, editor: "CodeEditor"):
        super().__init__(editor)
        self.editor = editor

    def sizeHint(self):
        return QSize(self.editor.gutter_width(), 0)

    def paintEvent(self, event):
        self.editor.paint_gutter(event)

    def mousePressEvent(self, event):
        block = self.editor.firstVisibleBlock()
        top = int(self.editor.blockBoundingGeometry(block)
                  .translated(self.editor.contentOffset()).top())
        while block.isValid():
            height = int(self.editor.blockBoundingRect(block).height())
            if top <= event.position().y() < top + height:
                self.editor.toggle_breakpoint(block.blockNumber() + 1)
                break
            top += height
            block = block.next()


class CodeEditor(QPlainTextEdit):
    breakpointsChanged = Signal()
    completionRequested = Signal(int, int)

    def __init__(self, filename: Path | None = None):
        super().__init__()
        self.filename = filename
        self.breakpoints: set[int] = set()
        self.diagnostics: list[dict] = []
        self.gutter = Gutter(self)
        font = QFont("JetBrains Mono", 12)
        if not QFont(font).exactMatch(): font = QFont("Menlo", 12)
        font.setStyleHint(QFont.Monospace)
        self.setFont(font)
        self.setTabStopDistance(4 * self.fontMetrics().horizontalAdvance(" "))
        self.setLineWrapMode(QPlainTextEdit.NoWrap)
        self.setStyleSheet("""
            QPlainTextEdit { color: #d9e1ec; background: #13191f;
                selection-background-color: #304865; border: none;
                padding: 4px 0; }
        """)
        self.highlighter = PythonHighlighter(self.document())
        self.blockCountChanged.connect(self._update_gutter_width)
        self.updateRequest.connect(self._update_gutter)
        self.cursorPositionChanged.connect(self._highlight_line)
        self._update_gutter_width()
        self._highlight_line()
        names = sorted(set(keyword.kwlist) | set(dir(builtins)) |
            {"numpy", "pandas", "matplotlib", "sklearn", "DataFrame", "Series",
             "read_csv", "groupby", "fit", "predict", "scatter", "plot"})
        self.completer = QCompleter(names, self)
        self.completer.setWidget(self)
        self.completer.setCompletionMode(QCompleter.PopupCompletion)
        self.completer.activated.connect(self._insert_completion)

    def gutter_width(self) -> int:
        return 23 + self.fontMetrics().horizontalAdvance("9") * (
            len(str(max(1, self.blockCount()))) + 1)

    def _update_gutter_width(self, _=0):
        self.setViewportMargins(self.gutter_width(), 0, 0, 0)

    def _update_gutter(self, rect: QRect, dy: int):
        if dy: self.gutter.scroll(0, dy)
        else: self.gutter.update(0, rect.y(), self.gutter.width(), rect.height())
        if rect.contains(self.viewport().rect()):
            self._update_gutter_width()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        cr = self.contentsRect()
        self.gutter.setGeometry(QRect(cr.left(), cr.top(),
                                      self.gutter_width(), cr.height()))

    def paint_gutter(self, event):
        painter = QPainter(self.gutter)
        painter.fillRect(event.rect(), QColor("#1c2530"))
        block = self.firstVisibleBlock()
        top = int(self.blockBoundingGeometry(block)
                  .translated(self.contentOffset()).top())
        while block.isValid() and top <= event.rect().bottom():
            bottom = top + int(self.blockBoundingRect(block).height())
            if block.isVisible() and bottom >= event.rect().top():
                num = block.blockNumber() + 1
                if num in self.breakpoints:
                    painter.setBrush(QColor("#e15663"))
                    painter.setPen(Qt.NoPen)
                    painter.drawEllipse(4, top + 5, 10, 10)
                painter.setPen(QColor("#8292a4"))
                painter.drawText(17, top, self.gutter.width() - 21,
                    self.fontMetrics().height(), Qt.AlignRight, str(num))
            top = bottom
            block = block.next()

    def _highlight_line(self):
        selection = QTextEdit.ExtraSelection()
        selection.format.setBackground(QColor("#202e3a"))
        selection.format.setProperty(QTextCharFormat.FullWidthSelection, True)
        selection.cursor = self.textCursor()
        selection.cursor.clearSelection()
        all_selections = [selection]
        for diagnostic in self.diagnostics[:150]:
            index = int(diagnostic.get("range", {}).get("start", {}).get("line", -1))
            block = self.document().findBlockByNumber(index)
            if not block.isValid():
                continue
            issue = QTextEdit.ExtraSelection()
            issue.cursor = QTextCursor(block)
            issue.cursor.select(QTextCursor.LineUnderCursor)
            issue.format.setUnderlineStyle(QTextCharFormat.WaveUnderline)
            issue.format.setUnderlineColor(QColor("#ec7279"))
            all_selections.append(issue)
        self.setExtraSelections(all_selections)

    def set_diagnostics(self, diagnostics: list[dict]):
        self.diagnostics = diagnostics
        self._highlight_line()

    def offer_lsp_completions(self, labels: list[str]):
        if not labels:
            return
        self.completer.setModel(QStringListModel(sorted(set(labels)), self))
        cursor = self.textCursor()
        cursor.select(QTextCursor.WordUnderCursor)
        prefix = cursor.selectedText()
        self.completer.setCompletionPrefix(prefix)
        rect = self.cursorRect()
        rect.setWidth(260)
        self.completer.complete(rect)

    def toggle_breakpoint(self, line: int):
        if line in self.breakpoints: self.breakpoints.remove(line)
        else: self.breakpoints.add(line)
        self.gutter.update()
        self.breakpointsChanged.emit()

    def _insert_completion(self, text: str):
        cursor = self.textCursor()
        cursor.select(QTextCursor.WordUnderCursor)
        cursor.insertText(text)
        self.setTextCursor(cursor)

    def keyPressEvent(self, event):
        if self.completer.popup().isVisible() and event.key() in (
            Qt.Key_Return, Qt.Key_Enter, Qt.Key_Escape, Qt.Key_Tab,
        ):
            if event.key() == Qt.Key_Escape:
                self.completer.popup().hide()
            return
        if event.key() == Qt.Key_Tab and not event.modifiers():
            self.insertPlainText("    ")
            return
        if event.key() in (Qt.Key_Return, Qt.Key_Enter):
            cursor = self.textCursor()
            line = cursor.block().text()
            indent = re.match(r"^\s*", line).group(0)
            if line.rstrip().endswith(":"): indent += "    "
            super().keyPressEvent(event)
            self.insertPlainText(indent)
            return
        super().keyPressEvent(event)
        if event.modifiers() == Qt.ControlModifier and event.key() == Qt.Key_Space:
            self._complete()

    def _complete(self):
        cursor = self.textCursor()
        cursor.select(QTextCursor.WordUnderCursor)
        prefix = cursor.selectedText()
        if len(prefix) < 2: return
        self.completer.setCompletionPrefix(prefix)
        rect = self.cursorRect()
        rect.setWidth(240)
        self.completer.complete(rect)
        if self.filename is not None:
            self.completionRequested.emit(cursor.blockNumber(),
                                          cursor.positionInBlock())

    def find_text(self, text: str):
        if not text: return
        if not self.find(text):
            cursor = self.textCursor()
            cursor.movePosition(QTextCursor.Start)
            self.setTextCursor(cursor)
            self.find(text)


class PythonLabWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Arcside · Python Lab")
        self.resize(1550, 920)
        self.project = Path.cwd()
        self.lsp = PylspClient(self)
        self.process: QProcess | None = None
        self.mode = ""
        self._output_lines = 0

        self.environment = QComboBox()
        self.tabs = QTabWidget()
        self.tabs.setTabsClosable(True)
        self.tabs.tabCloseRequested.connect(self._close_tab)
        self.tabs.currentChanged.connect(self._update_status)
        self.setCentralWidget(self.tabs)
        self._new_file()

        self.model = QFileSystemModel(self)
        self.model.setRootPath(str(self.project))
        self.tree = QTreeView()
        self.tree.setModel(self.model)
        self.tree.setRootIndex(self.model.index(str(self.project)))
        self.tree.hideColumn(1)
        self.tree.hideColumn(2)
        self.tree.hideColumn(3)
        self.tree.doubleClicked.connect(self._open_tree_file)
        explorer = QDockWidget("EXPLORER", self)
        explorer.setWidget(self.tree)
        self.addDockWidget(Qt.LeftDockWidgetArea, explorer)

        console_panel = QWidget()
        console_layout = QVBoxLayout(console_panel)
        console_layout.setContentsMargins(7, 7, 7, 7)
        self.output = QPlainTextEdit()
        self.output.setReadOnly(True)
        self.output.setMaximumBlockCount(10000)
        self.output.setStyleSheet("""
            QPlainTextEdit { background: #10161c; color: #ced7e0;
              font: 12px 'Menlo'; border: none; }
        """)
        self.command = QLineEdit()
        self.command.setPlaceholderText("Terminal / pdb command  •  Enter to send")
        self.command.returnPressed.connect(self._send_command)
        console_layout.addWidget(self.output)
        console_layout.addWidget(self.command)
        dock = QDockWidget("OUTPUT · TERMINAL · DEBUG CONSOLE", self)
        dock.setWidget(console_panel)
        self.addDockWidget(Qt.BottomDockWidgetArea, dock)
        self.resizeDocks([dock], [280], Qt.Vertical)

        self._toolbar()
        self.problems = QListWidget()
        self.problems.itemDoubleClicked.connect(self._jump_diagnostic)
        problems_dock = QDockWidget("PROBLEMS · LSP DIAGNOSTICS", self)
        problems_dock.setWidget(self.problems)
        self.addDockWidget(Qt.RightDockWidgetArea, problems_dock)
        self.lsp.ready.connect(self._lsp_ready)
        self.lsp.completions.connect(self._lsp_completions)
        self.lsp.diagnostics.connect(self._lsp_diagnostics)
        self.lsp.notice.connect(lambda notice: self._append(notice + "\\n"))
        self.environment.currentTextChanged.connect(self._restart_lsp)
        self._scan_interpreters()
        self._restart_lsp()
        self.statusBar().showMessage("Python Lab · local execution · choose a project to begin")
        self.setStyleSheet("""
            QMainWindow, QDockWidget { background: #0f141b; color: #dce5ef; }
            QTreeView, QTabWidget, QTabBar { background: #131a22; color: #dce5ef; }
            QTreeView::item:selected { background: #284369; }
            QTabBar::tab { padding: 10px 17px; background: #202a35; }
            QTabBar::tab:selected { background: #13191f;
                border-top: 2px solid #90a8ff; }
            QToolBar { background: #1b2531; border: none; spacing: 6px; }
            QToolBar QToolButton { color: white; padding: 9px 10px; }
            QToolBar QToolButton:hover { background: #30445d; }
            QLineEdit, QComboBox { background: #222e3c; color: white;
                border: 1px solid #3c4a5b; padding: 7px; }
        """)

    def _action(self, name: str, callback, shortcut: str | None = None):
        action = QAction(name, self)
        action.triggered.connect(callback)
        if shortcut:
            action.setShortcut(QKeySequence(shortcut))
            self.addAction(action)
        return action

    def _toolbar(self):
        bar = QToolBar("Python Lab")
        bar.setMovable(False)
        self.addToolBar(bar)
        for label, cb, shortcut in [
            ("New", self._new_file, "Ctrl+N"),
            ("Open", self._open_file_dialog, "Ctrl+O"),
            ("Project", self._open_project, "Ctrl+Shift+O"),
            ("Save", self._save, "Ctrl+S"),
            ("Save As", self._save_as, "Ctrl+Shift+S"),
            ("Run", self._run, "F5"),
            ("Debug", self._debug, "F9"),
            ("Step", lambda: self._debug_input("s"), "F11"),
            ("Next", lambda: self._debug_input("n"), "F10"),
            ("Continue", lambda: self._debug_input("c"), "F8"),
            ("Stop", self._stop, "Shift+F5"),
            ("Tests", self._pytest, None),
            ("Syntax", self._syntax, None),
            ("Find", self._find, "Ctrl+F"),
            ("Replace", self._replace, "Ctrl+H"),
            ("Shell", self._shell, None),
        ]:
            bar.addAction(self._action(label, cb, shortcut))
        bar.addSeparator()
        bar.addWidget(QLabel(" Python: "))
        bar.addWidget(self.environment)

    def _current(self) -> CodeEditor | None:
        current = self.tabs.currentWidget()
        return current if isinstance(current, CodeEditor) else None

    def _new_file(self):
        editor = CodeEditor()
        editor.setPlainText("import numpy as np\nimport pandas as pd\n\n"
            "# Arcside Python Lab — local execution\n"
            "values = np.array([1, 2, 3, 4, 5])\n"
            "print('Mean:', values.mean())\n"
            "print(pd.DataFrame({'value': values}).describe())\n")
        self.tabs.addTab(editor, "Untitled")
        self._attach_lsp(editor)
        self.tabs.setCurrentWidget(editor)

    def _open_project(self):
        folder = QFileDialog.getExistingDirectory(self, "Choose Python project", str(self.project))
        if not folder: return
        self.project = Path(folder)
        self.tree.setRootIndex(self.model.index(str(self.project)))
        self._scan_interpreters()
        self._restart_lsp()
        self.statusBar().showMessage(f"Project: {self.project}")

    def _open_tree_file(self, index):
        path = Path(self.model.filePath(index))
        if path.is_file(): self._open_file(path)

    def _open_file_dialog(self):
        name, _ = QFileDialog.getOpenFileName(self, "Open source file",
            str(self.project), "Python (*.py);;Text (*.txt *.json *.csv);;All (*)")
        if name: self._open_file(Path(name))

    def _open_file(self, path: Path):
        for i in range(self.tabs.count()):
            editor = self.tabs.widget(i)
            if isinstance(editor, CodeEditor) and editor.filename == path:
                self.tabs.setCurrentIndex(i)
                return
        try:
            code = path.read_text(encoding="utf-8")
        except Exception as error:
            QMessageBox.critical(self, "Open failed", str(error))
            return
        editor = CodeEditor(path)
        editor.setPlainText(code)
        editor.document().setModified(False)
        editor.document().modificationChanged.connect(
            lambda _: self._update_tab_label(editor))
        self.tabs.addTab(editor, path.name)
        self._attach_lsp(editor)
        self.lsp.open_document(path, code)
        self.tabs.setCurrentWidget(editor)

    def _update_tab_label(self, editor: CodeEditor):
        i = self.tabs.indexOf(editor)
        if i >= 0:
            title = editor.filename.name if editor.filename else "Untitled"
            self.tabs.setTabText(i, title + (" ●" if editor.document().isModified() else ""))

    def _save_as(self) -> bool:
        editor = self._current()
        if editor is None: return False
        filename, _ = QFileDialog.getSaveFileName(self, "Save Python file",
            str(editor.filename or self.project / "untitled.py"), "Python (*.py);;All (*)")
        if not filename: return False
        editor.filename = Path(filename)
        return self._save()

    def _save(self) -> bool:
        editor = self._current()
        if editor is None: return False
        if editor.filename is None: return self._save_as()
        try:
            editor.filename.write_text(editor.toPlainText(), encoding="utf-8")
            editor.document().setModified(False)
            self.lsp.open_document(editor.filename, editor.toPlainText())
            self._update_tab_label(editor)
            self.statusBar().showMessage(f"Saved {editor.filename}")
            return True
        except Exception as error:
            QMessageBox.critical(self, "Save failed", str(error))
            return False

    def _close_tab(self, index: int):
        editor = self.tabs.widget(index)
        if isinstance(editor, CodeEditor) and editor.document().isModified():
            decision = QMessageBox.question(self, "Unsaved file",
                f"Close {self.tabs.tabText(index)} without saving?")
            if decision != QMessageBox.Yes: return
        if isinstance(editor, CodeEditor) and editor.filename is not None:
            self.lsp.close_document(editor.filename)
        self.tabs.removeTab(index)
        editor.deleteLater()
        if self.tabs.count() == 0: self._new_file()

    def _scan_interpreters(self):
        previous = self.environment.currentText()
        self.environment.blockSignals(True)
        self.environment.clear()
        interpreters = [sys.executable]
        for folder in [self.project / ".venv", self.project / "venv",
                       self.project / ".conda", Path(os.environ.get("VIRTUAL_ENV", "/__none__"))]:
            for candidate in (folder / "bin/python",
                              folder / "Scripts/python.exe"):
                if candidate.is_file(): interpreters.insert(0, str(candidate))
        for path in dict.fromkeys(interpreters):
            self.environment.addItem(path)
        if previous in interpreters: self.environment.setCurrentText(previous)
        self.environment.blockSignals(False)

    def _restart_lsp(self, *_):
        interpreter = self._interpreter()
        if interpreter:
            self.lsp.start(interpreter, self.project)

    def _attach_lsp(self, editor: CodeEditor):
        timer = QTimer(editor)
        timer.setInterval(450)
        timer.setSingleShot(True)
        timer.timeout.connect(lambda: editor.filename is not None and
            self.lsp.change_document(editor.filename, editor.toPlainText()))
        editor.textChanged.connect(timer.start)
        editor.completionRequested.connect(lambda line, col:
            editor.filename is not None and
            self.lsp.request_completion(editor.filename, line, col))

    def _lsp_ready(self):
        for index in range(self.tabs.count()):
            editor = self.tabs.widget(index)
            if isinstance(editor, CodeEditor) and editor.filename is not None:
                self.lsp.open_document(editor.filename, editor.toPlainText())

    def _lsp_completions(self, labels: list):
        editor = self._current()
        if editor is not None:
            editor.offer_lsp_completions(labels)

    def _lsp_diagnostics(self, uri: str, records: list):
        for index in range(self.tabs.count()):
            editor = self.tabs.widget(index)
            if not isinstance(editor, CodeEditor) or editor.filename is None:
                continue
            if editor.filename.resolve().as_uri() == uri:
                editor.set_diagnostics(records)
        self.problems.clear()
        for diagnostic in records:
            line = int(diagnostic.get("range", {}).get("start", {}).get("line", 0))
            message = str(diagnostic.get("message", "Unknown diagnostic"))
            item = QListWidgetItem(f"Ln {line + 1} · {message}")
            item.setData(Qt.UserRole, (uri, line))
            self.problems.addItem(item)

    def _jump_diagnostic(self, item: QListWidgetItem):
        data = item.data(Qt.UserRole)
        if not data:
            return
        uri, line = data
        from urllib.parse import urlparse, unquote
        path = Path(unquote(urlparse(uri).path))
        if path.is_file():
            self._open_file(path)
            editor = self._current()
            if editor is not None:
                cursor = QTextCursor(editor.document().findBlockByNumber(line))
                editor.setTextCursor(cursor)
                editor.setFocus()

    def _interpreter(self) -> str:
        return self.environment.currentText() or sys.executable

    def _append(self, text: str):
        self.output.moveCursor(QTextCursor.End)
        self.output.insertPlainText(text)
        self.output.moveCursor(QTextCursor.End)

    def _start(self, args: list[str], mode: str, folder: Path | None = None):
        self._stop()
        self.mode = mode
        process = QProcess(self)
        self.process = process
        process.setProgram(self._interpreter())
        process.setArguments(args)
        process.setWorkingDirectory(str(folder or self.project))
        process.setProcessChannelMode(QProcess.MergedChannels)
        process.readyReadStandardOutput.connect(lambda: self._append(
            bytes(process.readAllStandardOutput()).decode("utf-8", errors="replace")))
        process.finished.connect(lambda exit_code, _:
            self._append(f"\n[Arcside {mode} exited: {exit_code}]\n"))
        self._append(f"\n$ {self._interpreter()} {' '.join(args)}\n")
        process.start()
        if not process.waitForStarted(1500):
            self._append(f"Process failed: {process.errorString()}\n")

    def _run(self):
        editor = self._current()
        if editor is None or not self._save(): return
        assert editor.filename is not None
        self._start(["-u", str(editor.filename)], "run", editor.filename.parent)

    def _debug(self):
        editor = self._current()
        if editor is None or not self._save(): return
        assert editor.filename is not None
        # Set breakpoints before the first continue. Standard pdb works with
        # every local Python interpreter and has no daemon or API.
        self._start(["-u", "-m", "pdb", str(editor.filename)], "debug",
                    editor.filename.parent)
        for line in sorted(editor.breakpoints):
            self._debug_input(f"break {editor.filename}:{line}")
        self._append("pdb: use Next (F10), Step (F11), Continue (F8), "
                     "or enter 'p variable' in the debug console.\n")

    def _debug_input(self, cmd: str):
        if (self.mode != "debug" or self.process is None or
                self.process.state() != QProcess.Running):
            self._append("\nStart Debug first to send debugger commands.\n")
            return
        self.process.write((cmd + "\n").encode("utf-8"))

    def _send_command(self):
        cmd = self.command.text()
        self.command.clear()
        if self.process is None or self.process.state() != QProcess.Running:
            self._append("No active console process. Choose Run, Debug or Shell.\n")
            return
        self._append(f"> {cmd}\n")
        self.process.write((cmd + "\n").encode("utf-8"))

    def _stop(self):
        if self.process is not None and self.process.state() == QProcess.Running:
            self.process.terminate()
            if not self.process.waitForFinished(1200):
                self.process.kill()
        self.process = None

    def _pytest(self):
        self._start(["-u", "-m", "pytest", "-v", str(self.project)], "test")

    def _shell(self):
        # Python REPL is portable and uses the same selected project interpreter.
        self._start(["-u", "-i"], "shell")

    def _syntax(self):
        editor = self._current()
        if editor is None: return
        try:
            ast.parse(editor.toPlainText(), filename=str(editor.filename or "<untitled>"))
            self._append("\nSyntax check passed.\n")
        except SyntaxError as error:
            self._append(f"\nSyntaxError: {error.msg} at line {error.lineno}, "
                         f"column {error.offset}\n")
            cursor = editor.textCursor()
            cursor.movePosition(QTextCursor.Start)
            for _ in range((error.lineno or 1) - 1):
                cursor.movePosition(QTextCursor.Down)
            editor.setTextCursor(cursor)
            editor.setFocus()

    def _find(self):
        editor = self._current()
        if editor is None: return
        word, ok = QInputDialog.getText(self, "Find", "Find text:")
        if ok: editor.find_text(word)

    def _replace(self):
        editor = self._current()
        if editor is None: return
        old, ok = QInputDialog.getText(self, "Replace", "Find:")
        if not ok or not old: return
        new, ok = QInputDialog.getText(self, "Replace", "Replace with:")
        if ok:
            editor.setPlainText(editor.toPlainText().replace(old, new))

    def _update_status(self, _=0):
        editor = self._current()
        if editor:
            pos = editor.textCursor()
            self.statusBar().showMessage(
                f"{editor.filename or 'Untitled'} · Ln {pos.blockNumber()+1}, "
                f"Col {pos.positionInBlock()+1} · Python: {self._interpreter()}")

    def closeEvent(self, event):
        self.lsp.stop()
        self._stop()
        super().closeEvent(event)


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName("Arcside Python Lab")
    window = PythonLabWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
