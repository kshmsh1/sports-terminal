"""Arcside Spreadsheet — independent local desktop workbook.

pip install PySide6 openpyxl matplotlib
python tools/arcside_spreadsheet/app.py
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PySide6.QtCore import Qt, QAbstractTableModel, QModelIndex
    from PySide6.QtGui import QAction, QColor, QFont, QKeySequence
    from PySide6.QtWidgets import (
        QApplication, QComboBox, QFileDialog, QInputDialog, QLabel, QLineEdit,
        QMainWindow, QMessageBox, QSpinBox, QTabWidget, QTableView, QToolBar,
        QVBoxLayout, QWidget
    )
except ImportError as exc:
    raise SystemExit("Install the free GUI dependency: python -m pip install PySide6") from exc

from engine import Workbook, Sheet, column_name, normalize_ref, cell_coords


class SheetModel(QAbstractTableModel):
    """Virtualized 1,000,000-row spreadsheet: materialize only visible cells."""
    def __init__(self, sheet: Sheet, parent=None):
        super().__init__(parent)
        self.sheet = sheet
        self.max_rows = 1_048_576
        self.max_cols = 16_384
        self._undo: list[tuple[str, str, str]] = []
        self._redo: list[tuple[str, str, str]] = []

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else self.max_rows

    def columnCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else self.max_cols

    def headerData(self, section, orientation, role):
        if role != Qt.ItemDataRole.DisplayRole:
            return None
        return (column_name(section + 1)
                if orientation == Qt.Orientation.Horizontal else str(section + 1))

    def _ref(self, index):
        return f"{column_name(index.column() + 1)}{index.row() + 1}"

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid():
            return None
        ref = self._ref(index)
        if role == Qt.ItemDataRole.DisplayRole:
            return self.sheet.display(ref)
        if role == Qt.ItemDataRole.EditRole:
            return self.sheet.raw(ref)
        if role == Qt.ItemDataRole.TextAlignmentRole:
            value = self.sheet.value(ref)
            return (Qt.AlignmentFlag.AlignVCenter |
                    (Qt.AlignmentFlag.AlignRight if isinstance(value, (int, float))
                     else Qt.AlignmentFlag.AlignLeft))
        if role == Qt.ItemDataRole.BackgroundRole:
            style = self.sheet.styles.get(ref, {})
            if style.get("fill"):
                return QColor(style["fill"])
        if role == Qt.ItemDataRole.ForegroundRole:
            style = self.sheet.styles.get(ref, {})
            if style.get("color"):
                return QColor(style["color"])
        if role == Qt.ItemDataRole.FontRole:
            style = self.sheet.styles.get(ref, {})
            if style.get("bold"):
                font = QFont()
                font.setBold(True)
                return font
        return None

    def flags(self, index):
        return (Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsSelectable |
                Qt.ItemFlag.ItemIsEditable)

    def setData(self, index, value, role=Qt.ItemDataRole.EditRole):
        if role != Qt.ItemDataRole.EditRole:
            return False
        ref = self._ref(index)
        old = self.sheet.raw(ref)
        next_value = str(value)
        if old == next_value:
            return True
        self._undo.append((ref, old, next_value))
        self._redo.clear()
        self.sheet.set(ref, next_value)
        # Formulas can reference any visible cell; redraw current viewport.
        self.layoutChanged.emit()
        return True

    def _replay(self, from_stack, to_stack, revert):
        if not from_stack:
            return
        ref, old, new = from_stack.pop()
        self.sheet.set(ref, old if revert else new)
        to_stack.append((ref, old, new))
        self.layoutChanged.emit()

    def undo(self):
        self._replay(self._undo, self._redo, True)

    def redo(self):
        self._replay(self._redo, self._undo, False)


class Spreadsheet(QMainWindow):
    def __init__(self):
        super().__init__()
        self.workbook = Workbook()
        self.path = None
        self.setWindowTitle("Arcside Spreadsheet — Untitled")
        self.resize(1500, 900)
        self.setStyleSheet(
            "QMainWindow {background:#F6F8FA;} QToolBar {background:#E9F1EB;"
            "spacing:8px;padding:6px;border-bottom:1px solid #CCD6CD;} "
            "QTabBar::tab:selected {background:#D6EEE0;color:#115F3C;} "
            "QTableView {background:white;color:#1C2630;gridline-color:#E4E8ED;"
            "selection-background-color:#E2F0E5;selection-color:#123726;} "
        )
        self.tabs = QTabWidget()
        self.tabs.currentChanged.connect(self._sync_bar)
        self.setCentralWidget(self.tabs)
        self.name_box = QLineEdit()
        self.name_box.setFixedWidth(95)
        self.name_box.returnPressed.connect(self._goto_name)
        self.formula_box = QLineEdit()
        self.formula_box.setPlaceholderText("fx   Enter value or =SUM(A1:A10)")
        self.formula_box.returnPressed.connect(self._commit_formula)
        self._make_toolbar()
        self._rebuild_tabs()
        self.statusBar().showMessage(
            "Local workbook · Formula engine · Save as .arcside.json or .xlsx"
        )

    def _make_toolbar(self):
        bar = QToolBar("Home")
        bar.setMovable(False)
        self.addToolBar(bar)
        for label, shortcut, callback in [
            ("New", "Ctrl+N", self.new_book),
            ("Open", "Ctrl+O", self.open_book),
            ("Save", "Ctrl+S", self.save_book),
            ("Save As", "Ctrl+Shift+S", self.save_as),
            ("Undo", "Ctrl+Z", self.undo),
            ("Redo", "Ctrl+Y", self.redo),
            ("Sheet +", "Ctrl+Shift+N", self.add_sheet),
            ("Bold", "Ctrl+B", self.toggle_bold),
            ("Chart", "Ctrl+Shift+C", self.create_chart),
            ("CSV Export", "", self.export_csv),
        ]:
            action = QAction(label, self)
            if shortcut:
                action.setShortcut(shortcut)
            action.triggered.connect(callback)
            bar.addAction(action)
            self.addAction(action)
        bar.addSeparator()
        bar.addWidget(QLabel("Name"))
        bar.addWidget(self.name_box)
        bar.addWidget(QLabel("  fx"))
        self.formula_box.setMinimumWidth(420)
        bar.addWidget(self.formula_box)

    def _current(self):
        view = self.tabs.currentWidget()
        return view if isinstance(view, QTableView) else None

    def _model(self):
        view = self._current()
        return view.model() if view is not None else None

    def _rebuild_tabs(self):
        self.tabs.clear()
        for sheet in self.workbook.sheets:
            model = SheetModel(sheet, self)
            view = QTableView()
            view.setModel(model)
            view.setAlternatingRowColors(False)
            view.setSelectionBehavior(QTableView.SelectionBehavior.SelectItems)
            view.setSelectionMode(QTableView.SelectionMode.ExtendedSelection)
            view.horizontalHeader().setDefaultSectionSize(115)
            view.verticalHeader().setDefaultSectionSize(24)
            view.selectionModel().currentChanged.connect(self._sync_bar)
            view.setCurrentIndex(model.index(0, 0))
            self.tabs.addTab(view, sheet.name)
        self._sync_bar()

    def _sync_bar(self, *_):
        view = self._current()
        if view is None:
            return
        index = view.currentIndex()
        if not index.isValid():
            return
        ref = f"{column_name(index.column() + 1)}{index.row() + 1}"
        self.name_box.setText(ref)
        self.formula_box.setText(view.model().sheet.raw(ref))

    def _goto_name(self):
        try:
            row, col = cell_coords(self.name_box.text())
        except ValueError:
            self.statusBar().showMessage("Invalid cell address")
            return
        view = self._current()
        if view:
            index = view.model().index(row - 1, col - 1)
            view.setCurrentIndex(index)
            view.scrollTo(index)

    def _commit_formula(self):
        view = self._current()
        if view is None:
            return
        index = view.currentIndex()
        if index.isValid():
            view.model().setData(index, self.formula_box.text())
            self._sync_bar()

    def new_book(self):
        self.workbook = Workbook()
        self.path = None
        self._rebuild_tabs()
        self.setWindowTitle("Arcside Spreadsheet — Untitled")

    def add_sheet(self):
        name, ok = QInputDialog.getText(self, "New worksheet", "Sheet name:")
        if not ok:
            return
        try:
            sheet = self.workbook.add_sheet(name)
        except ValueError as exc:
            QMessageBox.warning(self, "Worksheet error", str(exc))
            return
        model = SheetModel(sheet, self)
        view = QTableView()
        view.setModel(model)
        view.horizontalHeader().setDefaultSectionSize(115)
        view.verticalHeader().setDefaultSectionSize(24)
        view.selectionModel().currentChanged.connect(self._sync_bar)
        view.setCurrentIndex(model.index(0, 0))
        self.tabs.setCurrentIndex(self.tabs.addTab(view, sheet.name))

    def open_book(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Open workbook", str(Path.cwd()),
            "Workbooks (*.arcside.json *.xlsx *.csv);;All files (*)"
        )
        if not path:
            return
        try:
            if path.endswith(".xlsx"):
                self.workbook = Workbook.load_xlsx(path)
            elif path.endswith(".csv"):
                self.workbook = Workbook([Sheet.load_csv(path)])
            else:
                self.workbook = Workbook.load(path)
            self.path = path
            self._rebuild_tabs()
            self.setWindowTitle(f"Arcside Spreadsheet — {Path(path).name}")
        except (ValueError, OSError, RuntimeError, KeyError) as exc:
            QMessageBox.warning(self, "Open failed", str(exc))

    def save_as(self):
        path, _ = QFileDialog.getSaveFileName(
            self, "Save workbook", str(Path.cwd() / "Workbook.arcside.json"),
            "Arcside (*.arcside.json);;Excel (*.xlsx)"
        )
        if path:
            self.path = path
            self.save_book()

    def save_book(self):
        if not self.path:
            self.save_as()
            return
        try:
            if self.path.endswith(".xlsx"):
                self.workbook.save_xlsx(self.path)
            else:
                self.workbook.save(self.path)
            self.setWindowTitle(f"Arcside Spreadsheet — {Path(self.path).name}")
            self.statusBar().showMessage(f"Saved {self.path}")
        except (OSError, RuntimeError) as exc:
            QMessageBox.warning(self, "Save failed", str(exc))

    def export_csv(self):
        model = self._model()
        if model is None:
            return
        path, _ = QFileDialog.getSaveFileName(
            self, "Export active worksheet", str(Path.cwd() / "sheet.csv"),
            "CSV (*.csv)"
        )
        if path:
            model.sheet.save_csv(path)

    def undo(self):
        model = self._model()
        if model:
            model.undo()
            self._sync_bar()

    def redo(self):
        model = self._model()
        if model:
            model.redo()
            self._sync_bar()

    def toggle_bold(self):
        view = self._current()
        if view is None:
            return
        model = view.model()
        for index in view.selectedIndexes():
            ref = model._ref(index)
            style = model.sheet.styles.setdefault(ref, {})
            style["bold"] = not style.get("bold", False)
        model.layoutChanged.emit()

    def create_chart(self):
        view = self._current()
        if view is None:
            return
        indexes = view.selectedIndexes()
        if len(indexes) < 2:
            QMessageBox.information(self, "Chart", "Select a numeric range first.")
            return
        values = []
        labels = []
        for idx in sorted(indexes, key=lambda i: (i.row(), i.column())):
            value = view.model().sheet.value(view.model()._ref(idx))
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                labels.append(view.model()._ref(idx))
                values.append(value)
        if not values:
            QMessageBox.warning(self, "Chart", "No numeric values in selection.")
            return
        chart_type, ok = QInputDialog.getItem(
            self, "Chart type", "Choose chart:", ["Bar", "Line", "Scatter"], 0, False
        )
        if not ok:
            return
        try:
            import matplotlib.pyplot as plt
        except ImportError:
            QMessageBox.warning(self, "Chart", "Install matplotlib for local charts.")
            return
        figure, axes = plt.subplots()
        if chart_type == "Line":
            axes.plot(labels, values)
        elif chart_type == "Scatter":
            axes.scatter(range(len(values)), values)
            axes.set_xticks(range(len(labels)), labels)
        else:
            axes.bar(labels, values)
        axes.tick_params(axis="x", rotation=45)
        axes.set_title(f"{view.model().sheet.name} · {chart_type}")
        figure.tight_layout()
        plt.show(block=False)


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Arcside Spreadsheet")
    window = Spreadsheet()
    window.show()
    raise SystemExit(app.exec())


if __name__ == "__main__":
    main()
