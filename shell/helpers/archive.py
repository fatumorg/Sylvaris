#!/usr/bin/env python3
import calendar
import json
import os
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from files import Cancelled, Job, free_path, size_of

ENV = dict(os.environ, LC_ALL="C.UTF-8")
TARRED = (".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.lz", ".tar.lzma", ".tar.lz4", ".tar.z", ".tgz", ".tbz", ".tbz2", ".txz", ".tzst", ".tlz", ".taz")
SINGLE = (".gz", ".bz2", ".xz", ".zst", ".lz", ".lzma", ".lz4", ".z")
OTHER = (".zip", ".jar", ".war", ".apk", ".xpi", ".7z", ".rar", ".tar", ".cpio", ".iso", ".cab", ".deb", ".rpm", ".ar", ".xar", ".pkg", ".lha", ".lzh", ".warc")
MONTHS = {m: i for i, m in enumerate(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 1)}
LINE = re.compile(rb"^([-dlbcpsh?][rwxsStT-]{9})[+.@]?\s+\d+\s+\S+\s+\S+\s+(\d+)\s+([A-Z][a-z]{2})\s+(\d{1,2})\s+(\d{1,2}:\d{2}|\d{4})\s(.*)$")
PROMPT = b"Enter passphrase:"
ESCAPES = {"a": 7, "b": 8, "f": 12, "n": 10, "r": 13, "t": 9, "v": 11, "\\": 92}
QUIET = ("Error exit delayed from previous errors", "Enter passphrase:")


class Work(Job):
    def __init__(self, out):
        Job.__init__(self, out)
        self.child = None
        self.reader = None
        self.temps = []
        self.secret = None

    def clean(self):
        if self.child is not None and self.child.poll() is None:
            try:
                os.killpg(self.child.pid, signal.SIGTERM)
            except OSError:
                pass
            self.child.wait()
        if self.reader is not None:
            self.reader.join(1)
        if self.child is not None:
            for pipe in (self.child.stdin, self.child.stdout, self.child.stderr):
                if pipe is not None and not pipe.closed:
                    pipe.close()
        for t in self.temps:
            if os.path.isdir(t) and not os.path.islink(t):
                shutil.rmtree(t, ignore_errors=True)
            elif os.path.lexists(t):
                os.unlink(t)
        self.temps = []


def stem_of(name):
    low = name.lower()
    for ext in TARRED + OTHER + SINGLE:
        if low.endswith(ext) and len(name) > len(ext):
            return name[: -len(ext)]
    return name


def single(path):
    low = path.lower()
    return low.endswith(SINGLE) and not low.endswith(TARRED)


def unescape(raw):
    out = bytearray()
    i = 0
    while i < len(raw):
        c = raw[i]
        if c == 92 and i + 1 < len(raw):
            n = chr(raw[i + 1])
            octal = raw[i + 1: i + 4]
            if len(octal) == 3 and all(48 <= b <= 55 for b in octal):
                out.append(int(octal.decode(), 8) & 255)
                i += 4
                continue
            if n in ESCAPES:
                out.append(ESCAPES[n])
                i += 2
                continue
        out.append(c)
        i += 1
    return out.decode("utf-8", "replace")


def when(month, day, clock, now):
    year = time.gmtime(now).tm_year
    hour, minute = 0, 0
    if ":" in clock:
        hour, minute = int(clock.split(":")[0]), int(clock.split(":")[1])
    else:
        year = int(clock)
    stamp = calendar.timegm((year, MONTHS.get(month, 1), int(day), hour, minute, 0))
    if ":" in clock and stamp > now + 86400:
        stamp = calendar.timegm((year - 1, MONTHS.get(month, 1), int(day), hour, minute, 0))
    return stamp * 1000 - time.localtime(stamp).tm_gmtoff * 1000


def parse(line, now):
    m = LINE.match(line)
    if m is None:
        return None
    mode, size, month, day, clock = (g.decode("ascii") for g in m.groups()[:5])
    name = unescape(m.group(6))
    link = ""
    if mode[0] == "l" and " -> " in name:
        name, link = name.split(" -> ", 1)
    elif mode[0] != "d" and " link to " in name:
        name, link = name.split(" link to ", 1)
    return {"path": name, "dir": mode[0] == "d" or name.endswith("/"), "size": int(size), "mtime": when(month, day, clock, now), "link": link}


def pattern(path):
    return re.sub(r"([\\*?\[])", r"\\\1", path)


