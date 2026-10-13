import errno
import importlib.util
import io
import json
import os
import tempfile
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location("files", os.path.join(os.path.dirname(__file__), "..", "shell", "helpers", "files.py"))
files = importlib.util.module_from_spec(spec)
spec.loader.exec_module(files)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def read(path):
    with open(path) as f:
        return f.read()


def run(*argv):
    out = io.StringIO()
    code = files.main(["files.py"] + list(argv), out)
    lines = [json.loads(line) for line in out.getvalue().splitlines() if line.startswith("{")]
    return code, lines


class TransferTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def p(self, *parts):
        return os.path.join(self.dir, *parts)

    def test_copies_files_and_trees_with_links_and_reports_progress(self):
        write(self.p("src", "a.txt"), "hello")
        write(self.p("src", "tree", "deep", "b.txt"), "x" * 3000)
        os.symlink("deep/b.txt", self.p("src", "tree", "link"))
        os.utime(self.p("src", "a.txt"), (1000000000, 1000000000))
        code, lines = run("copy", self.p("src", "a.txt"), self.p("a copy.txt"), self.p("src", "tree"), self.p("tree2"))
        self.assertEqual(code, 0)
        self.assertEqual(read(self.p("a copy.txt")), "hello")
        self.assertEqual(os.stat(self.p("a copy.txt")).st_mtime, 1000000000)
        self.assertEqual(read(self.p("tree2", "deep", "b.txt")), "x" * 3000)
        self.assertEqual(os.readlink(self.p("tree2", "link")), "deep/b.txt")
        self.assertEqual(lines[0], {"done": 0, "total": 3005, "name": "a.txt"})
        self.assertEqual(lines[-2]["done"], 3005)
        self.assertEqual(lines[-1], {"ok": [self.p("a copy.txt"), self.p("tree2")], "failed": [], "cancelled": False})
        self.assertTrue(os.path.exists(self.p("src", "a.txt")))

    def test_never_overwrites_and_reports_missing_sources(self):
        write(self.p("a"), "new")
        write(self.p("b"), "old")
        code, lines = run("copy", self.p("a"), self.p("b"), self.p("gone"), self.p("c"))
        self.assertEqual(code, 1)
        self.assertEqual(read(self.p("b")), "old")
        self.assertEqual([f["error"] for f in lines[-1]["failed"]], ["Something with that name is already there", "It is gone"])
        code, lines = run("move", self.p("a"), self.p("b"))
        self.assertEqual(read(self.p("b")), "old")
        self.assertTrue(os.path.exists(self.p("a")))

    def test_moves_by_renaming_and_falls_back_to_copying_across_devices(self):
        write(self.p("a"), "1")
        code, lines = run("move", self.p("a"), self.p("b"))
        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(self.p("a")))
        self.assertEqual(lines, [{"ok": [self.p("b")], "failed": [], "cancelled": False}])
        write(self.p("d", "x"), "22")
        real = os.rename

        def cross(src, dst):
            if src == self.p("d"):
                raise OSError(errno.EXDEV, "Invalid cross-device link")
            return real(src, dst)

        with mock.patch.object(files.os, "rename", cross):
            code, lines = run("move", self.p("d"), self.p("e"))
        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(self.p("d")))
        self.assertEqual(read(self.p("e", "x")), "22")
        self.assertEqual(lines[-1]["ok"], [self.p("e")])

    def test_cancelling_removes_the_half_copied_item_and_keeps_the_source(self):
        write(self.p("big"), "y" * (files.CHUNK * 3))
        real = files.Job.tick
        fired = []

        def stop(job, name, force=False):
            if job.done >= files.CHUNK and not fired:
                fired.append(name)
                raise files.Cancelled()
            return real(job, name, force)

        with mock.patch.object(files.Job, "tick", stop):
            code, lines = run("copy", self.p("big"), self.p("half"))
        self.assertEqual(code, 1)
        self.assertEqual(lines[-1], {"ok": [], "failed": [], "cancelled": True})
        self.assertFalse(os.path.exists(self.p("half")))
        self.assertEqual(os.path.getsize(self.p("big")), files.CHUNK * 3)

    def test_rejects_odd_arguments_and_unknown_verbs(self):
        self.assertEqual(run("copy", "/a")[0], 2)
        self.assertEqual(run("explode")[0], 2)
        self.assertEqual(run()[0], 2)


class TrashTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.env = mock.patch.dict(os.environ, {"XDG_DATA_HOME": os.path.join(self.dir, "data")})
        self.env.start()
        self.trash = os.path.join(self.dir, "data", "Trash")

    def tearDown(self):
        self.env.stop()

    def trashed(self, name, original, date, text="t"):
        write(os.path.join(self.trash, "files", name), text)
        write(os.path.join(self.trash, "info", name + ".trashinfo"), "[Trash Info]\nPath=" + original.replace(" ", "%20") + "\nDeletionDate=" + date + "\n")

    def test_restore_puts_items_back_and_refuses_to_overwrite(self):
        target = os.path.join(self.dir, "home", "a b.txt")
        self.trashed("a b.txt", target, "2026-10-13T10:00:00")
        self.trashed("x", os.path.join(self.dir, "home", "x"), "2026-10-13T10:00:00")
        write(os.path.join(self.dir, "home", "x"), "here")
        code, lines = run("restore", "a b.txt", "x", "../etc", "missing")
        self.assertEqual(code, 1)
        self.assertEqual(read(target), "t")
        self.assertFalse(os.path.exists(os.path.join(self.trash, "info", "a b.txt.trashinfo")))
        self.assertEqual(lines[-1]["ok"], [target])
        self.assertEqual([f["path"] for f in lines[-1]["failed"]], ["x", "../etc", "missing"])
        self.assertEqual(read(os.path.join(self.dir, "home", "x")), "here")

    def test_untrash_restores_the_newest_copy_of_each_original(self):
        target = os.path.join(self.dir, "home", "n.txt")
        self.trashed("n.txt", target, "2026-10-12T10:00:00", "old")
        self.trashed("n.2.txt", target, "2026-10-13T10:00:00", "new")
        code, lines = run("untrash", target, os.path.join(self.dir, "never"))
        self.assertEqual(read(target), "new")
        self.assertTrue(os.path.exists(os.path.join(self.trash, "files", "n.txt")))
        self.assertEqual(lines[-1]["ok"], [target])
        self.assertEqual(lines[-1]["failed"], [{"path": os.path.join(self.dir, "never"), "error": "Not in the trash"}])


if __name__ == "__main__":
    unittest.main()
