#!/usr/bin/env python3
"""Dev aid: hover-switching test along the bar with a real (virtual) pointer.

Run against a nested Hyprland running Bifrost (scripts/nested.sh):
    WAYLAND_DISPLAY=<nested socket> HYPRLAND_INSTANCE_SIGNATURE=<nested> tools/dev/hovertest.py
For every pair of bar widgets that open something (menu or panel), it hovers
the first, checks it opened, glides along the bar to the second and checks
that the second's popup replaced the first within `--settle` ms. Also goes
into the open panel/menu first and back up to the bar (`--via-popup`).
Never run it against your session: it moves the real pointer.
"""
import argparse, json, os, subprocess, sys, time

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def ipc(*args):
    out = subprocess.run(["qs", "ipc", "-p", os.path.join(REPO, "shell"), "call", *args], capture_output=True, text=True, timeout=10)
    return out.stdout.strip()


def state():
    s = json.loads(ipc("bar", "widgets"))
    if s["controlCenter"]:
        s["open"] = "controlCenter"
    elif s["notificationCenter"]:
        s["open"] = "notifications"
    elif s["menu"]:
        s["open"] = s["menuFrom"] or "menu"
    else:
        s["open"] = None
    return s


def monitor_size():
    mons = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True).stdout)
    return mons[0]["width"], mons[0]["height"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--settle", type=int, default=700)
    ap.add_argument("--via-popup", action="store_true")
    ap.add_argument("--only", help="comma separated widget ids")
    a = ap.parse_args()
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or os.environ.get("WAYLAND_DISPLAY") in (None, "wayland-0", "wayland-1") and not os.environ.get("BIFROST_HOVERTEST_FORCE"):
        print("point WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE at a nested Hyprland (BIFROST_HOVERTEST_FORCE=1 overrides)")
        return 2
    W, H = monitor_size()
    ptr = subprocess.Popen([os.path.join(REPO, "scripts", "vpointer.sh"), str(W), str(H)], stdin=subprocess.PIPE, text=True)

    def send(*lines):
        for l in lines:
            ptr.stdin.write(l + "\n")
        ptr.stdin.flush()

    def glide(x, y, ms):
        send(f"glide {x} {y} {ms}", "sleep 0")
        time.sleep(ms / 1000 + 0.05)

    def wait(ms):
        send(f"sleep {ms}")
        time.sleep(ms / 1000 + 0.05)

    widgets = [w for w in state()["bars"][0]["widgets"] if w["id"] not in ("spacer", "workspaces")]
    if a.only:
        widgets = [w for w in widgets if w["id"] in a.only.split(",")]
    cy = lambda w: w["y"] + w["height"] / 2
    cx = lambda w: w["x"] + w["width"] / 2
    park = (W / 2, H / 2)

    # Which widgets open something on hover.
    openers = []
    for w in widgets:
        glide(park[0], park[1], 150); wait(700)
        glide(cx(w), cy(w), 200); wait(a.settle)
        s = state()
        if s["open"]:
            openers.append((w, s["open"]))
    print("openers:", ", ".join(f"{w['id']}→{o}" for w, o in openers))

    fails = 0
    for w1, o1 in openers:
        for w2, o2 in openers:
            if w1 is w2 or o1 == o2:
                continue
            glide(park[0], park[1], 150); wait(700)
            glide(cx(w1), cy(w1), 200); wait(a.settle)
            if a.via_popup:
                glide(cx(w1), cy(w1) + 120, 200); wait(200)
            if state()["open"] != o1:
                print(f"SKIP {w1['id']}: not open"); continue
            glide(cx(w2), cy(w2), 250); wait(a.settle)
            got = state()["open"]
            ok = got == o2
            fails += not ok
            print(f"{'ok  ' if ok else 'FAIL'} {w1['id']} → {w2['id']}: {got} (want {o2})")
    glide(park[0], park[1], 150); wait(300)
    ptr.stdin.close(); ptr.wait()
    print(f"{fails} failures")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
