"""Run a validated command DAG with bounded local concurrency."""

import argparse
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path, PureWindowsPath
import re
import signal
import subprocess
import sys
import threading
import time
import uuid


ROOT = Path(__file__).resolve().parent.parent


class ConfigError(ValueError):
    """Invalid task manifest or selection."""


def validate_manifest(data, root=ROOT):
    if not isinstance(data, dict) or type(data.get("version")) is not int or data.get("version") != 1:
        raise ConfigError("Manifest version must be 1")
    if not isinstance(data.get("tasks"), list) or not data["tasks"]:
        raise ConfigError("Manifest tasks must be a nonempty list")
    tasks = {}
    for task in data["tasks"]:
        if not isinstance(task, dict):
            raise ConfigError("Each task must be an object")
        name = task.get("id")
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", name):
            raise ConfigError("Task id must contain only letters, digits, '-' or '_'")
        if name in tasks:
            raise ConfigError(f"Duplicate task id: {name}")
        if not isinstance(task.get("description"), str):
            raise ConfigError(f"{name}: description must be a string")
        command = task.get("command")
        if (not isinstance(command, list) or not command
                or any(not isinstance(arg, str) or "\0" in arg for arg in command)
                or not command[0].strip()):
            raise ConfigError(f"{name}: command must be a nonempty string argv list")
        dependencies = task.get("depends_on")
        if (not isinstance(dependencies, list)
                or any(not isinstance(dep, str) for dep in dependencies)
                or len(set(dependencies)) != len(dependencies)):
            raise ConfigError(f"{name}: depends_on must contain unique task ids")
        timeout = task.get("timeout_seconds")
        if (isinstance(timeout, bool) or not isinstance(timeout, (int, float))
                or not math.isfinite(timeout) or timeout <= 0):
            raise ConfigError(f"{name}: timeout_seconds must be finite and positive")
        writes = task.get("writes")
        if not isinstance(writes, list):
            raise ConfigError(f"{name}: writes must be a list")
        for value in writes:
            if not isinstance(value, str) or not value or "\0" in value:
                raise ConfigError(f"{name}: invalid writes path")
            path = Path(value.replace("\\", "/"))
            windows_path = PureWindowsPath(value)
            if (path.is_absolute() or windows_path.drive or windows_path.root
                    or ".." in path.parts or path == Path(".")):
                raise ConfigError(f"{name}: writes must be relative paths below the project root")
            resolved = (root / path).resolve()
            if resolved == root.resolve() or root.resolve() not in resolved.parents:
                raise ConfigError(f"{name}: writes escapes the project root: {value}")
        tasks[name] = dict(task)
    visiting, visited = set(), set()

    def visit(name):
        if name not in tasks:
            raise ConfigError(f"Unknown dependency: {name}")
        if name in visiting:
            raise ConfigError(f"Dependency cycle at: {name}")
        if name in visited:
            return
        visiting.add(name)
        for dep in tasks[name]["depends_on"]:
            visit(dep)
        visiting.remove(name)
        visited.add(name)

    for name in tasks:
        visit(name)
    return tasks


def select_tasks(tasks, requested=None, root=ROOT):
    selected = set()

    def include(name):
        if name not in tasks:
            raise ConfigError(f"Unknown task: {name}")
        if name not in selected:
            selected.add(name)
            for dep in tasks[name]["depends_on"]:
                include(dep)

    for name in requested or tasks:
        include(name)
    ancestors = {}

    def dependencies(name):
        if name not in ancestors:
            ancestors[name] = set(tasks[name]["depends_on"])
            for dep in tasks[name]["depends_on"]:
                ancestors[name].update(dependencies(dep))
        return ancestors[name]

    names = [name for name in tasks if name in selected]
    for index, left in enumerate(names):
        for right in names[index + 1:]:
            if left in dependencies(right) or right in dependencies(left):
                continue
            for a in tasks[left]["writes"]:
                pa = (root / a.replace("\\", "/")).resolve()
                for b in tasks[right]["writes"]:
                    pb = (root / b.replace("\\", "/")).resolve()
                    if pa == pb or pa in pb.parents or pb in pa.parents:
                        raise ConfigError(f"Unordered write conflict: {left} ({a}) / {right} ({b})")
    return {name: tasks[name] for name in names}


def stop_process(process):
    if os.name == "nt":
        try:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=10, check=False)
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"harness: taskkill failed: {error}", file=sys.stderr)
        finally:
            if process.poll() is None:
                process.kill()
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    process.wait(timeout=10)


