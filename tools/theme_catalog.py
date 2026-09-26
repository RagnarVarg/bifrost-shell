"""Data-only Tinted Theming catalog adapter for bifrostctl. No archive extraction."""
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile
import urllib.request

SOURCE = 'https://github.com/tinted-theming/schemes'
ARCHIVE = 'https://codeload.github.com/tinted-theming/schemes/tar.gz/refs/heads/spec-0.11'
ID = re.compile(r'tinted-[a-z0-9][a-z0-9-]{0,100}\Z')
HEX = re.compile(r'#[0-9a-fA-F]{6}\Z')


def scalar(text, key):
    match = re.search(r'^' + re.escape(key) + r':\s*(.+?)\s*$', text, re.M)
    if not match:
        raise ValueError(f'Missing {key}')
    value = match[1].strip()
    if value.startswith('"'):
        return json.loads(value)
    return value.strip("'")


def parse_scheme(name, data):
    tid = 'tinted-' + name
    if not ID.fullmatch(tid):
        raise ValueError('Invalid theme id')
    text = data.decode('utf-8')
    if scalar(text, 'system') != 'base16':
        raise ValueError('Unsupported color system')
    variant = scalar(text, 'variant')
    if variant not in ('dark', 'light'):
        raise ValueError('Invalid variant')
    pairs = re.findall(r'^\s+base([0-9A-Fa-f]{2}):\s*[\"\']?(#[0-9a-fA-F]{6})[\"\']?\s*(?:#.*)?$', text, re.M)
    palette = {key.upper(): value for key, value in pairs}
    if len(pairs) != 16 or set(palette) != {f'{i:02X}' for i in range(16)}:
        raise ValueError('Incomplete or duplicate Base16 palette')
    return dict(id=tid, name=scalar(text, 'name'), author=scalar(text, 'author'),
                version=hashlib.sha256(data).hexdigest(), variant=variant,
                description='Base16 palette from Tinted Theming', palette=palette,
                compatibility='Bifrost palette v1', source=SOURCE + '/blob/spec-0.11/base16/' + name + '.yaml')


def fetch_catalog():
    request = urllib.request.Request(ARCHIVE, headers={'User-Agent': 'Bifrost-theme-browser/1'})
    with urllib.request.urlopen(request, timeout=12) as response:
        data = response.read(4 * 1024 * 1024 + 1)
    if len(data) > 4 * 1024 * 1024:
        raise ValueError('Catalog download too large')
    entries, license_text = [], ''
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        total_size = 0
        for count, member in enumerate(archive):
            total_size += member.size
            if count > 2000 or total_size > 16 * 1024 * 1024:
                raise ValueError('Expanded catalog too large')
            if not member.isfile() or member.size > 65536:
                continue
            parts = Path(member.name).parts
            if len(parts) == 2 and parts[1] == 'LICENSE':
                license_text = archive.extractfile(member).read().decode('utf-8')
            elif len(parts) == 3 and parts[1] == 'base16' and parts[2].endswith('.yaml'):
                entries.append(parse_scheme(parts[2][:-5], archive.extractfile(member).read()))
    if not entries or not license_text:
        raise ValueError('Incomplete catalog')
    return dict(format='bifrost-catalog', version=1, source=SOURCE,
                license=license_text, themes=sorted(entries, key=lambda x: x['name'].lower()))


def theme_document(entry, license_text):
    if not ID.fullmatch(entry['id']) or entry['variant'] not in ('light', 'dark'):
        raise ValueError('Invalid catalog entry')
    p = entry['palette']
    if set(p) != {f'{i:02X}' for i in range(16)} or not all(HEX.fullmatch(v) for v in p.values()):
        raise ValueError('Invalid palette')
    palette = dict(void=p['00'], base=p['00'], surface=p['01'], surfaceRaised=p['02'],
                   surfaceHover=p['03'], text=p['05'], textMuted=p['04'], textFaint=p['03'],
                   silver=p['06'], silverBright=p['07'], accent=p['0D'], accentDeep=p['0C'],
                   accentText=p['00'], success=p['0B'], warning=p['0A'], danger=p['08'],
                   aurora=[p['0D'], p['0E'], p['0C']])
    return dict(id=entry['id'], name=entry['name'], version=entry['version'], extends='_base',
                author=entry['author'], description=entry['description'], license=license_text,
                catalogSource=SOURCE, source=entry['source'],
                variants={entry['variant']: {'palette': palette}})


def run(args, config_dir, active_theme, write_json):
    cache = config_dir / 'catalogs/tinted.json'
    themes = config_dir / 'themes'
    if themes.is_symlink():
        raise ValueError('Refusing a symlink theme directory')
    offline = False
    catalog = None
    if args.action == 'browse' and (args.refresh or not cache.exists()):
        try:
            catalog = fetch_catalog()
            write_json(cache, catalog)
        except (OSError, ValueError, tarfile.TarError):
            offline = True
    if catalog is None:
        catalog = json.loads(cache.read_text()) if cache.exists() else {'themes': []}
    if args.action == 'browse':
        rows = []
        for entry in catalog['themes']:
            if not ID.fullmatch(entry['id']):
                continue
            path = themes / (entry['id'] + '.json')
            installed = json.loads(path.read_text()) if path.is_file() else None
            rows.append(dict(entry, installed=installed is not None,
                             updateAvailable=installed is not None and installed.get('version') != entry['version']))
        return dict(themes=rows, offline=offline, source=SOURCE)
    if not args.theme or not ID.fullmatch(args.theme):
        raise ValueError('Invalid theme id')
    target = themes / (args.theme + '.json')
    # Refuse symlinks and foreign files even inside the theme directory.
    if target.is_symlink():
        raise ValueError('Refusing a symlink theme target')
    if target.exists() and json.loads(target.read_text()).get('catalogSource') != SOURCE:
        raise ValueError('This theme is not managed by the catalog')
    if args.action == 'remove':
        if active_theme == args.theme:
            raise ValueError('Apply another theme before removing the active theme')
        target.unlink(missing_ok=True)
        return {'removed': args.theme}
    entry = next((t for t in catalog['themes'] if t['id'] == args.theme), None)
    if entry is None:
        raise ValueError('Theme is not in the catalog; refresh first')
    write_json(target, theme_document(entry, catalog['license']))
    return {'installed': args.theme, 'variant': entry['variant']}
