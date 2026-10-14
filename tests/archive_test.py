import gzip
import importlib.util
import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile
from unittest import mock

HELPERS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shell", "helpers")
sys.path.insert(0, HELPERS)
spec = importlib.util.spec_from_file_location("archive", os.path.join(HELPERS, "archive.py"))
archive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive)

ODD = ["żółw ✓.md", "back\\slash.txt", "new\nline.txt", "tab\tx.txt", "arrow -> x.txt", "big[1]*?.txt"]


def run(*argv, secret=None):
    out = io.StringIO()
    args = ["archive.py"] + (["--ask"] if secret is not None else []) + list(argv)
    code = archive.main(args, out, io.StringIO((secret or "") + "\n"))
    lines = [json.loads(line) for line in out.getvalue().splitlines() if line.startswith("{")]
    return code, lines


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def read(path):
    with open(path) as f:
        return f.read()


@unittest.skipUnless(shutil.which("bsdtar") and shutil.which("bsdcat"), "needs bsdtar from libarchive")
class ArchiveTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        os.makedirs(self.p("out"))

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def p(self, *parts):
        return os.path.join(self.dir, *parts)

    def leftovers(self, folder):
        return [n for n in os.listdir(folder) if n.startswith(".syl")]

    def zip_of(self, name, files):
        with zipfile.ZipFile(self.p(name), "w") as z:
            for path, text in files.items():
                z.writestr(path, text)
        return self.p(name)

    def test_lists_odd_names_folders_links_and_sizes(self):
        src = self.p("src")
        for n in ODD:
            write(os.path.join(src, "dir one", n), "abc")
        os.symlink("żółw ✓.md", os.path.join(src, "dir one", "link"))
        tar = self.p("odd.tar.gz")
        with tarfile.open(tar, "w:gz") as t:
            t.add(src, ".", recursive=True)
        code, lines = run("list", tar)
        self.assertEqual(code, 0)
        entries = {e["path"].lstrip("./").rstrip("/"): e for e in lines[-1]["entries"]}
        for n in ODD:
            self.assertIn("dir one/" + n, entries)
            self.assertEqual(entries["dir one/" + n]["size"], 3)
            self.assertFalse(entries["dir one/" + n]["dir"])
        self.assertEqual(entries["dir one/link"]["link"], "żółw ✓.md")
        self.assertTrue(entries["dir one"]["dir"])
        self.assertGreater(entries["dir one/" + ODD[0]]["mtime"], 1500000000000)

    def test_lists_zip_7z_and_single_gzip_files(self):
        z = self.zip_of("a.zip", {"x/y.txt": "hello", "z.txt": "!"})
        code, lines = run("list", z)
        self.assertEqual(sorted(e["path"] for e in lines[-1]["entries"]), ["x/y.txt", "z.txt"])
        seven = self.p("a.7z")
        subprocess.run(["bsdtar", "-a", "-cf", seven, "-C", self.dir, "a.zip"], check=True)
        code, lines = run("list", seven)
        self.assertEqual([e["path"] for e in lines[-1]["entries"]], ["a.zip"])
        with gzip.open(self.p("notes.txt.gz"), "wb") as f:
            f.write(b"plain")
        code, lines = run("list", self.p("notes.txt.gz"))
        self.assertEqual(code, 0)
        self.assertEqual([e["path"] for e in lines[-1]["entries"]], ["notes.txt"])

    def test_broken_archives_say_why(self):
        write(self.p("bad.zip"), "not a zip at all")
        code, lines = run("list", self.p("bad.zip"))
        self.assertEqual(code, 1)
        self.assertEqual(lines[-1]["entries"], [])
        self.assertTrue(lines[-1]["failed"][0]["error"])

    def test_smart_extraction_keeps_a_single_folder_and_wraps_loose_files(self):
        one = self.zip_of("project.zip", {"project/a.txt": "a", "project/b/c.txt": "c"})
        code, lines = run("extract", one, self.p("out"), "smart", "0")
        self.assertEqual(code, 0)
        self.assertEqual(lines[-1]["ok"], [[one, self.p("out", "project")]])
        self.assertEqual(read(self.p("out", "project", "b", "c.txt")), "c")
        loose = self.zip_of("loose.zip", {"a.txt": "a", "b.txt": "b"})
        code, lines = run("extract", loose, self.p("out"), "smart", "0")
        self.assertEqual(lines[-1]["ok"], [[loose, self.p("out", "loose")]])
        self.assertEqual(stat.S_IMODE(os.stat(self.p("out", "loose")).st_mode) & 0o055, 0o055 & ~archive.umask())
        code, lines = run("extract", one, self.p("out"), "smart", "0")
        self.assertEqual(lines[-1]["ok"], [[one, self.p("out", "project (2)")]])
        code, lines = run("extract", one, self.p("out"), "folder", "0")
        self.assertEqual(lines[-1]["ok"], [[one, self.p("out", "project (3)")]])
        self.assertTrue(os.path.isfile(self.p("out", "project (3)", "project", "a.txt")))
        self.assertEqual(self.leftovers(self.p("out")), [])
        self.assertTrue(any("total" in line for line in lines[:-1]))

    def test_extracts_chosen_items_without_their_parent_folders(self):
        z = self.zip_of("deep.zip", {"top/sub/a[1].txt": "a", "top/sub/b.txt": "b", "top/sub/c/d.txt": "d", "top/other.txt": "o"})
        write(self.p("out", "b.txt"), "mine")
        code, lines = run("extract", z, self.p("out"), "into", "2", "top/sub/a[1].txt", "top/sub/b.txt", "top/sub/c")
        self.assertEqual(code, 0)
        self.assertEqual(sorted(os.listdir(self.p("out"))), ["a[1].txt", "b (2).txt", "b.txt", "c"])
        self.assertEqual(read(self.p("out", "b.txt")), "mine")
        self.assertEqual(read(self.p("out", "c", "d.txt")), "d")

    def test_unpacks_a_single_compressed_file(self):
        with gzip.open(self.p("notes.txt.gz"), "wb") as f:
            f.write(b"plain text")
        code, lines = run("extract", self.p("notes.txt.gz"), self.p("out"), "smart", "0")
        self.assertEqual(code, 0)
        self.assertEqual(read(self.p("out", "notes.txt")), "plain text")

    def test_password_archives_ask_and_never_leave_files_behind(self):
        src = self.p("secret")
        write(os.path.join(src, "s.txt"), "classified")
        enc = self.p("enc.zip")
        subprocess.run(["bsdtar", "-a", "-cf", enc, "--options", "zip:encryption=aes256", "--passphrase", "open sesame", "-C", src, "s.txt"], check=True, env=dict(os.environ, LC_ALL="C.UTF-8"))
        code, lines = run("extract", enc, self.p("out"), "smart", "0")
        self.assertEqual((code, lines[-1]["password"], lines[-1]["failed"]), (1, "needed", []))
        code, lines = run("extract", enc, self.p("out"), "smart", "0", secret="wrong")
        self.assertEqual(lines[-1]["password"], "wrong")
        self.assertEqual(os.listdir(self.p("out")), [])
        code, lines = run("extract", enc, self.p("out"), "smart", "0", secret="open sesame")
        self.assertEqual(code, 0)
        self.assertEqual(read(self.p("out", "s.txt")), "classified")

    def test_compresses_with_levels_free_names_and_progress(self):
        write(self.p("src", "folder", "a.txt"), "a" * 5000)
        write(self.p("src", "b.txt"), "b")
        write(self.p("out", "pack.zip"), "taken")
        code, lines = run("compress", self.p("out", "pack.zip"), "best", self.p("src"), "folder", "b.txt")
        self.assertEqual(code, 0)
        self.assertEqual(lines[-1]["ok"], [["", self.p("out", "pack (2).zip")]])
        self.assertEqual(lines[0], {"done": 0, "total": 5001, "name": "pack (2).zip"})
        self.assertEqual(lines[-2]["done"], 5001)
        with zipfile.ZipFile(self.p("out", "pack (2).zip")) as z:
            self.assertEqual(sorted(z.namelist()), ["b.txt", "folder/", "folder/a.txt"])
        for name in ("pack.tar.zst", "pack.7z", "pack.tar"):
            code, lines = run("compress", self.p("out", name), "fast", self.p("src"), "folder")
            self.assertEqual(code, 0, name)
            code, lines = run("list", self.p("out", name))
            self.assertIn("folder/a.txt", [e["path"] for e in lines[-1]["entries"]])
        self.assertEqual(self.leftovers(self.p("out")), [])

    def test_adds_into_a_folder_with_free_names_and_keeps_the_rest(self):
        z = self.zip_of("box.zip", {"docs/a.txt": "a", "top.txt": "t"})
        os.chmod(z, 0o640)
        write(self.p("new", "a.txt"), "new a")
        write(self.p("new", "pics", "p.png"), "p")
        code, lines = run("add", z, "docs", self.p("new", "a.txt"), self.p("new", "pics"))
        self.assertEqual(code, 0)
        self.assertEqual(lines[-1]["ok"], [[self.p("new", "a.txt"), z + "/docs/a (2).txt"], [self.p("new", "pics"), z + "/docs/pics"]])
        with zipfile.ZipFile(z) as f:
            names = f.namelist()
            self.assertEqual(f.read("docs/a (2).txt"), b"new a")
            self.assertEqual(f.read("docs/a.txt"), b"a")
        self.assertIn("docs/pics/p.png", names)
        self.assertIn("top.txt", names)
        self.assertEqual(stat.S_IMODE(os.stat(z).st_mode), 0o640)
        self.assertEqual(self.leftovers(self.dir), [])

    def test_removes_files_and_folders(self):
        z = self.zip_of("box.zip", {"docs/a.txt": "a", "docs/b[1].txt": "b", "keep.txt": "k", "gone/x.txt": "x"})
        code, lines = run("remove", z, "docs/b[1].txt", "gone")
        self.assertEqual(code, 0)
        with zipfile.ZipFile(z) as f:
            self.assertEqual(sorted(n for n in f.namelist() if not n.endswith("/")), ["docs/a.txt", "keep.txt"])

    def test_stopping_cleans_up_the_half_made_folder(self):
        z = self.zip_of("big.zip", {"a/%d.txt" % i: "x" * 1000 for i in range(50)})

        def stop(pid, target):
            raise archive.Cancelled()

        with mock.patch.object(archive, "position", stop):
            code, lines = run("extract", z, self.p("out"), "smart", "0")
        self.assertEqual(lines[-1]["cancelled"], True)
        self.assertEqual(os.listdir(self.p("out")), [])

    def test_usage_errors(self):
        self.assertEqual(run()[0], 2)
        self.assertEqual(run("extract", "a.zip", "/tmp", "sideways", "0")[0], 2)
        self.assertEqual(run("compress", "a.zip", "max", "/tmp", "x")[0], 2)


class PieceTest(unittest.TestCase):
    def test_unescape_reads_what_bsdtar_prints(self):
        self.assertEqual(archive.unescape(b"a\\\\b\\nc\\td\\303\\263"), "a\\b\nc\tdó")
        self.assertEqual(archive.unescape("żółw".encode()), "żółw")

    def test_pattern_and_stem(self):
        self.assertEqual(archive.pattern("a[1]*?.txt"), "a\\[1]\\*\\?.txt")
        self.assertEqual(archive.stem_of("x.tar.gz"), "x")
        self.assertEqual(archive.stem_of("notes.txt.gz"), "notes.txt")
        self.assertTrue(archive.single("a.txt.gz"))
        self.assertFalse(archive.single("a.tar.gz"))
        self.assertEqual(archive.level_option("a.tar", "best"), [])
        self.assertEqual(archive.level_option("a.tar.zst", "best"), ["--options", "compression-level=19"])
        self.assertEqual(archive.level_option("a.zip", "fast"), ["--options", "compression-level=1"])


if __name__ == "__main__":
    unittest.main()
