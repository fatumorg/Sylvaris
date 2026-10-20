#!/usr/bin/env python3
import errno
import json
import os
import re
import shutil
import signal
import sys
import subprocess
import time
from urllib.parse import quote, unquote

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


DOUBLE = (".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.lz", ".tar.lzma", ".tar.lz4")


def free_path(path, is_dir, exists=os.path.lexists):
    if not exists(path):
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
    while exists(os.path.join(folder, "%s (%d)%s" % (stem, n, ext))):
        n += 1
    return os.path.join(folder, "%s (%d)%s" % (stem, n, ext))


def remove_any(path):
    if os.path.islink(path) or not os.path.isdir(path):
        os.unlink(path)
    else:
        shutil.rmtree(path)


def is_dir(path):
    return os.path.isdir(path) and not os.path.islink(path)


def facts_of(path):
    try:
        st = os.lstat(path)
    except OSError:
        return {"dir": False, "size": -1, "time": 0, "count": 0}
    folder = is_dir(path)
    count = 0
    if folder:
        try:
            count = len(os.listdir(path))
        except OSError:
            count = -1
    return {"dir": folder, "size": -1 if folder else st.st_size, "time": int(st.st_mtime * 1000), "count": count}


def bad_name(name):
    return not isinstance(name, str) or name.strip() == "" or "/" in name or "\0" in name or name in (".", "..")


class Clashes:
    def __init__(self, job, answers=None, op="copy"):
        self.job = job
        self.answers = answers
        self.op = op
        self.always = {}

    def decide(self, src, dst, origin, incoming=None, kinds=None, existing=None, free=None):
        theirs = incoming if incoming is not None else facts_of(src)
        mine = existing if existing is not None else facts_of(dst)
        both_dirs = theirs["dir"] and mine["dir"]
        kind = "folder" if both_dirs else "file"
        allowed = list(kinds) if kinds is not None else (["merge", "replace", "skip", "both", "rename"] if both_dirs else ["replace", "skip", "both", "rename"])
        if src and (dst.startswith(src.rstrip("/") + "/") or src.startswith(dst.rstrip("/") + "/")) and "replace" in allowed:
            allowed.remove("replace")
        if kind in self.always and self.always[kind] in allowed:
            return {"do": self.always[kind]}
        if self.answers is None:
            return {"do": "both"}
        free = free if free is not None else os.path.basename(free_path(dst, theirs["dir"]))
        ask = {"op": self.op, "name": os.path.basename(dst), "folder": os.path.dirname(dst), "from": origin, "free": free, "actions": allowed, "incoming": theirs, "existing": mine}
        self.job.say({"clash": ask})
        while True:
            line = self.answers.readline()
            if not line:
                raise Cancelled()
            try:
                answer = json.loads(line)
            except ValueError:
                answer = {}
            do = answer.get("do") if isinstance(answer, dict) else None
            if do == "cancel":
                raise Cancelled()
            if do in allowed and (do != "rename" or not bad_name(answer.get("name"))):
                break
            self.job.say({"clash": dict(ask, error="That name cannot be used" if do == "rename" else "Pick one of the choices")})
        if answer.get("all") is True and do != "rename":
            self.always[kind] = do
        return {"do": do, "name": answer.get("name", "")}


class Outcome:
    def __init__(self):
        self.ok = []
        self.failed = []
        self.skipped = []
        self.made = []
        self.moved = []
        self.trashed = []
        self.binned = []
        self.cancelled = False

    def fail(self, path, error):
        self.failed.append({"path": path, "error": error})

    def result(self):
        return {"ok": self.ok, "failed": self.failed, "cancelled": self.cancelled, "skipped": self.skipped, "made": self.made, "moved": self.moved, "trashed": self.trashed, "binned": self.binned}


