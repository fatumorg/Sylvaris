#!/usr/bin/env python3
import json
import os
import re
import select
import socket
import struct
import sys

MAX_PROTOCOL = 5
TYPES = ["motherboard", "dram", "gpu", "cooler", "ledstrip", "keyboard", "mouse", "mousemat", "headset", "headset stand", "gamepad", "light", "speaker", "virtual", "storage", "case", "microphone", "accessory", "keypad", "laptop", "monitor"]
PER_LED, MODE_SPECIFIC = 1, 2
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
UNREACHABLE = "OpenRGB is not reachable at {}:{}; start OpenRGB with its SDK server on (openrgb --server, or SDK Server in the OpenRGB window)"


class Reader:
    def __init__(self, data):
        self.d, self.i = data, 0

    def take(self, fmt):
        v = struct.unpack_from(fmt, self.d, self.i)
        self.i += struct.calcsize(fmt)
        return v[0] if len(v) == 1 else v

    def skip(self, n):
        self.i += n

    def text(self):
        n = self.take("<H")
        s = self.d[self.i:self.i + n].split(b"\0", 1)[0].decode("utf-8", "replace")
        self.i += n
        return s

    def colors(self):
        return [self.take("<BBBB")[:3] for _ in range(self.take("<H"))]


def pack_text(s):
    b = s.encode() + b"\0"
    return struct.pack("<H", len(b)) + b


def pack_colors(colors):
    return struct.pack("<H", len(colors)) + b"".join(struct.pack("<BBBB", c[0], c[1], c[2], 0) for c in colors)


def read_mode(r, proto):
    m = {"name": r.text(), "value": r.take("<i") if proto < 6 else 0}
    m["flags"], m["speed_min"], m["speed_max"] = r.take("<III")
    m["bmin"], m["bmax"] = r.take("<II") if proto >= 3 else (0, 0)
    m["cmin"], m["cmax"], m["speed"] = r.take("<III")
    m["brightness"] = r.take("<I") if proto >= 3 else 0
    m["direction"], m["color_mode"] = r.take("<II")
    m["colors"] = r.colors()
    return m


def pack_mode(m, proto):
    out = pack_text(m["name"]) + (struct.pack("<i", m["value"]) if proto < 6 else b"")
    out += struct.pack("<III", m["flags"], m["speed_min"], m["speed_max"])
    if proto >= 3:
        out += struct.pack("<II", m["bmin"], m["bmax"])
    out += struct.pack("<III", m["cmin"], m["cmax"], m["speed"])
    if proto >= 3:
        out += struct.pack("<I", m["brightness"])
    return out + struct.pack("<II", m["direction"], m["color_mode"]) + pack_colors(m["colors"])


def read_device(data, proto):
    r = Reader(data)
    r.take("<I")
    kind = r.take("<i")
    d = {"type": TYPES[kind] if 0 <= kind < len(TYPES) else "other", "name": r.text()}
    d["vendor"] = r.text() if proto >= 1 else ""
    for _ in range(3):
        r.text()
    d["location"] = r.text()
    count = r.take("<H")
    d["active"] = r.take("<i")
    d["modes"] = [read_mode(r, proto) for _ in range(count)]
    zones = []
    for _ in range(r.take("<H")):
        name = r.text()
        r.take("<i")
        r.take("<III")
        r.skip(r.take("<H"))
        if proto >= 4:
            for _ in range(r.take("<H")):
                r.text()
                r.take("<iII")
        if proto >= 5:
            r.take("<I")
        zones.append(name)
    d["zones"] = zones
    leds = r.take("<H")
    for _ in range(leds):
        r.text()
        if proto < 6:
            r.take("<I")
    d["leds"] = leds
    d["colors"] = r.colors()
    return d


def hexof(c):
    return "#%02x%02x%02x" % tuple(c)


def rgbof(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16))


