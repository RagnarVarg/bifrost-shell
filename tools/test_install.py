#!/usr/bin/env python3
"""Isolated copy/update/uninstall smoke test. Needs bwrap, lua and install dependencies.
The real home is hidden by a temporary mount; systemctl is stubbed.
Run explicitly with python3 tools/test_install.py (extracts bundled icons).
"""
import os, pathlib, shutil, subprocess, tempfile
repo=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='bifrost-install-') as td:
    root=pathlib.Path(td)
    source=root/'source'
    shutil.copytree(repo, source, ignore=shutil.ignore_patterns('.git','__pycache__'))
    home=root/'home'; home.mkdir()
    stubs=root/'stubs'; stubs.mkdir()
    (stubs/'systemctl').write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$INSTALL_TEST_LOG"\n')
    (stubs/'systemctl').chmod(0o755)
    config=home/'custom-config'; (config/'hypr').mkdir(parents=True)
    (config/'hypr/hyprland.lua').write_text('-- existing user config\n')
    actual_home=str(pathlib.Path.home())
    env=dict(os.environ)
    for key in ['BIFROST_DIR','BIFROST_CONFIG_DIR','HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY','DBUS_SESSION_BUS_ADDRESS']:
        env.pop(key,None)
    env.update(XDG_CONFIG_HOME=actual_home+'/custom-config', XDG_DATA_HOME=actual_home+'/.local/share', XDG_RUNTIME_DIR=td+'/runtime', INSTALL_TEST_LOG=td+'/systemctl.log', PATH=str(stubs)+':'+env['PATH'])
    (root/'runtime').mkdir()
    def sandbox(command):
        cmd=['bwrap','--ro-bind','/','/','--bind',td,td,'--bind',str(home),actual_home,'--proc','/proc','--dev','/dev','--unshare-pid','--chdir',str(source)]
        if (root/'os-release').exists():
            cmd += ['--ro-bind', str(root/'os-release'), '/etc/os-release']
        return cmd + ['--'] + command
    def run(*args, expected=0):
        p=subprocess.run(sandbox(['bash',str(source/'install.sh'),*args]),env=env,text=True,capture_output=True,timeout=120)
        print('RUN',args,'EXIT',p.returncode)
        if p.returncode != expected:
            print(p.stdout+p.stderr)
        assert p.returncode==expected
    run('--yes','--no-enable','--no-greeter')
    dest=home/'.local/share/bifrost-shell'
    assert dest.is_dir() and not dest.is_symlink()
    assert (config/'bifrost/hypr/bifrost.lua').is_file()
    # Execute the actual hook as Lua, intercepting only the loaded path.
    hook = (config/'hypr/hyprland.lua').read_text()
    for custom in (True, False):
        lua = "local getenv = os.getenv; os.getenv = function(k) if k == 'XDG_CONFIG_HOME' then return " + ('getenv(k)' if custom else 'nil') + " end return getenv(k) end; dofile = function(p) assert(p == os.getenv('HOME') .. " + ("'/custom-config" if custom else "'/.config") + "/bifrost/hypr/bifrost.lua', p) end; " + hook
        subprocess.run(['lua', '-e', lua], env=env, check=True, timeout=10)
    assert '.git' not in [p.name for p in dest.iterdir()]
    for command in ('bifrost-shell', 'bifrost-settings', 'bifrostctl'):
        assert (home/'.local/bin'/command).is_symlink()
    assert '%h/.local/share/bifrost-shell/bin/bifrost-shell' in (config/'systemd/user/bifrost.service').read_text()
    (dest/'obsolete-test-file').write_text('stale')
    # Simulate an earlier installed hook and verify upgrade preserves its backup.
    legacy = hook.replace('dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/bifrost/hypr/bifrost.lua")', 'dofile(os.getenv("HOME") .. "/.config/bifrost/hypr/bifrost.lua")')
    (config/'hypr/hyprland.lua').write_text(legacy)
    run('--yes','--no-enable','--no-greeter')
    assert (config/'hypr/hyprland.lua').read_text() == hook
    assert any(p.read_text() == legacy for p in (config/'hypr').glob('hyprland.lua.before-bifrost.*'))
    assert not (dest/'obsolete-test-file').exists()
    assert (config/'hypr/hyprland.lua').read_text().count('-- BIFROST_END')==1
    run('--uninstall')
    assert not dest.exists()
    assert not (config/'systemd/user/bifrost.service').exists()
    assert not (home/'.local/bin/bifrost-shell').is_symlink()
    assert (config/'hypr/hyprland.lua').read_text()=='-- existing user config\n'
    assert (config/'bifrost/hypr/bifrost.lua').exists()
    print('COPY / UPDATE / UNINSTALL PASS')

    # Missing/old runtime must fail before copying or enabling anything.
    (stubs/'qs').write_text('#!/bin/sh\necho "Quickshell 0.2.1"\n')
    (stubs/'qs').chmod(0o755)
    run('--yes', '--no-enable', '--no-greeter', expected=1)
    assert not dest.exists()
    (stubs/'qs').unlink()

    # Test distro selection/package argv without installing host packages.
    for command in ('dnf','apt-get','add-apt-repository'):
        (stubs/command).write_text('#!/bin/sh\nprintf "%s %s\n" "$(basename "$0")" "$*" >> "$INSTALL_TEST_LOG"\n')
        (stubs/command).chmod(0o755)
    (stubs/'sudo').write_text('#!/bin/sh\nexec "$@"\n')
    (stubs/'sudo').chmod(0o755)
    for distro, version in [('fedora','44'), ('ubuntu','26.04')]:
        (root/'os-release').write_text(f'ID={distro}\nVERSION_ID="{version}"\n')
        (config/'hypr/hyprland.lua').unlink()
        run('--yes','--install-deps','--no-enable','--no-greeter')
        assert (config/'systemd/user/bifrost-session.target').exists()
        assert 'hl.monitor' in (config/'hypr/hyprland.lua').read_text()
        assert (config/'hypr/hyprland.lua').read_text().count('-- BIFROST_END') == 1
        wrapper=root/'verify.lua'
        wrapper.write_text('__bifrost_verify = true\ndofile(' + repr(actual_home + '/custom-config/hypr/hyprland.lua') + ')\n')
        verified=subprocess.run(sandbox(['Hyprland','--verify-config','--config',str(wrapper)]), env=env, capture_output=True,text=True,timeout=30)
        assert verified.returncode == 0, verified.stdout + verified.stderr

        for name in ('app-launcher.svg','overview.svg'):
            assert (dest/'assets/icons'/name).read_bytes() == (repo/'assets/icons'/name).read_bytes()
        run('--uninstall')
    log=(root/'systemctl.log').read_text()
    assert 'dnf copr enable -y lionheartp/Hyprland' in log
    assert 'add-apt-repository -y ppa:cppiber/hyprland' in log
    assert 'enable bifrost.service' not in log
    print('FEDORA / UBUNTU PACKAGE PLANS + FRESH CONFIG PASS (package managers stubbed)')

    # An existing legacy compositor config must not be silently superseded.
    (config/'hypr/hyprland.lua').unlink()
    legacy_conf=config/'hypr/hyprland.conf'
    legacy_conf.write_text('# existing configuration\n')
    run('--yes','--no-enable','--no-greeter',expected=1)
    assert not dest.exists()
    assert not (config/'hypr/hyprland.lua').exists()
    assert legacy_conf.read_text() == '# existing configuration\n'
    print('EXISTING HYPRLAND.CONF PRESERVED')
