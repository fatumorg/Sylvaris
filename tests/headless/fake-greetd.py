#!/usr/bin/env python3
import json
import os
import socket
import struct
import sys

path, log = sys.argv[1], sys.argv[2]
if os.path.exists(path):
    os.unlink(path)
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen(4)


def recv(conn, n):
    data = b""
    while len(data) < n:
        chunk = conn.recv(n - len(data))
        if not chunk:
            return None
        data += chunk
    return data


def send(conn, obj):
    body = json.dumps(obj).encode()
    conn.sendall(struct.pack("=I", len(body)) + body)


def note(obj):
    with open(log, "a") as f:
        f.write(json.dumps(obj) + "\n")


while True:
    conn, _ = server.accept()
    while True:
        head = recv(conn, 4)
        if head is None:
            break
        req = json.loads(recv(conn, struct.unpack("=I", head)[0]))
        kind = req.get("type")
        note({k: v for k, v in req.items() if k != "response"})
        if kind == "create_session":
            send(conn, {"type": "auth_message", "auth_message_type": "secret", "auth_message": "Password:"})
        elif kind == "post_auth_message_response":
            if req.get("response") == "right":
                send(conn, {"type": "success"})
            else:
                send(conn, {"type": "error", "error_type": "auth_error", "description": "authentication failed"})
        else:
            send(conn, {"type": "success"})
    conn.close()