class Client:
    def __init__(self, host, port):
        self.sock = socket.create_connection((host, int(port)), timeout=3)
        self.buf = b""
        self.send(0, 50, b"Sylvaris\0")
        self.send(0, 40, struct.pack("<I", MAX_PROTOCOL))
        try:
            self.sock.settimeout(0.6)
            self.protocol = min(struct.unpack("<I", self.recv(40)[1])[0], MAX_PROTOCOL)
        except socket.timeout:
            self.protocol = 0
        self.sock.settimeout(5)

    def close(self):
        self.sock.close()

    def send(self, dev, pid, data=b""):
        self.sock.sendall(b"ORGB" + struct.pack("<III", dev, pid, len(data)) + data)

    def packet(self):
        while len(self.buf) < 16:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("OpenRGB closed the connection")
            self.buf += chunk
        if self.buf[:4] != b"ORGB":
            raise ConnectionError("OpenRGB sent something that is not an SDK packet")
        dev, pid, size = struct.unpack_from("<III", self.buf, 4)
        while len(self.buf) < 16 + size:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("OpenRGB closed the connection")
            self.buf += chunk
        data, self.buf = self.buf[16:16 + size], self.buf[16 + size:]
        return dev, pid, data

    def recv(self, want):
        while True:
            dev, pid, data = self.packet()
            if pid == want:
                return dev, data

    def devices(self):
        self.send(0, 0)
        count = struct.unpack("<I", self.recv(0)[1][:4])[0]
        out = []
        for i in range(count):
            self.send(i, 1, struct.pack("<I", self.protocol) if self.protocol >= 1 else b"")
            out.append(read_device(self.recv(1)[1], self.protocol))
        return out

    def profiles(self):
        if self.protocol < 2:
            return []
        self.send(0, 150)
        r = Reader(self.recv(150)[1])
        r.take("<I")
        return [r.text() for _ in range(r.take("<H"))]

    def update_mode(self, dev, idx, mode):
        body = struct.pack("<i", idx) + pack_mode(mode, self.protocol)
        self.send(dev, 1101, struct.pack("<I", len(body) + 4) + body)

    def update_leds(self, dev, colors):
        body = pack_colors(colors)
        self.send(dev, 1050, struct.pack("<I", len(body) + 4) + body)


def public(i, d):
    active = d["modes"][d["active"]] if 0 <= d["active"] < len(d["modes"]) else None
    shown = active["colors"][0] if active is not None and active["color_mode"] == MODE_SPECIFIC and active["colors"] else d["colors"][0] if d["colors"] else None
    return {
        "id": i,
        "name": d["name"],
        "vendor": d["vendor"],
        "type": d["type"],
        "mode": active["name"] if active is not None else "",
        "modes": [{"name": m["name"], "color": m["color_mode"] in (PER_LED, MODE_SPECIFIC), "speed": m["speed_max"] != m["speed_min"]} for m in d["modes"]],
        "leds": d["leds"],
        "zones": d["zones"],
        "location": d["location"],
        "color": hexof(shown) if shown is not None else "",
    }


def connect(host, port):
    try:
        return Client(host, port), None
    except OSError:
        return None, {"ok": False, "error": UNREACHABLE.format(host, port)}


def listing(host, port):
    c, err = connect(host, port)
    if err:
        return err
    try:
        devices = c.devices()
        return {"ok": True, "protocol": c.protocol, "devices": [public(i, d) for i, d in enumerate(devices)], "profiles": c.profiles()}
    except (OSError, ConnectionError, struct.error, IndexError) as e:
        return {"ok": False, "error": "could not read the device list from OpenRGB: " + str(e)}
    finally:
        c.close()


def find(devices, op):
    i = op.get("id")
    if isinstance(i, int) and 0 <= i < len(devices) and devices[i]["name"] == op.get("name"):
        return i
    for j, d in enumerate(devices):
        if d["name"] == op.get("name"):
            return j
    return -1


def mode_index(d, name):
    for i, m in enumerate(d["modes"]):
        if m["name"].lower() == name.lower():
            return i
    return -1


