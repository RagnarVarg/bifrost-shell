#!/usr/bin/env python3
"""A stand-in for greetd, for testing the login screen without logging in.

Speaks greetd's IPC (4-byte native length + JSON) on a private socket, with
made-up accounts, and prints one JSON line per request so tests can follow the
dialogue. Nothing is authenticated or started for real.

  tools/dev/fakegreetd.py SOCKET [--user NAME:PASSWORD ...] [--otp CODE]
  GREETD_SOCK=SOCKET qs -p shell/greeter.qml

--otp adds a second, visible question after the password (like a second factor).
"""
import argparse
import json
import os
import socket
import struct
import sys


def recv(conn):
    head = conn.recv(4)
    if len(head) < 4:
        return None
    n = struct.unpack("=I", head)[0]
    data = b""
    while len(data) < n:
        chunk = conn.recv(n - len(data))
        if not chunk:
            return None
        data += chunk
    return json.loads(data)


def send(conn, obj):
    data = json.dumps(obj).encode()
    conn.sendall(struct.pack("=I", len(data)) + data)


def log(**event):
    print(json.dumps(event), flush=True)


def serve(path, accounts, otp):
    if os.path.exists(path):
        os.unlink(path)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(path)
    srv.listen(4)
    log(event="listening", socket=path)
    while True:
        conn, _ = srv.accept()
        state = {"user": None, "step": None, "ok": False}
        while True:
            req = recv(conn)
            if req is None:
                break
            kind = req.get("type")
            log(event="request", request=kind, **({"username": req["username"]} if "username" in req else {}),
                **({"cmd": req.get("cmd"), "env": req.get("env")} if kind == "start_session" else {}))
            if kind == "create_session":
                state.update(user=req.get("username"), step="password", ok=False)
                send(conn, {"type": "auth_message", "auth_message_type": "secret", "auth_message": "Password: "})
            elif kind == "post_auth_message_response":
                answer = req.get("response")
                if state["step"] == "password":
                    if accounts.get(state["user"]) == answer:
                        if otp:
                            state["step"] = "otp"
                            send(conn, {"type": "auth_message", "auth_message_type": "visible", "auth_message": "Verification code: "})
                        else:
                            state.update(step=None, ok=True)
                            send(conn, {"type": "success"})
                    else:
                        state.update(step=None)
                        log(event="auth_failed", username=state["user"])
                        send(conn, {"type": "error", "error_type": "auth_error", "description": "authentication failed"})
                elif state["step"] == "otp":
                    ok = answer == otp
                    state.update(step=None, ok=ok)
                    send(conn, {"type": "success"} if ok else {"type": "error", "error_type": "auth_error", "description": "wrong code"})
                else:
                    send(conn, {"type": "error", "error_type": "error", "description": "no question pending"})
            elif kind == "start_session":
                if state["ok"]:
                    log(event="session_started", username=state["user"], cmd=req.get("cmd"), env=req.get("env"))
                    send(conn, {"type": "success"})
                else:
                    send(conn, {"type": "error", "error_type": "error", "description": "not authenticated"})
            elif kind == "cancel_session":
                state.update(user=None, step=None, ok=False)
                send(conn, {"type": "success"})
            else:
                send(conn, {"type": "error", "error_type": "error", "description": f"unknown request {kind}"})
        conn.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("socket")
    ap.add_argument("--user", action="append", default=[], help="NAME:PASSWORD")
    ap.add_argument("--otp")
    args = ap.parse_args()
    accounts = dict(u.split(":", 1) for u in args.user)
    try:
        serve(args.socket, accounts, args.otp)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main())
