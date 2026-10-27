import os

os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["PYTEST_QT_API"] = "pyqt6"

import pytest


@pytest.fixture(autouse=True)
def fonts(qapp):
    from ads807.qt_support import load_offscreen_fonts
    load_offscreen_fonts()
