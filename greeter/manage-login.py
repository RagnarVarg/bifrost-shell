#!/usr/bin/python3
"""Switch the next boot's display manager; never stop the current session."""
import json
import fcntl
import os
from pathlib import Path
import subprocess
import sys

PREFIX = Path('/usr/share/bifrost-greeter')
STATE = Path('/var/lib/bifrost-login/previous-manager.json')
MANAGER = Path('/etc/systemd/system/display-manager.service')


def run(*args):
    subprocess.run(list(args), check=True, capture_output=True, text=True)


def current_manager():
    return MANAGER.resolve().name if MANAGER.exists() else ''


def switch(action):
    helper = str(PREFIX / 'greeter/install-greeter.sh')
    if action == 'enable':
        if STATE.exists():
            # Idempotent, but refuse to overwrite an externally changed manager.
            if current_manager() != 'greetd.service':
                raise RuntimeError('Display manager changed externally; restore the previous configuration first.')
            run(helper, '--enable')
            return
        previous = current_manager()
        if not previous or not previous.endswith('.service'):
            raise RuntimeError('No previous display manager found; refusing to replace it without a rollback target.')
        if not (PREFIX / 'bin/bifrost-greeter').is_file() or not Path('/usr/bin/greetd').is_file():
            raise RuntimeError('Install Bifrost login files and greetd first.')
        STATE.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        STATE.write_text(json.dumps({'previous': previous}) + '\n')
        os.chmod(STATE, 0o600)
        try:
            run(helper, '--enable')
            if previous != 'greetd.service':
                run('/usr/bin/systemctl', 'disable', previous)
                run('/usr/bin/systemctl', 'enable', '--force', 'greetd.service')
        except Exception:
            # Keep the state file if rollback itself fails, so it can be retried.
            if previous != 'greetd.service':
                run('/usr/bin/systemctl', 'disable', 'greetd.service')
                run('/usr/bin/systemctl', 'enable', '--force', previous)
            run(helper, '--disable')
            STATE.unlink()
            raise
    elif action == 'disable':
        if not STATE.exists():
            # Existing greetd installations can still restore their config backup.
            if current_manager() != 'greetd.service':
                raise RuntimeError('No Bifrost display-manager backup exists.')
            run(helper, '--disable')
            return
        previous = json.loads(STATE.read_text())['previous']
        if '/' in previous or not previous.endswith('.service'):
            raise RuntimeError('Invalid previous display manager in backup.')
        if current_manager() not in ('greetd.service', previous):
            raise RuntimeError('Display manager changed externally; refusing to overwrite it.')
        if previous != 'greetd.service':
            run('/usr/bin/systemctl', 'disable', 'greetd.service')
            run('/usr/bin/systemctl', 'enable', '--force', previous)
        run(helper, '--disable')
        STATE.unlink()
    else:
        raise ValueError('Expected enable or disable')


if __name__ == '__main__':
    try:
        if os.geteuid() != 0:
            raise RuntimeError('Administrator authentication is required.')
        if len(sys.argv) != 2:
            raise ValueError('Expected enable or disable')
        with open("/run/lock/bifrost-login.lock", "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            switch(sys.argv[1])
        print('Login screen updated for the next reboot. Current session unchanged.')
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
