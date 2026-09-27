#!/usr/bin/env python3
"""Shared dependency checks and distro-specific package plans.
Versions, packages and repositories live in dependencies.json. Checks are read-only.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]

def version_tuple(v):
    m = re.search(r"(\d+)(?:\.(\d+))?(?:\.(\d+))?", str(v or ""))
    return tuple(int(x or 0) for x in m.groups()) if m else None


def run(cmd, timeout=5):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout + p.stderr
    except (OSError, subprocess.TimeoutExpired) as e:
        return 127, str(e)


def qml_import_paths():
    paths = [p for p in os.environ.get("QML_IMPORT_PATH", "").split(":") + os.environ.get("QML2_IMPORT_PATH", "").split(":") if p]
    for tool in qtpaths_commands():
        code, out = run([tool, "--query", "QT_INSTALL_QML"])
        if code == 0 and out.strip():
            paths.append(out.strip().splitlines()[0])
            break
    return paths or ["/usr/lib/qt6/qml"]


def check_dependency(dep):
    """Returns (status, detail); status in ok/warn/fail."""
    chk = dep.get("check", {})
    bad = "fail" if dep.get("level") == "required" else "warn"
    kind = chk.get("type")
    if kind == "executable":
        return ("ok", "installed") if resolve_command(chk) else (bad, "not installed")
    if kind == "command":
        command = resolve_command(chk)
        if not command:
            return bad, "not installed"
        code, out = run(command)
        if code != 0:
            return bad, f"`{' '.join(command)}` failed: {out.strip()[:120]}"
        if chk.get("json"):
            try:
                out = str(json.loads(out).get(chk["json"], ""))
            except json.JSONDecodeError:
                return bad, "unexpected output"
        m = re.search(chk.get("regex", r"(\d+\.\d+(?:\.\d+)?)"), out)
        found = m.group(1) if m else "?"
        if dep.get("min") and (version_tuple(found) or (0,)) < version_tuple(dep["min"]):
            return bad, f"{found} < required {dep['min']}"
        note = ""
        if dep.get("tested") and version_tuple(found) and version_tuple(found) > version_tuple(dep["tested"]):
            note = f" (newer than tested {dep['tested']})"
        return "ok", found + note
    if kind == "qml-modules":
        roots = qml_import_paths()
        missing = [m for m in chk["modules"] if not any((Path(r) / m.replace(".", "/") / "qmldir").exists() for r in roots)]
        return (bad, "missing: " + ", ".join(missing)) if missing else ("ok", f"{len(chk['modules'])} modules")
    if kind == "font":
        code, out = run(["fc-list", ":", "family"])
        families = {f.strip() for line in out.splitlines() for f in line.split(",")}
        return ("ok", chk["family"]) if chk["family"] in families else (bad, "not installed")
    return "warn", f"unknown check type {kind!r}"


def manifest():
    return json.loads((REPO / 'dependencies.json').read_text())


def resolve_command(check):
    command = check['cmd']
    for name in [command[0]] + check.get('alternatives', []):
        resolved = shutil.which(name)
        if resolved:
            return [resolved] + command[1:]
    return None


def qtpaths_commands():
    dep = next(d for d in manifest()['dependencies'] if d['id'] == 'qt')
    return [dep['check']['cmd'][0]] + dep['check'].get('alternatives', [])


def distro_info(path='/etc/os-release'):
    """Parse data, never source /etc/os-release as shell code."""
    values = {}
    try:
        for line in Path(path).read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                key, value = line.split('=', 1)
                parts = shlex.split(value, comments=True)
                values[key] = parts[0] if parts else ''
    except (OSError, ValueError):
        return 'unknown', ''
    ident = values.get('ID', 'unknown')
    if ident not in ('fedora', 'ubuntu') and 'arch' in values.get('ID_LIKE', '').split():
        ident = 'arch'
    return ident, values.get('VERSION_ID', '')


def install_hint(dep, distro):
    return dep.get('install', {}).get(distro, '')


def package_plan(distro, version):
    platform = manifest().get('platforms', {}).get(distro)
    if not platform or version not in platform['versions']:
        raise ValueError(f'No automatic package recipe for {distro} {version}. Install the dependencies manually, then rerun install.sh.')
    commands = [platform[k] for k in ('prepare', 'bootstrap') if k in platform]
    commands += [repo['command'] for repo in platform['repositories']]
    if 'refresh' in platform:
        commands.append(platform['refresh'])
    commands.append(platform['install'] + platform['packages'])
    return platform, commands


def preflight():
    failed = False
    distro, version = distro_info()
    print(f'Dependency check: {distro} {version}')
    for dep in manifest()['dependencies']:
        if dep.get('level') != 'required':
            continue
        status, detail = check_dependency(dep)
        print(f' {status:4} {dep["id"]}: {detail}')
        if status == 'fail':
            failed = True
            hint = install_hint(dep, distro)
            if hint:
                print('      ' + hint)
    if failed:
        print('Install matching dependencies first. Fedora/Ubuntu: ./install.sh --install-deps\nPreview repository/package changes with ./install.sh --deps-plan.', file=sys.stderr)
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--plan', action='store_true')
    action.add_argument('--install', action='store_true')
    action.add_argument('--install-greeter', action='store_true')
    action.add_argument('--check', action='store_true')
    action.add_argument('--tool', choices=['qt-shadertools', 'qt'])
    parser.add_argument('--yes', action='store_true')
    parser.add_argument('--distro', choices=['fedora', 'ubuntu'], help='Preview only')
    parser.add_argument('--version', help='Preview only')
    args = parser.parse_args()
    if (args.distro or args.version) and not args.plan:
        parser.error('--distro/--version are only supported with --plan')
    if args.tool:
        dep = next(d for d in manifest()['dependencies'] if d['id'] == args.tool)
        command = resolve_command(dep['check'])
        if not command:
            print(f'{args.tool} not installed', file=sys.stderr)
            return 1
        print(command[0])
        return 0
    if not (args.plan or args.install or args.install_greeter):
        return preflight()
    distro, version = distro_info()
    distro, version = args.distro or distro, args.version or version
    try:
        platform, commands = package_plan(distro, version)
        if args.install_greeter:
            commands = [platform["install"] + platform["greeterPackages"]]
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2
    print(f'Package plan for {distro} {version}. Adds these package sources:')
    for repo in platform['repositories']:
        print(f'  {repo["name"]}: {repo["url"]}')
    for command in commands:
        print('  sudo ' + shlex.join(command))
    if args.plan:
        return 0
    if not args.yes:
        if not sys.stdin.isatty() or input('Apply this package plan with sudo? [y/N] ').lower() not in ('y', 'yes', 'j', 'ja'):
            return 1
    prefix = [] if os.geteuid() == 0 else ['sudo']
    for command in commands:
        subprocess.run(prefix + command, check=True)
    return 0 if args.install_greeter else preflight()


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError) as error:
        print(f'Dependency installation failed: {error}', file=sys.stderr)
        raise SystemExit(1)
