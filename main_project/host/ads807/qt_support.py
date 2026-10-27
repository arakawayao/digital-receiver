"""Windows offscreen Qt has no system font database until explicitly populated."""
import os
from pathlib import Path


def load_offscreen_fonts():
    if os.name != "nt" or os.environ.get("QT_QPA_PLATFORM") != "offscreen":
        return
    from PyQt6.QtGui import QFontDatabase
    font_dir = Path(os.environ.get("WINDIR", "C:/Windows"))/"Fonts"
    for name in ("msyh.ttc", "msyhbd.ttc", "segoeui.ttf", "segoeuib.ttf", "consola.ttf"):
        path = font_dir/name
        if path.is_file():
            QFontDatabase.addApplicationFont(str(path))
