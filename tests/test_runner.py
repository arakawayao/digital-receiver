"""Exercise scheduling, failure isolation and manifest validation."""

import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

from harness.runner import ConfigError, execute, select_tasks, stop_process, validate_manifest


def task(name, script="pass", dependencies=(), writes=(), timeout=10):
    return {"id": name, "description": name, "depends_on": list(dependencies),
            "command": ["{python}", "-c", script], "writes": list(writes),
            "timeout_seconds": timeout}


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def validated(self, items):
        return validate_manifest({"version": 1, "tasks": items}, self.root)

    def run_tasks(self, items, jobs=3):
        tasks = select_tasks(self.validated(items), root=self.root)
        return execute(tasks, jobs=jobs, root=self.root)

    def test_parallel_and_dependency_order(self):
        # Each peer waits for the other to start; serial execution must time out.
        def peer(name, other):
            return ("from pathlib import Path; import time\n"
                    f"Path('{name}').touch()\n"
                    "deadline = time.monotonic() + 5\n"
                    f"while not Path('{other}').exists():\n"
                    "    assert time.monotonic() < deadline, 'peer never started'\n"
                    "    time.sleep(0.01)\n")
        items = [task("left", peer("left", "right"), writes=["left"]),
                 task("right", peer("right", "left"), writes=["right"]),
                 task("join", "from pathlib import Path; assert Path('left').exists() and Path('right').exists()", ["left", "right"])]
        code, directory, summary = self.run_tasks(items, jobs=2)
        self.assertEqual(code, 0)
        self.assertTrue(all(row["status"] == "passed" for row in summary["tasks"].values()))
        self.assertEqual(json.loads((directory / "summary.json").read_text()), summary)
        self.assertFalse((self.root / ".harness" / "run.lock").exists())

    def test_failure_blocks_descendants_only_and_logs(self):
        code, directory, summary = self.run_tasks([
            task("fail", "import sys; print('failure evidence', flush=True); sys.exit(7)"),
            task("child", dependencies=["fail"]),
            task("grandchild", dependencies=["child"]), task("independent")])
        self.assertEqual(code, 1)
        rows = summary["tasks"]
        self.assertEqual(rows["fail"]["exitcode"], 7)
        self.assertEqual(rows["child"]["status"], "blocked")
        self.assertEqual(rows["grandchild"]["status"], "blocked")
        self.assertEqual(rows["independent"]["status"], "passed")
        self.assertIn("failure evidence", (directory / "fail.log").read_text())

    def test_timeout(self):
        code, _, summary = self.run_tasks([task("timeout", "import time; time.sleep(30)", timeout=0.2),
                                          task("child", dependencies=["timeout"])])
        self.assertEqual(code, 1)
        self.assertEqual(summary["tasks"]["timeout"]["status"], "timeout")
        self.assertEqual(summary["tasks"]["child"]["status"], "blocked")

    def test_interrupt_terminates_running_process(self):
        marker = self.root / "started"

        def interrupt(*args, **kwargs):
            deadline = time.monotonic() + 5
            while not marker.exists():
                if time.monotonic() >= deadline:
                    self.fail("task did not start before interruption")
                time.sleep(0.01)
            raise KeyboardInterrupt

        with patch("harness.runner.wait", side_effect=interrupt), \
                patch("harness.runner.stop_process", wraps=stop_process) as terminate:
            code, _, summary = self.run_tasks([
                task("running", "from pathlib import Path; import time; Path('started').touch(); time.sleep(30)", timeout=40),
                task("pending", dependencies=["running"])])
        self.assertEqual(code, 130)
        self.assertTrue(summary["interrupted"])
        self.assertEqual(summary["tasks"]["running"]["status"], "cancelled")
        self.assertEqual(summary["tasks"]["pending"]["status"], "cancelled")
        self.assertIsNotNone(terminate.call_args.args[0].poll())
        self.assertFalse((self.root / ".harness" / "run.lock").exists())

    def test_subset_includes_dependencies(self):
        tasks = self.validated([task("first"), task("last", dependencies=["first"]), task("other")])
        self.assertEqual(set(select_tasks(tasks, ["last"], self.root)), {"first", "last"})
        with self.assertRaisesRegex(ConfigError, "Unknown task"):
            select_tasks(tasks, ["missing"], self.root)

    def test_cycle_unknown_dependency_duplicate(self):
        for items in ([task("a", dependencies=["b"]), task("b", dependencies=["a"])],
                      [task("a", dependencies=["missing"])], [task("a"), task("a")]):
            with self.subTest(items=items), self.assertRaises(ConfigError):
                self.validated(items)

    def test_write_conflict_and_ordered_overlap(self):
        for path in ("out", "out/child"):
            tasks = self.validated([task("a", writes=["out"]), task("b", writes=[path])])
            with self.subTest(path=path), self.assertRaisesRegex(ConfigError, "write conflict"):
                select_tasks(tasks, root=self.root)
            self.assertEqual(list(select_tasks(tasks, ["a"], self.root)), ["a"])
        tasks = self.validated([task("a", writes=["out"]),
                               task("b", dependencies=["a"], writes=["out/child"])])
        self.assertEqual(len(select_tasks(tasks, root=self.root)), 2)

    def test_invalid_manifest_fields(self):
        for field, value in [("command", "echo hello"), ("command", []), ("command", [""]),
                             ("timeout_seconds", 0), ("timeout_seconds", True),
                             ("timeout_seconds", float("nan")), ("writes", ["../escape"]),
                             ("writes", ["."]), ("writes", ["C:\\absolute"]),
                             ("writes", ["/absolute"]), ("writes", ["out/../escape"])]:
            item = task("a")
            item[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ConfigError):
                self.validated([item])
        for version in (True, 1.0, "1"):
            with self.subTest(version=version), self.assertRaises(ConfigError):
                validate_manifest({"version": version, "tasks": [task("a")]}, self.root)

    def test_existing_run_lock_rejected(self):
        lock = self.root / ".harness" / "run.lock"
        lock.mkdir(parents=True)
        with self.assertRaisesRegex(ConfigError, "Another run"):
            execute(self.validated([task("a")]), root=self.root)
        self.assertTrue(lock.exists())

    def test_output_must_stay_under_state_directory(self):
        for path in (self.root, self.root / "source", self.root / ".harness", self.root.parent / "outside",
                     self.root / ".harness" / "run.lock" / "bad"):
            with self.subTest(path=path), self.assertRaisesRegex(ConfigError, "output-dir"):
                execute(self.validated([task("a")]), output_dir=path, root=self.root)

    def test_missing_executable_is_failure(self):
        item = task("missing")
        item["command"] = [str(self.root / "does-not-exist-executable")]
        code, _, summary = self.run_tasks([item])
        self.assertEqual(code, 1)
        self.assertEqual(summary["tasks"]["missing"]["status"], "failed")
        self.assertIn("error", summary["tasks"]["missing"])


if __name__ == "__main__":
    unittest.main()
