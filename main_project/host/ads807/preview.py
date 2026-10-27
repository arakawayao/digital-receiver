"""Loopback-only live mirror of the actual Qt window, not an HTML mockup."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import queue
import secrets
import threading
import time

from PyQt6.QtCore import QByteArray, QBuffer, QIODevice, QTimer, Qt


class Preview:
    def __init__(self, window, port=8767):
        self.window = window
        self.png = b""
        self.encode_ms = 0.0
        self.state = b"{}"
        self.commands = queue.Queue(maxsize=8)
        self.token = secrets.token_urlsafe(24)
        self.images = queue.Queue(maxsize=1)
        self.closed = threading.Event()
        preview = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                if self.headers.get("Host", "") not in (f"127.0.0.1:{preview.port}", f"localhost:{preview.port}"):
                    self.send_error(403)
                    return
                path = self.path.split("?", 1)[0]
                if path == "/":
                    body = ("<!doctype html><html lang='zh-CN'><meta charset='utf-8'>"
                            "<meta name='viewport' content='width=device-width,initial-scale=1'>"
                            "<title>ADS807 · Qt 实时界面</title><style>"
                            "*{box-sizing:border-box}body{margin:0;background:#151719;color:#dfe5ec;"
                            "font:14px 'Segoe UI','Microsoft YaHei',sans-serif}header{padding:12px 16px;"
                            "display:flex;gap:16px;border-bottom:1px solid #43474d;align-items:center}"
                            "header span{color:#91ef7d}img{display:block;width:100%;height:auto}"
                            "small{color:#aab3bf;margin-left:auto}header{flex-wrap:wrap}"
                            "nav{display:flex;gap:6px;align-items:center;padding:8px 12px;border-bottom:1px solid #43474d}"
                            "button{background:#30343a;color:#e7ecf3;border:1px solid #555d67;padding:6px 10px;border-radius:3px}"
                            "button[aria-pressed=true]{color:#53d9d1;border-color:#53d9d1}"
                            "main{overflow:auto;height:calc(100vh - 118px)}"
                            "img.full{width:1440px;max-width:none}</style><header><b>ADS807 / Qt 实时画面</b>"
                            "<span id='state'>连接预览…</span><small>本地 127.0.0.1</small></header>"
                            "<nav><button data-tab='0' aria-pressed='true'>解调</button><button data-tab='1'>FFT</button>"
                            "<button data-tab='2'>I/Q</button><button id='zoom' title='切换实际尺寸与适应宽度'>⊕</button></nav><main>"
                            "<img id='frame' alt='ADS807 接收分析工作台实际 Qt 窗口'>"
                            "</main><script>const frame=document.getElementById('frame');"
                            "document.getElementById('zoom').onclick=()=>frame.classList.toggle('full');"
                            "document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=async()=>{"
                            "await fetch('/command',{method:'POST',headers:{'Content-Type':'application/json','X-Preview-Token':'"
                            + preview.token + "'},body:JSON.stringify({tab:Number(b.dataset.tab)})});"
                            "document.querySelectorAll('[data-tab]').forEach(x=>x.setAttribute('aria-pressed',x===b))});"
                            "async function refresh(){try{const r=await fetch('/frame.jpg?t='+Date.now());"
                            "if(r.ok){const url=URL.createObjectURL(await r.blob());const old=frame.src;"
                            "await new Promise(resolve=>{frame.onload=resolve;frame.onerror=resolve;frame.src=url});"
                            "if(old.startsWith('blob:'))URL.revokeObjectURL(old)}"
                            "const s=await (await fetch('/state')).json();document.getElementById('state').textContent="
                            "(s.source||'就绪')+' · '+(s.kind||'等待数据')}catch(e){}setTimeout(refresh,500)}"
                            "refresh()</script></html>").encode("utf-8")
                    content_type = "text/html; charset=utf-8"
                elif path == "/frame.jpg":
                    body, content_type = preview.png, "image/jpeg"
                    if not body:
                        self.send_error(503, "First frame pending")
                        return
                elif path == "/state":
                    body, content_type = preview.state, "application/json"
                else:
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header("Content-Type", content_type)
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                try:
                    self.wfile.write(body)
                except (ConnectionResetError, BrokenPipeError):
                    pass

            def do_POST(self):
                if (self.path != "/command" or self.headers.get("Host", "") not in
                        (f"127.0.0.1:{preview.port}", f"localhost:{preview.port}")
                        or self.headers.get("X-Preview-Token") != preview.token):
                    self.send_error(403)
                    return
                try:
                    length = int(self.headers.get("Content-Length", 0))
                    if not 0 < length <= 128:
                        raise ValueError()
                    value = json.loads(self.rfile.read(length))
                    tab = value["tab"]
                    if type(tab) is not int or tab not in (0, 1, 2):
                        raise ValueError()
                    preview.commands.put_nowait(tab)
                except (ValueError, KeyError, queue.Full):
                    self.send_error(400)
                    return
                self.send_response(204)
                self.end_headers()

        for candidate in range(port, port+20):
            self.port = candidate
            try:
                self.server = ThreadingHTTPServer(("127.0.0.1", candidate), Handler)
                break
            except OSError:
                if candidate == port+19:
                    raise
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.encoder = threading.Thread(target=self.encode_images, daemon=True)
        self.encoder.start()
        self.timer = QTimer(window)
        self.timer.timeout.connect(self.update)
        self.timer.start(500)

    def update(self):
        start = time.perf_counter()
        while not self.commands.empty():
            self.window.tabs.setCurrentIndex(self.commands.get_nowait())
        if not self.images.full():
            screenshot = self.window.grab().toImage()
            screenshot = screenshot.scaled(self.window.size(), Qt.AspectRatioMode.KeepAspectRatio,
                                           Qt.TransformationMode.FastTransformation)
            self.images.put_nowait(screenshot)
        self.state = json.dumps({"source": self.window.source_badge.text(),
                                 "kind": self.window.kind_label.text(),
                                 "grab_ms": (time.perf_counter()-start)*1000,
                                 "encode_ms": self.encode_ms,
                                 "stats": self.window.stats}, ensure_ascii=False).encode("utf-8")

    def encode_images(self):
        while not self.closed.is_set():
            try:
                screenshot = self.images.get(timeout=.2)
            except queue.Empty:
                continue
            array = QByteArray()
            buffer = QBuffer(array)
            buffer.open(QIODevice.OpenModeFlag.WriteOnly)
            start = time.perf_counter()
            screenshot.save(buffer, "JPEG", 90)
            self.png = bytes(array)
            self.encode_ms = (time.perf_counter()-start)*1000

    def close(self):
        self.timer.stop()
        self.closed.set()
        self.server.shutdown()
        self.server.server_close()
        self.encoder.join(timeout=1)
