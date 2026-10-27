from pathlib import Path

import pytest
from PyQt6.QtCore import Qt, QPoint, QPointF, QTimer
from PyQt6.QtGui import QWheelEvent
from PyQt6.QtWidgets import QApplication, QFileDialog

from ads807.gui import Window, wire
from ads807.runtime import Controller
from ads807.sources import SourceConfig
from ads807.settings_dialog import SettingsDialog


@pytest.fixture
def workstation(qtbot, tmp_path, qapp):
    qapp.setStyle("Fusion")
    qapp.setStyleSheet((Path(__file__).resolve().parents[2]/"ads807/theme.qss").read_text(encoding="utf-8"))
    controller = Controller()
    window = Window(tmp_path)
    wire(window, controller)
    qtbot.addWidget(window)
    window.show()
    window.reset_view()
    yield window, controller
    controller.shutdown()
    window.allow_close = True
    window.close()


def test_views_pause_window_and_manual_zoom(workstation, qtbot):
    window, controller = workstation
    window.source.setCurrentText("合成 AM")
    window.request_start()
    qtbot.waitUntil(lambda: window.kind_label.text() == "AM", timeout=8000)
    assert window.save_action.isEnabled()
    for index in range(3):
        window.tabs.setCurrentIndex(index)
        assert window.tabs.currentIndex() == index
    window.window_ms.setValue(100)
    assert controller.window_ms == 100
    qtbot.wait(150)
    assert len(window.current["iq"]) > 10000
    window.tabs.setCurrentIndex(0)
    viewport = window.demod_plot.viewport()
    center = viewport.rect().center()
    before = window.demod_plot.getViewBox().viewRange()[0]
    wheel = QWheelEvent(QPointF(center), QPointF(viewport.mapToGlobal(center)),
                        QPoint(0, 0), QPoint(0, 120), Qt.MouseButton.NoButton,
                        Qt.KeyboardModifier.NoModifier, Qt.ScrollPhase.NoScrollPhase, False)
    QApplication.sendEvent(viewport, wheel)
    after = window.demod_plot.getViewBox().viewRange()[0]
    assert after[1]-after[0] < before[1]-before[0]
    assert not window.follow.isChecked()
    window.reset_view()
    assert window.follow.isChecked()
    window.pause_action.trigger()
    assert controller.paused
    previous = window.current["version"]
    frames = controller.processor.decoder.frames
    qtbot.wait(250)
    assert window.current["version"] == previous
    assert controller.processor.decoder.frames > frames
    window.pause_action.trigger()
    qtbot.waitUntil(lambda: window.current["version"] > previous)
    window.stop_action.trigger()
    qtbot.waitUntil(lambda: controller.state == "已停止", timeout=5000)
    assert window.start_action.isEnabled()


@pytest.mark.parametrize("size", [(1440, 940), (1100, 760)])
def test_layout_and_screenshots(workstation, qtbot, tmp_path, size):
    window, controller = workstation
    window.resize(*size)
    controller.start(SourceConfig("合成 FM"))
    qtbot.waitUntil(lambda: window.kind_label.text() == "FM", timeout=8000)
    qtbot.wait(150)
    assert window.centralWidget().width() >= 280
    assert window.connection_dock.width() >= 215
    assert window.measurement_dock.width() >= 215
    assert window.save_action.isVisible()
    assert window.grab().save(str(tmp_path/"window.png"))


def test_records_filter_and_replay_selection(workstation, qtbot, tmp_path):
    window, controller = workstation
    controller.start(SourceConfig("合成 AM"))
    qtbot.waitUntil(lambda: window.kind_label.text() == "AM", timeout=8000)
    with qtbot.waitSignal(controller.saved, timeout=8000):
        window.save_requested.emit(str(tmp_path))
    qtbot.waitUntil(lambda: window.records.rowCount() == 1, timeout=3000)
    window.record_query.setText("FM")
    assert window.records.isRowHidden(0)
    window.record_query.setText("AM")
    assert not window.records.isRowHidden(0)
    window.replay_record(0, 0)
    assert window.source.currentText() == "文件回放"
    assert Path(window.replay_path.text()).is_file()


def test_graceful_close_with_active_stream(workstation, qtbot):
    window, controller = workstation
    controller.start(SourceConfig("合成 FM"))
    qtbot.waitUntil(lambda: window.kind_label.text() == "FM", timeout=5000)
    window.close()
    qtbot.waitUntil(lambda: not window.isVisible(), timeout=5000)
    assert not controller.busy()


