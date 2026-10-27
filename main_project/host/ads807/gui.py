"""Qt workstation. All receiver commands cross explicit Qt signals."""
from datetime import datetime
from pathlib import Path

import numpy as np
import pyqtgraph as pg
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QAction, QActionGroup, QFont, QIcon
from PyQt6.QtWidgets import (
    QAbstractItemView, QApplication, QCheckBox, QComboBox, QDockWidget,
    QDialog, QDoubleSpinBox, QFileDialog, QFormLayout, QGroupBox, QHBoxLayout,
    QHeaderView, QLabel, QLineEdit, QMainWindow, QPlainTextEdit,
    QPushButton, QScrollArea, QSlider, QSplitter, QStyle,
    QTableWidget, QTableWidgetItem, QTabWidget, QToolBar, QToolButton, QVBoxLayout, QWidget,
)

from .paths import HOST_ROOT
from .dsp import AUDIO_RATE, DEMODULATION_MODES, FM_DEEMPHASIS_OPTIONS
from .protocol import IQ_RATE
from .sources import SourceConfig
from .tuning import MODE_NAMES
from .settings_dialog import SettingsDialog


def label(text="", role=None):
    widget = QLabel(text)
    if role:
        widget.setProperty("role", role)
    widget.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
    return widget


class Window(QMainWindow):
    start_requested = pyqtSignal(object)
    stop_requested = pyqtSignal()
    window_requested = pyqtSignal(float)
    pause_requested = pyqtSignal(bool)
    save_requested = pyqtSignal(str)
    audio_requested = pyqtSignal(bool, object)
    volume_requested = pyqtSignal(float)
    deemphasis_requested = pyqtSignal(int)
    demodulation_requested = pyqtSignal(str)
    close_requested = pyqtSignal()
    records_requested = pyqtSignal(str)
    devices_requested = pyqtSignal()
    fft_requested = pyqtSignal(int)

    def __init__(self, records_path=None):
        super().__init__()
        self.setWindowTitle("ADS807 · EP4CE6 两模式接收分析工作台")
        self.setWindowIcon(QIcon(str(Path(__file__).with_name("assets") / "receiver.ico")))
        self.resize(1440, 940)
        self.setMinimumSize(1024, 720)
        self.records_path = Path(records_path or HOST_ROOT/"captures")
        self.current = None
        self.stats = {}
        self.measurement = {}
        self.closing = False
        self.allow_close = False
        self.tracking = True
        self.last_display_mode = ""
        self.current_theme = "dark"
        self.panels = {}
        self.panel_actions = {}
        self._build_toolbar()
        self._build_connection()
        self._build_center()
        self._build_measurements()
        self.resizeDocks([self.connection_dock, self.measurement_dock], [260, 285], Qt.Orientation.Horizontal)
        self.status = label("就绪")
        self.statusBar().addWidget(self.status, 1)
        self.rate_label = label("43.5 MS/s ADC   |   500 kIQ/s   |   TRI1 / FCR1 回放")
        self.statusBar().addPermanentWidget(self.rate_label)
        self._build_menus()
        self.default_layout = self.saveState()
        self.append_log("工作台就绪；USB 使用 receiver_ads807_dual，EP2 IN / EP6 OUT。")
        self.append_log("版本标识：FM 低频偏/宽带识别 + 10 Hz 界面刷新。")

    def _action(self, title, icon, slot, checkable=False):
        action = QAction(self.style().standardIcon(icon), title, self)
        action.setToolTip(title)
        action.setCheckable(checkable)
        action.triggered.connect(slot)
        return action

    def _build_toolbar(self):
        toolbar = QToolBar("采集控制", self)
        self.toolbar = toolbar
        toolbar.setObjectName("acquisition_toolbar")
        toolbar.setMovable(False)
        toolbar.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.addToolBar(toolbar)
        toolbar.addWidget(label("ADS807 / 接收分析", "brand"))
        self.start_action = self._action("开始", QStyle.StandardPixmap.SP_MediaPlay, self.request_start)
        toolbar.addAction(self.start_action)
        self.stop_action = self._action("停止", QStyle.StandardPixmap.SP_MediaStop, self.stop_requested.emit)
        self.stop_action.setEnabled(False)
        toolbar.addAction(self.stop_action)
        self.pause_action = self._action("冻结显示", QStyle.StandardPixmap.SP_MediaPause,
                                         self.pause_requested.emit, True)
        toolbar.addAction(self.pause_action)
        toolbar.addSeparator()
        self.save_action = self._action("保存波形", QStyle.StandardPixmap.SP_DialogSaveButton, self.request_save)
        self.save_action.setEnabled(False)
        toolbar.addAction(self.save_action)
        self.reset_action = self._action("复位视图", QStyle.StandardPixmap.SP_BrowserReload, self.reset_view)
        toolbar.addAction(self.reset_action)
        toolbar.addSeparator()
        self.source_badge = label("USB · 未连接", "warning")
        toolbar.addWidget(self.source_badge)

    def _dock(self, name, body, side):
        dock = QDockWidget(name, self)
        dock.setObjectName(name)
        dock.setFeatures(QDockWidget.DockWidgetFeature.DockWidgetMovable |
                         QDockWidget.DockWidgetFeature.DockWidgetFloatable)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(body)
        dock.setWidget(scroll)
        dock.setMinimumWidth(215)
        self.addDockWidget(side, dock)
        return dock

    def _config_button(self, form, key, title):
        button = QToolButton()
        button.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogDetailedView))
        button.setToolTip(f"配置{title}")
        button.setAccessibleName(f"配置{title}")
        button.clicked.connect(lambda: self.open_settings(key))
        row = QHBoxLayout()
        row.addStretch()
        row.addWidget(button)
        form.addRow(row)

    def _build_connection(self):
        body = QWidget()
        layout = QVBoxLayout(body)
        connection_group = QGroupBox("连接与数据源")
        form = QFormLayout(connection_group)
        self.panels["connection"] = connection_group
        self._config_button(form, "connection", "连接与数据源")
        form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        self.source = QComboBox()
        self.source.addItems(["USB", "合成 AM", "合成 FM", "合成 无信号", "合成 噪声", "文件回放"])
        self.source.currentTextChanged.connect(self.source_changed)
        form.addRow("数据源", self.source)
        self.vid, self.pid = QLineEdit("04B4"), QLineEdit("1004")
        self.vid.setMaxLength(6)
        self.pid.setMaxLength(6)
        form.addRow("USB VID", self.vid)
        form.addRow("USB PID", self.pid)
        self.dll_path = QLineEdit()
        self.dll_path.setPlaceholderText("自动查找 CyUSB.dll")
        self.dll_path.setToolTip("官方 Cypress .NET DLL 路径")
        dll_row = QWidget()
        row = QHBoxLayout(dll_row)
        row.setContentsMargins(0, 0, 0, 0)
        row.addWidget(self.dll_path)
        browse = QPushButton()
        self.dll_browse = browse
        browse.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DirOpenIcon))
        browse.setToolTip("选择 CyUSB.dll")
        browse.clicked.connect(self.select_dll)
        row.addWidget(browse)
        form.addRow("驱动 DLL", dll_row)
        self.replay_path = QLineEdit()
        self.replay_path.setPlaceholderText("transport.fcr / capture.bin")
        self.replay_path.setToolTip("TRI1 / FCR1 v2 原始字节流")
        form.addRow("回放文件", self.replay_path)
        open_file = QPushButton("选择回放文件…")
        self.replay_browse = open_file
        open_file.clicked.connect(self.select_replay)
        form.addRow(open_file)
        layout.addWidget(connection_group)
        tuning_group = QGroupBox("载频调谐")
        self.panels["tuning"] = tuning_group
        tuning_form = QFormLayout(tuning_group)
        self._config_button(tuning_form, "tuning", "载频调谐")
        self.tuning_mode = QComboBox()
        for code, name in MODE_NAMES.items():
            self.tuning_mode.addItem(name, code)
        self.tuning_mode.currentIndexChanged.connect(self.tuning_changed)
        tuning_form.addRow("模式", self.tuning_mode)
        self.manual_rf = QDoubleSpinBox()
        self.manual_rf.setDecimals(6)
        self.manual_rf.setRange(88, 108)
        self.manual_rf.setValue(100)
        self.manual_rf.setSingleStep(.1)
        self.manual_rf.setSuffix(" MHz")
        self.manual_rf.setEnabled(False)
        tuning_form.addRow("载频", self.manual_rf)
        self.hold_time = QDoubleSpinBox()
        self.hold_time.setDecimals(0)
        self.hold_time.setRange(1, 60000)
        self.hold_time.setValue(500)
        self.hold_time.setSuffix(" ms")
        tuning_form.addRow("失信保持", self.hold_time)
        layout.addWidget(tuning_group)
        display_group = QGroupBox("显示与 FFT")
        self.panels["display"] = display_group
        display_form = QFormLayout(display_group)
        self._config_button(display_form, "display", "显示与 FFT")
        self.window_ms = QDoubleSpinBox()
        self.window_ms.setRange(2, 200)
        self.window_ms.setValue(20)
        self.window_ms.setSuffix(" ms")
        self.window_ms.setSingleStep(2)
        self.window_ms.valueChanged.connect(self.window_changed)
        display_form.addRow("时间窗口", self.window_ms)
        self.fft_size = QComboBox()
        self.fft_size.addItems(["2048", "4096", "8192"])
        self.fft_size.setCurrentText("8192")
        self.fft_size.currentTextChanged.connect(lambda value: self.fft_requested.emit(int(value)))
        display_form.addRow("FFT 点数", self.fft_size)
        self.fft_span = QDoubleSpinBox()
        self.fft_span.setRange(1, 250)
        self.fft_span.setValue(100)
        self.fft_span.setSuffix(" kHz")
        self.fft_span.valueChanged.connect(self.reset_view)
        display_form.addRow("频谱半宽", self.fft_span)
        self.follow = QCheckBox("跟随最新数据")
        self.follow.setChecked(True)
        self.follow.toggled.connect(self.follow_changed)
        display_form.addRow(self.follow)
        layout.addWidget(display_group)
        audio_group = QGroupBox("音频输出")
        self.panels["audio"] = audio_group
        audio_form = QFormLayout(audio_group)
        self._config_button(audio_form, "audio", "音频输出")
        self.audio_device = QComboBox()
        self.audio_device.addItem("系统默认扬声器", None)
        self.device_refresh = QPushButton()
        self.device_refresh.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_BrowserReload))
        self.device_refresh.setToolTip("刷新音频设备")
        self.device_refresh.clicked.connect(self.populate_audio_devices)
        audio_form.addRow("设备", self.audio_device)
        audio_form.addRow(self.device_refresh)
        self.audio_on = QCheckBox("扬声器输出")
        self.audio_on.toggled.connect(lambda enabled: self.audio_requested.emit(enabled, self.audio_device.currentData()))
        audio_form.addRow(self.audio_on)
        self.volume = QSlider(Qt.Orientation.Horizontal)
        self.volume.setRange(0, 100)
        self.volume.setValue(35)
        self.volume.setToolTip("音量")
        self.volume.valueChanged.connect(lambda value: self.volume_requested.emit(value/100))
        audio_form.addRow("音量", self.volume)
        self.deemphasis = QComboBox()
        for value, title in FM_DEEMPHASIS_OPTIONS:
            self.deemphasis.addItem(title, value)
        self.deemphasis.setToolTip("FM 一阶去加重时间常数；50/75 µs 为广播常用值，其余为实验档位")
        self.deemphasis.currentIndexChanged.connect(
            lambda index: self.deemphasis_requested.emit(self.deemphasis.itemData(index)))
        audio_form.addRow("FM 去加重", self.deemphasis)
        layout.addWidget(audio_group)
        audio_form.addRow(label("单声道 48 kHz  /  音频带宽 15 kHz", "muted"))
        layout.addStretch()
        self.connection_dock = self._dock("连接与采集", body, Qt.DockWidgetArea.LeftDockWidgetArea)

    def populate_audio_devices(self):
        self.devices_requested.emit()

    @pyqtSlot(object)
    def update_devices(self, devices):
        self.audio_device.clear()
        self.audio_device.addItem("系统默认扬声器", None)
        for index, name in devices:
            self.audio_device.addItem(f"{index}: {name}", index)

    def _build_center(self):
        pg.setConfigOptions(antialias=False, background="#151719", foreground="#aab3bf")
        self.splitter = QSplitter(Qt.Orientation.Vertical)
        self.tabs = QTabWidget()
        self.plots = []
        for title, ylabel, unit in [("解调波形", "幅度", ""), ("FFT 频谱", "幅度", "dBFS"), ("原始 I/Q", "幅度", "FS")]:
            plot = pg.PlotWidget()
            plot.setLabel("left", ylabel, units=unit)
            plot.setLabel("bottom", "时间", units="ms")
            plot.showGrid(x=True, y=True, alpha=.18)
            plot.setMenuEnabled(False)
            plot.getPlotItem().hideButtons()
            plot.getViewBox().sigRangeChangedManually.connect(self.manual_zoom)
            plot.setMinimumSize(280, 190)
            self.tabs.addTab(plot, title)
            self.plots.append(plot)
        self.demod_plot, self.fft_plot, self.iq_plot = self.plots
        self.fft_plot.setLabel("bottom", "相对数字本振频率", units="kHz")
        self.demod_curve = self.demod_plot.plot(pen=pg.mkPen("#91ef7d", width=1.4))
        self.fft_curve = self.fft_plot.plot(pen=pg.mkPen("#f5c96d", width=1.3), fillLevel=-140, brush=(245, 201, 109, 14))
        self.iq_plot.addLegend(offset=(12, 12))
        self.i_curve = self.iq_plot.plot(pen=pg.mkPen("#53d9ed", width=1.2), name="I")
        self.q_curve = self.iq_plot.plot(pen=pg.mkPen("#f088bc", width=1.2), name="Q")
        self.peak_line = pg.InfiniteLine(angle=90, pen=pg.mkPen("#a2acbc", style=Qt.PenStyle.DashLine))
        self.fft_plot.addItem(self.peak_line)
        for plot in self.plots:
            for axis in ("left", "bottom"):
                plot.getAxis(axis).setStyle(tickFont=QFont("Segoe UI", 9))
        self.tabs.currentChanged.connect(self.redraw)
        self.splitter.addWidget(self.tabs)
        lower = self.lower = QTabWidget()
        self.log_view = QPlainTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setMaximumBlockCount(300)
        self.log_view.setFont(QFont("Consolas", 10))
        lower.addTab(self.log_view, "事件日志")
        self.panels["log"] = self.log_view
        records = QWidget()
        records_layout = QVBoxLayout(records)
        controls = QHBoxLayout()
        self.record_query = QLineEdit()
        self.record_query.setPlaceholderText("查找记录：时间 / 类型 / 载频 / 数据源")
        self.record_query.textChanged.connect(self.filter_records)
        controls.addWidget(self.record_query)
        refresh = QPushButton("刷新")
        refresh.clicked.connect(self.refresh_records)
        controls.addWidget(refresh)
        records_layout.addLayout(controls)
        self.records = QTableWidget(0, 4)
        self.records.setHorizontalHeaderLabels(["保存时间", "调制", "载频 MHz", "数据源"])
        self.records.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.records.verticalHeader().hide()
        self.records.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.records.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.records.cellDoubleClicked.connect(self.replay_record)
        records_layout.addWidget(self.records)
        lower.addTab(records, "测量记录")
        self.panels["records"] = records
        lower.setMinimumHeight(120)
        self.splitter.addWidget(lower)
        self.splitter.setSizes([610, 180])
        self.setCentralWidget(self.splitter)
        self.apply_plot_theme("dark")

    def _theme_colors(self, theme):
        if theme == "light":
            return {
                "plot_background": "#f7f9fb",
                "foreground": "#364152",
                "grid_alpha": .24,
                "demod": "#16843b",
                "fft": "#a46100",
                "fft_fill": (164, 97, 0, 28),
                "i": "#007a9a",
                "q": "#a52b70",
                "peak": "#687384",
            }
        return {
            "plot_background": "#151719",
            "foreground": "#aab3bf",
            "grid_alpha": .18,
            "demod": "#91ef7d",
            "fft": "#f5c96d",
            "fft_fill": (245, 201, 109, 14),
            "i": "#53d9ed",
            "q": "#f088bc",
            "peak": "#a2acbc",
        }

    def apply_plot_theme(self, theme=None):
        """Apply colors to pyqtgraph objects, which do not consume Qt QSS."""
        theme = theme or self.current_theme
        colors = self._theme_colors(theme)
        for plot in self.plots:
            plot.setBackground(colors["plot_background"])
            plot.showGrid(x=True, y=True, alpha=colors["grid_alpha"])
            for axis_name in ("left", "bottom"):
                axis = plot.getAxis(axis_name)
                axis.setPen(pg.mkPen(colors["foreground"]))
                axis.setTextPen(pg.mkPen(colors["foreground"]))
                axis.setTickFont(QFont("Segoe UI", 9))
        self.demod_curve.setPen(pg.mkPen(colors["demod"], width=1.4))
        self.fft_curve.setPen(pg.mkPen(colors["fft"], width=1.3))
        self.fft_curve.setBrush(pg.mkBrush(colors["fft_fill"]))
        self.i_curve.setPen(pg.mkPen(colors["i"], width=1.2))
        self.q_curve.setPen(pg.mkPen(colors["q"], width=1.2))
        self.peak_line.setPen(pg.mkPen(colors["peak"], style=Qt.PenStyle.DashLine))
        legend = self.iq_plot.plotItem.legend
        if legend is not None:
            for _, text_item in legend.items:
                text_item.setText(text_item.text, color=colors["foreground"])

    def set_theme(self, theme):
        if theme not in ("dark", "light"):
            return
        filename = "theme_light.qss" if theme == "light" else "theme.qss"
        stylesheet = Path(__file__).with_name(filename).read_text(encoding="utf-8")
        app = QApplication.instance()
        if app is not None:
            app.setStyleSheet(stylesheet)
        self.current_theme = theme
        self.apply_plot_theme(theme)
        for name, action in getattr(self, "theme_actions", {}).items():
            action.setChecked(name == theme)
        self.append_log(f"界面主题：{'浅色' if theme == 'light' else '深色'}")

    def _build_measurements(self):
        body = QWidget()
        layout = QVBoxLayout(body)
        recognition = QGroupBox("调制识别")
        self.panels["recognition"] = recognition
        recognition_layout = QVBoxLayout(recognition)
        self.kind_label = label("—", "signal")
        recognition_layout.addWidget(self.kind_label)
        self.confidence_label = label("等待有效连续数据", "muted")
        self.confidence_label.setWordWrap(True)
        recognition_layout.addWidget(self.confidence_label)
        recognition_form = QFormLayout()
        self._config_button(recognition_form, "recognition", "解调模式")
        self.demodulation_mode = QComboBox()
        self.demodulation_mode.setAccessibleName("解调模式")
        for mode, title in DEMODULATION_MODES.items():
            self.demodulation_mode.addItem(title, mode)
        self.demodulation_mode.currentIndexChanged.connect(
            lambda: self.demodulation_requested.emit(self.demodulation_mode.currentData()))
        recognition_form.addRow("解调模式", self.demodulation_mode)
        recognition_layout.addLayout(recognition_form)
        self.demodulation_status = label("解调：等待数据", "muted")
        self.demodulation_status.setWordWrap(True)
        recognition_layout.addWidget(self.demodulation_status)
        layout.addWidget(recognition)
        tuning_group = QGroupBox("调谐状态")
        self.panels["tuningstatus"] = tuning_group
        tuning_layout = QVBoxLayout(tuning_group)
        self.tuning_status = label("调谐：未连接", "muted")
        self.tuning_status.setWordWrap(True)
        tuning_layout.addWidget(self.tuning_status)
        self.tuning_values = label("设定载频：—\n可信度：—", "muted")
        self.tuning_values.setWordWrap(True)
        tuning_layout.addWidget(self.tuning_values)
        layout.addWidget(tuning_group)
        group = QGroupBox("信号测量")
        self.panels["measurements"] = group
        form = QFormLayout(group)
        self.values = {}
        for key, name in [("carrier", "载频"), ("residual", "残余频偏"), ("depth", "AM 调制度"),
                          ("deviation", "FM 峰值频偏"), ("tone", "主调制频率"),
                          ("index", "FM 调制指数"), ("level", "I/Q 电平"), ("bandwidth", "99% 占用带宽")]:
            self.values[key] = label("—", "value")
            form.addRow(name, self.values[key])
        layout.addWidget(group)
        self.quality = label("等待数据", "warning")
        group = QGroupBox("数据完整性")
        self.panels["integrity"] = group
        form = QFormLayout(group)
        form.addRow(self.quality)
        self.integrity = {}
        for key, name in [("frames", "有效帧"), ("crc", "CRC / 帧头错误"), ("transport", "全局序号异常"), ("gaps", "I/Q 连续性异常"),
                          ("missing", "本次缺失样本"), ("fpga", "FPGA 累计丢样"), ("clip", "削顶帧"),
                          ("queue", "接收队列"), ("hostdrop", "主机丢弃字节"),
                          ("dspdrop", "DSP 丢弃样本"),
                          ("audio", "音频欠载 / 溢出"), ("epoch", "Epoch / 变化次数")]:
            self.integrity[key] = label("0")
            form.addRow(name, self.integrity[key])
        layout.addWidget(group)
        self.segment = label("连续缓存：0.000 s", "muted")
        form.addRow(self.segment)
        layout.addStretch()
        self.measurement_dock = self._dock("分析与校验", body, Qt.DockWidgetArea.RightDockWidgetArea)

    def _build_menus(self):
        file_menu = self.menuBar().addMenu("文件")
        self.replay_action = file_menu.addAction("打开回放文件…", self.select_replay)
        file_menu.addAction(self.save_action)
        file_menu.addAction("记录目录…", self.select_records_directory)
        file_menu.addSeparator()
        file_menu.addAction("退出", self.close)
        self.view_menu = self.menuBar().addMenu("视图")
        groups = [
            ("采集与设置", [("connection", "连接与数据源"), ("tuning", "载频调谐"),
                          ("display", "显示与 FFT"), ("audio", "音频输出")]),
            ("分析与校验", [("recognition", "调制识别"), ("tuningstatus", "调谐状态"),
                          ("measurements", "信号测量"), ("integrity", "数据完整性")]),
            ("日志与记录", [("log", "事件日志"), ("records", "测量记录")]),
        ]
        for title, panels in groups:
            self.view_menu.addSection(title)
            for key, name in panels:
                action = QAction(name, self)
                action.setCheckable(True)
                action.setChecked(True)
                action.toggled.connect(lambda visible, key=key: self.set_panel_visible(key, visible))
                self.panel_actions[key] = action
                self.view_menu.addAction(action)
        self.view_menu.addSection("界面")
        theme_menu = self.view_menu.addMenu("主题")
        self.theme_actions = {}
        theme_group = QActionGroup(self)
        theme_group.setExclusive(True)
        for theme, title in (("dark", "深色"), ("light", "浅色")):
            action = theme_menu.addAction(title)
            action.setCheckable(True)
            action.setChecked(theme == self.current_theme)
            action.triggered.connect(lambda checked, theme=theme: self.set_theme(theme))
            theme_group.addAction(action)
            self.theme_actions[theme] = action
        self.toolbar.toggleViewAction().setText("采集工具栏")
        self.view_menu.addAction(self.toolbar.toggleViewAction())
        self.statusbar_action = QAction("状态栏", self)
        self.statusbar_action.setCheckable(True)
        self.statusbar_action.setChecked(True)
        self.statusbar_action.toggled.connect(self.statusBar().setVisible)
        self.view_menu.addAction(self.statusbar_action)
        self.view_menu.addSection("布局")
        self.view_menu.addAction("显示全部面板", lambda: self.set_all_panels(True))
        self.view_menu.addAction("仅显示波形", lambda: self.set_all_panels(False))
        self.view_menu.addAction("恢复默认布局", self.restore_default_layout)

        acquire = self.menuBar().addMenu("采集")
        for action in (self.start_action, self.stop_action, self.pause_action):
            acquire.addAction(action)
        acquire.addSection("参数配置")
        acquire.addAction("连接与数据源…", lambda: self.open_settings("connection"))
        acquire.addAction("载频调谐…", lambda: self.open_settings("tuning"))
        analysis = self.menuBar().addMenu("分析")
        demodulation_menu = analysis.addMenu("解调模式")
        self.demodulation_actions = QActionGroup(self)
        for index in range(self.demodulation_mode.count()):
            action = demodulation_menu.addAction(self.demodulation_mode.itemText(index))
            action.setCheckable(True)
            action.setChecked(index == self.demodulation_mode.currentIndex())
            action.triggered.connect(lambda checked, index=index: self.demodulation_mode.setCurrentIndex(index))
            self.demodulation_actions.addAction(action)
        self.demodulation_mode.currentIndexChanged.connect(
            lambda index: self.demodulation_actions.actions()[index].setChecked(True))
        analysis.addAction("解调参数…", lambda: self.open_settings("recognition"))
        analysis.addAction("显示与 FFT 参数…", lambda: self.open_settings("display"))
        waves = analysis.addMenu("波形窗口")
        self.wave_actions = QActionGroup(self)
        for index in range(self.tabs.count()):
            action = waves.addAction(self.tabs.tabText(index))
            action.setCheckable(True)
            action.setChecked(index == self.tabs.currentIndex())
            action.triggered.connect(lambda checked, index=index: self.tabs.setCurrentIndex(index))
            self.wave_actions.addAction(action)
        self.tabs.currentChanged.connect(lambda index: self.wave_actions.actions()[index].setChecked(True))
        analysis.addAction(self.reset_action)
        analysis.addSection("分析结果")
        for key in ("recognition", "tuningstatus", "measurements", "integrity"):
            analysis.addAction(self.panel_actions[key].text(), lambda checked=False, key=key: self.show_panel(key))
        audio = self.menuBar().addMenu("音频")
        audio.addAction("输出参数…", lambda: self.open_settings("audio"))
        self.speaker_action = QAction("扬声器输出", self)
        self.speaker_action.setCheckable(True)
        self.speaker_action.triggered.connect(self.audio_on.setChecked)
        self.audio_on.toggled.connect(self.speaker_action.setChecked)
        audio.addAction(self.speaker_action)
        audio.addAction("刷新输出设备", self.populate_audio_devices)
        records = self.menuBar().addMenu("记录")
        records.addAction("查找测量记录…", self.find_records)
        records.addAction("刷新测量记录", self.refresh_records)
        records.addAction("记录目录…", self.select_records_directory)
        records.addAction("事件日志", lambda: self.show_panel("log"))

    def set_panel_visible(self, key, visible):
        panel = self.panels[key]
        if key in ("log", "records"):
            self.lower.setTabVisible(self.lower.indexOf(panel), visible)
            self.lower.setVisible(any(self.panel_actions[k].isChecked() for k in ("log", "records")))
        else:
            panel.setVisible(visible)
            keys = ("connection", "tuning", "display", "audio") if key in (
                "connection", "tuning", "display", "audio") else (
                "recognition", "tuningstatus", "measurements", "integrity")
            dock = self.connection_dock if key in ("connection", "tuning", "display", "audio") else self.measurement_dock
            dock.setVisible(any(self.panel_actions[k].isChecked() for k in keys))

    def show_panel(self, key):
        self.panel_actions[key].setChecked(True)
        if key in ("log", "records"):
            self.lower.setCurrentWidget(self.panels[key])
        else:
            dock = self.connection_dock if key in ("connection", "tuning", "display", "audio") else self.measurement_dock
            dock.show()
            dock.raise_()
            dock.widget().ensureWidgetVisible(self.panels[key])

    def set_all_panels(self, visible):
        for action in self.panel_actions.values():
            action.setChecked(visible)
        if visible:
            self.toolbar.show()
            self.statusbar_action.setChecked(True)

    def restore_default_layout(self):
        self.restoreState(self.default_layout)
        self.set_all_panels(True)
        self.lower.setCurrentWidget(self.log_view)
        self.resizeDocks([self.connection_dock, self.measurement_dock], [260, 285], Qt.Orientation.Horizontal)
        self.splitter.setSizes([610, 180])

    def find_records(self):
        self.show_panel("records")
        self.record_query.setFocus()

    def select_records_directory(self):
        path = QFileDialog.getExistingDirectory(self, "选择记录目录", str(self.records_path))
        if path:
            self.records_path = Path(path)
            self.refresh_records()
            self.append_log(f"记录目录：{path}")

    def open_settings(self, key):
        fields = {
            "recognition": [("demodulation_mode", "解调模式")],
            "connection": [("source", "数据源"), ("vid", "USB VID"), ("pid", "USB PID"),
                           ("dll_path", "驱动 DLL"), ("replay_path", "回放文件")],
            "tuning": [("tuning_mode", "调谐模式"), ("manual_rf", "载频"), ("hold_time", "失信保持")],
            "display": [("window_ms", "时间窗口"), ("fft_size", "FFT 点数"),
                        ("fft_span", "频谱半宽"), ("follow", "跟随最新数据")],
            "audio": [("audio_device", "输出设备"), ("volume", "音量"),
                      ("deemphasis", "FM 去加重"), ("audio_on", "扬声器输出")],
        }
        dialog = SettingsDialog(self.panel_actions[key].text() + "参数",
                                [(name, title, getattr(self, name)) for name, title in fields[key]], self)
        dialog.setObjectName("settings_" + key)
        controls = dialog.controls
        if key == "connection":
            def update_connection():
                usb = controls["source"].currentText() == "USB" and self.source.isEnabled()
                for name in ("vid", "pid", "dll_path"):
                    controls[name].setEnabled(usb)
            controls["source"].currentTextChanged.connect(update_connection)
            update_connection()
        elif key == "tuning":
            def update_tuning():
                controls["manual_rf"].setEnabled(self.tuning_mode.isEnabled()
                                                 and controls["tuning_mode"].currentData() == 2)
            controls["tuning_mode"].currentIndexChanged.connect(update_tuning)
            update_tuning()
        elif key == "audio":
            controls["audio_on"].toggled.connect(
                lambda enabled: controls["audio_device"].setEnabled(self.audio_device.isEnabled() and not enabled))
        try:
            if dialog.exec() == QDialog.DialogCode.Accepted:
                dialog.apply()
        finally:
            dialog.deleteLater()

    @pyqtSlot()
    def request_start(self):
        try:
            config = SourceConfig(self.source.currentText(), int(self.vid.text(), 16),
                                  int(self.pid.text(), 16), self.dll_path.text(), self.replay_path.text(),
                                  self.tuning_mode.currentData(), round(self.manual_rf.value()*1e6),
                                  round(self.hold_time.value()),
                                  usb_managed_pump=self.source.currentText() == "USB")
            if not 0 <= config.vid <= 65535 or not 0 <= config.pid <= 65535:
                raise ValueError("VID/PID 须为 16 位十六进制")
            if config.mode == "文件回放" and not Path(config.path).is_file():
                raise ValueError("请选择原始 TRI1 / FCR1 帧文件")
        except ValueError as error:
            self.append_log(f"连接参数错误：{error}")
            return
        self.pause_action.setChecked(False)
        self.pause_requested.emit(False)
        self.source_badge.setText(config.mode + (" · 合成数据" if config.mode.startswith("合成") else ""))
        self.start_requested.emit(config)

    @pyqtSlot(str)
    def source_changed(self, value):
        if hasattr(self, "vid"):
            for widget in (self.vid, self.pid, self.dll_path):
                widget.setEnabled(value == "USB")
        if hasattr(self, "tuning_mode"):
            self.tuning_mode.setEnabled(value == "USB")
            self.hold_time.setEnabled(value == "USB")
            self.tuning_changed()

    def tuning_changed(self, *args):
        if hasattr(self, "manual_rf"):
            self.manual_rf.setEnabled(self.source.currentText() == "USB"
                                      and self.tuning_mode.currentData() == 2
                                      and self.source.isEnabled())

    def select_dll(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择官方 CyUSB.dll", "", "CyUSB.dll (CyUSB.dll)")
        if path:
            self.dll_path.setText(path)

    def select_replay(self):
        if not self.source.isEnabled():
            return
        path, _ = QFileDialog.getOpenFileName(self, "选择原始 TRI1 / FCR1 文件", "", "原始传输帧 (*.fcr *.bin);;所有文件 (*)")
        if path:
            self.replay_path.setText(path)
            self.source.setCurrentText("文件回放")

    def request_save(self):
        parent = QFileDialog.getExistingDirectory(self, "选择波形保存目录", str(self.records_path))
        if parent:
            self.records_path = Path(parent)
            self.save_requested.emit(parent)
            self.append_log("正在后台保存连续数据…")

    @pyqtSlot(str)
    def capture_saved(self, path):
        self.append_log(f"波形已保存：{path}")
        self.refresh_records()

    def refresh_records(self):
        self.records_requested.emit(str(self.records_path))

    @pyqtSlot(object)
    def update_records(self, rows):
        self.records.setRowCount(0)
        for record in rows:
            row = self.records.rowCount()
            self.records.insertRow(row)
            for col, value in enumerate(record["values"]):
                item = QTableWidgetItem(value)
                item.setData(Qt.ItemDataRole.UserRole, record["path"])
                item.setToolTip(str(Path(record["path"]).parent))
                self.records.setItem(row, col, item)
        self.filter_records()

    def filter_records(self):
        query = self.record_query.text().casefold()
        for row in range(self.records.rowCount()):
            text = " ".join(self.records.item(row, col).text() for col in range(4))
            self.records.setRowHidden(row, query not in text.casefold())

    def replay_record(self, row, col):
        self.replay_path.setText(self.records.item(row, col).data(Qt.ItemDataRole.UserRole))
        self.source.setCurrentText("文件回放")

    @pyqtSlot(str)
    def append_log(self, text):
        self.log_view.appendPlainText(f"{datetime.now():%H:%M:%S}  {text}")

    @pyqtSlot(str)
    def set_state(self, state):
        running = state in ("连接中", "运行中", "等待有效帧", "停止中")
        self.start_action.setEnabled(not running)
        self.stop_action.setEnabled(running and state != "停止中")
        self.source.setEnabled(not running)
        self.replay_action.setEnabled(not running)
        self.replay_path.setEnabled(not running)
        self.replay_browse.setEnabled(not running)
        self.dll_browse.setEnabled(not running and self.source.currentText() == "USB")
        for widget in (self.vid, self.pid, self.dll_path):
            widget.setEnabled(not running and self.source.currentText() == "USB")
        self.tuning_mode.setEnabled(not running and self.source.currentText() == "USB")
        self.hold_time.setEnabled(not running and self.source.currentText() == "USB")
        self.tuning_changed()
        self.status.setText(state)
        if state in ("错误", "等待有效帧"):
            self.update_display(None)
        if state in ("错误", "已停止", "回放结束"):
            self.append_log(state)

    @pyqtSlot(bool)
    def set_audio_state(self, enabled):
        self.audio_on.blockSignals(True)
        self.audio_on.setChecked(enabled)
        self.audio_on.blockSignals(False)
        self.speaker_action.setChecked(enabled)
        self.audio_device.setEnabled(not enabled)
        self.append_log("扬声器已开启" if enabled else "扬声器已关闭")

    @pyqtSlot(object)
    def update_stats(self, stats):
        self.stats = stats
        tuning = stats.get("tuning", {})
        mode = tuning.get("mode")
        name = MODE_NAMES.get(mode, "历史主机自动模式" if mode == 0 else "离线数据")
        self.tuning_status.setText(f"{name}：{tuning.get('message', '')}")
        rf = tuning.get("tuned_rf", 0)
        flags = tuning.get("flags", 0)
        confidence = "可信" if flags & 512 else "低可信 / 等待评估"
        if flags & 1024:
            confidence += " · 保持超时"
        setting = f"{rf/1e6:.6f} MHz" if rf and flags & 256 else "尚无调谐参数"
        self.tuning_values.setText(f"设定载频：{setting}\n可信度：{confidence}"
                                   + (f"\nEpoch / 配置：{tuning['epoch']} / {tuning['config_id']}" if "config_id" in tuning else ""))
        values = {"frames": f"{stats['frames']:,}",
                  "crc": f"{stats['crc_errors']} / {stats['header_errors']}",
                  "transport": str(stats["transport_gaps"]),
                  "gaps": f"{stats['continuity_gaps']:,}", "missing": f"{stats['missing_samples']:,}",
                  "fpga": f"{stats['fpga_dropped']:,}", "clip": str(stats["clipped_frames"]),
                  "queue": f"{stats['queue_depth']} / {stats['queue_capacity']}",
                  "hostdrop": f"{stats['queue_dropped_bytes']:,}",
                  "dspdrop": f"{stats['dsp_dropped_samples']:,}",
                  "audio": f"{stats['audio_underruns']} / {stats['audio_overruns']}",
                  "epoch": f"{stats['epoch']} / {stats['epoch_changes']}"}
        for key, value in values.items():
            self.integrity[key].setText(value)
        issues = stats["crc_errors"]+stats["header_errors"]+stats["continuity_gaps"]+stats["transport_gaps"]+stats["queue_dropped_bytes"]+stats["clipped_frames"]
        self.quality.setText("存在异常，见校验计数" if issues else "本次会话未检出数据异常")
        if stats["last_valid_age_s"] is None or stats["last_valid_age_s"] > .6:
            self.quality.setText("等待 I/Q / 搜索 / 断流")
        self.save_action.setEnabled(bool(self.current is not None))

    @pyqtSlot(object)
    def update_display(self, display):
        self.current = display
        if display is None:
            for curve in (self.demod_curve, self.fft_curve, self.i_curve, self.q_curve):
                curve.clear()
            self.kind_label.setText("—")
            self.confidence_label.setText("等待有效连续数据")
            self.demodulation_status.setText("解调：等待数据")
            for widget in self.values.values():
                widget.setText("—")
            self.save_action.setEnabled(False)
            self.measurement = {}
            return
        m = display["measurement"]
        self.measurement = m
        self.kind_label.setText(m["kind"])
        self.confidence_label.setText(m["reason"] or f"特征评分 {m['confidence']*100:.0f}% · 自动识别")
        demodulation = display.get("demodulation", {"mode": "auto", "kind": m["kind"], "forced": False})
        if demodulation["forced"]:
            self.demodulation_status.setText(f"解调：{DEMODULATION_MODES[demodulation['mode']]} · 自动识别 {m['kind']}")
        else:
            self.demodulation_status.setText(f"解调：自动 · {demodulation['kind']}")
        self.segment.setText(f"显示数据：{len(display['iq'])/IQ_RATE:.3f} s")
        def value(key, scale, suffix, digits):
            return "—" if m[key] is None else f"{m[key]*scale:.{digits}f}{suffix}"
        self.values["carrier"].setText(value("carrier_hz", 1e-6, " MHz", 6))
        self.values["residual"].setText(value("residual_hz", 1, " Hz", 1))
        self.values["depth"].setText(value("am_depth", 100, " %", 1))
        self.values["deviation"].setText(value("fm_deviation_hz", .001, " kHz", 2))
        self.values["tone"].setText(value("modulation_hz", 1, " Hz", 1))
        self.values["index"].setText(value("fm_index", 1, "", 2))
        self.values["level"].setText(f"{m['level_dbfs']:.1f} dBFS")
        self.values["bandwidth"].setText(f"{m['occupied_hz']/1000:.2f} kHz")
        if demodulation["kind"] != self.last_display_mode:
            self.last_display_mode = demodulation["kind"]
            self.demod_plot.enableAutoRange(axis="y", enable=True)
        self.redraw()

    def redraw(self, *args):
        if self.current is None:
            return
        d = self.current
        z = d["iq"]
        selected = self.tabs.currentIndex()
        # Peak downsampling preserves extrema rather than taking unfiltered points.
        time_iq = np.arange(-len(z)+1, 1)/IQ_RATE*1000
        if selected == 2:
            self.i_curve.setData(time_iq, z.real, autoDownsample=True, downsampleMethod="peak")
            self.q_curve.setData(time_iq, z.imag, autoDownsample=True, downsampleMethod="peak")
        audio = d["audio"]
        if selected == 0:
            self.demod_curve.setData(np.arange(-len(audio)+1, 1)/AUDIO_RATE*1000, audio)
        if selected == 1:
            self.fft_curve.setData(d["freq"]/1000, d["power"])
        residual = d["measurement"].get("residual_hz")
        self.peak_line.setVisible(residual is not None)
        if residual is not None:
            self.peak_line.setValue(residual/1000)
        if self.tracking:
            self.demod_plot.setXRange(-self.window_ms.value(), 0, padding=0)
            self.iq_plot.setXRange(-self.window_ms.value(), 0, padding=0)
        self.save_action.setEnabled(True)

    def manual_zoom(self, *args):
        self.follow.setChecked(False)

    def follow_changed(self, checked):
        self.tracking = checked
        if checked:
            self.redraw()

    def window_changed(self, value):
        self.window_requested.emit(value)
        self.follow.setChecked(True)
        self.redraw()

    def reset_view(self, *args):
        self.follow.setChecked(True)
        self.fft_plot.setXRange(-self.fft_span.value(), self.fft_span.value(), padding=0)
        self.fft_plot.setYRange(-120, 0, padding=0)
        for plot in (self.demod_plot, self.iq_plot):
            plot.enableAutoRange(axis="y", enable=True)
        self.redraw()

    def closeEvent(self, event):
        if self.allow_close:
            event.accept()
            return
        event.ignore()
        if not self.closing:
            self.closing = True
            self.setEnabled(False)
            self.close_requested.emit()

    @pyqtSlot()
    def finish_close(self):
        self.allow_close = True
        self.close()


def wire(window, controller):
    window.start_requested.connect(controller.start)
    window.stop_requested.connect(controller.stop)
    window.pause_requested.connect(controller.set_paused)
    window.window_requested.connect(controller.set_window)
    window.audio_requested.connect(controller.set_audio)
    window.volume_requested.connect(controller.set_volume)
    window.deemphasis_requested.connect(controller.set_deemphasis)
    window.demodulation_requested.connect(controller.set_demodulation)
    window.save_requested.connect(controller.save)
    window.records_requested.connect(controller.scan_records)
    window.devices_requested.connect(controller.scan_devices)
    window.fft_requested.connect(controller.set_fft)
    window.close_requested.connect(controller.request_shutdown)
    controller.display_ready.connect(window.update_display)
    controller.stats_ready.connect(window.update_stats)
    controller.state_changed.connect(window.set_state)
    controller.log.connect(window.append_log)
    controller.saved.connect(window.capture_saved)
    controller.audio_changed.connect(window.set_audio_state)
    controller.ready_to_close.connect(window.finish_close)
    controller.records_ready.connect(window.update_records)
    controller.devices_ready.connect(window.update_devices)
    QTimer.singleShot(0, window.refresh_records)