def position(pid, target):
    folder = "/proc/%d/fd" % pid
    try:
        fds = os.listdir(folder)
    except OSError:
        return -1
    for fd in fds:
        try:
            if os.readlink(os.path.join(folder, fd)) != target:
                continue
            with open("/proc/%d/fdinfo/%s" % (pid, fd)) as f:
                for line in f:
                    if line.startswith("pos:"):
                        return int(line.split()[1])
        except (OSError, ValueError):
            continue
    return -1


def run(job, args, watch=None, on_line=None, out=None):
    p = subprocess.Popen(args, stdin=subprocess.PIPE if job.secret is not None else subprocess.DEVNULL, stdout=subprocess.PIPE if out is not None else subprocess.DEVNULL, stderr=subprocess.PIPE, env=ENV, start_new_session=True)
    job.child = p
    if job.secret is not None:
        try:
            p.stdin.write((job.secret + "\n").encode("utf-8"))
            p.stdin.close()
        except OSError:
            pass
    tail = []

    def handle(line):
        if on_line is not None and line.startswith(b"a "):
            on_line(unescape(line[2:]))
            return
        text = line.decode("utf-8", "replace").strip()
        if text and text not in QUIET:
            tail.append(text)
            del tail[:-40]

    def drain():
        buf = b""
        prompts = 0
        while True:
            chunk = p.stderr.read1(65536)
            if not chunk:
                break
            buf += chunk
            if PROMPT in buf:
                prompts += buf.count(PROMPT)
                buf = buf.replace(PROMPT, b"")
                if prompts > (0 if job.secret is None else 1) and p.poll() is None:
                    tail.append("passphrase needed")
                    try:
                        os.killpg(p.pid, signal.SIGTERM)
                    except OSError:
                        pass
            *lines, buf = buf.split(b"\n")
            for line in lines:
                handle(line)
        if buf:
            handle(buf)

    reader = threading.Thread(target=drain, daemon=True)
    job.reader = reader
    reader.start()
    if out is not None:
        for line in iter(p.stdout.readline, b""):
            out(line.rstrip(b"\n"))
    while p.poll() is None:
        if watch is not None:
            watch(p.pid)
        time.sleep(0.1)
    reader.join()
    p.stderr.close()
    if p.stdout is not None:
        p.stdout.close()
    job.child = None
    job.reader = None
    return p.returncode, tail


def problem(lines, fallback):
    for line in reversed(lines):
        text = re.sub(r"^bsdtar: ", "", line.strip())
        if text and text not in QUIET:
            return text.rstrip(".")
    return fallback


def locked(lines):
    return any("passphrase" in line.lower() or "encrypted" in line.lower() for line in lines)


def password_state(job, lines):
    if not locked(lines):
        return ""
    return "wrong" if job.secret else "needed"


def result(**extra):
    out = {"ok": [], "failed": [], "cancelled": False, "password": ""}
    out.update(extra)
    return out


def unrecognized(lines):
    return any("Unrecognized archive format" in line for line in lines)


def listing(job, archive):
    now = time.time()
    entries = []
    code, lines = run(job, ["bsdtar", "-tvf", archive], out=lambda b: entries.append(parse(b, now)))
    entries = [e for e in entries if e is not None]
    if code != 0 and single(archive) and unrecognized(lines):
        name = stem_of(os.path.basename(archive))
        return result(entries=[{"path": name, "dir": False, "size": 0, "mtime": int(os.stat(archive).st_mtime * 1000), "link": ""}])
    pw = password_state(job, lines)
    if code != 0 and (pw or not entries):
        return result(entries=[], password=pw, failed=[] if pw else [{"path": archive, "error": problem(lines, "This archive cannot be read")}])
    return result(entries=entries)


def umask():
    mask = os.umask(0)
    os.umask(mask)
    return mask


def place(tmp, dest, mode, stem):
    tops = sorted(os.listdir(tmp))
    made = []
    if mode == "into" or (mode == "smart" and len(tops) == 1):
        for top in tops:
            src = os.path.join(tmp, top)
            dst = free_path(os.path.join(dest, top), os.path.isdir(src) and not os.path.islink(src))
            os.rename(src, dst)
            made.append(dst)
        os.rmdir(tmp)
    else:
        dst = free_path(os.path.join(dest, stem or "Extracted"), True)
        os.rename(tmp, dst)
        os.chmod(dst, 0o777 & ~umask())
        made.append(dst)
    return made