def execute(tasks, jobs=3, output_dir=None, root=ROOT, cancel_event=None, on_update=None):
    """Execute tasks; optional cancellation and record snapshots support the dialog.

    on_update(name, record, run_dir) runs on scheduler/task threads and must not block or
    raise. It observes validation results only, not engineering completion.
    """
    root = Path(root).resolve()
    state_dir = root / ".harness"
    base = Path(output_dir) if output_dir else state_dir / "runs"
    if not base.is_absolute():
        base = root / base
    base = base.resolve()
    if (state_dir not in base.parents or base == state_dir
            or base == state_dir / "run.lock" or state_dir / "run.lock" in base.parents):
        raise ConfigError("output-dir must be a subdirectory of project .harness/")
    state_dir.mkdir(exist_ok=True)
    lock_dir = state_dir / "run.lock"
    try:
        lock_dir.mkdir()
    except FileExistsError as error:
        raise ConfigError("Another run holds .harness/run.lock") from error
    try:
        return _execute(tasks, jobs, base, root, cancel_event, on_update)
    finally:
        lock_dir.rmdir()


def _execute(tasks, jobs, base, root, cancel_event=None, on_update=None):
    if isinstance(jobs, bool) or not isinstance(jobs, int) or jobs < 1:
        raise ConfigError("jobs must be a positive integer")
    run_dir = base / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:12])
    run_dir.mkdir(parents=True, exist_ok=False)
    records = {name: {"status": "pending", "exitcode": None, "started_at": None,
                      "duration_seconds": None, "log": None,
                      "command": [sys.executable if arg == "{python}" else arg
                                  for arg in task["command"]]}
               for name, task in tasks.items()}
    processes = {}
    lock = threading.Lock()
    cancelled = threading.Event()

    def publish(name):
        if on_update is not None:
            on_update(name, dict(records[name]), run_dir)

    def run_task(name):
        record = records[name]
        start = time.monotonic()
        record.update(status="running", started_at=datetime.now(timezone.utc).isoformat(),
                      log=f"{name}.log")
        publish(name)
        try:
            with (run_dir / record["log"]).open("wb") as log:
                with lock:
                    if cancelled.is_set():
                        record["status"] = "cancelled"
                        return
                    options = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if os.name == "nt" else {"start_new_session": True}
                    process = subprocess.Popen(record["command"], cwd=root, shell=False,
                                               stdin=subprocess.DEVNULL, stdout=log,
                                               stderr=subprocess.STDOUT, **options)
                    processes[name] = process
                try:
                    record["exitcode"] = process.wait(timeout=tasks[name]["timeout_seconds"])
                    record["status"] = "passed" if record["exitcode"] == 0 else "failed"
                except subprocess.TimeoutExpired:
                    stop_process(process)
                    record.update(status="timeout", exitcode=process.returncode)
                    log.write(b"\n[harness] Task timeout; process tree terminated.\n")
                if cancelled.is_set():
                    record["status"] = "cancelled"
        except OSError as error:
            record.update(status="failed", error=str(error))
        finally:
            record["duration_seconds"] = round(time.monotonic() - start, 6)
            with lock:
                processes.pop(name, None)
            publish(name)

    interrupted = False
    pool = ThreadPoolExecutor(max_workers=jobs)
    futures = {}
    try:
        while True:
            if cancel_event is not None and cancel_event.is_set():
                raise KeyboardInterrupt
            for name, record in records.items():
                if record["status"] != "pending":
                    continue
                states = [records[dep]["status"] for dep in tasks[name]["depends_on"]]
                if any(state in {"failed", "timeout", "blocked", "cancelled"} for state in states):
                    record["status"] = "blocked"
                    publish(name)
                elif all(state == "passed" for state in states) and len(futures) < jobs:
                    record["status"] = "queued"
                    futures[pool.submit(run_task, name)] = name
            if not futures:
                if all(record["status"] != "pending" for record in records.values()):
                    break
                continue
            done, _ = wait(futures, timeout=0.2, return_when=FIRST_COMPLETED)
            for future in done:
                future.result()
                del futures[future]
    except KeyboardInterrupt:
        interrupted = True
        with lock:
            cancelled.set()
            active = list(processes.values())
        for process in active:
            stop_process(process)
    finally:
        pool.shutdown(wait=True, cancel_futures=True)
        for name, record in records.items():
            if record["status"] in {"pending", "queued"}:
                record["status"] = "cancelled" if interrupted else "blocked"
            publish(name)
        summary = {"version": 1, "interrupted": interrupted, "tasks": records}
        (run_dir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    code = 130 if interrupted else int(any(record["status"] != "passed" for record in records.values()))
    return code, run_dir, summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("list", "run"))
    parser.add_argument("--manifest", type=Path, default=ROOT / "harness" / "tasks.json")
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--task", action="append")
    parser.add_argument("--output-dir", type=Path, default=ROOT / ".harness" / "runs")
    args = parser.parse_args(argv)
    try:
        if args.jobs < 1:
            raise ConfigError("jobs must be positive")
        data = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
        tasks = select_tasks(validate_manifest(data), args.task)
        if args.action == "list":
            for name, task in tasks.items():
                print(f"{name}: {task['description']} [depends: {', '.join(task['depends_on']) or '-'}]")
            return 0
        code, directory, summary = execute(tasks, args.jobs, args.output_dir)
        for name, record in summary["tasks"].items():
            print(f"{name}: {record['status']}")
        print(f"Summary: {directory / 'summary.json'}")
        return code
    except (ConfigError, OSError, ValueError) as error:
        print(f"harness: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
