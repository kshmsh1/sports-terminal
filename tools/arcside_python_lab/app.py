"""Arcside Python Lab — local, standalone desktop Python IDE.

Launch: python -m pip install PySide6; python tools/arcside_python_lab/app.py
Everything runs on the user's computer. No remote code execution, AI or telemetry.
"""
from __future__ import annotations

import ast

from lsp_client import LocalPythonLanguageServer
import os
import re
import sys
from pathlib import Path

try:
    from PySide6.QtCore import Qt, QProcess, QProcessEnvironment, QTimer, QRect, QSize
    from PySide6.QtGui import (
        QAction, QColor, QFont, QPainter, QTextCharFormat, QSyntaxHighlighter,
        QTextCursor, QTextFormat
    )
    from PySide6.QtWidgets import (
        QApplication, QComboBox, QDockWidget, QFileDialog, QFileSystemModel,
        QInputDialog, QLabel, QLineEdit, QMainWindow, QMenu, QMessageBox,
        QPlainTextEdit, QPushButton, QSplitter, QTabWidget, QToolBar, QTreeView,
        QVBoxLayout, QWidget
    )
except ImportError as exc:
    raise SystemExit(
        "Arcside Python Lab requires the free PySide6 package. "
        "Install it locally: python -m pip install PySide6"
    ) from exc


class PythonHighlighter(QSyntaxHighlighter):
    _keywords = set(
        "False None True and as assert async await break class continue def del "
        "elif else except finally for from global if import in is lambda nonlocal "
        "not or pass raise return try while with yield match case".split()
    )

    def __init__(self, document):
        super().__init__(document)
        self.keyword = QTextCharFormat()
        self.keyword.setForeground(QColor("#C792EA"))
        self.keyword.setFontWeight(QFont.Weight.Bold)
        self.string = QTextCharFormat()
        self.string.setForeground(QColor("#C3E88D"))
        self.comment = QTextCharFormat()
        self.comment.setForeground(QColor("#7E8B9E"))
        self.number = QTextCharFormat()
        self.number.setForeground(QColor("#F78C6C"))
        self.function = QTextCharFormat()
        self.function.setForeground(QColor("#82AAFF"))

    def highlightBlock(self, text):
        for match in re.finditer(r"\b[A-Za-z_][A-Za-z_0-9]*\b", text):
            if match.group() in self._keywords:
                self.setFormat(match.start(), len(match.group()), self.keyword)
        for match in re.finditer(r"\b\d+(?:\.\d+)?\b", text):
            self.setFormat(match.start(), len(match.group()), self.number)
        for match in re.finditer(r"\b(?:def|class)\s+([A-Za-z_]\w*)", text):
            begin = match.start(1)
            self.setFormat(begin, len(match.group(1)), self.function)
        for match in re.finditer(r"""(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")""", text):
            self.setFormat(match.start(), len(match.group()), self.string)
        comment = text.find("#")
        if comment >= 0:
            self.setFormat(comment, len(text) - comment, self.comment)


class LineNumberGutter(QWidget):
    def __init__(self, editor):
        super().__init__(editor)
        self.editor = editor

    def sizeHint(self):
        return QSize(self.editor.gutter_width(), 0)

    def paintEvent(self, event):
        self.editor.paint_gutter(event)

    def mousePressEvent(self, event):
        line = self.editor.firstVisibleBlock()
        block_number = line.blockNumber()
        top = self.editor.blockBoundingGeometry(line).translated(
            self.editor.contentOffset()
        ).top()
        while line.isValid() and top <= event.position().y():
            bottom = top + self.editor.blockBoundingRect(line).height()
            if top <= event.position().y() < bottom:
                number = block_number + 1
                if number in self.editor.breakpoints:
                    self.editor.breakpoints.remove(number)
                else:
                    self.editor.breakpoints.add(number)
                self.update()
                break
            line = line.next()
            top = bottom
            block_number += 1