def colour_mode(d, fast):
    modes = list(enumerate(d["modes"]))
    static = [i for i, m in modes if m["color_mode"] == MODE_SPECIFIC and m["name"].lower() == "static"]
    direct = [i for i, m in modes if m["color_mode"] == PER_LED and m["name"].lower() in ("direct", "custom", "static")]
    other = [i for i, m in modes if m["color_mode"] == MODE_SPECIFIC]
    for group in (direct, static, other) if fast else (static, direct, other):
        if group:
            return group[0]
    return -1


def paint(c, i, d, idx, color):
    m = dict(d["modes"][idx])
    if m["bmax"] > m["bmin"]:
        m["brightness"] = m["bmax"]
    c.update_mode(i, idx, dict(m, colors=[color] * max(1, len(m["colors"]))) if m["color_mode"] == MODE_SPECIFIC else m)
    if m["color_mode"] == PER_LED:
        c.update_leds(i, [color] * d["leds"])


def run(c, devices, op):
    i = find(devices, op)
    if i < 0:
        return "no device called " + str(op.get("name"))
    d = devices[i]
    what = op.get("do")
    color = op.get("color", "")
    if color and not HEX.match(color):
        return "not a colour: " + str(color)
    if what == "color":
        if not color:
            return "no colour given"
        idx = colour_mode(d, op.get("fast") is True)
        if idx < 0:
            return d["name"] + " has no colour you can set"
        paint(c, i, d, idx, rgbof(color))
        return ""
    if what == "off":
        idx = mode_index(d, "off")
        if idx >= 0:
            c.update_mode(i, idx, d["modes"][idx])
            return ""
        return run(c, devices, dict(op, do="color", color="#000000"))
    if what == "mode":
        idx = mode_index(d, str(op.get("mode", "")))
        if idx < 0:
            return d["name"] + " has no effect called " + str(op.get("mode"))
        m = d["modes"][idx]
        if color and m["color_mode"] in (PER_LED, MODE_SPECIFIC):
            paint(c, i, d, idx, rgbof(color))
        else:
            c.update_mode(i, idx, m)
        return ""
    return "unknown action " + str(what)


def apply(host, port, ops):
    c, err = connect(host, port)
    if err:
        return err
    try:
        devices = c.devices()
        results = []
        for op in ops if isinstance(ops, list) else []:
            problem = run(c, devices, op if isinstance(op, dict) else {})
            results.append({"name": op.get("name", "") if isinstance(op, dict) else "", "ok": problem == "", "error": problem})
        return {"ok": True, "results": results}
    except (OSError, ConnectionError, struct.error, IndexError) as e:
        return {"ok": False, "error": "OpenRGB stopped answering: " + str(e)}
    finally:
        c.close()


def load(host, port, name):
    c, err = connect(host, port)
    if err:
        return err
    try:
        if name not in c.profiles():
            return {"ok": False, "error": "OpenRGB has no profile called " + name}
        c.send(0, 152, name.encode() + b"\0")
        for i, d in enumerate(c.devices()):
            if 0 <= d["active"] < len(d["modes"]):
                c.update_mode(i, d["active"], d["modes"][d["active"]])
        return {"ok": True}
    except (OSError, ConnectionError, struct.error, IndexError) as e:
        return {"ok": False, "error": "OpenRGB stopped answering: " + str(e)}
    finally:
        c.close()


EVENT = struct.Struct("<qqHHi")
BUTTONS = range(0x110, 0x120)


def event_nodes(location, sys_root="/sys"):
    m = re.search(r"hidraw\d+", location or "")
    if not m:
        return []
    path = os.path.realpath(os.path.join(sys_root, "class", "hidraw", m.group(0), "device"))
    top = os.path.realpath(sys_root)
    while path.startswith(top) and path != top and not os.path.exists(os.path.join(path, "idVendor")):
        path = os.path.dirname(path)
    if not os.path.exists(os.path.join(path, "idVendor")):
        return []
    names = set()
    for _, dirs, _ in os.walk(path):
        names.update(n for n in dirs if re.fullmatch(r"event\d+", n))
    return ["/dev/input/" + n for n in sorted(names)]


