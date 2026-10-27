"""Chinese desktop dialog for the project's trusted harness manifest.

Run with python -B -m harness.dialog. Only the Python standard library is used.
"""

import copy
import json
import os
from pathlib import Path
import threading

from .runner import ROOT, ConfigError, execute, select_tasks, validate_manifest


STATUS = {
    "not_run": "未运行", "pending": "等待依赖", "queued": "排队",
    "running": "执行中", "passed": "通过", "failed": "失败",
    "blocked": "依赖阻塞", "timeout": "超时", "cancelled": "已取消",
}


class RunController:
    """Keep subprocess execution off the UI thread and bound state by task count."""

    def __init__(self, root=ROOT):
        self.root = Path(root).resolve()
        self.lock = threading.Lock()
        self.cancel_event = threading.Event()
        self.thread = None
        self.state = {"busy": False, "records": {}, "run_dir": None,
                      "code": None, "error": None}

    def load_tasks(self):
        data = json.loads((self.root / "harness/tasks.json").read_text(encoding="utf-8-sig"))
        return validate_manifest(data, self.root)

    def start(self, requested, jobs):
        if not requested:
            raise ConfigError("请至少选择一个任务。")
        if type(jobs) is not int or not 1 <= jobs <= 32:
            raise ConfigError("并发数必须为 1 至 32 的整数。")
        tasks = select_tasks(self.load_tasks(), requested, self.root)
        with self.lock:
            if self.state["busy"]:
                raise ConfigError("当前验证尚未结束。")
            self.cancel_event.clear()
            self.state = {"busy": True,
                          "records": {name: {"status": "pending"} for name in tasks},
                          "run_dir": None, "code": None, "error": None}
            self.thread = threading.Thread(target=self._run, args=(tasks, jobs),
                                           name="harness-dialog-run", daemon=False)
            self.thread.start()
        return tasks

    def _update(self, name, record, directory):
        with self.lock:
            self.state["records"][name] = record
            self.state["run_dir"] = str(directory)

    def _run(self, tasks, jobs):
        try:
            code, directory, summary = execute(
                tasks, jobs=jobs, root=self.root, cancel_event=self.cancel_event,
                on_update=self._update)
            with self.lock:
                self.state.update(code=code, run_dir=str(directory), records=summary["tasks"])
        except Exception as error:
            with self.lock:
                self.state["error"] = str(error)
        finally:
            with self.lock:
                self.state["busy"] = False

    def cancel(self):
        self.cancel_event.set()

    def snapshot(self):
        with self.lock:
            return copy.deepcopy(self.state)


def read_log(directory, record, limit=128 * 1024):
    """Only read a task's log inside its run, with a bounded tail for the UI."""
    if not directory or not record.get("log"):
        return "尚无日志。依赖阻塞或未运行的任务不会生成任务日志。"
    base = Path(directory).resolve()
    path = (base / record["log"]).resolve()
    if path.parent != base:
        raise ValueError("日志路径超出本次运行目录。")
    try:
        with path.open("rb") as stream:
            size = stream.seek(0, 2)
            stream.seek(max(0, size - limit))
            data = stream.read(limit)
    except OSError as error:
        return f"暂时无法读取日志：{error}"
    # Existing tools may emit the Windows code page; avoid silently losing text.
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("gb18030", errors="replace")
    return ("[仅显示最后 128 KiB；完整日志保存在运行目录]\n" if size > limit else "") + text


