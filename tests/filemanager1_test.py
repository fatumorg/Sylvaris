import importlib.util
import os
import unittest

spec = importlib.util.spec_from_file_location("filemanager1", os.path.join(os.path.dirname(__file__), "..", "shell", "helpers", "filemanager1.py"))
fm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fm)


class Commands(unittest.TestCase):
    def test_each_uri_opens_once(self):
        self.assertEqual(fm.commands("/bin/sylvaris", "ShowItems", ["file:///home/u/Downloads/a%20b.pdf", "file:///tmp/x"]),
                         [["/bin/sylvaris", "files", "open", "file:///home/u/Downloads/a%20b.pdf"], ["/bin/sylvaris", "files", "open", "file:///tmp/x"]])

    def test_all_three_methods_open(self):
        for m in ("ShowFolders", "ShowItems", "ShowItemProperties"):
            self.assertEqual(fm.commands("s", m, ["file:///tmp"]), [["s", "files", "open", "file:///tmp"]])

    def test_empty_and_unknown(self):
        self.assertEqual(fm.commands("s", "ShowItems", []), [])
        self.assertEqual(fm.commands("s", "ShowItems", [""]), [])
        self.assertEqual(fm.commands("s", "Quit", ["file:///tmp"]), [])


if __name__ == "__main__":
    unittest.main()
