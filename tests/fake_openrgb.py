#!/usr/bin/env python3
import json
import signal
import socket
import struct
import sys
import threading

PER_LED, MODE_SPECIFIC, NONE = 1, 2, 0


def mode(name, color_mode, colors=(), flags=0, speed=(0, 0, 0)):
    return {"name": name, "value": 0, "flags": flags, "speed_min": speed[0], "speed_max": speed[1], "bmin": 0, "bmax": 100, "cmin": len(colors), "cmax": len(colors), "speed": speed[2], "brightness": 100, "direction": 0, "color_mode": color_mode, "colors": list(colors)}


def devices():
    return [
        {"type": 6, "name": "SteelSeries Rival 3 Wireless", "vendor": "SteelSeries", "active": 1,
         "modes": [mode("Direct", PER_LED, flags=1 << 5), mode("Static", MODE_SPECIFIC, [(255, 0, 0)], flags=1 << 6), mode("Breathing", MODE_SPECIFIC, [(255, 0, 0)], flags=1 << 6 | 1, speed=(1, 5, 3)), mode("Off", NONE)],
         "zones": [{"name": "Logo", "count": 1, "matrix": None}], "leds": ["Logo"], "colors": [(255, 0, 0)]},
        {"type": 5, "name": "Krux Atax Pro RGB", "vendor": "Krux", "active": 2,
         "modes": [mode("Direct", PER_LED, flags=1 << 5), mode("Static", MODE_SPECIFIC, [(0, 0, 255)], flags=1 << 6), mode("Spectrum Cycle", NONE, flags=1, speed=(0, 4, 2)), mode("Off", NONE)],
         "zones": [{"name": "Keyboard", "count": 3, "matrix": (1, 3, [0, 1, 2])}], "leds": ["Key: A", "Key: B", "Key: C"], "colors": [(0, 0, 0)] * 3},
        {"type": 0, "name": "Gigabyte RGB", "vendor": "Gigabyte", "active": 0,
         "modes": [mode("Static", MODE_SPECIFIC, [(0, 255, 0)], flags=1 << 6)],
         "zones": [{"name": "Board", "count": 2, "matrix": None}], "leds": ["LED 1", "LED 2"], "colors": [(0, 255, 0)] * 2},
    ]


def u16(v):
    return struct.pack("<H", v)


def u32(v):
    return struct.pack("<I", v)


def i32(v):
    return struct.pack("<i", v)


def text(s):
    b = s.encode() + b"\0"
    return u16(len(b)) + b


def color(c):
    return struct.pack("<BBBB", c[0], c[1], c[2], 0)


def encode_mode(m, proto):
    out = text(m["name"]) + (i32(m["value"]) if proto < 6 else b"") + u32(m["flags"]) + u32(m["speed_min"]) + u32(m["speed_max"])
    if proto >= 3:
        out += u32(m["bmin"]) + u32(m["bmax"])
    out += u32(m["cmin"]) + u32(m["cmax"]) + u32(m["speed"])
    if proto >= 3:
        out += u32(m["brightness"])
    out += u32(m["direction"]) + u32(m["color_mode"]) + u16(len(m["colors"])) + b"".join(color(c) for c in m["colors"])
    return out


def encode_device(d, proto):
    body = i32(d["type"]) + text(d["name"]) + (text(d["vendor"]) if proto >= 1 else b"") + text("fake") + text("1") + text("") + text("HID: fake")
    body += u16(len(d["modes"])) + i32(d["active"]) + b"".join(encode_mode(m, proto) for m in d["modes"])
    body += u16(len(d["zones"]))
    for z in d["zones"]:
        body += text(z["name"]) + i32(1) + u32(z["count"]) + u32(z["count"]) + u32(z["count"])
        if z["matrix"] is None:
            body += u16(0)
        else:
            h, w, cells = z["matrix"]
            body += u16(8 + 4 * len(cells)) + u32(h) + u32(w) + b"".join(u32(c) for c in cells)
        if proto >= 4:
            body += u16(1) + text(z["name"]) + i32(1) + u32(0) + u32(z["count"])
        if proto >= 5:
            body += u32(0)
    body += u16(len(d["leds"])) + b"".join(text(n) + (u32(i) if proto < 6 else b"") for i, n in enumerate(d["leds"]))
    body += u16(len(d["colors"])) + b"".join(color(c) for c in d["colors"])
    if proto >= 5:
        body += u16(0) + u32(0)
    return u32(len(body) + 4) + body


class Reader:
    def __init__(self, data):
        self.d, self.i = data, 0

    def take(self, fmt):
        v = struct.unpack_from(fmt, self.d, self.i)
        self.i += struct.calcsize(fmt)
        return v[0] if len(v) == 1 else v

    def text(self):
        n = self.take("<H")
        s = self.d[self.i:self.i + n].rstrip(b"\0").decode()
        self.i += n
        return s

    def colors(self):
        return [self.take("<BBBB")[:3] for _ in range(self.take("<H"))]


