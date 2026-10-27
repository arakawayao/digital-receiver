"""Transactional copies of the workstation's parameter controls."""
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QCheckBox, QComboBox, QDialog, QDialogButtonBox, QDoubleSpinBox,
    QFileDialog, QFormLayout, QHBoxLayout, QLabel, QLineEdit, QSlider,
    QStyle, QToolButton, QVBoxLayout, QWidget,
)


class SettingsDialog(QDialog):
    def __init__(self, title, fields, parent):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setMinimumWidth(420)
        self.controls = {}
        self.originals = {}
        layout = QVBoxLayout(self)
        form = QFormLayout()
        form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        layout.addLayout(form)
        for key, name, original in fields:
            control = self._copy_control(original)
            control.setObjectName(key)
            control.setAccessibleName(name)
            control.setEnabled(original.isEnabled())
            self.controls[key] = control
            self.originals[key] = original
            row = control
            if key in ("dll_path", "replay_path"):
                row = QWidget()
                horizontal = QHBoxLayout(row)
                horizontal.setContentsMargins(0, 0, 0, 0)
                horizontal.addWidget(control)
                button = QToolButton()
                button.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DirOpenIcon))
                button.setToolTip("选择文件")
                button.setEnabled(parent.source.isEnabled())
                button.clicked.connect(lambda checked=False, key=key: self._browse(key))
                horizontal.addWidget(button)
            elif isinstance(control, QSlider):
                row = QWidget()
                horizontal = QHBoxLayout(row)
                horizontal.setContentsMargins(0, 0, 0, 0)
                horizontal.addWidget(control)
                value = QLabel(f"{control.value()} %")
                value.setMinimumWidth(48)
                control.valueChanged.connect(lambda number, value=value: value.setText(f"{number} %"))
                horizontal.addWidget(value)
            form.addRow(name, row)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.button(QDialogButtonBox.StandardButton.Ok).setText("确定")
        buttons.button(QDialogButtonBox.StandardButton.Cancel).setText("取消")
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    @staticmethod
    def _copy_control(original):
        if isinstance(original, QComboBox):
            copy = QComboBox()
            for index in range(original.count()):
                copy.addItem(original.itemText(index), original.itemData(index))
            copy.setCurrentIndex(original.currentIndex())
        elif isinstance(original, QDoubleSpinBox):
            copy = QDoubleSpinBox()
            copy.setDecimals(original.decimals())
            copy.setRange(original.minimum(), original.maximum())
            copy.setSingleStep(original.singleStep())
            copy.setSuffix(original.suffix())
            copy.setValue(original.value())
        elif isinstance(original, QLineEdit):
            copy = QLineEdit(original.text())
            copy.setMaxLength(original.maxLength())
            copy.setPlaceholderText(original.placeholderText())
        elif isinstance(original, QCheckBox):
            copy = QCheckBox()
            copy.setChecked(original.isChecked())
        elif isinstance(original, QSlider):
            copy = QSlider(Qt.Orientation.Horizontal)
            copy.setRange(original.minimum(), original.maximum())
            copy.setValue(original.value())
        else:
            raise TypeError(type(original).__name__)
        return copy

    def _browse(self, key):
        file_filter = "CyUSB.dll (CyUSB.dll)" if key == "dll_path" else "原始传输帧 (*.fcr *.bin);;所有文件 (*)"
        path, _ = QFileDialog.getOpenFileName(self, "选择文件", self.controls[key].text(), file_filter)
        if path:
            self.controls[key].setText(path)
            if key == "replay_path":
                self.controls["source"].setCurrentText("文件回放")

    def apply(self):
        # A running stream or an audio state change may have locked a field while open.
        for key, control in self.controls.items():
            original = self.originals[key]
            if not original.isEnabled():
                continue
            if isinstance(control, QComboBox):
                original.setCurrentIndex(original.findData(control.currentData())
                                         if control.currentData() is not None else original.findText(control.currentText()))
            elif isinstance(control, QLineEdit):
                original.setText(control.text())
            elif isinstance(control, QCheckBox):
                original.setChecked(control.isChecked())
            else:
                original.setValue(control.value())