class CodeEditor(QPlainTextEdit):
    def __init__(self, path=None):
        super().__init__()
        self.path = Path(path).resolve() if path else None
        self.setFont(QFont("Menlo" if sys.platform == "darwin" else "Consolas", 12))
        self.setTabStopDistance(self.fontMetrics().horizontalAdvance(" ") * 4)
        self.setStyleSheet(
            "QPlainTextEdit { background:#111821; color:#D6DEEB; "
            "border:0; selection-background-color:#324C71; }"
        )
        self.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        self.breakpoints: set[int] = set()
        self.gutter = LineNumberGutter(self)
        self.blockCountChanged.connect(self._update_gutter_width)
        self.updateRequest.connect(self._update_gutter)
        self._update_gutter_width()
        self.highlighter = PythonHighlighter(self.document())
        self.cursorPositionChanged.connect(self.highlight_current_line)
        self.highlight_current_line()
        if self.path and self.path.is_file():
            self.setPlainText(self.path.read_text(encoding="utf-8"))

    def gutter_width(self):
        digits = len(str(max(1, self.blockCount())))
        return 26 + self.fontMetrics().horizontalAdvance("9") * digits

    def _update_gutter_width(self, *_):
        self.setViewportMargins(self.gutter_width(), 0, 0, 0)

    def _update_gutter(self, rect, dy):
        if dy:
            self.gutter.scroll(0, dy)
        else:
            self.gutter.update(0, rect.y(), self.gutter.width(), rect.height())
        if rect.contains(self.viewport().rect()):
            self._update_gutter_width()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        bounds = self.contentsRect()
        self.gutter.setGeometry(
            QRect(bounds.left(), bounds.top(),
                  self.gutter_width(), bounds.height())
        )

    def paint_gutter(self, event):
        painter = QPainter(self.gutter)
        painter.fillRect(event.rect(), QColor("#1B2735"))
        block = self.firstVisibleBlock()
        number = block.blockNumber()
        top = self.blockBoundingGeometry(block).translated(
            self.contentOffset()
        ).top()
        bottom = top + self.blockBoundingRect(block).height()
        while block.isValid() and top <= event.rect().bottom():
            if block.isVisible() and bottom >= event.rect().top():
                lineno = number + 1
                painter.setPen(QColor("#8C9BAB"))
                painter.drawText(
                    0, int(top), self.gutter.width() - 6,
                    self.fontMetrics().height(),
                    Qt.AlignmentFlag.AlignRight, str(lineno)
                )
                if lineno in self.breakpoints:
                    painter.setBrush(QColor("#E76A6A"))
                    painter.setPen(QColor("#E76A6A"))
                    painter.drawEllipse(4, int(top) + 4, 10, 10)
            block = block.next()
            top = bottom
            bottom = top + self.blockBoundingRect(block).height()
            number += 1

    def highlight_current_line(self):
        selection = QPlainTextEdit.ExtraSelection()
        selection.format.setBackground(QColor("#1D2937"))
        selection.format.setProperty(QTextFormat.Property.FullWidthSelection, True)
        selection.cursor = self.textCursor()
        selection.cursor.clearSelection()
        self.setExtraSelections([selection])

    def keyPressEvent(self, event):
        if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            cursor = self.textCursor()
            line = cursor.block().text()
            indent = re.match(r"\s*", line).group()
            extra = "    " if line.rstrip().endswith(":") else ""
            super().keyPressEvent(event)
            self.insertPlainText(indent + extra)
            return
        if event.key() == Qt.Key.Key_Tab and not event.modifiers():
            self.insertPlainText("    ")
            return
        super().keyPressEvent(event)

    def goto_line(self, lineno):
        cursor = self.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.Start)
        cursor.movePosition(
            QTextCursor.MoveOperation.Down,
            QTextCursor.MoveMode.MoveAnchor,
            max(0, lineno - 1),
        )
        self.setTextCursor(cursor)
        self.setFocus()


