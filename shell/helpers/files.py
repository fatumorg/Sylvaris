#!/usr/bin/env python3
import errno
import json
import os
import re
import shutil
import signal
import sys
import time
from urllib.parse import unquote

CHUNK = 1 << 20


class Cancelled(Exception):
    pass


class Job:
    def __init__(self, out):
        self.out = out
        self.total = 0
        self.done = 0
        self.last = 0.0

    def say(self, obj):
        self.out.write(json.dumps(obj) + "\n")
        self.out.flush()

    def tick(self, name, force=False):
        now = time.monotonic()
        if force or now - self.last >= 0.1:
            self.last = now
            self.say({"done": self.done, "total": self.total, "name": name})


def size_of(path):
    if os.path.islink(path):
        return 0
    if not os.path.isdir(path):
        try:
            return os.lstat(path).st_size
        except OSError:
            return 0
    total = 0
    for root, dirs, files in os.walk(path):
        for f in files:
            p = os.path.join(root, f)
            if not os.path.islink(p):
                try:
                    total += os.lstat(p).st_size
                except OSError:
                    pass
    return total


def copy_file(job, src, dst):
    with open(src, "rb") as a, open(dst, "xb") as b:
        while True:
            buf = a.read(CHUNK)
            if not buf:
                break
            b.write(buf)
            job.done += len(buf)
            job.tick(os.path.basename(src))
    shutil.copystat(src, dst)


def copy_any(job, src, dst):
    if os.path.islink(src):
        os.symlink(os.readlink(src), dst)
    elif os.path.isdir(src):
        os.mkdir(dst)
        for name in sorted(os.listdir(src)):
            copy_any(job, os.path.join(src, name), os.path.join(dst, name))
        shutil.copystat(src, dst)
    else:
        copy_file(job, src, dst)


DOUBLE = (".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.lz", ".tar.lzma")


def free_path(path, is_dir):
    if not os.path.lexists(path):
        return path
    folder, name = os.path.split(path)
    stem, ext = name, ""
    if not is_dir:
        low = name.lower()
        double = [d for d in DOUBLE if low.endswith(d) and len(name) > len(d)]
        dot = name.rfind(".")
        if double:
            stem, ext = name[: -len(double[0])], name[-len(double[0]):]
        elif dot > 0:
            stem, ext = name[:dot], name[dot:]
    n = 2
    m = re.match(r"^(.*) \((\d+)\)$", stem)
    if m:
        stem, n = m.group(1), int(m.group(2)) + 1
    while os.path.lexists(os.path.join(folder, "%s (%d)%s" % (stem, n, ext))):
        n += 1
    return os.path.join(folder, "%s (%d)%s" % (stem, n, ext))


def remove_any(path):
    if os.path.islink(path) or not os.path.isdir(path):
        os.unlink(path)
    else:
        shutil.rmtree(path)


def transfer(job, mode, pairs):
    ok = []
    failed = []
    slow = []
    for src, dst in pairs:
        if mode != "rename" and os.path.lexists(src):
            dst = free_path(dst, os.path.isdir(src) and not os.path.islink(src))
        if not os.path.lexists(src):
            failed.append({"path": src, "error": "It is gone"})
        elif os.path.lexists(dst):
            failed.append({"path": src, "error": "Something with that name is already there"})
        elif mode != "copy":
            try:
                os.rename(src, dst)
                ok.append([src, dst])
            except OSError as e:
                if e.errno == errno.EXDEV:
                    slow.append((src, dst))
                else:
                    failed.append({"path": src, "error": e.strerror or str(e)})
        else:
            slow.append((src, dst))
    job.total = sum(size_of(src) for src, _ in slow)
    if slow:
        job.say({"done": 0, "total": job.total, "name": os.path.basename(slow[0][0])})
    cancelled = False
    for src, dst in slow:
        copied = False
        try:
            copy_any(job, src, dst)
            copied = True
            if mode != "copy":
                remove_any(src)
            ok.append([src, dst])
        except Cancelled:
            cancelled = True
            if copied:
                ok.append([src, dst])
            elif os.path.lexists(dst):
                remove_any(dst)
            break
        except OSError as e:
            if copied:
                ok.append([src, dst])
                failed.append({"path": src, "error": "Copied, but the original could not be removed: " + (e.strerror or str(e))})
            else:
                failed.append({"path": src, "error": e.strerror or str(e)})
                if os.path.lexists(dst):
                    remove_any(dst)
    if slow and not cancelled:
        job.tick("", True)
    return {"ok": ok, "failed": failed, "cancelled": cancelled}


def trash_dir():
    data = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(data, "Trash")


def read_info(path):
    found = {"path": "", "date": ""}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith("Path="):
                    found["path"] = unquote(line[5:].strip())
                elif line.startswith("DeletionDate="):
                    found["date"] = line[13:].strip()
    except OSError:
        pass
    return found


def restore(names):
    base = trash_dir()
    ok = []
    failed = []
    for name in names:
        if "/" in name or name in ("", ".", ".."):
            failed.append({"path": name, "error": "Not in the trash"})
            continue
        info_path = os.path.join(base, "info", name + ".trashinfo")
        item = os.path.join(base, "files", name)
        info = read_info(info_path)
        target = info["path"]
        if not os.path.lexists(item) or not target.startswith("/"):
            failed.append({"path": name, "error": "Not in the trash"})
            continue
        if os.path.lexists(target):
            failed.append({"path": name, "error": "Something is already at " + target})
            continue
        try:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            shutil.move(item, target)
            os.unlink(info_path)
            ok.append([name, target])
        except OSError as e:
            failed.append({"path": name, "error": e.strerror or str(e)})
    return {"ok": ok, "failed": failed, "cancelled": False}


def untrash(originals):
    info_dir = os.path.join(trash_dir(), "info")
    newest = {}
    try:
        entries = os.listdir(info_dir)
    except OSError:
        entries = []
    for entry in entries:
        if not entry.endswith(".trashinfo"):
            continue
        info = read_info(os.path.join(info_dir, entry))
        if info["path"] in originals:
            best = newest.get(info["path"])
            if best is None or info["date"] > best[1]:
                newest[info["path"]] = (entry[: -len(".trashinfo")], info["date"])
    names = [newest[p][0] for p in originals if p in newest]
    out = restore(names)
    out["ok"] = [[target, target] for _, target in out["ok"]]
    out["failed"] += [{"path": p, "error": "Not in the trash"} for p in originals if p not in newest]
    return out


def main(argv, out):
    if len(argv) < 2:
        out.write("usage: files.py copy|move|rename SRC DST [SRC DST ...] | restore NAME... | untrash PATH...\n")
        return 2
    verb, args = argv[1], argv[2:]
    job = Job(out)

    def stop(signum, frame):
        raise Cancelled()

    signal.signal(signal.SIGTERM, stop)
    if verb in ("copy", "move", "rename"):
        if len(args) % 2 != 0:
            out.write("copy, move and rename take pairs of paths\n")
            return 2
        result = transfer(job, verb, list(zip(args[0::2], args[1::2])))
    elif verb == "restore":
        result = restore(args)
    elif verb == "untrash":
        result = untrash(args)
    else:
        out.write("unknown verb: " + verb + "\n")
        return 2
    job.say(result)
    return 0 if not result["failed"] and not result["cancelled"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv, sys.stdout))
