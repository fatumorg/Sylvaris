#!/usr/bin/env python3
import base64
import json
import math
import os
import struct
import sys
import urllib.error
import urllib.parse
import urllib.request

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "sylvaris", "diver.json")


def out(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def load():
    try:
        with open(STATE) as f:
            s = json.load(f)
    except (OSError, ValueError):
        return None
    if not all(isinstance(s.get(k), str) and s[k] for k in ("url", "token", "salt", "key")):
        return None
    return s


def decode_code(code):
    code = code.strip()
    if code.startswith("sylvaris diver pair "):
        code = code[len("sylvaris diver pair "):].strip()
    padded = code + "=" * (-len(code) % 4)
    s = json.loads(base64.urlsafe_b64decode(padded.encode()).decode())
    if s.get("v") != 1:
        raise ValueError("unsupported pairing code")
    for k in ("url", "token", "salt", "key"):
        if not isinstance(s.get(k), str) or not s[k]:
            raise ValueError("the pairing code is missing " + k)
    u = urllib.parse.urlsplit(s["url"])
    if not u.hostname or not (u.scheme == "https" or (u.scheme == "http" and u.hostname in ("127.0.0.1", "localhost"))):
        raise ValueError("the server must use https")
    if len(bytes.fromhex(s["key"])) != 32:
        raise ValueError("the key in the pairing code is not 256 bits")
    return {"url": s["url"].rstrip("/"), "token": s["token"], "salt": s["salt"], "key": s["key"]}


def save_state(s):
    os.makedirs(os.path.dirname(STATE), mode=0o700, exist_ok=True)
    tmp = STATE + ".part"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(s, f)
    os.replace(tmp, STATE)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


OPENER = urllib.request.build_opener(NoRedirect)


def request(s, method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(s["url"] + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + s["token"])
    req.add_header("User-Agent", "sylvaris-diver")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with OPENER.open(req, timeout=15) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        try:
            payload = json.loads(e.read().decode() or "null")
        except ValueError:
            payload = None
        return e.code, payload


def decrypt(s, blob):
    if not isinstance(blob, str) or not blob.startswith("v1:"):
        return blob if isinstance(blob, list) else []
    salt, iv, ct = blob[3:].split(":")
    if salt != s["salt"]:
        raise PermissionError("the list was encrypted with another key, pair again")
    plain = AESGCM(bytes.fromhex(s["key"])).decrypt(bytes.fromhex(iv), bytes.fromhex(ct), None)
    return json.loads(plain.decode())


def encrypt(s, obj):
    iv = os.urandom(12)
    ct = AESGCM(bytes.fromhex(s["key"])).encrypt(iv, json.dumps(obj, separators=(",", ":")).encode(), None)
    return "v1:" + s["salt"] + ":" + iv.hex() + ":" + ct.hex()


def pull(s):
    status, j = request(s, "GET", "/api/dives")
    if status == 401:
        raise PermissionError("this device was removed in diver, pair again")
    if status != 200:
        raise ConnectionError("diver answered " + str(status))
    return {"ok": True, "version": j.get("version", 0), "data": decrypt(s, j.get("data"))}


def push(s, body):
    status, j = request(s, "PUT", "/api/dives", {"data": encrypt(s, body["data"]), "base": body["base"]})
    if status == 409:
        return {"ok": False, "conflict": True, "version": (j or {}).get("version", 0)}
    if status == 401:
        raise PermissionError("this device was removed in diver, pair again")
    if status != 200:
        raise ConnectionError("diver answered " + str(status))
    return {"ok": True, "version": j["version"]}


GENERIC = "you have something planned"


def answered(status):
    if status == 401:
        raise PermissionError("this device was removed in diver, pair again")
    if status != 200:
        raise ConnectionError("diver answered " + str(status))


def reminders(s, body):
    status, prefs = request(s, "GET", "/api/prefs")
    answered(status)
    if not isinstance(prefs, dict) or not prefs.get("pushDevices"):
        return {"ok": True, "sent": False, "count": 0}
    detailed = prefs.get("pushDetails") is True
    items = []
    for it in (body or {}).get("items") or []:
        at = it.get("at") if isinstance(it, dict) else None
        if not isinstance(it, dict) or not isinstance(it.get("rid"), str) or isinstance(at, bool) or not isinstance(at, (int, float)) or not isinstance(it.get("title"), str):
            continue
        items.append({"rid": it["rid"][:120], "at": at, "title": it["title"][:140] if detailed else GENERIC, "alarm": it.get("alarm") is True})
    status, j = request(s, "PUT", "/api/reminders", {"items": items[:500]})
    answered(status)
    return {"ok": True, "sent": True, "count": j.get("count", len(items)) if isinstance(j, dict) else len(items)}


def tone(path):
    rate = 44100
    frames = []
    for i in range(int(rate * 1.4)):
        t = i / rate
        beep = 0.0
        for start in (0.0, 0.22, 0.44):
            dt = t - start
            if 0 <= dt < 0.18:
                env = min(1.0, dt / 0.01) * max(0.0, 1 - dt / 0.18)
                beep += math.sin(2 * math.pi * 880 * dt) * env * 0.5
        frames.append(struct.pack("<h", int(max(-1, min(1, beep)) * 32767)))
    data = b"".join(frames)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16) + b"data" + struct.pack("<I", len(data)) + data)
    return {"ok": True, "path": path}


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("usage: diver.py pair <code> | unpair | status | pull | push | reminders | tone <path>\n")
        return 2
    cmd = sys.argv[1]
    try:
        if cmd == "pair":
            s = decode_code(sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read())
            result = pull(s)
            save_state(s)
            out({"ok": True, "url": s["url"], "tasks": sum(len(sub.get("dives", [])) for c in result["data"] for g in c.get("groups", []) for sub in g.get("subs", []))})
        elif cmd == "unpair":
            try:
                os.remove(STATE)
            except FileNotFoundError:
                pass
            out({"ok": True})
        elif cmd == "tone":
            out(tone(sys.argv[2]))
        else:
            s = load()
            if s is None:
                out({"ok": False, "paired": False, "error": "not paired"})
                return 0
            if cmd == "status":
                out({"ok": True, "paired": True, "url": s["url"]})
            elif cmd == "pull":
                out(pull(s))
            elif cmd == "push":
                out(push(s, json.loads(sys.stdin.read())))
            elif cmd == "reminders":
                out(reminders(s, json.loads(sys.stdin.read())))
            else:
                raise ValueError("unknown command " + cmd)
    except InvalidTag:
        out({"ok": False, "paired": load() is not None, "error": "the key does not open this list, pair again"})
    except PermissionError as e:
        out({"ok": False, "paired": load() is not None, "error": str(e)})
    except (OSError, ValueError, KeyError, ConnectionError) as e:
        out({"ok": False, "error": str(e) or e.__class__.__name__})
    except Exception as e:
        out({"ok": False, "error": e.__class__.__name__ + ": " + str(e)})
    return 0


if __name__ == "__main__":
    sys.exit(main())
