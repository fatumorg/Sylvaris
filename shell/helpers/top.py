#!/usr/bin/env python3
import glob
import json
import os
import pwd
import re
import select
import shutil
import signal
import subprocess
import sys
import time

HZ = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
SIGNALS = {"term": signal.SIGTERM, "kill": signal.SIGKILL, "stop": signal.SIGSTOP, "cont": signal.SIGCONT}
IO_CLASSES = {"realtime": "1", "best-effort": "2", "idle": "3"}
DISK = re.compile(r"^(sd[a-z]+|vd[a-z]+|xvd[a-z]+|hd[a-z]+|nvme\d+n\d+|mmcblk\d+)$")
USERS = {}
NAMES = {}


def read(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8", "replace")
    except OSError:
        return ""


def user(uid):
    if uid not in USERS:
        try:
            USERS[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            USERS[uid] = str(uid)
    return USERS[uid]


def cpu_times(root):
    out = {}
    for line in read(root + "/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        parts = line.split()
        nums = [int(x) for x in parts[1:9]]
        idle = nums[3] + nums[4]
        out[parts[0]] = (sum(nums) - idle, sum(nums))
    return out


def memory(root):
    info = {}
    for line in read(root + "/proc/meminfo").splitlines():
        key, _, rest = line.partition(":")
        info[key] = int(rest.split()[0]) * 1024 if rest.split() else 0
    total = info.get("MemTotal", 0)
    available = info.get("MemAvailable", info.get("MemFree", 0))
    return {"total": total, "used": total - available, "available": available, "swapTotal": info.get("SwapTotal", 0), "swapUsed": info.get("SwapTotal", 0) - info.get("SwapFree", 0)}


def disks(root):
    read_b = write_b = 0
    for line in read(root + "/proc/diskstats").splitlines():
        f = line.split()
        if len(f) >= 10 and DISK.match(f[2]):
            read_b += int(f[5]) * 512
            write_b += int(f[9]) * 512
    return {"read": read_b, "write": write_b}


def nets(root):
    rx = tx = 0
    for line in read(root + "/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        f = rest.split()
        if name.strip() != "lo" and len(f) >= 9:
            rx += int(f[0])
            tx += int(f[8])
    return {"rx": rx, "tx": tx}


def number(path):
    text = read(path).strip()
    return int(text) if text.isdigit() else 0


def gpus(root):
    out = []
    for card in sorted(glob.glob(root + "/sys/class/drm/card*/device/gpu_busy_percent")):
        dev = os.path.dirname(card)
        if read(card).strip().isdigit():
            out.append({"name": os.path.basename(os.path.dirname(dev)), "busy": number(card), "memUsed": number(dev + "/mem_info_vram_used"), "memTotal": number(dev + "/mem_info_vram_total")})
    if root == "" and shutil.which("nvidia-smi"):
        try:
            lines = subprocess.run(["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=2).stdout.splitlines()
            for line in lines:
                name, busy, used, total = (x.strip() for x in line.split(","))
                out.append({"name": name, "busy": int(busy), "memUsed": int(used) * 1048576, "memTotal": int(total) * 1048576})
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
    return out


def processes(root):
    out = {}
    for name in os.listdir(root + "/proc"):
        if not name.isdigit():
            continue
        pid = int(name)
        stat = read(f"{root}/proc/{pid}/stat")
        head, sep, tail = stat.rpartition(")")
        if not sep:
            continue
        f = tail.split()
        if len(f) < 22:
            continue
        key = (pid, f[19])
        if key not in NAMES:
            cmd = read(f"{root}/proc/{pid}/cmdline").replace("\0", " ").strip()[:240]
            try:
                owner = user(os.stat(f"{root}/proc/{pid}").st_uid)
            except OSError:
                continue
            NAMES[key] = (head.partition("(")[2], cmd, owner)
        comm, cmd, owner = NAMES[key]
        out[pid] = {"pid": pid, "ppid": int(f[1]), "name": comm, "cmd": cmd or "[" + comm + "]", "user": owner, "state": f[0], "ticks": int(f[11]) + int(f[12]), "nice": int(f[16]), "threads": int(f[17]), "mem": int(f[21]) * PAGE, "start": f[19]}
    for key in [k for k in NAMES if k[0] not in out or out[k[0]]["start"] != k[1]]:
        del NAMES[key]
    return out


def snapshot(root, now=None):
    return {"t": time.monotonic() if now is None else now, "cpu": cpu_times(root), "mem": memory(root), "disk": disks(root), "net": nets(root), "gpus": gpus(root), "procs": processes(root)}


def percent(a, b):
    busy, total = b[0] - a[0], b[1] - a[1]
    return round(100.0 * busy / total, 1) if total > 0 else 0.0


def sample(a, b):
    dt = max(1e-3, b["t"] - a["t"])
    cores = sorted((k for k in b["cpu"] if k != "cpu"), key=lambda k: int(k[3:]))
    procs = []
    for pid, p in b["procs"].items():
        before = a["procs"].get(pid)
        ticks = p["ticks"] - before["ticks"] if before is not None and before["start"] == p["start"] else 0
        row = {k: v for k, v in p.items() if k not in ("ticks", "start")}
        row["cpu"] = round(max(0, ticks) / HZ / dt * 100, 1)
        procs.append(row)
    return {
        "event": "sample",
        "cpu": {"total": percent(a["cpu"].get("cpu", (0, 0)), b["cpu"].get("cpu", (0, 0))), "cores": [percent(a["cpu"].get(k, (0, 0)), b["cpu"][k]) for k in cores]},
        "mem": b["mem"],
        "disk": {k: max(0.0, (b["disk"][k] - a["disk"][k]) / dt) for k in ("read", "write")},
        "net": {k: max(0.0, (b["net"][k] - a["net"][k]) / dt) for k in ("rx", "tx")},
        "gpus": b["gpus"],
        "procs": procs,
    }


def pid_of(msg):
    pid = msg.get("pid")
    if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 1:
        raise ValueError("pick a process")
    return pid


def command(msg):
    cmd = msg.get("cmd")
    if cmd == "interval":
        seconds = msg.get("seconds")
        if not isinstance(seconds, (int, float)) or isinstance(seconds, bool):
            raise ValueError("interval needs seconds")
        return {"interval": float(min(5, max(0.5, seconds)))}
    if cmd == "signal":
        if msg.get("sig") not in SIGNALS:
            raise ValueError("signal is one of " + ", ".join(SIGNALS))
        os.kill(pid_of(msg), SIGNALS[msg["sig"]])
        return {}
    if cmd == "renice":
        nice = msg.get("nice")
        if not isinstance(nice, int) or isinstance(nice, bool) or not -20 <= nice <= 19:
            raise ValueError("nice is -20 to 19")
        os.setpriority(os.PRIO_PROCESS, pid_of(msg), nice)
        return {}
    if cmd == "ionice":
        level = msg.get("level", 4)
        if msg.get("class") not in IO_CLASSES or not isinstance(level, int) or not 0 <= level <= 7:
            raise ValueError("ionice class is realtime, best-effort or idle, level 0 to 7")
        args = ["ionice", "-c", IO_CLASSES[msg["class"]]] + ([] if msg["class"] == "idle" else ["-n", str(level)]) + ["-p", str(pid_of(msg))]
        done = subprocess.run(args, capture_output=True, text=True)
        if done.returncode != 0:
            raise OSError(done.stderr.strip() or "ionice failed")
        return {}
    if cmd == "affinity":
        cpus = msg.get("cpus")
        if not isinstance(cpus, list) or not cpus or not all(isinstance(c, int) and 0 <= c < os.cpu_count() for c in cpus):
            raise ValueError("pick at least one processor")
        os.sched_setaffinity(pid_of(msg), cpus)
        return {}
    raise ValueError("unknown command")


def files(root, pid):
    out = []
    base = f"{root}/proc/{pid}/fd"
    try:
        names = sorted(os.listdir(base), key=int)
    except OSError:
        return out
    for name in names:
        try:
            out.append({"fd": int(name), "target": os.readlink(base + "/" + name)})
        except OSError:
            pass
    return out


def answer(root, line):
    try:
        msg = json.loads(line)
        if not isinstance(msg, dict):
            raise ValueError("commands are JSON objects")
        if msg.get("cmd") == "files":
            return {"event": "files", "pid": pid_of(msg), "files": files(root, msg["pid"])}
        if msg.get("cmd") == "detail":
            pid = pid_of(msg)
            return {"event": "detail", "pid": pid, "affinity": sorted(os.sched_getaffinity(pid)), "cores": os.cpu_count()}
        return dict({"event": "done", "cmd": msg.get("cmd")}, **command(msg))
    except (ValueError, OSError) as e:
        return {"event": "error", "message": str(e)}


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def main():
    interval = 2.0
    prev = snapshot("")
    wait = 0.3
    while True:
        ready, _, _ = select.select([sys.stdin], [], [], wait)
        if ready:
            line = sys.stdin.readline()
            if not line:
                return 0
            reply = answer("", line)
            interval = reply.get("interval", interval)
            emit(reply)
            continue
        cur = snapshot("")
        emit(sample(prev, cur))
        prev = cur
        wait = interval


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    sys.exit(main())