class PythonLab(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Arcside Python Lab")
        self.resize(1450, 900)
        self.root = Path.cwd()
        self.process = None
        self._mode = "idle"
        self.setStyleSheet(
            "QMainWindow,QDockWidget,QTreeView,QTabWidget,QTabBar,QMenu "
            "{background:#19222D;color:#DCE3EF;} "
            "QToolBar {background:#222E3B;border:none;spacing:6px;} "
            "QPushButton,QComboBox,QLineEdit {background:#2B3A4C; "
            "color:#ECF2FD;border:1px solid #42536A;padding:6px;} "
            "QTabBar::tab:selected {background:#324760;} "
        )
        self.tabs = QTabWidget()
        self.tabs.setTabsClosable(True)
        self.tabs.tabCloseRequested.connect(self.close_tab)
        self.tabs.currentChanged.connect(self.update_title)
        self.setCentralWidget(self.tabs)

        self.file_model = QFileSystemModel()
        self.file_model.setRootPath(str(self.root))
        self.tree = QTreeView()
        self.tree.setModel(self.file_model)
        self.tree.setRootIndex(self.file_model.index(str(self.root)))
        self.tree.doubleClicked.connect(self.open_tree)
        for col in (1, 2, 3):
            self.tree.hideColumn(col)
        self.explorer = QDockWidget("Explorer", self)
        self.explorer.setWidget(self.tree)
        self.addDockWidget(Qt.DockWidgetArea.LeftDockWidgetArea, self.explorer)

        self.console = QPlainTextEdit()
        self.console.setReadOnly(True)
        self.console.setFont(QFont("Menlo", 11))
        self.console.setStyleSheet(
            "background:#0D141D;color:#D0DCED;border:0;"
        )
        self.stdin = QLineEdit()
        self.stdin.setPlaceholderText(
            "Process input / pdb command — press Enter"
        )
        self.stdin.returnPressed.connect(self.send_stdin)
        console_frame = QWidget()
        console_layout = QVBoxLayout(console_frame)
        console_layout.setContentsMargins(0, 0, 0, 0)
        console_layout.addWidget(self.console)
        console_layout.addWidget(self.stdin)
        self.output_dock = QDockWidget("Run / Debug / Terminal", self)
        self.output_dock.setWidget(console_frame)
        self.addDockWidget(Qt.DockWidgetArea.BottomDockWidgetArea, self.output_dock)

        self.issues = QPlainTextEdit()
        self.issues.setReadOnly(True)
        self.issues.setPlaceholderText("Diagnostics")
        self.problems_dock = QDockWidget("Problems", self)
        self.problems_dock.setWidget(self.issues)
        self.tabifyDockWidget(self.output_dock, self.problems_dock)
        self.output_dock.raise_()

        self.interpreter = QComboBox()
        self.interpreter.setMinimumWidth(225)
        self.find_box = QLineEdit()
        self.find_box.setPlaceholderText("Find in file (Enter)")
        self.find_box.returnPressed.connect(self.find_next)
        self.lsp = LocalPythonLanguageServer(self)
        self.lsp.status.connect(self._lsp_status)
        self.lsp.diagnostics.connect(self._lsp_diagnostics)
        self.lsp.completions.connect(self._lsp_completions)
        self._lsp_timer = QTimer(self)
        self._lsp_timer.setSingleShot(True)
        self._lsp_timer.setInterval(450)
        self._lsp_timer.timeout.connect(self._lsp_publish)
        self.interpreter.currentIndexChanged.connect(self._lsp_interpreter_changed)
        self._build_actions()
        self.discover_interpreters()
        self.new_file()
        self.statusBar().showMessage("Local Python environment · No external services")

        timer = QTimer(self)
        timer.setInterval(650)
        timer.timeout.connect(self.check_syntax)
        timer.start()
        self._diagnostic_timer = timer

    def _build_actions(self):
        toolbar = QToolBar("Development")
        self.addToolBar(toolbar)
        for text, shortcut, handler in [
            ("New", "Ctrl+N", self.new_file),
            ("Open", "Ctrl+O", self.open_file),
            ("Save", "Ctrl+S", self.save_file),
            ("Save As", "Ctrl+Shift+S", self.save_as),
            ("Folder", "Ctrl+Shift+O", self.open_folder),
            ("Run", "F5", self.run_file),
            ("Debug (pdb)", "F6", self.debug_file),
            ("Stop", "Shift+F5", self.stop_process),
            ("pytest", "Ctrl+Shift+T", self.run_tests),
            ("Terminal", "Ctrl+Backtick", self.open_terminal),
            ("Start LSP", "Ctrl+Shift+L", self.start_lsp),
            ("Complete", "Ctrl+Space", self.complete),
        ]:
            action = QAction(text, self)
            action.setShortcut(shortcut)
            action.triggered.connect(handler)
            self.addAction(action)
            toolbar.addAction(action)
        toolbar.addSeparator()
        toolbar.addWidget(QLabel("Python: "))
        toolbar.addWidget(self.interpreter)
        refresh = QAction("Refresh envs", self)
        refresh.triggered.connect(self.discover_interpreters)
        toolbar.addAction(refresh)
        toolbar.addSeparator()
        toolbar.addWidget(self.find_box)
        search = QAction("Find next", self)
        search.setShortcut("Ctrl+F")
        search.triggered.connect(lambda: self.find_box.setFocus())
        self.addAction(search)
        toolbar.addAction(search)
        goto = QAction("Go to line", self)
        goto.setShortcut("Ctrl+G")
        goto.triggered.connect(self.goto_line)
        toolbar.addAction(goto)
        self.addAction(goto)

    def discover_interpreters(self):
        selected = self.interpreter.currentData()
        self.interpreter.clear()
        options = [Path(sys.executable)]
        for folder in (".venv", "venv", "env"):
            base = self.root / folder
            for exe in ("bin/python", "Scripts/python.exe"):
                candidate = base / exe
                if candidate.is_file():
                    options.insert(0, candidate)
        for path in dict.fromkeys(options):
            self.interpreter.addItem(str(path), str(path))
        if selected:
            idx = self.interpreter.findData(selected)
            if idx >= 0:
                self.interpreter.setCurrentIndex(idx)

    def current_editor(self):
        widget = self.tabs.currentWidget()
        return widget if isinstance(widget, CodeEditor) else None

    def new_file(self):
        editor = CodeEditor()
        editor.textChanged.connect(self.update_title)
        editor.textChanged.connect(self._lsp_timer.start)
        index = self.tabs.addTab(editor, "untitled.py")
        self.tabs.setCurrentIndex(index)

    def open_folder(self):
        path = QFileDialog.getExistingDirectory(self, "Open project", str(self.root))
        if not path:
            return
        self.root = Path(path).resolve()
        self.tree.setRootIndex(self.file_model.index(str(self.root)))
        self.discover_interpreters()
        self.statusBar().showMessage(f"Project: {self.root}")

    def open_tree(self, index):
        path = Path(self.file_model.filePath(index))
        if path.is_file():
            self.open_path(path)

    def open_file(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Open Python file", str(self.root),
            "Python (*.py *.pyw *.ipynb);;All files (*)"
        )
        if path:
            self.open_path(Path(path))

    def open_path(self, path):
        path = path.resolve()
        for idx in range(self.tabs.count()):
            editor = self.tabs.widget(idx)
            if isinstance(editor, CodeEditor) and editor.path == path:
                self.tabs.setCurrentIndex(idx)
                return
        try:
            editor = CodeEditor(path)
        except (OSError, UnicodeError) as exc:
            QMessageBox.warning(self, "Cannot open file", str(exc))
            return
        editor.textChanged.connect(self.update_title)
        editor.textChanged.connect(self._lsp_timer.start)
        index = self.tabs.addTab(editor, path.name)
        self._lsp_timer.start()
        self.tabs.setCurrentIndex(index)

    def update_title(self, *_):
        for idx in range(self.tabs.count()):
            editor = self.tabs.widget(idx)
            if not isinstance(editor, CodeEditor):
                continue
            name = editor.path.name if editor.path else "untitled.py"
            self.tabs.setTabText(
                idx, ("● " if editor.document().isModified() else "") + name
            )

    def save_file(self):
        editor = self.current_editor()
        if editor is None:
            return False
        if editor.path is None:
            return self.save_as()
        try:
            editor.path.write_text(editor.toPlainText(), encoding="utf-8")
        except OSError as exc:
            QMessageBox.warning(self, "Save failed", str(exc))
            return False
        editor.document().setModified(False)
        self.update_title()
        self._lsp_timer.start()
        return True

    def save_as(self):
        editor = self.current_editor()
        if editor is None:
            return False
        path, _ = QFileDialog.getSaveFileName(
            self, "Save Python file", str(self.root / "untitled.py"), "Python (*.py)"
        )
        if not path:
            return False
        editor.path = Path(path).resolve()
        return self.save_file()

    def close_tab(self, index):
        editor = self.tabs.widget(index)
        if isinstance(editor, CodeEditor) and editor.document().isModified():
            choice = QMessageBox.question(
                self, "Unsaved changes",
                "Discard unsaved changes in this file?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            if choice != QMessageBox.StandardButton.Yes:
                return
        if isinstance(editor, CodeEditor) and editor.path:
            self.lsp.close_document(editor.path)
        self.tabs.removeTab(index)
        if self.tabs.count() == 0:
            self.new_file()

    def check_syntax(self):
        if self.lsp.ready:
            return
        editor = self.current_editor()
        if editor is None:
            return
        try:
            ast.parse(editor.toPlainText(), filename=str(editor.path or "untitled.py"))
            self.issues.clear()
        except SyntaxError as exc:
            self.issues.setPlainText(
                f"{exc.filename}:{exc.lineno}:{exc.offset} — {exc.msg}"
            )

    def _lsp_interpreter_changed(self, *_):
        if self.lsp.ready:
            self.lsp.stop()
            self.issues.setPlainText("Python interpreter changed. Restart LSP.")

    def start_lsp(self):
        interpreter = self.interpreter.currentData() or sys.executable
        self.lsp.start(str(interpreter), self.root)

    def _lsp_status(self, message):
        self.statusBar().showMessage(message)
        if self.lsp.ready:
            self._lsp_publish()

    def _lsp_publish(self):
        editor = self.current_editor()
        if editor and editor.path and self.lsp.ready:
            self.lsp.open_or_change(editor.path, editor.toPlainText())

    def _lsp_diagnostics(self, uri, diagnostics):
        editor = self.current_editor()
        if not editor or not editor.path or uri != editor.path.as_uri():
            return
        lines = []
        for item in diagnostics:
            pos = item.get("range", {}).get("start", {})
            line = int(pos.get("line", 0)) + 1
            message = str(item.get("message", "")).strip()
            severity = {1: "Error", 2: "Warning", 3: "Info"}.get(
                item.get("severity"), "Diagnostic"
            )
            lines.append(f"{editor.path.name}:{line} [{severity}] {message}")
        self.issues.setPlainText("\n".join(lines))

    def complete(self):
        editor = self.current_editor()
        if editor is None:
            return
        if not editor.path:
            self.statusBar().showMessage(
                "Save the Python file to request local LSP completion."
            )
            return
        cursor = editor.textCursor()
        self.lsp.request_completion(
            editor.path,
            cursor.blockNumber(),
            cursor.positionInBlock(),
        )

    def _lsp_completions(self, suggestions):
        editor = self.current_editor()
        if editor is None or not suggestions:
            return
        menu = QMenu(editor)
        for item in suggestions[:35]:
            label = str(item.get("label", ""))
            if not label:
                continue
            text = item.get("insertText") or label
            action = menu.addAction(label)
            action.triggered.connect(
                lambda checked=False, value=text:
                    self._insert_completion(value)
            )
        location = editor.mapToGlobal(
            editor.cursorRect().bottomRight()
        )
        menu.popup(location)

    def _insert_completion(self, text):
        editor = self.current_editor()
        if editor is None:
            return
        cursor = editor.textCursor()
        cursor.select(QTextCursor.SelectionType.WordUnderCursor)
        cursor.insertText(text)
        editor.setTextCursor(cursor)

    def goto_line(self):
        editor = self.current_editor()
        if editor is None:
            return
        line, ok = QInputDialog.getInt(
            self, "Go to line", "Line:", 1, 1, editor.blockCount()
        )
        if ok:
            editor.goto_line(line)

    def find_next(self):
        editor = self.current_editor()
        if editor and self.find_box.text():
            if not editor.find(self.find_box.text()):
                cursor = editor.textCursor()
                cursor.movePosition(QTextCursor.MoveOperation.Start)
                editor.setTextCursor(cursor)
                editor.find(self.find_box.text())

    def _start(self, args, *, mode, program=None, cwd=None):
        if self.process is not None and self.process.state() != QProcess.ProcessState.NotRunning:
            QMessageBox.information(self, "Process running", "Stop the current process first.")
            return
        self.console.clear()
        self.output_dock.raise_()
        self._mode = mode
        interpreter = program or self.interpreter.currentData() or sys.executable
        proc = QProcess(self)
        proc.setWorkingDirectory(str(cwd or self.root))
        proc.setProcessChannelMode(QProcess.ProcessChannelMode.SeparateChannels)
        env = QProcessEnvironment.systemEnvironment()
        env.insert("PYTHONUNBUFFERED", "1")
        proc.setProcessEnvironment(env)
        proc.readyReadStandardOutput.connect(
            lambda: self._append(bytes(proc.readAllStandardOutput()).decode("utf-8", errors="replace"))
        )
        proc.readyReadStandardError.connect(
            lambda: self._append(bytes(proc.readAllStandardError()).decode("utf-8", errors="replace"))
        )
        proc.finished.connect(
            lambda code, status: self._finished(code, status)
        )
        self.process = proc
        self._append(f"$ {interpreter} {' '.join(args)}\n\n")
        proc.start(str(interpreter), args)

    def run_file(self):
        editor = self.current_editor()
        if editor and self.save_file():
            self._start([str(editor.path)], mode="run", cwd=editor.path.parent)

    def debug_file(self):
        editor = self.current_editor()
        if editor and self.save_file():
            arguments = ["-u", "-m", "pdb"]
            for line in sorted(editor.breakpoints):
                arguments.extend(["-c", f"break {line}"])
            arguments.append(str(editor.path))
            self._start(arguments, mode="debug", cwd=editor.path.parent)
            self._append("pdb: n=next, s=step, c=continue, b N=breakpoint, p X=inspect\n")

    def run_tests(self):
        self._start(["-m", "pytest", "-q"], mode="test")

    def open_terminal(self):
        if os.name == "nt":
            shell = os.environ.get("COMSPEC", "cmd.exe")
            args = ["/Q"]
        else:
            shell = os.environ.get("SHELL", "/bin/sh")
            args = ["-i"]
        self._start(args, mode="terminal", program=shell)

    def send_stdin(self):
        if self.process and self.process.state() == QProcess.ProcessState.Running:
            value = self.stdin.text()
            self.process.write((value + "\n").encode("utf-8"))
            self._append(f"> {value}\n")
            self.stdin.clear()

    def stop_process(self):
        if self.process and self.process.state() == QProcess.ProcessState.Running:
            self.process.terminate()
            if not self.process.waitForFinished(1500):
                self.process.kill()

    def _append(self, value):
        self.console.moveCursor(QTextCursor.MoveOperation.End)
        self.console.insertPlainText(value)
        self.console.moveCursor(QTextCursor.MoveOperation.End)

    def _finished(self, code, status):
        self._append(f"\n[Process exited with code {code}]\n")
        self.statusBar().showMessage(f"{self._mode} completed · exit {code}")

    def closeEvent(self, event):
        self.stop_process()
        self.lsp.stop()
        for index in range(self.tabs.count()):
            editor = self.tabs.widget(index)
            if isinstance(editor, CodeEditor) and editor.document().isModified():
                decision = QMessageBox.question(
                    self, "Unsaved changes", "Exit with unsaved files?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
                )
                if decision != QMessageBox.StandardButton.Yes:
                    event.ignore()
                    return
                break
        event.accept()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Arcside Python Lab")
    window = PythonLab()
    window.show()
    raise SystemExit(app.exec())


if __name__ == "__main__":
    main()
