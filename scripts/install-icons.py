#!/usr/bin/env python3
"""Install the bundled FullBlue snapshot, without network or other icon packs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile


def install(icons):
    bundle = Path(__file__).resolve().parents[1] / 'assets/icon-theme'
    manifest = json.loads((bundle / 'manifest.json').read_text())
    theme = manifest['theme']
    target = icons / theme
    if (target / 'index.theme').is_file():
        print(f'{theme} already installed (kept)')
        return target
    archive = bundle / 'fullblue.tar.xz'
    if hashlib.sha256(archive.read_bytes()).hexdigest() != manifest['sha256']:
        raise ValueError('FullBlue archive checksum mismatch')
    if target.exists():
        raise ValueError(f'Incomplete existing theme: {target}; move it aside before installing')
    icons.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.bifrost-icons-', dir=icons) as tmp:
        with tarfile.open(archive) as tar:
            tar.extractall(tmp, filter='data')
        staged = Path(tmp) / theme
        if not (staged / 'index.theme').is_file():
            raise ValueError('FullBlue index.theme missing')
        shutil.copy2(bundle / 'README.md', staged / 'BIFROST-ATTRIBUTION.md')
        cache = shutil.which('gtk-update-icon-cache')
        if cache:
            subprocess.run([cache, '-f', '-t', str(staged)], check=True)
        staged.rename(target)
    print(f'Installed {theme}')
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--icons-dir', type=Path, default=Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'icons')
    install(parser.parse_args().icons_dir)
