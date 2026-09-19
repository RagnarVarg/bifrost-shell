#!/usr/bin/env python3
"""Install only the exported desktop files; existing files are backed up."""
import argparse
from datetime import datetime
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true', help='Copy files (default: preview only)')
parser.add_argument('--target', type=Path, default=Path.home(), help='Target home, also useful for an isolated test')
parser.add_argument('--ultrawide', action='store_true', help='Use the DP-2 5120x1440 240 Hz monitor profile')
args = parser.parse_args()
root = Path(__file__).resolve().parent
home = args.target.resolve()
backup = home / '.local/state/cachyos-shell-config/backups' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
files = []
for source, destination in [('config', '.config'), ('icons', '.local/share/icons'), ('wallpapers', 'Pictures/Wallpapers')]:
    for p in sorted((root / source).rglob('*')):
        if p.is_file() or p.is_symlink():
            files.append((p, home / destination / p.relative_to(root / source)))
if args.ultrawide:
    target = home / '.config/hypr/dms/outputs.lua'
    files = [(p, q) for p, q in files if q != target]
    files.append((root / 'profiles/ultrawide-5120x1440.lua', target))
print(f'{len(files)} desktop files -> {home}')
print(f'Existing files will be backed up under {backup}')
if not args.apply:
    print('Preview only. Run again with --apply to install. No services are changed.')
    raise SystemExit(0)
for p, q in files:
    q.parent.mkdir(parents=True, exist_ok=True)
    if q.exists() or q.is_symlink():
        saved = backup / q.relative_to(home)
        saved.parent.mkdir(parents=True, exist_ok=True)
        if q.is_symlink():
            saved.symlink_to(q.readlink())
        elif q.is_file():
            shutil.copy2(q, saved)
        else:
            raise RuntimeError(f'Refusing to replace a directory: {q}')
    if q.is_symlink():
        q.unlink()
    if p.is_symlink():
        if q.exists(): q.unlink()
        q.symlink_to(p.readlink())
    else:
        shutil.copy2(p, q)
        if p.is_relative_to(root / 'config'):
            try:
                text = q.read_text()
            except UnicodeError:
                continue
            if '@HOME@' in text:
                # JSON uses escaped string content; shell paths in this export are quoted.
                replacement = str(home)
                if q.suffix == '.json':
                    import json
                    replacement = json.dumps(replacement, ensure_ascii=False)[1:-1]
                q.write_text(text.replace('@HOME@', replacement))
print('Installed. Follow README.md to activate DMS and check the gesture service.')
