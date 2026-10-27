"""Render the editable receiver SVG to a Windows icon with native Qt tools."""
import os
from pathlib import Path
import struct

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtCore import QByteArray, QBuffer, QIODevice, Qt
from PyQt6.QtGui import QGuiApplication, QImage, QPainter
from PyQt6.QtSvg import QSvgRenderer


def main():
    app = QGuiApplication.instance() or QGuiApplication([])
    assets = Path(__file__).resolve().parents[1] / "ads807/assets"
    renderer = QSvgRenderer(str(assets / "receiver.svg"))
    if not renderer.isValid():
        raise RuntimeError("Invalid receiver SVG")
    sizes = (16, 20, 24, 32, 40, 48, 64, 128, 256)
    frames = []
    for size in sizes:
        image = QImage(size, size, QImage.Format.Format_ARGB32)
        image.fill(Qt.GlobalColor.transparent)
        painter = QPainter(image)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        renderer.render(painter)
        painter.end()
        buffer = QBuffer()
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        if not image.save(buffer, "PNG"):
            raise RuntimeError("Icon PNG encoding failed")
        frames.append(bytes(buffer.data()))
        if size == 256:
            image.save(str(assets / "receiver.png"))
    offset = 6 + 16 * len(sizes)
    directory = bytearray(struct.pack("<HHH", 0, 1, len(sizes)))
    for size, frame in zip(sizes, frames):
        directory.extend(struct.pack("<BBBBHHII", size % 256, size % 256,
                                     0, 0, 1, 32, len(frame), offset))
        offset += len(frame)
    (assets / "receiver.ico").write_bytes(directory + b"".join(frames))
    print(assets / "receiver.ico")


if __name__ == "__main__":
    main()
