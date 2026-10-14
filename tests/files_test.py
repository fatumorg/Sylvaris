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


def ask(answers, *argv):
    out = io.StringIO()
    code = files.main(["files.py", "--clashes"] + list(argv), out, io.StringIO("".join(json.dumps(a) + "\n" for a in answers)))
    lines = [json.loads(line) for line in out.getvalue().splitlines() if line.startswith("{")]
    return code, lines, [line["clash"] for line in lines if "clash" in line]


def plain(result):
    return {k: result[k] for k in ("ok", "failed", "cancelled")}


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
        self.assertEqual(plain(lines[-1]), {"ok": [[self.p("src", "a.txt"), self.p("a copy.txt")], [self.p("src", "tree"), self.p("tree2")]], "failed": [], "cancelled": False})
        self.assertEqual(lines[-1]["made"], [self.p("a copy.txt"), self.p("tree2")])
        self.assertTrue(os.path.exists(self.p("src", "a.txt")))

    def test_never_overwrites_picks_free_names_and_reports_missing_sources(self):
        write(self.p("a"), "new")
        write(self.p("b.tar.gz"), "old")
        write(self.p("b (2).tar.gz"), "old2")
        os.makedirs(self.p("D"))
        code, lines = run("copy", self.p("a"), self.p("b.tar.gz"), self.p("gone"), self.p("c"), self.p("D"), self.p("D"))
        self.assertEqual(code, 1)
        self.assertEqual(read(self.p("b.tar.gz")), "old")
        self.assertEqual(read(self.p("b (3).tar.gz")), "new")
        self.assertTrue(os.path.isdir(self.p("D (2)")))
        self.assertEqual(lines[-1]["ok"], [[self.p("a"), self.p("b (3).tar.gz")], [self.p("D"), self.p("D (2)")]])
        self.assertEqual([f["error"] for f in lines[-1]["failed"]], ["It is gone"])
        code, lines = run("rename", self.p("a"), self.p("b.tar.gz"))
        self.assertEqual(code, 1)
        self.assertEqual(read(self.p("b.tar.gz")), "old")
        self.assertEqual(lines[-1]["failed"], [{"path": self.p("a"), "error": "Something with that name is already there"}])
        code, lines = run("rename", self.p("a"), self.p("z"))
        self.assertEqual(lines[-1]["ok"], [[self.p("a"), self.p("z")]])

    def test_moves_by_renaming_and_falls_back_to_copying_across_devices(self):
        write(self.p("a"), "1")
        code, lines = run("move", self.p("a"), self.p("b"))
        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(self.p("a")))
        self.assertEqual([plain(line) for line in lines], [{"ok": [[self.p("a"), self.p("b")]], "failed": [], "cancelled": False}])
        self.assertEqual(lines[-1]["moved"], [[self.p("a"), self.p("b")]])
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
        self.assertEqual(lines[-1]["ok"], [[self.p("d"), self.p("e")]])

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
        self.assertEqual(plain(lines[-1]), {"ok": [], "failed": [], "cancelled": True})
        self.assertFalse(os.path.exists(self.p("half")))
        self.assertEqual(os.path.getsize(self.p("big")), files.CHUNK * 3)

    def test_renaming_only_the_case_works_where_names_ignore_case(self):
        write(self.p("a.txt"), "a")
        real = files.os.path.lexists

        def folded(path):
            return real(path) or real(os.path.join(os.path.dirname(path), os.path.basename(path).lower()))

        def same(a, b):
            return a.lower() == b.lower()

        with mock.patch.object(files.os.path, "lexists", folded), mock.patch.object(files, "same_item", same):
            code, lines = run("rename", self.p("a.txt"), self.p("A.txt"))
        self.assertEqual(code, 0)
        self.assertEqual(os.listdir(self.dir), ["A.txt"])

    def test_rejects_odd_arguments_and_unknown_verbs(self):
        self.assertEqual(run("copy", "/a")[0], 2)
        self.assertEqual(run("explode")[0], 2)
        self.assertEqual(run()[0], 2)


class ClashTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.env = mock.patch.dict(os.environ, {"XDG_DATA_HOME": os.path.join(self.dir, "data")})
        self.env.start()

    def tearDown(self):
        self.env.stop()

    def p(self, *parts):
        return os.path.join(self.dir, *parts)

    def trash_text(self, name):
        return read(self.p("data", "Trash", "files", name))

    def test_asks_with_both_sides_and_replaces_into_the_trash(self):
        write(self.p("in", "a.txt"), "new text")
        write(self.p("to", "a.txt"), "old")
        os.utime(self.p("to", "a.txt"), (1000000000, 1000000000))
        code, lines, asked = ask([{"do": "replace"}], "copy", self.p("in", "a.txt"), self.p("to", "a.txt"))
        self.assertEqual(code, 0)
        self.assertEqual(asked, [{"op": "copy", "name": "a.txt", "folder": self.p("to"), "from": self.p("in"), "free": "a (2).txt", "actions": ["replace", "skip", "both", "rename"],
                                  "incoming": {"dir": False, "size": 8, "time": asked[0]["incoming"]["time"], "count": 0}, "existing": {"dir": False, "size": 3, "time": 1000000000000, "count": 0}}])
        self.assertEqual(read(self.p("to", "a.txt")), "new text")
        self.assertEqual(self.trash_text("a.txt"), "old")
        info = read(self.p("data", "Trash", "info", "a.txt.trashinfo"))
        self.assertIn("Path=" + self.p("to", "a.txt").replace(" ", "%20") + "\n", info)
        self.assertEqual(lines[-1]["trashed"], [self.p("to", "a.txt")])
        self.assertEqual(lines[-1]["binned"], ["a.txt"])
        self.assertEqual(lines[-1]["made"], [self.p("to", "a.txt")])
        write(self.p("in", "a.txt"), "third")
        code, lines, asked = ask([{"do": "replace"}], "copy", self.p("in", "a.txt"), self.p("to", "a.txt"))
        self.assertEqual(lines[-1]["binned"], ["a.txt.2"])
        self.assertEqual(self.trash_text("a.txt.2"), "new text")
        self.assertEqual(os.listdir(self.p("to")), ["a.txt"])

    def test_skip_keep_both_rename_and_asking_again_for_a_taken_name(self):
        for n in ("a", "b", "c"):
            write(self.p("in", n), "new " + n)
            write(self.p("to", n), "old " + n)
        answers = [{"do": "skip"}, {"do": "both"}, {"do": "rename", "name": "../x"}, {"do": "rename", "name": "b"}, {"do": "rename", "name": "c2"}]
        code, lines, asked = ask(answers, "copy", self.p("in", "a"), self.p("to", "a"), self.p("in", "b"), self.p("to", "b"), self.p("in", "c"), self.p("to", "c"))
        self.assertEqual(code, 0)
        self.assertEqual([a["name"] for a in asked], ["a", "b", "c", "c", "b"])
        self.assertEqual(asked[3]["error"], "That name cannot be used")
        self.assertEqual(sorted(os.listdir(self.p("to"))), ["a", "b", "b (2)", "c", "c2"])
        self.assertEqual(read(self.p("to", "a")), "old a")
        self.assertEqual(read(self.p("to", "b (2)")), "new b")
        self.assertEqual(read(self.p("to", "c2")), "new c")
        self.assertEqual(lines[-1]["skipped"], [self.p("in", "a")])
        self.assertEqual(lines[-1]["ok"], [[self.p("in", "b"), self.p("to", "b (2)")], [self.p("in", "c"), self.p("to", "c2")]])

    def test_merges_folders_asking_inside_and_remembering_do_the_same(self):
        write(self.p("in", "D", "same.txt"), "new")
        write(self.p("in", "D", "other.txt"), "new other")
        write(self.p("in", "D", "fresh.txt"), "fresh")
        write(self.p("in", "D", "sub", "deep.txt"), "deep new")
        write(self.p("to", "D", "same.txt"), "old")
        write(self.p("to", "D", "other.txt"), "old other")
        write(self.p("to", "D", "sub", "deep.txt"), "deep old")
        write(self.p("to", "D", "keep.txt"), "keep")
        answers = [{"do": "merge", "all": True}, {"do": "skip", "all": True}]
        code, lines, asked = ask(answers, "move", self.p("in", "D"), self.p("to", "D"))
        self.assertEqual(code, 0)
        self.assertEqual([(a["name"], a["actions"][0]) for a in asked], [("D", "merge"), ("other.txt", "replace")])
        self.assertEqual(asked[0]["incoming"]["count"], 4)
        self.assertEqual(asked[0]["existing"]["count"], 4)
        self.assertEqual(read(self.p("to", "D", "same.txt")), "old")
        self.assertEqual(read(self.p("to", "D", "sub", "deep.txt")), "deep old")
        self.assertEqual(read(self.p("to", "D", "fresh.txt")), "fresh")
        self.assertEqual(read(self.p("to", "D", "keep.txt")), "keep")
        self.assertEqual(lines[-1]["moved"], [[self.p("in", "D", "fresh.txt"), self.p("to", "D", "fresh.txt")]])
        self.assertEqual(lines[-1]["ok"], [[self.p("in", "D"), self.p("to", "D")]])
        self.assertTrue(os.path.exists(self.p("in", "D", "same.txt")))

    def test_a_move_merge_removes_the_emptied_source(self):
        write(self.p("in", "D", "n.txt"), "n")
        write(self.p("to", "D", "o.txt"), "o")
        code, lines, asked = ask([{"do": "merge"}], "move", self.p("in", "D"), self.p("to", "D"))
        self.assertEqual(code, 0)
        self.assertFalse(os.path.exists(self.p("in", "D")))
        self.assertEqual(sorted(os.listdir(self.p("to", "D"))), ["n.txt", "o.txt"])

    def test_replacing_a_folder_with_a_file_and_cancelling(self):
        write(self.p("in", "D"), "now a file")
        write(self.p("to", "D", "x"), "x")
        write(self.p("in", "E"), "e")
        write(self.p("to", "E"), "old e")
        code, lines, asked = ask([{"do": "replace"}, {"do": "cancel"}], "copy", self.p("in", "D"), self.p("to", "D"), self.p("in", "E"), self.p("to", "E"))
        self.assertEqual(code, 1)
        self.assertEqual(asked[0]["actions"], ["replace", "skip", "both", "rename"])
        self.assertEqual(read(self.p("to", "D")), "now a file")
        self.assertEqual(self.trash_text(os.path.join("D", "x")), "x")
        self.assertEqual(read(self.p("to", "E")), "old e")
        self.assertTrue(lines[-1]["cancelled"])
        self.assertEqual(lines[-1]["ok"], [[self.p("in", "D"), self.p("to", "D")]])

    def test_no_answer_cancels_and_duplicates_never_ask(self):
        write(self.p("a.txt"), "a")
        code, lines, asked = ask([], "copy", self.p("a.txt"), self.p("a.txt"))
        self.assertEqual(asked, [])
        self.assertEqual(read(self.p("a (2).txt")), "a")
        write(self.p("in", "b"), "b")
        write(self.p("b"), "old")
        code, lines, asked = ask([], "copy", self.p("in", "b"), self.p("b"))
        self.assertEqual(len(asked), 1)
        self.assertTrue(lines[-1]["cancelled"])
        self.assertEqual(read(self.p("b")), "old")

    def test_never_offers_replacing_a_folder_that_holds_the_source(self):
        write(self.p("D", "sub", "D", "f"), "f")
        code, lines, asked = ask([{"do": "replace"}, {"do": "skip"}], "copy", self.p("D", "sub", "D"), self.p("D"))
        self.assertEqual(asked[0]["actions"], ["merge", "skip", "both", "rename"])
        self.assertEqual(asked[1]["error"], "Pick one of the choices")
        self.assertTrue(os.path.exists(self.p("D", "sub", "D", "f")))

    def test_waits_for_an_archive_still_unpacking_the_dragged_file(self):
        drag = self.p("cache", "drag-1")
        os.makedirs(os.path.join(drag, ".sylfiles-x"))
        real = files.time.sleep
        calls = []

        def later(t):
            calls.append(t)
            if len(calls) == 3:
                write(os.path.join(drag, "f.txt"), "ready")
                os.rmdir(os.path.join(drag, ".sylfiles-x"))
            real(0)

        with mock.patch.object(files.time, "sleep", later):
            code, lines = run("copy", os.path.join(drag, "f.txt"), self.p("f.txt"))
        self.assertEqual(code, 0)
        self.assertEqual(read(self.p("f.txt")), "ready")
        code, lines = run("copy", os.path.join(drag, "never.txt"), self.p("never.txt"))
        self.assertEqual(lines[-1]["failed"][0]["error"], "It is gone")


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

    def test_restore_puts_items_back_and_never_overwrites_silently(self):
        target = os.path.join(self.dir, "home", "a b.txt")
        self.trashed("a b.txt", target, "2026-10-13T10:00:00")
        self.trashed("x", os.path.join(self.dir, "home", "x"), "2026-10-13T10:00:00")
        write(os.path.join(self.dir, "home", "x"), "here")
        code, lines = run("restore", "a b.txt", "x", "../etc", "missing")
        self.assertEqual(code, 1)
        self.assertEqual(read(target), "t")
        self.assertFalse(os.path.exists(os.path.join(self.trash, "info", "a b.txt.trashinfo")))
        self.assertEqual(lines[-1]["ok"], [["a b.txt", target], ["x", os.path.join(self.dir, "home", "x (2)")]])
        self.assertEqual([f["path"] for f in lines[-1]["failed"]], ["../etc", "missing"])
        self.assertEqual(read(os.path.join(self.dir, "home", "x")), "here")

    def test_restore_asks_when_something_took_the_place(self):
        home = os.path.join(self.dir, "home")
        self.trashed("x", os.path.join(home, "x"), "2026-10-13T10:00:00", "old")
        self.trashed("y", os.path.join(home, "y"), "2026-10-13T10:00:00", "old y")
        write(os.path.join(home, "x"), "now")
        write(os.path.join(home, "y"), "now y")
        code, lines, asked = ask([{"do": "replace"}, {"do": "skip"}], "restore", "x", "y")
        self.assertEqual([a["op"] for a in asked], ["restore", "restore"])
        self.assertEqual(read(os.path.join(home, "x")), "old")
        self.assertEqual(read(os.path.join(home, "y")), "now y")
        self.assertEqual(lines[-1]["skipped"], ["y"])
        self.assertEqual(lines[-1]["trashed"], [os.path.join(home, "x")])
        self.assertTrue(os.path.exists(os.path.join(self.trash, "info", "y.trashinfo")))
        self.assertFalse(os.path.exists(os.path.join(self.trash, "info", "x.trashinfo")))

    def test_untrash_restores_the_newest_copy_of_each_original(self):
        target = os.path.join(self.dir, "home", "n.txt")
        self.trashed("n.txt", target, "2026-10-12T10:00:00", "old")
        self.trashed("n.2.txt", target, "2026-10-13T10:00:00", "new")
        code, lines = run("untrash", target, os.path.join(self.dir, "never"))
        self.assertEqual(read(target), "new")
        self.assertTrue(os.path.exists(os.path.join(self.trash, "files", "n.txt")))
        self.assertEqual(lines[-1]["ok"], [[target, target]])
        self.assertEqual(lines[-1]["failed"], [{"path": os.path.join(self.dir, "never"), "error": "Not in the trash"}])


if __name__ == "__main__":
    unittest.main()