def trash(path):
    base = trash_dir()
    folder, info_dir = os.path.join(base, "files"), os.path.join(base, "info")
    try:
        os.makedirs(folder, exist_ok=True)
        os.makedirs(info_dir, exist_ok=True)
        same = os.stat(folder).st_dev == os.lstat(path).st_dev
    except OSError:
        same = False
    if same:
        name = os.path.basename(path.rstrip("/")) or "item"
        n = 1
        while True:
            pick = name if n == 1 else "%s.%d" % (name, n)
            info = os.path.join(info_dir, pick + ".trashinfo")
            if not os.path.lexists(os.path.join(folder, pick)):
                try:
                    fd = os.open(info, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                    break
                except FileExistsError:
                    pass
            n += 1
        with os.fdopen(fd, "w") as f:
            f.write("[Trash Info]\nPath=%s\nDeletionDate=%s\n" % (quote(os.path.abspath(path)), time.strftime("%Y-%m-%dT%H:%M:%S")))
        try:
            os.rename(path, os.path.join(folder, pick))
            return pick
        except OSError:
            os.unlink(info)
    try:
        r = subprocess.run(["gio", "trash", "--", path], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    except OSError as e:
        raise OSError(e.errno or errno.EIO, "The old one could not go to the trash")
    if r.returncode != 0 or os.path.lexists(path):
        raise OSError(errno.EIO, "The old one could not go to the trash")
    return ""


def bin_into(out, path):
    out.binned.append(trash(path))
    out.trashed.append(path)


def same_device(src, dst):
    try:
        return os.lstat(src).st_dev == os.stat(os.path.dirname(dst) or "/").st_dev
    except OSError:
        return False


def copy_any_safe(job, src, dst):
    try:
        copy_any(job, src, dst)
    except BaseException:
        if os.path.lexists(dst):
            remove_any(dst)
        raise


def build(job, mode, src, dst):
    if mode == "move":
        try:
            os.rename(src, dst)
            return False
        except OSError as e:
            if e.errno != errno.EXDEV:
                raise
    copy_any_safe(job, src, dst)
    return mode == "move"


def land(job, mode, src, dst, out, replacing):
    if not replacing:
        if build(job, mode, src, dst):
            try:
                remove_any(src)
            except OSError as e:
                out.fail(src, "Copied, but the original could not be removed: " + (e.strerror or str(e)))
        return
    if mode == "move" and same_device(src, dst):
        bin_into(out, dst)
        os.rename(src, dst)
        return
    tmp = os.path.join(os.path.dirname(dst), ".syl-%d-%s" % (os.getpid(), os.path.basename(dst)))
    copy_any_safe(job, src, tmp)
    try:
        bin_into(out, dst)
    except OSError:
        remove_any(tmp)
        raise
    os.rename(tmp, dst)
    if mode == "move":
        try:
            remove_any(src)
        except OSError as e:
            out.fail(src, "Copied, but the original could not be removed: " + (e.strerror or str(e)))


def same_item(a, b):
    if os.path.realpath(a) == os.path.realpath(b):
        return True
    try:
        return os.path.samefile(a, b)
    except OSError:
        return False


def put(job, clashes, mode, src, dst, out, origin):
    if not os.path.lexists(src):
        out.fail(src, "It is gone")
        return None
    replacing = False
    if os.path.lexists(dst):
        if same_item(src, dst):
            if mode != "copy":
                out.fail(src, "It is already there")
                return None
            dst = free_path(dst, is_dir(src))
        else:
            answer = clashes.decide(src, dst, origin)
            do = answer["do"]
            if do == "skip":
                out.skipped.append(src)
                return None
            if do == "both":
                return put(job, clashes, mode, src, free_path(dst, is_dir(src)), out, origin)
            if do == "rename":
                return put(job, clashes, mode, src, os.path.join(os.path.dirname(dst), answer["name"]), out, origin)
            if do == "merge":
                for name in sorted(os.listdir(src)):
                    put(job, clashes, mode, os.path.join(src, name), os.path.join(dst, name), out, origin)
                if mode == "move":
                    try:
                        os.rmdir(src)
                    except OSError:
                        pass
                return dst
            replacing = True
    try:
        land(job, mode, src, dst, out, replacing)
    except Cancelled:
        raise
    except OSError as e:
        out.fail(src, e.strerror or str(e))
        return None
    if mode == "copy":
        out.made.append(dst)
    else:
        out.moved.append([src, dst])
    return dst


def cost(mode, src, dst):
    if mode == "move" and same_device(src, dst):
        return 0
    return size_of(src)


def settle(path, limit=300.0):
    folder = os.path.dirname(path)
    end = time.monotonic() + limit
    while not os.path.lexists(path) and time.monotonic() < end:
        try:
            busy = any(n.startswith(".sylfiles-") for n in os.listdir(folder))
        except OSError:
            busy = False
        if not busy:
            break
        time.sleep(0.1)


def transfer(job, mode, pairs, answers=None):
    out = Outcome()
    if mode == "rename":
        for src, dst in pairs:
            if not os.path.lexists(src):
                out.fail(src, "It is gone")
            elif os.path.lexists(dst) and not same_item(src, dst):
                out.fail(src, "Something with that name is already there")
            else:
                try:
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    os.rename(src, dst)
                    out.ok.append([src, dst])
                    out.moved.append([src, dst])
                except OSError as e:
                    out.fail(src, e.strerror or str(e))
        return out.result()
    for src, _ in pairs:
        settle(src)
    clashes = Clashes(job, answers, mode)
    job.total = sum(cost(mode, src, dst) for src, dst in pairs if os.path.lexists(src))
    if job.total > 0:
        job.say({"done": 0, "total": job.total, "name": os.path.basename(pairs[0][0])})
    try:
        for src, dst in pairs:
            final = put(job, clashes, mode, src, dst, out, os.path.dirname(src))
            if final is not None:
                out.ok.append([src, final])
    except Cancelled:
        out.cancelled = True
    if job.total > 0 and not out.cancelled:
        job.tick("", True)
    return out.result()


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


def restore(names, answers=None, job=None):
    base = trash_dir()
    out = Outcome()
    clashes = Clashes(job, answers, "restore")
    try:
        for name in names:
            if "/" in name or name in ("", ".", ".."):
                out.fail(name, "Not in the trash")
                continue
            info_path = os.path.join(base, "info", name + ".trashinfo")
            item = os.path.join(base, "files", name)
            info = read_info(info_path)
            target = info["path"]
            if not os.path.lexists(item) or not target.startswith("/"):
                out.fail(name, "Not in the trash")
                continue
            try:
                os.makedirs(os.path.dirname(target), exist_ok=True)
            except OSError as e:
                out.fail(name, e.strerror or str(e))
                continue
            before = len(out.failed)
            final = put(job, clashes, "move", item, target, out, "")
            for f in out.failed[before:]:
                if f["path"] == item:
                    f["path"] = name
            out.skipped = [name if p == item else p for p in out.skipped]
            if final is None:
                continue
            if not os.path.lexists(item):
                os.unlink(info_path)
            out.ok.append([name, final])
    except Cancelled:
        out.cancelled = True
    return out.result()


def untrash(originals, answers=None, job=None):
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
    out = restore(names, answers, job)
    out["ok"] = [[target, target] for _, target in out["ok"]]
    out["failed"] += [{"path": p, "error": "Not in the trash"} for p in originals if p not in newest]
    return out


def main(argv, out, stdin=sys.stdin):
    args = argv[1:]
    answers = None
    if args[:1] == ["--clashes"]:
        answers = stdin
        args = args[1:]
    if not args:
        out.write("usage: files.py [--clashes] copy|move|rename SRC DST [SRC DST ...] | restore NAME... | untrash PATH...\n")
        return 2
    verb, args = args[0], args[1:]
    job = Job(out)

    def stop(signum, frame):
        raise Cancelled()

    signal.signal(signal.SIGTERM, stop)
    if verb in ("copy", "move", "rename"):
        if len(args) % 2 != 0:
            out.write("copy, move and rename take pairs of paths\n")
            return 2
        result = transfer(job, verb, list(zip(args[0::2], args[1::2])), answers)
    elif verb == "restore":
        result = restore(args, answers, job)
    elif verb == "untrash":
        result = untrash(args, answers, job)
    else:
        out.write("unknown verb: " + verb + "\n")
        return 2
    job.say(result)
    return 0 if not result["failed"] and not result["cancelled"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv, sys.stdout))
