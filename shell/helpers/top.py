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
import threading
import time

HZ = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
SIGNALS = {"term": signal.SIGTERM, "kill": signal.SIGKILL, "stop": signal.SIGSTOP, "cont": signal.SIGCONT}
IO_CLASSES = {"realtime": "1", "best-effort": "2", "idle": "3"}
UNIT = re.compile(r"^[A-Za-z0-9][A-Za-z0-9@:._\\-]*\.service$")
DESKTOP = re.compile(r"^[A-Za-z0-9@:._+\-]+\.desktop$")
VERBS = {"user": ["start", "stop", "restart", "enable", "disable"], "system": ["start", "stop", "restart"]}
LOCK = threading.Lock()
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


def entry(path):
    out = {}
    group = ""
    for line in read(path).splitlines():
        line = line.strip()
        if line.startswith("["):
            group = line
        elif group == "[Desktop Entry]" and "=" in line and not line.startswith("#"):
            key, _, value = line.partition("=")
            out.setdefault(key.strip(), value.strip())
    return out


def autostart_dirs(home, config_dirs):
    return home + "/autostart", [d + "/autostart" for d in config_dirs]


def autostart(user_dir, system_dirs, desktops=()):
    files = {}
    for d in list(reversed(system_dirs)) + [user_dir]:
        try:
            for name in os.listdir(d):
                if DESKTOP.match(name):
                    files[name] = d + "/" + name
        except OSError:
            pass
    out = []
    for name, path in sorted(files.items()):
        e = entry(path)
        only = [x for x in e.get("OnlyShowIn", "").split(";") if x]
        if e.get("Type", "Application") != "Application" or only and not set(only) & set(desktops) or set(x for x in e.get("NotShowIn", "").split(";") if x) & set(desktops):
            continue
        on = e.get("Hidden", "false").lower() != "true" and e.get("X-GNOME-Autostart-enabled", "true").lower() != "false"
        out.append({"file": name, "name": e.get("Name", name[:-8]), "exec": e.get("Exec", ""), "icon": e.get("Icon", ""), "on": on, "mine": path.startswith(user_dir + "/")})
    return out


def set_autostart(user_dir, system_dirs, name, on):
    if not DESKTOP.match(name or ""):
        raise ValueError("pick an autostart entry")
    path = user_dir + "/" + name
    source = path if os.path.exists(path) else next((d + "/" + name for d in system_dirs if os.path.exists(d + "/" + name)), None)
    if source is None:
        raise ValueError("no autostart entry called " + name)
    lines = read(source).splitlines()
    out = []
    group = ""
    placed = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("["):
            if group == "[Desktop Entry]" and not placed:
                out.append("Hidden=" + ("false" if on else "true"))
                placed = True
            group = stripped
        if group == "[Desktop Entry]" and re.match(r"^(Hidden|X-GNOME-Autostart-enabled)\s*=", stripped):
            continue
        out.append(line)
    if not placed:
        out.append("Hidden=" + ("false" if on else "true"))
    os.makedirs(user_dir, exist_ok=True)
    with open(path + ".part", "w") as f:
        f.write("\n".join(out) + "\n")
    os.replace(path + ".part", path)


def systemctl_json(args):
    try:
        done = subprocess.run(["systemctl"] + args + ["--output=json", "--no-pager"], capture_output=True, text=True, timeout=10)
        return json.loads(done.stdout or "[]")
    except (OSError, ValueError, subprocess.SubprocessError):
        return []


def services():
    out = {}
    for scope in ("system", "user"):
        rows = systemctl_json((["--user"] if scope == "user" else []) + ["list-units", "--type=service", "--all"])
        out[scope] = [{"unit": r.get("unit", ""), "active": r.get("active", ""), "sub": r.get("sub", ""), "description": r.get("description", "")} for r in rows if r.get("load") == "loaded"]
    return out


