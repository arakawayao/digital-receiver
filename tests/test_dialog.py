"""Check the dialog's execution bridge without requiring a desktop display."""

import json
from pathlib import Path
import tempfile
import time
import unittest

from harness.dialog import RunController, read_log
from harness.runner import ConfigError


def task(name, script, dependencies=(), writes=()):
    return {"id": name, "description": name, "depends_on": list(dependencies),
            "command": ["{python}", "-B", "-c", script],
            "writes": list(writes), "timeout_seconds": 20}


class DialogTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        (self.root / "harness").mkdir()
        self.controller = RunController(self.root)
        self.addCleanup(self.finish)

    def finish(self):
        self.controller.cancel()
        if self.controller.thread:
            self.controller.thread.join(15)

    def manifest(self, tasks):
        (self.root / "harness/tasks.json").write_text(
            json.dumps({"version": 1, "tasks": tasks}), encoding="utf-8")

    def wait_for(self, predicate):
        end = time.monotonic() + 10
        while time.monotonic() < end:
            state = self.controller.snapshot()
            if predicate(state):
                return state
            time.sleep(0.02)
        self.fail(f"Timed out: {self.controller.snapshot()}")

    def test_selection_dependencies_failure_and_log(self):
        self.manifest([task("bad", "import sys; print('evidence', flush=True); sys.exit(7)"),
                       task("child", "raise AssertionError('must not run')", ["bad"]),
                       task("other", "print('independent')")])
        chosen = self.controller.start(["child", "other"], 2)
        self.assertEqual(set(chosen), {"bad", "child", "other"})
        state = self.wait_for(lambda state: not state["busy"])
        self.assertIsNone(state["error"])
        self.assertEqual(state["code"], 1)
        self.assertEqual(state["records"]["child"]["status"], "blocked")
        self.assertEqual(state["records"]["other"]["status"], "passed")
        self.assertIn("evidence", read_log(state["run_dir"], state["records"]["bad"]))
        saved = json.loads((Path(state["run_dir"]) / "summary.json").read_text())
        self.assertEqual(saved["tasks"], state["records"])

    def test_cancel_preserves_completed_result_and_releases_lock(self):
        self.manifest([task("done", "print('completed')"),
                       task("slow", "from pathlib import Path; import time; Path('started').touch(); time.sleep(60)", ["done"]),
                       task("child", "raise AssertionError('must not run')", ["slow"])])
        self.controller.start(["child"], 1)
        state = self.wait_for(lambda state: (self.root / "started").exists())
        self.assertEqual(state["records"]["done"]["status"], "passed")
        with self.assertRaises(ConfigError):
            self.controller.start(["done"], 1)
        self.controller.cancel()
        state = self.wait_for(lambda state: not state["busy"])
        self.assertEqual(state["code"], 130)
        self.assertEqual(state["records"]["done"]["status"], "passed")
        self.assertEqual(state["records"]["slow"]["status"], "cancelled")
        self.assertEqual(state["records"]["child"]["status"], "cancelled")
        self.assertFalse((self.root / ".harness/run.lock").exists())
        self.controller.start(["done"], 1)
        state = self.wait_for(lambda state: not state["busy"])
        self.assertEqual(state["code"], 0)

    def test_configuration_errors_and_existing_lock(self):
        self.manifest([task("a", "print('test')")])
        for names, jobs in (([], 1), (["missing"], 1), (["a"], 0), (["a"], True)):
            with self.subTest(names=names, jobs=jobs), self.assertRaises(ConfigError):
                self.controller.start(names, jobs)
        lock = self.root / ".harness/run.lock"
        lock.mkdir(parents=True)
        self.controller.start(["a"], 1)
        state = self.wait_for(lambda state: not state["busy"])
        self.assertIn("Another run", state["error"])
        self.assertTrue(lock.exists())
        self.assertIsNone(state["run_dir"])

    def test_unordered_write_conflict_rejected_before_start(self):
        self.manifest([task("a", "print('a')", writes=["out"]),
                       task("b", "print('b')", writes=["out/child"])])
        with self.assertRaisesRegex(ConfigError, "write conflict"):
            self.controller.start(["a", "b"], 2)
        self.assertFalse(self.controller.snapshot()["busy"])

    def test_log_path_boundary_and_bounded_tail(self):
        run = self.root / "run"
        run.mkdir()
        (run / "a.log").write_bytes(b"prefix" + b"x" * 150000 + b"END")
        text = read_log(run, {"log": "a.log"})
        self.assertTrue(text.endswith("END"))
        self.assertLess(len(text), 132000)
        with self.assertRaises(ValueError):
            read_log(run, {"log": "../outside.log"})


if __name__ == "__main__":
    unittest.main()
