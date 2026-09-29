"""Read-only wallpaper discovery; JSON keeps arbitrary filenames intact."""
import json
import os
from pathlib import Path
import sys

EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif', '.svg', '.avif'}


def discover(directory='', current='', home=None):
    home = Path(home or Path.home())

    def expand(value):
        return Path(str(value).replace('~/', str(home) + '/', 1)) if str(value).startswith('~/') else Path(value)

    roots = [home / 'Pictures' / 'Wallpapers']
    if directory:
        roots.append(expand(directory))
    if current:
        roots.append(expand(current).parent)
    images, seen, errors = [], set(), []

    def add(path):
        try:
            canonical = str(path.resolve())
            if path.suffix.lower() in EXTENSIONS and path.is_file() and canonical not in seen:
                seen.add(canonical)
                images.append(str(path.absolute()))
        except OSError as error:
            errors.append(str(error))

    visited = set()
    for root in roots:
        key = str(root.absolute())
        if key in visited:
            continue
        visited.add(key)
        if not root.exists():
            continue
        for base, dirs, files in os.walk(root, onerror=lambda e: errors.append(str(e))):
            dirs.sort(key=str.casefold)
            for name in sorted(files, key=str.casefold):
                add(Path(base) / name)
    if current:
        active = expand(current)
        add(active)
        # Keep the configured spelling so selected-state URL comparisons also
        # work when the current wallpaper is reached through a symlink.
        images = [str(active.absolute()) if Path(p).resolve() == active.resolve() else p for p in images]
    return {'images': images, 'errors': errors}


if __name__ == '__main__':
    print(json.dumps(discover(*sys.argv[1:3])))