def react(host, port, targets, out, stopped=lambda: False):
    c, err = connect(host, port)
    if err:
        out(json.dumps(err))
        return 1
    watched = {}
    try:
        devices = c.devices()
        for t in targets if isinstance(targets, list) else []:
            if not isinstance(t, dict) or not HEX.match(str(t.get("base", ""))) or not HEX.match(str(t.get("press", ""))):
                continue
            i = find(devices, t)
            if i < 0:
                continue
            d = devices[i]
            direct = next((idx for idx, m in enumerate(d["modes"]) if m["color_mode"] == PER_LED and m["name"].lower() in ("direct", "custom", "static")), -1)
            state = {"i": i, "d": d, "direct": direct, "base": rgbof(t["base"]), "press": rgbof(t["press"]), "held": set()}
            run(c, devices, {"id": i, "name": d["name"], "do": "color", "color": t["base"], "fast": True})
            for path in t.get("events") or event_nodes(d["location"]):
                try:
                    watched[os.open(path, os.O_RDONLY | os.O_NONBLOCK)] = (state, bytearray())
                except OSError as e:
                    out(json.dumps({"ok": False, "error": "cannot read " + path + " for " + d["name"] + ": " + e.strerror}))
        if not watched:
            out(json.dumps({"ok": False, "error": "no mouse buttons to watch"}))
            return 1
        out("ready")

        def show(s, color):
            if s["direct"] >= 0:
                c.update_leds(s["i"], [color] * s["d"]["leds"])
            else:
                run(c, devices, {"id": s["i"], "name": s["d"]["name"], "do": "color", "color": hexof(color), "fast": True})

        while not stopped():
            ready = select.select(list(watched), [], [], 0.3)[0]
            for fd in ready:
                s, buf = watched[fd]
                try:
                    chunk = os.read(fd, EVENT.size * 32)
                except BlockingIOError:
                    continue
                if not chunk:
                    select.select([], [], [], 0.05)
                    continue
                buf += chunk
                while len(buf) >= EVENT.size:
                    _, _, kind, code, value = EVENT.unpack_from(buf)
                    del buf[:EVENT.size]
                    if kind != 1 or code not in BUTTONS:
                        continue
                    before = bool(s["held"])
                    if value:
                        s["held"].add(code)
                    else:
                        s["held"].discard(code)
                    if bool(s["held"]) != before:
                        show(s, s["press"] if s["held"] else s["base"])
        return 0
    except (OSError, ConnectionError, struct.error, IndexError):
        return 1
    finally:
        for fd in watched:
            os.close(fd)
        c.close()


def watch(host, port, out):
    c, err = connect(host, port)
    if err:
        out(json.dumps(err))
        return 1
    c.sock.settimeout(None)
    out("ready")
    try:
        while True:
            if c.packet()[1] == 100:
                out("changed")
    except (OSError, ConnectionError):
        return 1
    finally:
        c.close()


def main():
    args = sys.argv[1:]
    if len(args) < 3:
        sys.stderr.write("usage: rgb.py HOST PORT list|apply|load NAME|watch|react\n")
        return 2
    host, port, cmd = args[0], args[1], args[2]
    def line(s):
        sys.stdout.write(s + "\n")
        sys.stdout.flush()
    if cmd == "watch":
        return watch(host, port, line)
    if cmd == "react":
        try:
            targets = json.loads(sys.stdin.readline() or "[]")
        except ValueError:
            targets = []
        return react(host, port, targets, line)
    if cmd == "list":
        got = listing(host, port)
    elif cmd == "apply":
        try:
            ops = json.loads(sys.stdin.read() or "[]")
        except ValueError:
            ops = []
        got = apply(host, port, ops)
    elif cmd == "load" and len(args) > 3:
        got = load(host, port, args[3])
    else:
        got = {"ok": False, "error": "unknown command " + cmd}
    sys.stdout.write(json.dumps(got) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
