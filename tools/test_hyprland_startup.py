#!/usr/bin/env python3
"""Exercise the real backend against delayed initial Hyprland IPC replies."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StartupTest(unittest.TestCase):
    def test_delayed_status_seeds_monitors_and_workspaces(self):
        with tempfile.TemporaryDirectory(prefix='bifrost-ipc-') as tmp:
            base = Path(tmp)
            ipc = base / 'hypr' / 'test'
            ipc.mkdir(parents=True)
            (base / 'dependencies.json').symlink_to(ROOT / 'dependencies.json')
            replies = {
                'j/status': {'configProvider': 'lua'},
                'j/version': {'version': '0.56.2'},
                'j/monitors': [{'id': 0, 'name': 'TEST', 'x': 0, 'y': 0,
                                'width': 1920, 'height': 1080, 'scale': 1,
                                'focused': True, 'activeWorkspace': {'id': 1, 'name': '1'}}],
                'j/workspaces': [{'id': 1, 'name': '1', 'monitor': 'TEST', 'monitorID': 0,
                                  'windows': 0}],
                'j/clients': [],
            }
            stop = threading.Event()
            def serve_request(conn):
                with conn:
                    request = conn.recv(4096).decode()
                    # An eager update remains in flight when status completes:
                    # Quickshell then skips its create-capable seed request.
                    time.sleep(0.15 if request == 'j/status' else 0.3)
                    try:
                        conn.sendall(json.dumps(replies.get(request, {})).encode())
                    except BrokenPipeError:
                        pass
            sockets = []
            def serve(sock, events):
                sock.settimeout(0.1)
                while not stop.is_set():
                    try:
                        conn, _ = sock.accept()
                    except socket.timeout:
                        continue
                    except OSError:
                        return
                    if events:
                        stop.wait(4)
                        conn.close()
                    else:
                        threading.Thread(target=serve_request, args=(conn,), daemon=True).start()
            for name in ('.socket.sock', '.socket2.sock'):
                sock = socket.socket(socket.AF_UNIX)
                sock.bind(str(ipc / name))
                sock.listen()
                sockets.append(sock)
                threading.Thread(target=serve, args=(sock, name == '.socket2.sock'), daemon=True).start()
            shell = base / 'shell'
            shell.mkdir()
            for entry in (ROOT / 'shell').iterdir():
                if entry.is_dir():
                    (shell / entry.name).symlink_to(entry)
            (shell / 'shell.qml').write_text('''import QtQuick
import Quickshell
import qs.Compositor
ShellRoot {
    HyprlandBackend { id: backend; geometryWatchers: 1 }
    Timer {
        interval: 1600; running: true
        onTriggered: {
            console.info("STARTUP_RESULT " + JSON.stringify({monitors: backend.monitors, workspaces: backend.workspaces}));
            Qt.quit();
        }
    }
}
''')
            env = dict(os.environ, XDG_RUNTIME_DIR=tmp, HYPRLAND_INSTANCE_SIGNATURE='test',
                       QT_QPA_PLATFORM='offscreen', BIFROST_RUN_MODE='overlay',
                       BIFROST_CONFIG_DIR=str(base / 'config'))
            try:
                result = subprocess.run(['qs', '-p', str(shell)], env=env,
                                        capture_output=True, text=True, timeout=8)
                output = result.stdout + result.stderr
                lines = [line.split('STARTUP_RESULT ', 1)[1] for line in output.splitlines()
                         if 'STARTUP_RESULT ' in line]
                self.assertTrue(lines, f'exit={result.returncode}\n{output}')
                state = json.loads(lines[-1])
                self.assertEqual([m['name'] for m in state['monitors']], ['TEST'], output)
                self.assertEqual([w['id'] for w in state['workspaces']], [1], output)
                self.assertEqual(state['monitors'][0]['activeWorkspaceId'], 1, output)
            finally:
                stop.set()
                for sock in sockets:
                    sock.close()


if __name__ == '__main__':
    unittest.main()