class HarnessDialog:
    def __init__(self, window, root=ROOT):
        import tkinter as tk
        from tkinter import ttk
        from tkinter.scrolledtext import ScrolledText

        self.window, self.tk, self.ttk = window, tk, ttk
        self.controller = RunController(root)
        self.tasks = {}
        self.shown = {"records": {}, "run_dir": None}
        self.last_busy = False
        self.closing = False
        self.log_signature = None
        window.title("简易数字接收机 · Harness 验证对话框")
        window.geometry("1180x800")
        window.minsize(980, 680)
        style = ttk.Style(window)
        style.theme_use("clam")
        style.configure("TLabel", font=("Microsoft YaHei UI", 10))
        style.configure("TButton", font=("Microsoft YaHei UI", 10), padding=6)
        style.configure("Treeview", font=("Microsoft YaHei UI", 10), rowheight=30)
        style.configure("Treeview.Heading", font=("Microsoft YaHei UI", 10, "bold"))
        frame = ttk.Frame(window, padding=18)
        frame.pack(fill="both", expand=True)
        ttk.Label(frame, text="项目验证", font=("Microsoft YaHei UI", 20, "bold")).pack(anchor="w")
        ttk.Label(frame, text=str(self.controller.root)).pack(anchor="w", pady=(4, 8))
        ttk.Label(frame, text="本界面执行本地检查。检查通过仅覆盖任务描述的范围；整机接收、时序及上板验收须另行验证。",
                  foreground="#80551c", wraplength=1100).pack(anchor="w", pady=(0, 12))
        toolbar = ttk.Frame(frame)
        toolbar.pack(fill="x", pady=(0, 10))
        self.run_button = ttk.Button(toolbar, text="运行所选任务", command=self.start)
        self.run_button.pack(side="left")
        self.all_button = ttk.Button(toolbar, text="选择全部", command=self.select_all)
        self.all_button.pack(side="left", padx=6)
        self.reload_button = ttk.Button(toolbar, text="重新读取清单", command=self.reload)
        self.reload_button.pack(side="left")
        ttk.Label(toolbar, text="并发数").pack(side="left", padx=(20, 6))
        self.jobs = tk.StringVar(value="3")
        self.jobs_input = ttk.Spinbox(toolbar, from_=1, to=32, width=4, textvariable=self.jobs)
        self.jobs_input.pack(side="left")
        self.cancel_button = ttk.Button(toolbar, text="取消运行", command=self.cancel, state="disabled")
        self.cancel_button.pack(side="left", padx=12)
        self.history_button = ttk.Button(toolbar, text="打开历史结果", command=self.open_history)
        self.history_button.pack(side="right")
        ttk.Label(frame, text="按 Ctrl / Shift 多选；选择下游任务会自动包含依赖。双击任务查看命令、依赖和写入范围。").pack(anchor="w", pady=(0, 6))
        table_frame = ttk.Frame(frame)
        table_frame.pack(fill="x")
        self.table = ttk.Treeview(table_frame, columns=("task", "status", "deps", "seconds"),
                                  show="headings", selectmode="extended", height=8)
        for key, label, width in (("task", "任务 ID", 340), ("status", "本次状态", 150),
                                  ("deps", "前置任务", 400), ("seconds", "耗时 / s", 100)):
            self.table.heading(key, text=label)
            self.table.column(key, width=width, minwidth=80, stretch=key in ("task", "deps"))
        self.table.pack(side="left", fill="x", expand=True)
        scrollbar = ttk.Scrollbar(table_frame, orient="vertical", command=self.table.yview)
        scrollbar.pack(side="right", fill="y")
        self.table.configure(yscrollcommand=scrollbar.set)
        for status, color in (("passed", "#166534"), ("failed", "#b91c1c"),
                              ("timeout", "#b91c1c"), ("running", "#1d4ed8"),
                              ("blocked", "#935c12"), ("cancelled", "#666666")):
            self.table.tag_configure(status, foreground=color)
        self.table.bind("<<TreeviewSelect>>", lambda event: self.refresh_log())
        self.table.bind("<Double-1>", self.show_task)
        notebook = ttk.Notebook(frame)
        notebook.pack(fill="both", expand=True, pady=(12, 8))
        self.log = ScrolledText(notebook, wrap="word", font=("Consolas", 10), height=10)
        notebook.add(self.log, text="任务日志")
        self.plan = ScrolledText(notebook, wrap="word", font=("Microsoft YaHei UI", 10))
        notebook.add(self.plan, text="项目方案与审阅结论")
        plan_path = self.controller.root / "docs/project_review_2026-10-04.md"
        self._set_text(self.plan, plan_path.read_text(encoding="utf-8") if plan_path.exists()
                       else "方案文件尚未建立。请阅读 README.md 与 docs/work_plan.md。")
        bottom = ttk.Frame(frame)
        bottom.pack(fill="x")
        self.message = tk.StringVar(value="准备就绪")
        ttk.Label(bottom, textvariable=self.message, wraplength=850).pack(side="left")
        self.folder_button = ttk.Button(bottom, text="打开运行目录", command=self.open_directory, state="disabled")
        self.folder_button.pack(side="right")
        window.protocol("WM_DELETE_WINDOW", self.close)
        self.reload()
        self.tick_id = window.after(200, self.tick)

    def _set_text(self, widget, text):
        widget.configure(state="normal")
        widget.delete("1.0", "end")
        widget.insert("1.0", text)
        widget.configure(state="disabled")

    def reload(self):
        from tkinter import messagebox
        try:
            tasks = self.controller.load_tasks()
        except (OSError, ValueError) as error:
            self.run_button.configure(state="disabled")
            messagebox.showerror("任务清单错误", str(error), parent=self.window)
            return
        self.tasks = tasks
        self.table.delete(*self.table.get_children())
        self.shown = {"records": {}, "run_dir": None}
        for name, task in tasks.items():
            self.table.insert("", "end", iid=name, values=(name, STATUS["not_run"],
                              ", ".join(task["depends_on"]) or "—", "—"))
        self.run_button.configure(state="normal")
        self.select_all()
        self.message.set(f"已读取 {len(tasks)} 项检查。运行产物写入 .harness/，执行期间清单不可修改。")

    def select_all(self):
        self.table.selection_set(self.table.get_children())

    def set_busy(self, busy):
        for button in (self.run_button, self.all_button, self.reload_button, self.history_button, self.jobs_input):
            button.configure(state="disabled" if busy else "normal")
        self.cancel_button.configure(state="normal" if busy else "disabled")

    def start(self):
        from tkinter import messagebox
        try:
            tasks = self.controller.start(list(self.table.selection()), int(self.jobs.get()))
        except (ValueError, OSError) as error:
            messagebox.showerror("无法启动", str(error), parent=self.window)
            return
        # Refresh changed manifest definitions before displaying this run.
        self.tasks.update(tasks)
        for name, task in tasks.items():
            if not self.table.exists(name):
                self.table.insert("", "end", iid=name)
        self.shown = self.controller.snapshot()
        self.last_busy = True
        self.log_signature = None
        self.set_busy(True)
        self.message.set(f"正在执行 {len(tasks)} 项检查（包含依赖）；界面保持响应。")
        self.paint_records()

    def cancel(self):
        self.controller.cancel()
        self.cancel_button.configure(state="disabled")
        self.message.set("正在取消并终止检查子进程；等待保存 summary.json 和释放运行锁。")

    def paint_records(self):
        for name in self.table.get_children():
            record = self.shown["records"].get(name, {})
            status = record.get("status", "not_run")
            self.table.item(name, values=(name, STATUS.get(status, status),
                            ", ".join(self.tasks[name]["depends_on"]) or "—",
                            record.get("duration_seconds") if record.get("duration_seconds") is not None else "—"),
                            tags=(status,))

    def tick(self):
        state = self.controller.snapshot()
        if self.last_busy:
            self.shown = state
            self.paint_records()
            self.refresh_log()
            self.folder_button.configure(state="normal" if state["run_dir"] else "disabled")
            if not state["busy"]:
                self.last_busy = False
                self.set_busy(False)
                if state["error"]:
                    self.message.set(f"运行错误：{state['error']}")
                else:
                    counts = {}
                    for record in state["records"].values():
                        label = STATUS[record["status"]]
                        counts[label] = counts.get(label, 0) + 1
                    self.message.set("本次检查结束：" + "，".join(f"{k} {v}" for k, v in counts.items())
                                     + f"；退出码 {state['code']}。")
        if self.closing and not state["busy"]:
            self.window.destroy()
            return
        self.tick_id = self.window.after(200, self.tick)

    def refresh_log(self):
        selection = self.table.selection()
        if not selection:
            return
        name = selection[0]
        record = self.shown["records"].get(name, {})
        try:
            text = read_log(self.shown["run_dir"], record)
        except ValueError as error:
            text = str(error)
        text = name + "\n" + text
        if text != self.log_signature:
            self._set_text(self.log, text)
            self.log.see("end")
            self.log_signature = text

    def show_task(self, event=None):
        from tkinter import messagebox
        names = self.table.selection()
        if not names:
            return
        name = names[0]
        task = self.tasks[name]
        text = (f"{task['description']}\n\n依赖：{', '.join(task['depends_on']) or '无'}"
                f"\n超时：{task['timeout_seconds']} s\n写入：{', '.join(task['writes']) or '无共享输出'}"
                "\n\n命令数组：\n" + json.dumps(task['command'], ensure_ascii=False, indent=2))
        messagebox.showinfo(name, text, parent=self.window)

    def open_history(self):
        from tkinter import filedialog, messagebox
        path = filedialog.askopenfilename(parent=self.window, title="选择历史 summary.json",
                initialdir=self.controller.root / ".harness/runs", filetypes=[("运行摘要", "summary.json")])
        if not path:
            return
        try:
            path = Path(path).resolve()
            if self.controller.root / ".harness" not in path.parents:
                raise ValueError("仅支持本项目 .harness/ 下的运行摘要。")
            summary = json.loads(path.read_text(encoding="utf-8-sig"))
            if (not isinstance(summary, dict) or summary.get("version") != 1
                    or not isinstance(summary.get("tasks"), dict)):
                raise ValueError("运行摘要格式错误。")
            for name, record in summary["tasks"].items():
                if name not in self.tasks or not isinstance(record, dict) or record.get("status") not in STATUS:
                    raise ValueError("摘要包含未知任务或非法状态，请先读取对应版本的任务清单。")
            self.shown = {"records": summary["tasks"], "run_dir": str(path.parent)}
            self.paint_records()
            self.refresh_log()
            self.folder_button.configure(state="normal")
            self.message.set(f"历史结果（非当前运行）：{path.parent.name}")
        except (OSError, ValueError, TypeError) as error:
            messagebox.showerror("无法读取历史结果", str(error), parent=self.window)

    def open_directory(self):
        directory = self.shown.get("run_dir")
        if directory:
            os.startfile(directory)

    def close(self):
        if self.controller.snapshot()["busy"]:
            self.closing = True
            self.cancel()
            self.message.set("关闭前正在结束检查并保存运行记录……")
        else:
            self.window.after_cancel(self.tick_id)
            self.window.destroy()


def main():
    import tkinter as tk
    window = tk.Tk()
    HarnessDialog(window)
    window.mainloop()


if __name__ == "__main__":
    main()