def test_tuning_controls_emit_two_mode_configuration(workstation, qtbot):
    window, controller = workstation
    assert window.tuning_mode.count() == 2
    assert window.tuning_mode.currentIndex() == 0
    assert window.tuning_mode.currentData() == 1
    assert not window.manual_rf.isEnabled()
    window.start_requested.disconnect(controller.start)
    for mode in (1, 2):
        window.tuning_mode.setCurrentIndex(window.tuning_mode.findData(mode))
        assert window.manual_rf.isEnabled() == (mode == 2)
        window.manual_rf.setValue(98.765432)
        window.hold_time.setValue(750)
        with qtbot.waitSignal(window.start_requested) as signal:
            window.request_start()
        config = signal.args[0]
        assert config.tuning_mode == mode
        assert config.rf_hz == 98_765_432
        assert config.hold_ms == 750
    window.set_state("运行中")
    assert not window.tuning_mode.isEnabled()
    assert not window.manual_rf.isEnabled()
    window.set_state("已停止")
    assert window.manual_rf.isEnabled()
    window.source.setCurrentText("文件回放")
    assert not window.tuning_mode.isEnabled()
    assert not window.manual_rf.isEnabled()


def test_individual_panels_and_wave_only_keep_stream_alive(workstation, qtbot):
    window, controller = workstation
    window.source.setCurrentText("合成 AM")
    window.request_start()
    qtbot.waitUntil(lambda: window.kind_label.text() == "AM", timeout=8000)
    for key in ("connection", "tuning", "display", "audio", "recognition", "tuningstatus", "measurements", "integrity"):
        window.panel_actions[key].setChecked(False)
        assert window.panels[key].isHidden()
        window.show_panel(key)
        assert window.panels[key].isVisible()
    before_width = window.tabs.width()
    processed = controller.processor.processed
    window.set_all_panels(False)
    qtbot.waitUntil(lambda: window.tabs.width() > before_width)
    assert not window.connection_dock.isVisible()
    assert not window.measurement_dock.isVisible()
    assert not window.lower.isVisible()
    assert window.tabs.isVisible()
    qtbot.waitUntil(lambda: controller.processor.processed > processed)
    window.find_records()
    assert window.lower.isVisible()
    assert window.lower.currentWidget() is window.panels["records"]
    assert not window.lower.isTabVisible(window.lower.indexOf(window.log_view))
    window.restore_default_layout()
    assert all(action.isChecked() for action in window.panel_actions.values())
    assert window.connection_dock.isVisible() and window.measurement_dock.isVisible()
    assert window.lower.currentWidget() is window.log_view


def test_top_level_menus_and_shared_action_state(workstation):
    window, _ = workstation
    assert [action.text() for action in window.menuBar().actions()] == ["文件", "视图", "采集", "分析", "音频", "记录"]
    acquire = window.menuBar().actions()[2].menu()
    assert window.start_action in acquire.actions()
    window.set_state("运行中")
    assert not window.start_action.isEnabled()
    assert window.stop_action.isEnabled()
    window.wave_actions.actions()[2].trigger()
    assert window.tabs.currentIndex() == 2
    window.tabs.setCurrentIndex(1)
    assert window.wave_actions.actions()[1].isChecked()
    window.set_audio_state(True)
    assert window.speaker_action.isChecked()
    window.set_audio_state(False)
    assert not window.speaker_action.isChecked()
    window.toolbar.hide()
    window.statusbar_action.setChecked(False)
    assert not window.toolbar.toggleViewAction().isChecked()
    assert window.statusBar().isHidden()
    window.restore_default_layout()
    assert window.toolbar.isVisible() and window.statusBar().isVisible()


def test_theme_switch_preserves_live_stream_and_frozen_view(workstation, qtbot):
    window, controller = workstation
    assert window.current_theme == "dark"
    window.source.setCurrentText("合成 FM")
    window.request_start()
    qtbot.waitUntil(lambda: window.current is not None and window.kind_label.text() == "FM", timeout=8000)
    window.pause_action.trigger()
    window.follow.setChecked(False)
    window.demod_plot.setXRange(-12, -2, padding=0)
    before_range = window.demod_plot.getViewBox().viewRange()[0][:]
    before_data = window.demod_curve.getData()[1].copy()
    before_version = window.current["version"]
    processed = controller.processor.processed
    for theme, background, foreground in (("light", "#f7f9fb", "#364152"),
                                           ("dark", "#151719", "#aab3bf")):
        window.theme_actions[theme].trigger()
        assert window.current_theme == theme
        assert window.theme_actions[theme].isChecked()
        assert sum(action.isChecked() for action in window.theme_actions.values()) == 1
        expected_qss = "theme_light.qss" if theme == "light" else "theme.qss"
        assert QApplication.instance().styleSheet() == (
            Path(__file__).resolve().parents[2]/"ads807"/expected_qss).read_text(encoding="utf-8")
        for plot in window.plots:
            assert plot.backgroundBrush().color().name() == background
            assert plot.getAxis("left").textPen().color().name() == foreground
        assert window.demod_plot.getViewBox().viewRange()[0] == before_range
        assert (window.demod_curve.getData()[1] == before_data).all()
        assert [text.text for _, text in window.iq_plot.plotItem.legend.items] == ["I", "Q"]
    qtbot.waitUntil(lambda: controller.processor.processed > processed)
    assert window.current["version"] == before_version
    assert controller.paused
    window.pause_action.trigger()
    qtbot.waitUntil(lambda: window.current["version"] > before_version)


