"""Memory-only live I/Q and AM baseband viewer for the receiver56 ADC stream."""
import csv
import json
import math
import struct
import threading
import time
from collections import deque
from datetime import datetime
from pathlib import Path

from ...paths import ARTIFACT_ROOT
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from .usb_capture import BLOCK, EP_IN, FCR1Decoder, HEADER, SAMPLE_RATE, fit_am
from .usb_transport import TransferTimeout, open_transport

DISPLAY_DECIMATION = 10  # Preserve 1 kHz AM shape while keeping UI work bounded.
DISPLAY_BUFFER_MS = 100


class LiveCaptureWindow:
    def __init__(self, root):
        self.root = root
        self.root.title("receiver56 实时 I/Q 与 AM 基带监视")
        self.root.geometry("1280x980")
        self.root.minsize(760, 600)
        self.root.resizable(True, True)
        self.lock = threading.Lock()
        self.stop_event = threading.Event()
        self.worker = None
        self.samples = deque(maxlen=SAMPLE_RATE*20//1000//DISPLAY_DECIMATION)
        self.sample_count = 0
        self.frame_count = 0
        self.current_rf = 0
        self.current_dropped = 0
        self.continuity_gaps = 0
        self.crc_errors = 0
        self.error = ""
        self.running = False
        self.started_at = 0.0
        self.vid = tk.StringVar(value="0x04B4")
        self.pid = tk.StringVar(value="0x1004")
        self.backend = tk.StringVar(value="cyusb")
        self.modulation_hz = tk.StringVar(value="5000")
        self.expected_depth = tk.StringVar(value="0.54")
        self.expected_rf_mhz = tk.StringVar(value="89")
        self.view_ms = tk.StringVar(value="20")
        self.status = tk.StringVar(value="就绪：连接 USB 后点击“开始采集”。")
        self.stats = tk.StringVar(value="帧 0 | 样本 0 | RF — | 时长 0.0 s")
        self._build()
        self.root.protocol("WM_DELETE_WINDOW", self._close)
        self.root.after(100, self._refresh)

    def _build(self):
        controls = ttk.Frame(self.root, padding=8)
        controls.pack(fill="x")
        fields = [
            ("VID", self.vid, 10), ("PID", self.pid, 10),
            ("USB 后端", self.backend, 9), ("AM 频率 Hz", self.modulation_hz, 10),
            ("预期调制度", self.expected_depth, 8), ("预期 RF MHz", self.expected_rf_mhz, 9),
        ]
        for col, (label, variable, width) in enumerate(fields):
            ttk.Label(controls, text=label).grid(row=0, column=col*2, sticky="w", padx=(0,4))
            if label == "USB 后端":
                ttk.Combobox(controls, textvariable=variable, values=("cyusb", "pyusb", "auto"),
                             width=width, state="readonly").grid(row=0, column=col*2+1, padx=(0,10))
            else:
                ttk.Entry(controls, textvariable=variable, width=width).grid(row=0, column=col*2+1, padx=(0,10))
        ttk.Label(controls, text="显示时长 ms").grid(row=1, column=0, sticky="w", pady=(8,0))
        ttk.Combobox(controls, textvariable=self.view_ms,
                     values=("2", "5", "10", "20", "50", "100"), width=8,
                     state="readonly").grid(row=1, column=1, sticky="w", pady=(8,0))
        self.start_button = ttk.Button(controls, text="开始实时显示", command=self.start)
        self.start_button.grid(row=1, column=9, padx=4, pady=(8,0))
        self.stop_button = ttk.Button(controls, text="停止显示", command=self.stop, state="disabled")
        self.stop_button.grid(row=1, column=10, padx=4, pady=(8,0))
        self.save_button = ttk.Button(controls, text="保存当前显示", command=self.save_display, state="disabled")
        self.save_button.grid(row=1, column=11, padx=4, pady=(8,0))
        controls.columnconfigure(1, weight=1)
        ttk.Label(self.root, textvariable=self.status, padding=(10,3)).pack(anchor="w")
        ttk.Label(self.root, textvariable=self.stats, padding=(10,3)).pack(anchor="w")
        self.iq_canvas = tk.Canvas(self.root, height=320, background="white", highlightthickness=1,
                                   highlightbackground="#bdbdbd")
        self.iq_canvas.pack(fill="both", expand=True, padx=10, pady=(4,6))
        self.env_canvas = tk.Canvas(self.root, height=300, background="white", highlightthickness=1,
                                    highlightbackground="#bdbdbd")
        self.env_canvas.pack(fill="both", expand=True, padx=10, pady=(4,8))
        self.message_canvas = tk.Canvas(self.root, height=240, background="white", highlightthickness=1,
                                        highlightbackground="#bdbdbd")
        self.message_canvas.pack(fill="both", expand=True, padx=10, pady=(0,8))
        ttk.Label(self.root, text="实时滚动显示；I/Q 每 10 点取 1 点以降低界面负载，AM 基带按设定频率拟合。内存仅保留当前显示时窗（默认 20 ms），默认不自动写文件；点击“保存当前显示”可导出当前窗口。可缩放横轴并调整窗口大小。",
                  padding=(10,4)).pack(anchor="w")

    def start(self):
        if self.worker and self.worker.is_alive():
            return
        try:
            vid, pid = int(self.vid.get(), 0), int(self.pid.get(), 0)
            mod_hz = float(self.modulation_hz.get())
            depth = float(self.expected_depth.get())
            expected_rf_hz = float(self.expected_rf_mhz.get())*1_000_000
            if mod_hz <= 0 or not 0 < depth < 1 or expected_rf_hz <= 0:
                raise ValueError("AM 频率和预期 RF 必须大于 0，调制度必须在 0 和 1 之间。")
        except ValueError as error:
            messagebox.showerror("参数错误", str(error))
            return
        self.stop_event.clear()
        with self.lock:
            self.samples.clear()
            self.sample_count = self.frame_count = self.current_rf = self.current_dropped = 0
            self.continuity_gaps = 0
            self.crc_errors = 0
            self.error = ""
            self.running = True
            self.started_at = time.monotonic()
        self.start_button.configure(state="disabled")
        self.stop_button.configure(state="normal")
        self.status.set("正在连接 USB；只在内存滚动显示，不会保存采集文件。")
        self.worker = threading.Thread(target=self._capture_worker,
                                       args=(vid, pid, self.backend.get()), daemon=True)
        self.worker.start()

    def stop(self):
        self.stop_event.set()
        self.stop_button.configure(state="disabled")
        self.status.set("正在停止实时 USB 显示……")

    def save_display(self):
        with self.lock:
            buffered = list(self.samples)
            samples, frames, rf, dropped = self.sample_count, self.frame_count, self.current_rf, self.current_dropped
            gaps, crc_errors = self.continuity_gaps, self.crc_errors
        if not buffered:
            messagebox.showinfo("没有数据", "当前内存缓冲为空，收到 I/Q 数据后才能保存。", parent=self.root)
            return
        try:
            view_ms = float(self.view_ms.get())
            mod_hz = float(self.modulation_hz.get())
            expected_depth = float(self.expected_depth.get())
            expected_rf_hz = float(self.expected_rf_mhz.get())*1_000_000
        except ValueError as error:
            messagebox.showerror("参数错误", str(error), parent=self.root)
            return
        if mod_hz <= 0 or view_ms <= 0 or expected_rf_hz <= 0 or not 0 < expected_depth < 1:
            messagebox.showerror("参数错误", "AM 频率和显示时长必须大于 0，预期调制度须在 0 到 1 之间。", parent=self.root)
            return
        visible_points = min(SAMPLE_RATE*DISPLAY_BUFFER_MS//1000//DISPLAY_DECIMATION, max(1, int(SAMPLE_RATE*view_ms/1000/DISPLAY_DECIMATION)))
        with self.lock:
            if self.samples.maxlen != visible_points:
                self.samples = deque(self.samples, maxlen=visible_points)
            buffered = list(self.samples)
        ring = buffered[-visible_points:]
        output_dir = ARTIFACT_ROOT / "legacy/receiver/live_adc"
        try:
            output_dir.mkdir(parents=True, exist_ok=True)
        except OSError as error:
            messagebox.showerror("无法创建保存目录", str(error), parent=self.root)
            return
        default_name = datetime.now().strftime("receiver56_live_%Y%m%d_%H%M%S.csv")
        selected_path = filedialog.asksaveasfilename(
            parent=self.root, title="保存当前显示的数据", initialdir=str(output_dir),
            initialfile=default_name, defaultextension=".csv",
            filetypes=(("CSV 数据", "*.csv"), ("所有文件", "*.*")))
        if not selected_path:
            return
        csv_path = Path(selected_path)
        metadata_path = csv_path.with_suffix(".json")
        fit_info = None
        normalized_message = False
        try:
            fit_rows = [(p[0], p[1], p[2], 0, 0, 0) for p in ring]
            _, fit_info = fit_am(fit_rows, mod_hz, 0)
            normalized_message = (fit_info["fit_r_squared"] >= 0.1
                                  and fit_info["estimated_modulation_depth"] >= expected_depth*0.2
                                  and fit_info["fitted_ac_amplitude"] > 0)
        except (ValueError, ZeroDivisionError):
            fit_info = None
        try:
            with csv_path.open("w", newline="", encoding="utf-8-sig") as output:
                writer = csv.writer(output)
                writer.writerow(("sample_index", "time_from_window_start_s", "i", "q", "envelope",
                                 "recovered_message_normalized", "rf_estimate_hz"))
                for index, i_value, q_value, envelope in ring:
                    message = ""
                    if normalized_message:
                        message = f"{(envelope-fit_info['mean_envelope'])/fit_info['fitted_ac_amplitude']:.8f}"
                    writer.writerow((index, f"{(index-ring[0][0])/SAMPLE_RATE:.9f}", i_value, q_value,
                                     f"{envelope:.6f}", message, rf))
            metadata = {
                "saved_at": datetime.now().astimezone().isoformat(timespec="seconds"),
                "sample_rate_hz": SAMPLE_RATE,
                "display_decimation": DISPLAY_DECIMATION,
                "display_sample_rate_hz": SAMPLE_RATE//DISPLAY_DECIMATION,
                "display_window_ms": view_ms,
                "display_samples_saved": len(ring),
                "sample_index_start": ring[0][0],
                "sample_index_end": ring[-1][0],
                "am_frequency_setting_hz": mod_hz,
                "expected_modulation_depth": expected_depth,
                "expected_rf_hz": expected_rf_hz,
                "reported_rf_hz": rf,
                "frames_since_start": frames,
                "samples_received_since_start": samples,
                "fpga_cumulative_dropped_samples": dropped,
                "continuity_gaps": gaps,
                "crc_errors": crc_errors,
                "demodulation_method": "sqrt(I^2+Q^2) envelope; fit configured AM tone; subtract fitted DC; normalize by fitted AC amplitude",
                "recovered_message_written": normalized_message,
                "analysis": fit_info or {"error": "At least four modulation periods were not available for the configured frequency."},
            }
            metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8")
        except OSError as error:
            messagebox.showerror("保存失败", str(error), parent=self.root)
            return
        messagebox.showinfo("保存完成", f"当前显示窗口已保存：\n{csv_path}\n分析参数：\n{metadata_path}", parent=self.root)

    def _capture_worker(self, vid, pid, backend):
        transport = None
        decoder = FCR1Decoder()
        epoch = last_sequence = next_index = None
        continuity_gaps = 0
        try:
            transport = open_transport(vid, pid, backend, 0)
            while not self.stop_event.is_set():
                try:
                    # Read one EP2 quad-buffer window. USB reads run on this
                    # worker thread; the Tk thread only redraws the newest ring.
                    data = transport.read(EP_IN, 4*BLOCK, timeout=250)
                except TransferTimeout:
                    continue
                records = decoder.feed(bytes(data))
                with self.lock:
                    self.crc_errors = decoder.bad_crc
                for words, packet in records:
                    if words[7] != 32_000_000 or words[8] != SAMPLE_RATE:
                        raise ValueError(f"帧采样率不匹配：ADC={words[7]} Hz, I/Q={words[8]} Hz；请下载 32 MHz receiver56 SOF。")
                    if epoch is None:
                        epoch, last_sequence, next_index = words[3], words[2], words[4]
                    elif words[3] != epoch or words[2] != last_sequence or words[4] != next_index:
                        # Keep valid frames after a gap. Sample indexes retain
                        # their time position; an epoch reset starts a new view.
                        continuity_gaps += 1
                        epoch_changed = words[3] != epoch
                        epoch, last_sequence, next_index = words[3], words[2], words[4]
                        if epoch_changed:
                            with self.lock:
                                self.samples.clear()
                    # The FPGA drop counter is cumulative and may predate this
                    # USB connection; display it without stopping the stream.
                    last_sequence = (words[2]+1) & 0xffffffff
                    next_index = (words[4]+words[5]) & 0xffffffff
                    frame_samples = []
                    for n in range(words[5]):
                        sample_index = words[4]+n
                        if sample_index % DISPLAY_DECIMATION:
                            continue
                        i_value, q_value = struct.unpack_from("<hh", packet, HEADER+4*n)
                        envelope = math.hypot(i_value, q_value)
                        frame_samples.append((sample_index, i_value, q_value, envelope))
                    with self.lock:
                        self.samples.extend(frame_samples)
                        self.sample_count += words[5]
                        self.frame_count += 1
                        self.current_rf = words[9]
                        self.current_dropped = words[6]
                        self.continuity_gaps = continuity_gaps
        except Exception as error:
            with self.lock:
                self.error = str(error)
        finally:
            if transport is not None:
                try:
                    transport.close()
                except Exception as error:
                    with self.lock:
                        if not self.error:
                            self.error = f"USB close failed: {error}"
        with self.lock:
            self.running = False

    def _refresh(self):
        with self.lock:
            buffered = list(self.samples)
            samples, frames, rf, dropped = self.sample_count, self.frame_count, self.current_rf, self.current_dropped
            gaps = self.continuity_gaps
            crc_errors = self.crc_errors
            running = self.running
        elapsed = (time.monotonic()-self.started_at) if self.started_at else 0
        try:
            mod_hz = float(self.modulation_hz.get())
            target_rf = float(self.expected_rf_mhz.get())
            view_ms = float(self.view_ms.get())
            expected_depth = float(self.expected_depth.get())
        except ValueError:
            mod_hz, target_rf, view_ms, expected_depth = 0, 0, 20, 0
        visible_points = min(SAMPLE_RATE*DISPLAY_BUFFER_MS//1000//DISPLAY_DECIMATION, max(1, int(SAMPLE_RATE*view_ms/1000/DISPLAY_DECIMATION)))
        with self.lock:
            if self.samples.maxlen != visible_points:
                self.samples = deque(self.samples, maxlen=visible_points)
            buffered = list(self.samples)
        ring = buffered[-visible_points:]
        self.save_button.configure(state="normal" if ring else "disabled")
        rf_text = f"{rf/1e6:.6f} MHz" if rf else "—"
        target_text = f" / 预期 {target_rf:g} MHz" if target_rf else ""
        buffered_ms = len(buffered)*DISPLAY_DECIMATION/SAMPLE_RATE*1000
        self.stats.set(f"帧 {frames:,} | 样本 {samples:,} | RF {rf_text}{target_text} | FPGA累计丢样 {dropped:,} | 间断 {gaps} | CRC错 {crc_errors} | "
                       f"内存缓冲 {buffered_ms:.1f} ms / {view_ms:g} ms | 时长 {elapsed:.1f} s")
        self._draw_iq(ring, view_ms)
        self._draw_env(ring, view_ms)
        self._draw_message(ring, mod_hz, expected_depth, view_ms)
        if self.worker and not self.worker.is_alive() and not running:
            self.start_button.configure(state="normal")
            self.stop_button.configure(state="disabled")
            with self.lock:
                error = self.error
            if error:
                self.status.set(f"实时显示停止：{error}")
            else:
                self.status.set("实时显示已停止；缓冲数据仅保留在内存中。")
        elif running and self.stop_event.is_set():
            self.status.set("正在停止 USB 实时读取……")
        elif running:
            if frames:
                self.status.set("正在实时接收 EP2 IN；按“停止显示”结束。")
            elif elapsed > 2:
                self.status.set("USB 已连接或正在等待；暂未收到锁频后的 I/Q 帧。检查 SOF、锁频灯和 EP2 IN。")
        self.root.after(100, self._refresh)

    def _draw_iq(self, ring, view_ms):
        canvas = self.iq_canvas
        canvas.delete("all")
        w, h = max(200, canvas.winfo_width()), max(120, canvas.winfo_height())
        left, right, top, bottom = 58, w-18, 30, h-28
        canvas.create_text(left, 12, anchor="w", text=f"最近 {view_ms:g} ms：I / Q", font=("Segoe UI", 11, "bold"))
        self._axes(canvas, left, right, top, bottom)
        if not ring:
            canvas.create_text(w/2, h/2, text="等待 I/Q 数据…", fill="#777")
            return
        peak = max(1, max(max(abs(point[1]), abs(point[2])) for point in ring))
        canvas.create_text(left-5, top, anchor="ne", text=f"+{peak}", fill="#555")
        canvas.create_text(left-5, bottom, anchor="se", text=f"-{peak}", fill="#555")
        step = max(1, len(ring)//1800)
        for idx, color, item in ((1, "#1565c0", "I"), (2, "#ef6c00", "Q")):
            pts=[]
            for p in ring[::step]:
                x=left+(p[0]-ring[0][0])*(right-left)/max(1,ring[-1][0]-ring[0][0])
                y=bottom-(p[idx]+peak)*(bottom-top)/(2*peak)
                pts.extend((x,y))
            if len(pts)>=4:
                canvas.create_line(*pts, fill=color, width=1.2)
        self._time_ticks(canvas, ring, left, right, bottom)
        canvas.create_text(right-75, top+8, text="I", fill="#1565c0")
        canvas.create_text(right-48, top+8, text="Q", fill="#ef6c00")

    def _draw_env(self, ring, view_ms):
        canvas = self.env_canvas
        canvas.delete("all")
        w, h = max(200, canvas.winfo_width()), max(120, canvas.winfo_height())
        left, right, top, bottom = 58, w-18, 30, h-28
        canvas.create_text(left, 12, anchor="w", text=f"最近 {view_ms:g} ms：包络 |I+jQ|", font=("Segoe UI", 11, "bold"))
        self._axes(canvas, left, right, top, bottom)
        if not ring:
            canvas.create_text(w/2, h/2, text="等待 I/Q 数据…", fill="#777")
            return
        values=[p[3] for p in ring]
        low, high=min(values), max(values)
        pad=max(1, (high-low)*0.1)
        low-=pad;high+=pad
        canvas.create_text(left-5, top, anchor="ne", text=f"{high:.0f}", fill="#555")
        canvas.create_text(left-5, bottom, anchor="se", text=f"{low:.0f}", fill="#555")
        step=max(1,len(ring)//1800)
        pts=[]
        for p in ring[::step]:
            x=left+(p[0]-ring[0][0])*(right-left)/max(1,ring[-1][0]-ring[0][0])
            y=bottom-(p[3]-low)*(bottom-top)/(high-low or 1)
            pts.extend((x,y))
        if len(pts)>=4:
            canvas.create_line(*pts, fill="#2e7d32", width=1.4)
        self._time_ticks(canvas, ring, left, right, bottom)

    def _draw_message(self, ring, mod_hz, expected_depth, view_ms):
        canvas = self.message_canvas
        canvas.delete("all")
        w, h = max(200, canvas.winfo_width()), max(120, canvas.winfo_height())
        left, right, top, bottom = 58, w-18, 30, h-28
        title = f"最近 {view_ms:g} ms：恢复的 AM 基带（去直流 / 归一化）"
        if mod_hz > 0:
            title += f" · {mod_hz:g} Hz"
        canvas.create_text(left, 12, anchor="w", text=title, font=("Segoe UI", 11, "bold"))
        self._axes(canvas, left, right, top, bottom)
        if not ring or mod_hz <= 0:
            canvas.create_text(w/2, h/2, text="等待有效 IQ 数据…", fill="#777")
            return
        stride = max(1, len(ring)//2000)
        fit_rows = [(p[0], p[1], p[2], 0, 0, 0) for p in ring[::stride]]
        try:
            _, am = fit_am(fit_rows, mod_hz, 0)
        except (ValueError, ZeroDivisionError):
            canvas.create_text(w/2, h/2, text="等待至少 4 个调制周期后恢复基带…", fill="#777")
            return
        dc, ac = am["mean_envelope"], am["fitted_ac_amplitude"]
        depth = am["estimated_modulation_depth"]
        if (ac <= 1e-12 or am["fit_r_squared"] < 0.1
                or depth < expected_depth*0.2):
            canvas.create_text(w/2, h/2,
                               text=f"{mod_hz:g} Hz 下未检测到可信 AM 正弦（拟合深度 {depth*100:.2f}% / R² {am['fit_r_squared']:.3f}）；请核对调制频率。",
                               fill="#b71c1c")
            return
        canvas.create_text(left-5, top, anchor="ne", text="+1.5", fill="#555")
        canvas.create_text(left-5, bottom, anchor="se", text="-1.5", fill="#555")
        mid = (top+bottom)/2
        canvas.create_line(left, mid, right, mid, fill="#aaa", dash=(3,3))
        step = max(1, len(ring)//1800)
        pts = []
        for p in ring[::step]:
            x = left+(p[0]-ring[0][0])*(right-left)/max(1,ring[-1][0]-ring[0][0])
            message = max(-1.5, min(1.5, (p[3]-dc)/ac))
            y = bottom-(message+1.5)*(bottom-top)/3
            pts.extend((x,y))
        if len(pts) >= 4:
            canvas.create_line(*pts, fill="#6a1b9a", width=1.4)
        self._time_ticks(canvas, ring, left, right, bottom)
        canvas.create_text(right-8, top+8, anchor="ne",
                           text=f"深度 {am['estimated_modulation_depth']*100:.1f}% / 预期 {expected_depth*100:.1f}%  ·  R² {am['fit_r_squared']:.3f}",
                           fill="#6a1b9a")

    @staticmethod
    def _time_ticks(canvas, ring, left, right, bottom):
        duration_ms=(ring[-1][0]-ring[0][0])/SAMPLE_RATE*1000
        for k in range(5):
            x=left+(right-left)*k/4
            canvas.create_line(x,bottom,x,bottom+4,fill="#555")
            canvas.create_text(x,bottom+14,text=f"{duration_ms*k/4:.1f} ms",font=("Segoe UI",8))

    @staticmethod
    def _axes(canvas, left, right, top, bottom):
        for k in range(5):
            y=top+(bottom-top)*k/4
            canvas.create_line(left,y,right,y,fill="#e1e1e1")
        canvas.create_line(left,top,left,bottom,fill="#555")
        canvas.create_line(left,bottom,right,bottom,fill="#555")

    def _close(self):
        if self.worker and self.worker.is_alive():
            self.stop_event.set()
            self.status.set("正在停止 USB 实时读取……")
            self.root.after(100, self._close_when_stopped)
        else:
            self.root.destroy()

    def _close_when_stopped(self):
        if self.worker and self.worker.is_alive():
            self.root.after(100, self._close_when_stopped)
        else:
            self.root.destroy()


def main():
    root = tk.Tk()
    LiveCaptureWindow(root)
    root.mainloop()


if __name__ == "__main__":
    main()