def extract(job, archive, dest, mode, strip, names):
    archive = os.path.abspath(archive)
    stem = stem_of(os.path.basename(archive))
    try:
        os.makedirs(dest, exist_ok=True)
    except OSError as e:
        return result(failed=[{"path": archive, "error": e.strerror or str(e)}])
    tmp = tempfile.mkdtemp(prefix=".sylfiles-", dir=dest)
    job.temps.append(tmp)
    job.total = os.path.getsize(archive)
    target = os.path.realpath(archive)
    job.say({"done": 0, "total": job.total, "name": os.path.basename(archive)})

    def watch(pid):
        pos = position(pid, target)
        if pos > job.done:
            job.done = min(pos, job.total)
            job.tick(os.path.basename(archive))

    args = ["bsdtar", "-x", "-f", archive, "-C", tmp]
    if strip > 0:
        args += ["--strip-components", str(strip)]
    code, lines = run(job, args + [pattern(n) for n in names], watch=watch)
    if code != 0 and single(archive) and unrecognized(lines) and not os.listdir(tmp):
        with open(os.path.join(tmp, stem or "data"), "wb") as f:
            p = subprocess.Popen(["bsdcat", archive], stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.PIPE, env=ENV, start_new_session=True)
            job.child = p
            while p.poll() is None:
                watch(p.pid)
                time.sleep(0.1)
            lines = p.stderr.read().decode("utf-8", "replace").splitlines()
            p.stderr.close()
            code = p.returncode
            job.child = None
        if code != 0:
            return result(failed=[{"path": archive, "error": problem(lines, "This file cannot be unpacked")}])
    pw = password_state(job, lines)
    if code != 0 and (pw or not os.listdir(tmp)):
        return result(password=pw, failed=[] if pw else [{"path": archive, "error": problem(lines, "This archive cannot be read")}])
    failed = [] if code == 0 else [{"path": archive, "error": problem(lines, "Some files could not be extracted")}]
    if not os.listdir(tmp):
        return result(failed=[{"path": archive, "error": "Nothing to extract"}])
    made = place(tmp, dest, mode, stem)
    job.temps.remove(tmp)
    job.done = job.total
    job.tick("", True)
    return result(ok=[[archive, m] for m in made], failed=failed)


def level_option(name, level):
    low = name.lower()
    if level == "normal" or low.endswith(".tar"):
        return []
    if level == "fast":
        return ["--options", "compression-level=1"]
    return ["--options", "compression-level=" + ("19" if low.endswith((".zst", ".tzst")) else "9")]


def sizes(base, names):
    found = {}
    for name in names:
        top = os.path.join(base, name)
        if os.path.isdir(top) and not os.path.islink(top):
            for root, dirs, files in os.walk(top):
                for f in files:
                    p = os.path.join(root, f)
                    try:
                        found[os.path.relpath(p, base)] = 0 if os.path.islink(p) else os.lstat(p).st_size
                    except OSError:
                        pass
        else:
            found[name] = size_of(top)
    return found


def compress(job, out, level, base, names):
    final = free_path(os.path.abspath(out), False)
    folder, name = os.path.split(final)
    tmp = os.path.join(folder, ".syl-%d-%s" % (os.getpid(), name))
    job.temps.append(tmp)
    known = sizes(base, names)
    job.total = sum(known.values())
    job.say({"done": 0, "total": job.total, "name": name})

    def added(path):
        job.done += known.get(path.rstrip("/"), 0)
        job.tick(os.path.basename(path))

    code, lines = run(job, ["bsdtar", "-a", "-c", "-v", "-f", tmp] + level_option(name, level) + ["-C", base, "--"] + names, on_line=added)
    if code != 0:
        return result(failed=[{"path": final, "error": problem(lines, "The archive could not be made")}])
    os.rename(tmp, final)
    job.temps.remove(tmp)
    job.done = job.total
    job.tick("", True)
    return result(ok=[["", final]])


def taken_in(job, archive, inner):
    found = listing(job, archive)
    prefix = inner + "/" if inner else ""
    names = set()
    for e in found.get("entries", []):
        path = re.sub(r"^(\./|/)+", "", e["path"]).rstrip("/")
        if path.startswith(prefix) and path != inner:
            names.add(path[len(prefix):].split("/")[0])
    return found, names


def rebuild(job, archive, extra):
    folder, name = os.path.split(archive)
    tmp = os.path.join(folder, ".syl-%d-%s" % (os.getpid(), name))
    job.temps.append(tmp)
    job.total = os.path.getsize(archive)
    target = os.path.realpath(archive)

    def watch(pid):
        pos = position(pid, target)
        if pos > job.done:
            job.done = min(pos, job.total)
            job.tick(name)

    code, lines = run(job, ["bsdtar", "-a", "-c", "-f", tmp] + extra(archive), watch=watch)
    if code != 0:
        return False, lines
    os.chmod(tmp, stat.S_IMODE(os.stat(archive).st_mode))
    os.replace(tmp, archive)
    job.temps.remove(tmp)
    return True, lines