@pytest.mark.parametrize("accept", [False, True])
def test_parameter_dialog_is_transactional(workstation, accept):
    window, controller = workstation
    observed = []

    def edit():
        dialog = window.findChild(SettingsDialog, "settings_display")
        dialog.controls["window_ms"].setValue(80)
        dialog.controls["fft_size"].setCurrentText("4096")
        observed.append(window.window_ms.value())
        (dialog.accept if accept else dialog.reject)()

    QTimer.singleShot(0, edit)
    window.open_settings("display")
    assert observed == [20]
    assert window.window_ms.value() == (80 if accept else 20)
    assert controller.window_ms == (80 if accept else 20)
    assert controller.fft_size == (4096 if accept else 8192)


def test_tuning_dialog_and_running_configuration_lock(workstation):
    window, _ = workstation
    observed = []

    def edit():
        dialog = window.findChild(SettingsDialog, "settings_tuning")
        controls = dialog.controls
        controls["tuning_mode"].setCurrentIndex(controls["tuning_mode"].findData(2))
        observed.append(controls["manual_rf"].isEnabled())
        controls["manual_rf"].setValue(98.765432)
        dialog.accept()

    QTimer.singleShot(0, edit)
    window.open_settings("tuning")
    assert observed == [True]
    assert window.tuning_mode.currentData() == 2
    assert window.manual_rf.value() == 98.765432
    window.set_state("运行中")

    def check_locked():
        dialog = next(d for d in window.findChildren(SettingsDialog) if d.isVisible())
        observed.append(not any(control.isEnabled() for control in dialog.controls.values()))
        dialog.reject()

    QTimer.singleShot(0, check_locked)
    window.open_settings("tuning")
    assert observed[-1]


def test_record_directory_menu_updates_scan(workstation, tmp_path, monkeypatch, qtbot):
    window, _ = workstation
    destination = tmp_path / "records"
    destination.mkdir()
    monkeypatch.setattr(QFileDialog, "getExistingDirectory", lambda *args: str(destination))
    with qtbot.waitSignal(window.records_requested) as signal:
        window.select_records_directory()
    assert window.records_path == destination
    assert signal.args == [str(destination)]


def test_forced_demodulation_menu_and_unknown_display(workstation, qtbot, tmp_path):
    window, controller = workstation
    window.demodulation_actions.actions()[2].trigger()
    assert window.demodulation_mode.currentData() == controller.demodulation_mode == "FM"
    window.source.setCurrentText("合成 噪声")
    window.request_start()
    qtbot.waitUntil(lambda: window.kind_label.text() == "未知" and
                    "强制 FM" in window.demodulation_status.text(), timeout=8000)
    assert "自动识别 未知" in window.demodulation_status.text()
    qtbot.waitUntil(lambda: len(window.demod_curve.getData()[1]) > 0, timeout=3000)
    assert window.demod_curve.getData()[1].std() > .001
    assert window.grab().save(str(tmp_path/"forced_fm_unknown.png"))
    with qtbot.waitSignal(controller.saved, timeout=8000):
        window.save_requested.emit(str(tmp_path))
    qtbot.waitUntil(lambda: window.records.rowCount() == 1, timeout=4000)
    assert "未知 / 强制 FM" in window.records.item(0, 1).text()
    window.demodulation_actions.actions()[0].trigger()
    qtbot.waitUntil(lambda: controller.processor.demodulation["mode"] == "auto", timeout=4000)
    assert window.demodulation_mode.currentData() == "auto"


def test_fm_deemphasis_options_emit_microseconds(workstation, qtbot):
    window, controller = workstation
    expected = {0, 50, 75, 100, 150, 200, 300}
    assert {window.deemphasis.itemData(i) for i in range(window.deemphasis.count())} == expected
    for value in [50, 75, 100, 150, 200, 300, 0]:
        with qtbot.waitSignal(window.deemphasis_requested) as signal:
            window.deemphasis.setCurrentIndex(window.deemphasis.findData(value))
        assert signal.args == [value]
        assert controller.deemphasis == value


@pytest.mark.parametrize("accept", [False, True])
def test_demodulation_dialog_applies_only_on_accept(workstation, accept):
    window, controller = workstation

    def edit():
        dialog = next(d for d in window.findChildren(SettingsDialog) if d.isVisible())
        dialog.controls["demodulation_mode"].setCurrentIndex(1)
        (dialog.accept if accept else dialog.reject)()

    QTimer.singleShot(0, edit)
    window.open_settings("recognition")
    assert controller.demodulation_mode == ("AM" if accept else "auto")
    assert window.demodulation_actions.actions()[1 if accept else 0].isChecked()