def user_units():
    rows = systemctl_json(["--user", "list-unit-files", "--type=service"])
    return [{"unit": r.get("unit_file", ""), "on": r.get("state") == "enabled"} for r in rows if r.get("state") in ("enabled", "disabled") and not r.get("unit_file", "").endswith("@.service")]


def sessions():
    out = []
    try:
        ids = [line.split()[0] for line in subprocess.run(["loginctl", "list-sessions", "--no-legend", "--no-pager"], capture_output=True, text=True, timeout=5).stdout.splitlines() if line.split()]
        for sid in ids:
            info = dict(line.partition("=")[::2] for line in subprocess.run(["loginctl", "show-session", sid, "-p", "Id", "-p", "Name", "-p", "Seat", "-p", "TTY", "-p", "Class", "-p", "Type", "-p", "State", "-p", "Remote", "-p", "Active"], capture_output=True, text=True, timeout=5).stdout.splitlines())
            out.append({"id": info.get("Id", sid), "user": info.get("Name", ""), "seat": info.get("Seat", ""), "tty": info.get("TTY", ""), "class": info.get("Class", ""), "type": info.get("Type", ""), "state": info.get("State", ""), "remote": info.get("Remote") == "yes", "active": info.get("Active") == "yes"})
    except (OSError, subprocess.SubprocessError):
        pass
    return out


def unit_args(msg):
    scope, verb, name = msg.get("scope"), msg.get("verb"), msg.get("name")
    if scope not in VERBS or verb not in VERBS[scope] or not isinstance(name, str) or not UNIT.match(name):
        raise ValueError("unit needs scope user or system, a verb it allows and a .service name")
    return ["systemctl", "--user", verb, "--", name] if scope == "user" else ["pkexec", "systemctl", verb, "--", name]


def run_unit(args, name, verb):
    try:
        done = subprocess.run(args, capture_output=True, text=True, timeout=120)
        reply = {"event": "done", "cmd": "unit", "name": name, "verb": verb} if done.returncode == 0 else {"event": "error", "message": done.stderr.strip() or verb + " " + name + " failed"}
    except (OSError, subprocess.SubprocessError) as e:
        reply = {"event": "error", "message": str(e)}
    emit(reply)


def answer(root, line):
    try:
        msg = json.loads(line)
        if not isinstance(msg, dict):
            raise ValueError("commands are JSON objects")
        if msg.get("cmd") == "files":
            return {"event": "files", "pid": pid_of(msg), "files": files(root, msg["pid"])}
        if msg.get("cmd") in ("startup", "autostart"):
            user_dir, system_dirs = autostart_dirs(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), (os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":"))
            if msg["cmd"] == "autostart":
                if not isinstance(msg.get("on"), bool):
                    raise ValueError("autostart needs on true or false")
                set_autostart(user_dir, system_dirs, msg.get("file"), msg["on"])
            return {"event": "startup", "apps": autostart(user_dir, system_dirs, (os.environ.get("XDG_CURRENT_DESKTOP") or "").split(":")), "units": user_units()}
        if msg.get("cmd") == "services":
            return dict({"event": "services"}, **services())
        if msg.get("cmd") == "users":
            return {"event": "users", "sessions": sessions()}
        if msg.get("cmd") == "unit":
            args = unit_args(msg)
            threading.Thread(target=run_unit, args=(args, msg["name"], msg["verb"]), daemon=True).start()
            return {"event": "pending", "cmd": "unit", "name": msg["name"], "verb": msg["verb"]}
        if msg.get("cmd") == "detail":
            pid = pid_of(msg)
            return {"event": "detail", "pid": pid, "affinity": sorted(os.sched_getaffinity(pid)), "cores": os.cpu_count()}
        return dict({"event": "done", "cmd": msg.get("cmd")}, **command(msg))
    except (ValueError, OSError) as e:
        return {"event": "error", "message": str(e)}


def emit(obj):
    with LOCK:
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
