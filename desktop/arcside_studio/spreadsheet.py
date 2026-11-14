"""Arcside Excel Workspace desktop shell (PySide6).

Virtualized sheet view, formula bar, undo/redo, clipboard ranges, formatting,
local workbook persistence, CSV/XLSX interchange, and chart construction.
Uses only the local spreadsheet engine; no remote APIs or AI.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtCore import QAbstractTableModel, QModelIndex, Qt
from PySide6.QtGui import QAction, QColor, QFont, QKeySequence, QUndoCommand, QUndoStack
from PySide6.QtWidgets import (
    QApplication, QComboBox, QDialog, QFileDialog, QHBoxLayout,
    QHeaderView, QInputDialog, QLabel, QLineEdit, QMainWindow,
    QMessageBox, QPushButton, QSpinBox, QTabBar, QTableView,
    QToolBar, QVBoxLayout, QWidget,
)

try:
    from .sheet_engine import Workbook, address, col_label
except ImportError:
    from sheet_engine import Workbook, address, col_label


class SetCellCommand(QUndoCommand):
    def __init__(self, model: "SheetModel", sheet: str, cell: str, before: str, after: str):
        super().__init__(f"Edit {sheet}!{cell}")
        self.model, self.sheet, self.cell = model, sheet, cell
        self.before, self.after = before, after

    def redo(self) -> None:
        self.model.workbook.set_cell(self.sheet, self.cell, self.after)
        self.model.refresh()

    def undo(self) -> None:
        self.model.workbook.set_cell(self.sheet, self.cell, self.before)
        self.model.refresh()


class SheetModel(QAbstractTableModel):
    ROWS = 3000
    COLUMNS = 200

    def __init__(self, workbook: Workbook, undo: QUndoStack):
        super().__init__()
        self.workbook = workbook
        self.undo = undo
        self.sheet = next(iter(workbook.sheets))

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else self.ROWS

    def columnCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else self.COLUMNS

    def headerData(self, section: int, orientation: Qt.Orientation, role=Qt.DisplayRole):
        if role != Qt.DisplayRole: return None
        return col_label(section + 1) if orientation == Qt.Horizontal else str(section + 1)

    def _key(self, index: QModelIndex) -> str:
        return address(index.row() + 1, index.column() + 1)

    def data(self, index: QModelIndex, role=Qt.DisplayRole):
        if not index.isValid(): return None
        key = self._key(index)
        if role == Qt.EditRole:
            return self.workbook.raw(self.sheet, key)
        if role == Qt.DisplayRole:
            value = self.workbook.value(self.sheet, key)
            style = self.workbook.styles.get((self.sheet, key), {})
            number_format = style.get("format", "General")
            if isinstance(value, (float, int)) and not isinstance(value, bool):
                if number_format == "Number": return f"{value:,.2f}"
                if number_format == "Percent": return f"{value:.2%}"
                if number_format == "Currency": return f"${value:,.2f}"
                return f"{value:,.10g}"
            return str(value) if value is not None else ""
        if role == Qt.TextAlignmentRole:
            value = self.workbook.value(self.sheet, key)
            return int(Qt.AlignVCenter | (Qt.AlignRight if isinstance(value, (float, int)) else Qt.AlignLeft))
        if role == Qt.ForegroundRole:
            value = self.workbook.value(self.sheet, key)
            if isinstance(value, str) and value.startswith("#"):
                return QColor("#c53030")
            text = self.workbook.styles.get((self.sheet, key), {}).get("color")
            return QColor(text) if text else None
        if role == Qt.BackgroundRole:
            background = self.workbook.styles.get((self.sheet, key), {}).get("background")
            return QColor(background) if background else None
        if role == Qt.FontRole:
            if self.workbook.styles.get((self.sheet, key), {}).get("bold"):
                font = QFont()
                font.setBold(True)
                return font
        return None

    def flags(self, index: QModelIndex):
        if not index.isValid(): return Qt.ItemIsEnabled
        return Qt.ItemIsEnabled | Qt.ItemIsSelectable | Qt.ItemIsEditable

    def setData(self, index: QModelIndex, value, role=Qt.EditRole) -> bool:
        if role != Qt.EditRole or not index.isValid(): return False
        key = self._key(index)
        previous = self.workbook.raw(self.sheet, key)
        next_value = str(value)
        if previous != next_value:
            self.undo.push(SetCellCommand(self, self.sheet, key, previous, next_value))
        return True

    def refresh(self) -> None:
        self.dataChanged.emit(self.index(0, 0), self.index(self.ROWS - 1, self.COLUMNS - 1),
                              [Qt.DisplayRole, Qt.EditRole, Qt.ForegroundRole])

    def select_sheet(self, sheet: str) -> None:
        self.beginResetModel()
        self.sheet = sheet
        self.endResetModel()


class SpreadsheetWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.book = Workbook()
        self.undo = QUndoStack(self)
        self.model = SheetModel(self.book, self.undo)
        self.current_file: Path | None = None
        self.setWindowTitle("Arcside · Excel Workspace")
        self.resize(1480, 860)

        base = QWidget()
        layout = QVBoxLayout(base)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        self.setCentralWidget(base)
        self._toolbar()

        formula_row = QHBoxLayout()
        formula_row.setContentsMargins(12, 8, 12, 8)
        self.name_box = QLineEdit("A1")
        self.name_box.setFixedWidth(92)
        self.name_box.returnPressed.connect(self._go_to_address)
        self.formula_bar = QLineEdit()
        self.formula_bar.setPlaceholderText("fx  =SUM(A1:B10)")
        self.formula_bar.returnPressed.connect(self._commit_formula)
        formula_row.addWidget(QLabel("Cell"))
        formula_row.addWidget(self.name_box)
        formula_row.addWidget(QLabel("fx"))
        formula_row.addWidget(self.formula_bar, 1)
        layout.addLayout(formula_row)

        self.grid = QTableView()
        self.grid.setModel(self.model)
        self.grid.setSelectionMode(QTableView.ExtendedSelection)
        self.grid.setSelectionBehavior(QTableView.SelectItems)
        self.grid.setAlternatingRowColors(True)
        self.grid.setWordWrap(False)
        self.grid.horizontalHeader().setSectionResizeMode(QHeaderView.Interactive)
        self.grid.verticalHeader().setDefaultSectionSize(27)
        self.grid.horizontalHeader().setDefaultSectionSize(105)
        self.grid.selectionModel().currentChanged.connect(self._selected)
        layout.addWidget(self.grid, 1)

        tabs_row = QHBoxLayout()
        self.tabs = QTabBar()
        self.tabs.currentChanged.connect(self._sheet_changed)
        self.tabs.addTab("Sheet1")
        add = QPushButton("+")
        add.setFixedWidth(32)
        add.clicked.connect(self._add_sheet)
        tabs_row.addWidget(self.tabs)
        tabs_row.addWidget(add)
        tabs_row.addStretch()
        layout.addLayout(tabs_row)
        self.statusBar().showMessage("Arcside workbook · formulas calculate locally · 3,000 × 200 virtual grid")
        self.grid.setCurrentIndex(self.model.index(0, 0))
        self.setStyleSheet("""
            QMainWindow { background: #f7f9fb; }
            QTableView { gridline-color: #dae0e6; font-size: 12px; }
            QHeaderView::section { background: #edf1f4; border: 1px solid #dce2e8;
                padding: 4px; font-weight: bold; }
            QToolBar { background: #107c41; border: 0; padding: 6px; spacing: 7px; }
            QToolBar QToolButton { color: white; padding: 7px 9px; border-radius: 4px; }
            QToolBar QToolButton:hover { background: #236e4b; }
            QTabBar::tab { padding: 8px 16px; background: #e6ecea; }
            QTabBar::tab:selected { background: white; border-top: 2px solid #107c41; }
        """)

    def _action(self, label: str, callback, shortcut: str | None = None):
        action = QAction(label, self)
        action.triggered.connect(callback)
        if shortcut: action.setShortcut(QKeySequence(shortcut))
        self.addAction(action)
        return action

    def _toolbar(self):
        toolbar = QToolBar("Workbook")
        toolbar.setMovable(False)
        self.addToolBar(toolbar)
        for label, callback, shortcut in [
            ("New", self._new, "Ctrl+N"),
            ("Open", self._open, "Ctrl+O"),
            ("Save", self._save, "Ctrl+S"),
            ("Save As", self._save_as, "Ctrl+Shift+S"),
            ("Undo", self.undo.undo, "Ctrl+Z"),
            ("Redo", self.undo.redo, "Ctrl+Y"),
            ("Copy", self._copy, "Ctrl+C"),
            ("Paste", self._paste, "Ctrl+V"),
            ("Clear", self._clear, "Delete"),
            ("Bold", self._bold, "Ctrl+B"),
            ("Format Table", self._table_style, None),
            ("Chart", self._chart, None),
        ]:
            toolbar.addAction(self._action(label, callback, shortcut))
        toolbar.addSeparator()
        self.number_format = QComboBox()
        self.number_format.addItems(["General", "Number", "Percent", "Currency"])
        self.number_format.currentTextChanged.connect(self._number_format)
        toolbar.addWidget(self.number_format)

    def _selected(self, index: QModelIndex):
        if not index.isValid(): return
        key = address(index.row() + 1, index.column() + 1)
        self.name_box.setText(key)
        self.formula_bar.setText(self.book.raw(self.model.sheet, key))
        self.statusBar().showMessage(f"{self.model.sheet}!{key}")

    def _go_to_address(self):
        try:
            from .sheet_engine import coordinates
        except ImportError:
            from sheet_engine import coordinates
        try:
            row, col = coordinates(self.name_box.text().upper())
            self.grid.setCurrentIndex(self.model.index(row - 1, col - 1))
            self.grid.scrollTo(self.grid.currentIndex())
        except Exception:
            QMessageBox.warning(self, "Address", "Enter a valid cell such as D23.")

    def _commit_formula(self):
        index = self.grid.currentIndex()
        if index.isValid():
            self.model.setData(index, self.formula_bar.text())
            next_index = self.model.index(index.row() + 1, index.column())
            self.grid.setCurrentIndex(next_index)

    def _sheet_changed(self, index: int):
        if index >= 0:
            self.model.select_sheet(self.tabs.tabText(index))
            self.grid.setCurrentIndex(self.model.index(0, 0))

    def _add_sheet(self):
        name, ok = QInputDialog.getText(self, "New sheet", "Sheet name:")
        if not ok or not name: return
        try:
            self.book.add_sheet(name)
            self.tabs.addTab(name)
            self.tabs.setCurrentIndex(self.tabs.count() - 1)
        except ValueError as error:
            QMessageBox.warning(self, "Sheet", str(error))

    def _new(self):
        self.book = Workbook()
        self.model.workbook = self.book
        self.model.select_sheet("Sheet1")
        self.tabs.blockSignals(True)
        self.tabs.clear()
        self.tabs.addTab("Sheet1")
        self.tabs.blockSignals(False)
        self.undo.clear()
        self.current_file = None
        self.setWindowTitle("Arcside · Excel Workspace")

    def _open(self):
        filename, _ = QFileDialog.getOpenFileName(self, "Open workbook", "",
            "Arcside (*.arcside.json *.json);;Excel (*.xlsx);;CSV (*.csv)")
        if not filename: return
        path = Path(filename)
        try:
            if path.suffix == ".xlsx":
                book = Workbook()
                book.import_xlsx(path)
            elif path.suffix == ".csv":
                book = Workbook()
                book.import_csv(path)
            else:
                book = Workbook.load(path)
            self.book = book
            self.model.workbook = book
            self.tabs.blockSignals(True)
            self.tabs.clear()
            for name in book.sheets: self.tabs.addTab(name)
            self.tabs.blockSignals(False)
            self.model.select_sheet(next(iter(book.sheets)))
            self.undo.clear()
            self.current_file = path
            self.setWindowTitle(f"Arcside · {path.name}")
        except Exception as error:
            QMessageBox.critical(self, "Open failed", str(error))

    def _save_as(self):
        filename, _ = QFileDialog.getSaveFileName(self, "Save workbook",
            str(self.current_file or "Workbook.arcside.json"),
            "Arcside (*.arcside.json);;Excel (*.xlsx);;CSV (*.csv)")
        if filename:
            self.current_file = Path(filename)
            self._save()

    def _save(self):
        if self.current_file is None:
            self._save_as()
            return
        try:
            path = self.current_file
            if path.suffix == ".xlsx": self.book.export_xlsx(path)
            elif path.suffix == ".csv": self.book.export_csv(path, self.model.sheet)
            else: self.book.save(path)
            self.setWindowTitle(f"Arcside · {path.name}")
            self.statusBar().showMessage(f"Saved {path}")
        except Exception as error:
            QMessageBox.critical(self, "Save failed", str(error))

    def _selected_cells(self):
        return self.grid.selectionModel().selectedIndexes()

    def _copy(self):
        indexes = self._selected_cells()
        if not indexes: return
        row_min, row_max = min(x.row() for x in indexes), max(x.row() for x in indexes)
        col_min, col_max = min(x.column() for x in indexes), max(x.column() for x in indexes)
        lines = [
            "\t".join(self.model.data(self.model.index(row, col), Qt.DisplayRole)
                      for col in range(col_min, col_max + 1))
            for row in range(row_min, row_max + 1)
        ]
        QApplication.clipboard().setText("\n".join(lines))

    def _paste(self):
        index = self.grid.currentIndex()
        if not index.isValid(): return
        text = QApplication.clipboard().text()
        if len(text) > 1_000_000:
            QMessageBox.warning(self, "Paste", "Paste is too large for one operation.")
            return
        for r, line in enumerate(text.splitlines()):
            for c, value in enumerate(line.split("\t")):
                target = self.model.index(index.row() + r, index.column() + c)
                if target.isValid():
                    self.model.setData(target, value)

    def _clear(self):
        for index in self._selected_cells():
            self.model.setData(index, "")

    def _bold(self):
        for index in self._selected_cells():
            key = (self.model.sheet, self.model._key(index))
            style = self.book.styles.setdefault(key, {})
            style["bold"] = not style.get("bold", False)
        self.model.refresh()

    def _number_format(self, value: str):
        for index in self._selected_cells():
            key = (self.model.sheet, self.model._key(index))
            self.book.styles.setdefault(key, {})["format"] = value
        self.model.refresh()

    def _table_style(self):
        indexes = self._selected_cells()
        if not indexes: return
        top = min(index.row() for index in indexes)
        for index in indexes:
            key = (self.model.sheet, self.model._key(index))
            style = self.book.styles.setdefault(key, {})
            if index.row() == top:
                style["bold"] = True
                style["background"] = "#107c41"
                style["color"] = "#ffffff"
            else:
                style["background"] = "#e9f4ee" if (index.row()-top) % 2 else "#ffffff"
                style["color"] = "#202830"
        self.model.refresh()

    def _chart(self):
        indexes = sorted(self._selected_cells(), key=lambda x: (x.row(), x.column()))
        if len(indexes) < 4:
            QMessageBox.information(self, "Chart", "Select a two-column table to chart.")
            return
        try:
            from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as Canvas
            from matplotlib.figure import Figure
        except ImportError:
            QMessageBox.information(self, "Charts", "Install matplotlib locally to create charts.")
            return
        rows = sorted({x.row() for x in indexes})
        cols = sorted({x.column() for x in indexes})
        if len(cols) < 2:
            QMessageBox.information(self, "Chart", "Select an X and Y column.")
            return
        points = []
        for row in rows:
            x = self.book.value(self.model.sheet, address(row + 1, cols[0] + 1))
            y = self.book.value(self.model.sheet, address(row + 1, cols[1] + 1))
            if isinstance(y, (float, int)) and not isinstance(y, bool):
                points.append((str(x), float(y)))
        if not points:
            QMessageBox.information(self, "Chart", "No numeric Y values found.")
            return
        chart_type, ok = QInputDialog.getItem(self, "Chart type", "Chart",
            ["Line", "Bar", "Scatter"], 0, False)
        if not ok: return
        dialog = QDialog(self)
        dialog.setWindowTitle("Arcside · Chart")
        dialog.resize(780, 520)
        layout = QVBoxLayout(dialog)
        figure = Figure(figsize=(9, 5))
        canvas = Canvas(figure)
        ax = figure.add_subplot(111)
        xx = list(range(len(points)))
        ys = [p[1] for p in points]
        if chart_type == "Bar": ax.bar(xx, ys)
        elif chart_type == "Scatter": ax.scatter(xx, ys)
        else: ax.plot(xx, ys)
        ax.set_xticks(xx)
        ax.set_xticklabels([p[0] for p in points], rotation=45, ha="right")
        ax.set_title(f"{self.model.sheet} · Arcside")
        figure.tight_layout()
        layout.addWidget(canvas)
        dialog.exec()


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName("Arcside Excel Workspace")
    window = SpreadsheetWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
