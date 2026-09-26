"""Dependency preflight and package planning; never invokes a package manager."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import dependencies as deps


class DependenciesTest(unittest.TestCase):
    def setUp(self):
        quiet = contextlib.redirect_stdout(io.StringIO())
        quiet.__enter__()
        self.addCleanup(quiet.__exit__, None, None, None)

    def test_os_release_is_data_and_arch_derivative(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'os-release'
            p.write_text('ID=cachyos\nID_LIKE="arch"\nVERSION_ID="2026"\n')
            self.assertEqual(deps.distro_info(p), ('arch', '2026'))
            p.write_text('ID=ubuntu\nVERSION_ID="26.04"\nNAME="$(false)"\n')
            self.assertEqual(deps.distro_info(p), ('ubuntu', '26.04'))
            self.assertEqual(deps.distro_info(p.with_name('missing')), ('unknown', ''))

    def test_plans_use_matching_managers_and_sources(self):
        for name, version, manager in [('ubuntu', '26.04', 'apt-get'), ('fedora', '44', 'dnf')]:
            platform, commands = deps.package_plan(name, version)
            self.assertEqual(commands[-1][0], manager)
            self.assertIn('hyprland', commands[-1])
            self.assertIn('quickshell', commands[-1])
            self.assertIn('rsync', commands[-1])
            self.assertTrue(platform['repositories'])
            self.assertNotIn('dms', platform['packages'])
            self.assertIn('greetd', platform['packages'])
            self.assertIn('greetd', platform['greeterPackages'])
        self.assertRaises(ValueError, deps.package_plan, 'ubuntu', '24.04')
        self.assertRaises(ValueError, deps.package_plan, 'debian', '13')

    def test_qt_fedora_and_ubuntu_paths(self):
        dep = next(d for d in deps.manifest()['dependencies'] if d['id'] == 'qt')
        for executable in ['/usr/lib64/qt6/bin/qtpaths', 'qtpaths-qt6', 'qtpaths6']:
            with patch.object(deps.shutil, 'which', side_effect=lambda x: x if x == executable else None), patch.object(deps, 'run', return_value=(0, '6.10.2')) as run:
                self.assertEqual(deps.check_dependency(dep), ('ok', '6.10.2'))
                self.assertEqual(run.call_args.args[0], [executable, '--qt-version'])

    def test_old_or_unparseable_version_fails(self):
        dep = next(d for d in deps.manifest()['dependencies'] if d['id'] == 'hyprland')
        for output in ['Hyprland 0.53.3', 'unrecognized']:
            with patch.object(deps.shutil, 'which', return_value='/usr/bin/Hyprland'), patch.object(deps, 'run', return_value=(0, output)):
                self.assertEqual(deps.check_dependency(dep)[0], 'fail')
        # Check works without logging into Hyprland first.
        self.assertEqual(dep['check']['cmd'], ['Hyprland', '--version'])

    def test_missing_qml_module_fails(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(deps, 'qml_import_paths', return_value=[tmp]):
            dep = {'level':'required', 'check':{'type':'qml-modules','modules':['Quickshell.Services.Pam']}}
            self.assertEqual(deps.check_dependency(dep)[0], 'fail')
            p=Path(tmp)/'Quickshell/Services/Pam'; p.mkdir(parents=True)
            (p/'qmldir').write_text('module Quickshell.Services.Pam\n')
            self.assertEqual(deps.check_dependency(dep)[0], 'ok')

    def test_plan_never_runs_commands(self):
        with patch('sys.argv', ['dependencies.py', '--plan', '--distro', 'ubuntu', '--version', '26.04']), patch.object(deps.subprocess, 'run') as run:
            self.assertEqual(deps.main(), 0)
            run.assert_not_called()

    def test_command_failure_stops_package_sequence(self):
        import subprocess
        with patch('sys.argv', ['dependencies.py','--install','--yes']), patch.object(deps,'distro_info',return_value=('fedora','44')), patch.object(deps.subprocess,'run',side_effect=subprocess.CalledProcessError(1,['dnf'])) as run, patch.object(deps,'preflight') as preflight:
            self.assertRaises(subprocess.CalledProcessError,deps.main)
            self.assertEqual(run.call_count,1)
            preflight.assert_not_called()

    def test_install_always_rechecks_dependencies(self):
        with patch('sys.argv', ['dependencies.py','--install','--yes']), patch.object(deps,'distro_info',return_value=('ubuntu','26.04')), patch.object(deps.subprocess,'run') as run, patch.object(deps,'preflight',return_value=1) as check:
            self.assertEqual(deps.main(),1)
            self.assertEqual(run.call_count,len(deps.package_plan('ubuntu','26.04')[1]))
            check.assert_called_once()

    def test_wrong_distro_hint_is_not_shown(self):
        dep={'install':{'arch':'pacman -S foo','fedora':'dnf install foo'}}
        self.assertEqual(deps.install_hint(dep,'fedora'),'dnf install foo')
        self.assertEqual(deps.install_hint(dep,'ubuntu'),'')


if __name__ == '__main__':
    unittest.main()