def decode_mode(r, proto):
    m = {"name": r.text()}
    if proto < 6:
        m["value"] = r.take("<i")
    m["flags"], m["speed_min"], m["speed_max"] = r.take("<I"), r.take("<I"), r.take("<I")
    if proto >= 3:
        m["bmin"], m["bmax"] = r.take("<I"), r.take("<I")
    m["cmin"], m["cmax"], m["speed"] = r.take("<I"), r.take("<I"), r.take("<I")
    if proto >= 3:
        m["brightness"] = r.take("<I")
    m["direction"], m["color_mode"] = r.take("<I"), r.take("<I")
    m["colors"] = r.colors()
    return m


def hexes(colors):
    return ["#%02x%02x%02x" % tuple(c) for c in colors]


class Server:
    def __init__(self, port, log=None, proto=5, profiles=("Evening", "Work")):
        self.proto, self.log_path, self.profiles = proto, log, list(profiles)
        self.devices = devices()
        self.events = []
        self.clients = []
        self.lock = threading.Lock()
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind(("127.0.0.1", port))
        self.sock.listen()
        self.port = self.sock.getsockname()[1]
        threading.Thread(target=self.accept, daemon=True).start()

    def record(self, event):
        with self.lock:
            self.events.append(event)
            if self.log_path:
                with open(self.log_path, "a") as f:
                    f.write(json.dumps(event) + "\n")

    def accept(self):
        while True:
            try:
                conn, _ = self.sock.accept()
            except OSError:
                return
            self.clients.append(conn)
            threading.Thread(target=self.serve, args=(conn,), daemon=True).start()

    def send(self, conn, dev, pid, data=b""):
        conn.sendall(b"ORGB" + u32(dev) + u32(pid) + u32(len(data)) + data)

    def notify(self):
        for c in list(self.clients):
            try:
                self.send(c, 0, 100)
            except OSError:
                pass

    def serve(self, conn):
        client_proto = 0
        buf = b""
        try:
            while True:
                while len(buf) < 16:
                    chunk = conn.recv(65536)
                    if not chunk:
                        return
                    buf += chunk
                dev, pid, size = struct.unpack_from("<III", buf, 4)
                while len(buf) < 16 + size:
                    chunk = conn.recv(65536)
                    if not chunk:
                        return
                    buf += chunk
                data, buf = buf[16:16 + size], buf[16 + size:]
                self.handle(conn, dev, pid, data)
        finally:
            if conn in self.clients:
                self.clients.remove(conn)
            conn.close()

    def handle(self, conn, dev, pid, data):
        if pid == 40:
            if self.proto > 0:
                self.send(conn, 0, 40, u32(self.proto))
        elif pid == 0:
            self.send(conn, 0, 0, u32(len(self.devices)))
        elif pid == 1:
            want = struct.unpack("<I", data)[0] if len(data) == 4 else 0
            self.send(conn, dev, 1, encode_device(self.devices[dev], min(want, self.proto)))
        elif pid == 50:
            self.record({"op": "name", "name": data.rstrip(b"\0").decode()})
        elif pid == 150:
            body = u16(len(self.profiles)) + b"".join(text(p) for p in self.profiles)
            self.send(conn, 0, 150, u32(len(body) + 4) + body)
        elif pid == 152:
            self.record({"op": "profile", "name": data.rstrip(b"\0").decode()})
        elif pid == 1100:
            d = self.devices[dev]
            names = [m["name"] for m in d["modes"]]
            d["active"] = names.index("Direct") if "Direct" in names else names.index("Static") if "Static" in names else d["active"]
            self.record({"op": "custom", "dev": d["name"]})
        elif pid == 1101:
            r = Reader(data)
            r.take("<I")
            idx = r.take("<i")
            m = decode_mode(r, self.proto)
            d = self.devices[dev]
            d["active"] = idx
            d["modes"][idx]["colors"] = m["colors"]
            self.record({"op": "mode", "dev": d["name"], "mode": d["modes"][idx]["name"], "colors": hexes(m["colors"]), "speed": m["speed"]})
            d["modes"][idx]["brightness"] = m.get("brightness", d["modes"][idx]["brightness"])
        elif pid == 1050:
            r = Reader(data)
            r.take("<I")
            cs = r.colors()
            d = self.devices[dev]
            d["colors"] = cs
            self.record({"op": "leds", "dev": d["name"], "colors": hexes(cs)})


def main():
    port = int(sys.argv[1])
    srv = Server(port, sys.argv[2] if len(sys.argv) > 2 else None, int(sys.argv[3]) if len(sys.argv) > 3 else 5)

    def changed(*_):
        srv.devices = srv.devices[:2] if len(srv.devices) == 3 else devices()
        srv.notify()

    signal.signal(signal.SIGUSR1, changed)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    while True:
        signal.pause()


if __name__ == "__main__":
    main()
