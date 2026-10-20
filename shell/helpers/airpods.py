#!/usr/bin/env python3
import json
import select
import socket
import sys

PSM = 0x1001
HEADER = bytes([0x04, 0x00, 0x04, 0x00])
HANDSHAKE = bytes.fromhex("00000400010002000000000000000000")
FEATURES = bytes.fromhex("040004004d00ff00000000000000")
NOTIFY = bytes.fromhex("040004000f00ffffffff")
NOISE = {"off": 1, "anc": 2, "transparency": 3, "adaptive": 4}
NOISE_NAMES = {v: k for k, v in NOISE.items()}
PARTS = {0x02: "right", 0x04: "left", 0x08: "case"}
CHARGE = {0x01: "charging", 0x02: "discharging", 0x04: "disconnected"}
EAR = {0x00: "ear", 0x01: "out", 0x02: "case"}
NOISE_ID = 0x0D
AWARENESS_ID = 0x28


def control(ident, value):
    return HEADER + bytes([0x09, 0x00, ident, value, 0x00, 0x00, 0x00])


def command(line):
    msg = json.loads(line)
    if msg.get("cmd") == "noise" and msg.get("mode") in NOISE:
        return control(NOISE_ID, NOISE[msg["mode"]])
    if msg.get("cmd") == "awareness" and isinstance(msg.get("enabled"), bool):
        return control(AWARENESS_ID, 0x01 if msg["enabled"] else 0x02)
    raise ValueError("unknown command")


def parse(pkt):
    if len(pkt) < 7 or pkt[:4] != HEADER:
        return None
    kind = pkt[4]
    if kind == 0x04 and pkt[5] == 0x00:
        count = pkt[6]
        battery = {}
        for i in range(count):
            at = 7 + i * 5
            if at + 4 > len(pkt):
                break
            part = PARTS.get(pkt[at])
            status = CHARGE.get(pkt[at + 3], "unknown")
            if part is not None and status != "disconnected":
                battery[part] = {"level": pkt[at + 2], "charging": status == "charging"}
        return {"event": "battery", "battery": battery}
    if kind == 0x09 and len(pkt) >= 8 and pkt[6] == NOISE_ID:
        return {"event": "noise", "mode": NOISE_NAMES.get(pkt[7], "off")}
    if kind == 0x09 and len(pkt) >= 8 and pkt[6] == AWARENESS_ID:
        return {"event": "awareness", "enabled": pkt[7] == 0x01}
    if kind == 0x06 and len(pkt) >= 8:
        return {"event": "ear", "primary": EAR.get(pkt[6], "out"), "secondary": EAR.get(pkt[7], "out")}
    return None


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def run(address):
    sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
    sock.settimeout(8)
    sock.connect((address, PSM))
    sock.settimeout(None)
    for pkt in (HANDSHAKE, FEATURES, NOTIFY):
        sock.send(pkt)
    emit({"event": "connected", "address": address})
    while True:
        ready, _, _ = select.select([sock, sys.stdin], [], [])
        if sock in ready:
            pkt = sock.recv(1024)
            if not pkt:
                raise ConnectionError("the AirPods closed the connection")
            event = parse(pkt)
            if event is not None:
                emit(event)
        if sys.stdin in ready:
            line = sys.stdin.readline()
            if not line:
                return
            try:
                sock.send(command(line))
            except ValueError as e:
                emit({"event": "error", "message": str(e)})


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: airpods.py <bluetooth address>\n")
        return 2
    try:
        run(sys.argv[1])
    except (OSError, ConnectionError) as e:
        emit({"event": "disconnected", "message": str(e)})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