def bre(text):
    return re.sub(r"([\\.\[\]*^$])", r"\\\1", text)


def add(job, archive, inner, sources):
    archive = os.path.abspath(archive)
    found, names = taken_in(job, archive, inner)
    if found["password"] or found["failed"]:
        return result(failed=[{"path": archive, "error": "Archives with a password cannot be changed" if found["password"] else found["failed"][0]["error"]}])
    part = os.path.join(os.path.dirname(archive), ".syl-%d-part.tar" % os.getpid())
    job.temps.append(part)
    pairs = []
    for i, src in enumerate(sources):
        src = os.path.abspath(src)
        if not os.path.lexists(src):
            continue
        parent, base = os.path.split(src.rstrip("/"))
        free = os.path.basename(free_path(os.path.join("/", base), os.path.isdir(src) and not os.path.islink(src), exists=lambda p: os.path.basename(p) in names))
        names.add(free)
        dest = (inner + "/" if inner else "") + free
        rule = "\x01^%s\x01%s\x01" % (bre(base), dest.replace("\\", "\\\\").replace("&", "\\&"))
        code, lines = run(job, ["bsdtar", "-c" if not pairs else "-r", "-f", part, "-C", parent, "-s", rule, "--", base])
        if code != 0:
            return result(failed=[{"path": src, "error": problem(lines, "It could not be added")}])
        pairs.append([src, archive + "/" + dest])
    if not pairs:
        return result(failed=[{"path": archive, "error": "Nothing to add"}])
    done, lines = rebuild(job, archive, lambda a: ["@" + a, "@" + part])
    if not done:
        return result(failed=[{"path": archive, "error": problem(lines, "The archive could not be changed")}])
    job.tick("", True)
    return result(ok=pairs)


def remove(job, archive, paths):
    archive = os.path.abspath(archive)
    rules = []
    for p in paths:
        rules += ["--exclude", pattern(p)]
    done, lines = rebuild(job, archive, lambda a: rules + ["@" + a])
    if not done:
        if locked(lines):
            return result(failed=[{"path": archive, "error": "Archives with a password cannot be changed"}])
        return result(failed=[{"path": archive, "error": problem(lines, "The archive could not be changed")}])
    job.tick("", True)
    return result(ok=[[archive + "/" + p, ""] for p in paths])


USAGE = "usage: archive.py [--ask] list ARCHIVE | extract ARCHIVE DEST smart|folder|into STRIP [NAME...] | compress OUT fast|normal|best BASE NAME... | add ARCHIVE INNER SRC... | remove ARCHIVE PATH...\n"


def main(argv, out, stdin=sys.stdin):
    args = argv[1:]
    job = Work(out)
    if args[:1] == ["--ask"]:
        job.secret = stdin.readline().rstrip("\n")
        args = args[1:]
    if not args:
        out.write(USAGE)
        return 2
    verb, rest = args[0], args[1:]

    def stop(signum, frame):
        raise Cancelled()

    signal.signal(signal.SIGTERM, stop)
    try:
        if verb == "list" and len(rest) == 1:
            outcome = listing(job, rest[0])
        elif verb == "extract" and len(rest) >= 4 and rest[2] in ("smart", "folder", "into") and rest[3].isdigit():
            outcome = extract(job, rest[0], rest[1], rest[2], int(rest[3]), rest[4:])
        elif verb == "compress" and len(rest) >= 4 and rest[1] in ("fast", "normal", "best"):
            outcome = compress(job, rest[0], rest[1], rest[2], rest[3:])
        elif verb == "add" and len(rest) >= 3:
            outcome = add(job, rest[0], rest[1].strip("/"), rest[2:])
        elif verb == "remove" and len(rest) >= 2:
            outcome = remove(job, rest[0], rest[1:])
        else:
            out.write(USAGE)
            return 2
    except Cancelled:
        outcome = result(cancelled=True)
    except OSError as e:
        outcome = result(failed=[{"path": rest[0] if rest else "", "error": e.strerror or str(e)}])
    finally:
        job.secret = None
        job.clean()
    job.say(outcome)
    return 0 if not outcome["failed"] and not outcome["cancelled"] and not outcome["password"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv, sys.stdout))
