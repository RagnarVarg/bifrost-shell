"""Tests for tools/bifrostctl. Run: python3 tools/test_bifrostctl.py"""

import importlib.machinery
import importlib.util
import json
import re
import os
import tempfile
from pathlib import Path
import unittest
import sys
from types import SimpleNamespace
from unittest.mock import patch
from pathlib import Path

_path = str(Path(__file__).with_name("bifrostctl"))
_loader = importlib.machinery.SourceFileLoader("bifrostctl", _path)
ctl = importlib.util.module_from_spec(importlib.util.spec_from_loader("bifrostctl", _loader))
_loader.exec_module(ctl)


sys.path.insert(0, str(Path(__file__).parent))
import theme_catalog
import brightness
import network_hidden
import input_backend


class BifrostctlTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        os.environ["BIFROST_CONFIG_DIR"] = self.tmp.name
        os.environ.pop("BIFROST_PRESET", None)
        self.schema = ctl.Schema()

    def tearDown(self):
        self.tmp.cleanup()

    def file(self):
        return json.loads((Path(self.tmp.name) / "config.json").read_text())

    def test_input_schema_per_device_roundtrip_and_rejection(self):
        d = self.schema.entries["input.devices"]
        value = {"test-keyboard": {"kind":"keyboard", "values":{"kb_layout":"se,us", "kb_options":"grp:alt_shift_toggle,compose:ralt", "repeat_rate":31}, "original":{"kb_layout":"se"}}}
        ok, got, err = ctl.coerce(d, value)
        self.assertTrue(ok, err)
        self.assertEqual(got, value)
        for bad in [
            {"__proto__":{"kind":"mouse","values":{}}},
            {"mouse":{"kind":"mouse","values":{"kb_layout":"us"}}},
            {"keyboard":{"kind":"keyboard","values":{"kb_layout":"us);bad()"}}},
            {"trackpad":{"kind":"trackpad","values":{"accel_profile":"invented"}}},
        ]:
            self.assertFalse(ctl.coerce(d,bad)[0],bad)
        cfg = ctl.Config(self.schema)
        cfg.set("input.devices",value)
        cfg.save()
        self.assertEqual(ctl.deep_get(ctl.Config(self.schema).values,"input.devices")[0], value)
        self.assertFalse(ctl.coerce(self.schema.entries["input.gestures"],{"3:evil()":"workspace"})[0])

    def test_display_hdr_sdr_roundtrip_and_generated_colour_mode(self):
        cfg = ctl.Config(self.schema)
        for cm, depth in (("hdr", 10), ("hdredid", 10), ("srgb", 8)):
            output = dict(width=1920, height=1080, refresh=60, x=0, y=0,
                          scale=1, vrr=False, bitdepth=depth, cm=cm, sdrBrightness=1.65)
            cfg.set("displays.outputs", {"TEST": output})
            cfg.save()
            loaded = ctl.Config(self.schema)
            self.assertEqual(ctl.deep_get(loaded.values, "displays.outputs")[0]["TEST"], output)
            text = ctl.generate_hypr(loaded)
            self.assertIn('cm = "' + cm + '"', text)
            self.assertIn("bitdepth = " + str(depth), text)
            self.assertIn("sdrbrightness = 1.65", text)

    def test_display_hdr_brightness_bounds(self):
        cfg = ctl.Config(self.schema)
        for brightness, expected in ((15, 15), (20, 15), (0.1, 0.5)):
            output = dict(width=1920, height=1080, refresh=60, x=0, y=0,
                          scale=1, vrr=False, bitdepth=10, cm="hdr", sdrBrightness=brightness)
            cfg.set("displays.outputs", {"TEST": output})
            cfg.save()
            text = ctl.generate_hypr(ctl.Config(self.schema))
            self.assertIn("sdrbrightness = " + str(expected), text)

    def test_border_resize_applies_both_values_independently_of_appearance(self):
        cfg = ctl.Config(self.schema)
        cfg.set("hyprland.manage", False)
        for enabled in (True, False):
            cfg.set("input.resizeOnBorder", enabled)
            cfg.save()
            text = ctl.generate_hypr(ctl.Config(self.schema))
            self.assertIn("resize_on_border = " + str(enabled).lower(), text)

    def test_input_generator_verifies_all_device_kinds_and_gestures(self):
        cfg = ctl.Config(self.schema)
        cfg.set("input.devices", {
            "keyboard-test": {"kind":"keyboard","values":{"kb_layout":"se,us","kb_variant":",","kb_options":"grp:alt_shift_toggle,compose:ralt","repeat_delay":400,"repeat_rate":32,"numlock_by_default":True},"original":{}},
            "mouse-test": {"kind":"mouse","values":{"sensitivity":0.15,"accel_profile":"flat","left_handed":True,"scroll_factor":1.3,"middle_button_emulation":True,"scroll_method":"on_button_down","scroll_button":274},"original":{"accel_profile":""}},
            "trackpad-test": {"kind":"trackpad","values":{"tap_to_click":True,"tap_and_drag":True,"drag_lock":2,"natural_scroll":True,"clickfinger_behavior":True,"disable_while_typing":True,"scroll_method":"2fg"},"original":{}},
        })
        cfg.set("input.gestures", {"3:horizontal":"workspace","4:up":"launcher","4:down":"close"})
        cfg.set("input.activeLayouts", {"keyboard-test":1})
        cfg.save()
        text = ctl.generate_hypr(ctl.Config(self.schema))
        self.assertIn("hl.device(rule)",text)
        self.assertIn("bifrost-ipc launcher toggle",text)
        self.assertIn("not __bifrost_verify",text)
        path=Path(self.tmp.name)/"input.lua"
        # Running the generated file twice must not duplicate gesture slots.
        path.write_text(text+"\n"+text)
        ok,msg=ctl.verify_hypr(path)
        self.assertTrue(ok,msg)

    def test_input_capability_fallback_uses_kernel_bits_not_name(self):
        root=Path(self.tmp.name)/"device"; (root/"capabilities").mkdir(parents=True)
        def bits(values):
            n=sum(1<<v for v in values); words=[]
            while n: words.insert(0,format(n & ((1<<64)-1),'x')); n >>= 64
            return " ".join(words or ["0"])
        for name,values in {"key":[0x110,0x145,0x14d,0x14e,0x14f],"abs":[0x2f,0x35,0x36],"rel":[]}.items(): (root/"capabilities"/name).write_text(bits(values))
        (root/"properties").write_text("5")
        caps=input_backend.kernel_capabilities({"sysfs":str(root),"kind":"trackpad","integration":"external"})
        self.assertEqual(caps["maxFingers"],4)
        self.assertTrue(caps["gestures"])
        self.assertFalse(caps["dwt"])
        self.assertNotIn("middle",caps)
        (root/"capabilities/abs").write_text("0")
        self.assertIsNone(input_backend.kernel_capabilities({"sysfs":str(root),"kind":"trackpad"}))

    def test_input_partial_json_batch_and_no_device(self):
        items=list(input_backend.json_stream('{"option":"a","bool":false}\nno such option\n{"option":"b","int":2}'))
        self.assertEqual([v["option"] for v in items],["a","b"])
        with patch.object(input_backend,"run",return_value=(1,"")):
            result=input_backend.query()
            self.assertEqual(result["devices"],[])
            self.assertTrue(result["error"])

    def test_fullblue_default_reset_and_custom_preservation(self):
        cfg = ctl.Config(self.schema)
        with patch.object(ctl, "icon_theme_exists", return_value=True):
            for variant in ("light", "dark"):
                self.assertEqual(ctl.effective_icon_theme(cfg, variant),
                                 ("Gruvbox-Plus-Dark-IceBlue-FullBlue", "default"))
            ctl.main(["set", "appearance.icons.theme", "Nordzy-dark"])
            self.assertEqual(ctl.effective_icon_theme(ctl.Config(self.schema))[0], "Nordzy-dark")
            ctl.main(["reset", "appearance.icons.theme"])
            self.assertEqual(ctl.effective_icon_theme(ctl.Config(self.schema))[0],
                             "Gruvbox-Plus-Dark-IceBlue-FullBlue")
        with patch.object(ctl, "icon_theme_exists", return_value=False), patch.object(ctl, "system_icon_theme", return_value="hicolor"):
            self.assertEqual(ctl.effective_icon_theme(cfg), ("hicolor", "default-missing"))

    def test_window_rounding_tracks_theme_and_explicit_zero(self):
        cfg = ctl.Config(self.schema)
        default = ctl.window_radius(cfg)
        ctl.main(["set", "appearance.radiusScale", "1.5"])
        self.assertEqual(ctl.window_radius(ctl.Config(self.schema)), int(default * 1.5 + 0.5))
        ctl.main(["set", "hyprland.rounding", "0"])
        self.assertEqual(ctl.window_radius(ctl.Config(self.schema)), 0)
        ctl.main(["set", "hyprland.rounding", "17"])
        self.assertEqual(ctl.window_radius(ctl.Config(self.schema)), 17)

    def test_theme_catalog_data_only_install_update_remove_offline(self):
        data = ('system: "base16"\nname: "Test"\nauthor: "Test author"\nvariant: "dark"\npalette:\n'
                + ''.join(f'  base{i:02X}: "#{i:02x}{i:02x}{i:02x}"\n' for i in range(16))).encode()
        entry = theme_catalog.parse_scheme("test", data)
        catalog = {"themes": [entry], "license": "MIT test fixture"}
        root = Path(self.tmp.name)
        ctl.write_json_atomic(root / "catalogs/tinted.json", catalog)
        args = SimpleNamespace(action="install", theme="tinted-test", refresh=False)
        theme_catalog.run(args, root, "bifrost-fjord", ctl.write_json_atomic)
        installed = json.loads((root / "themes/tinted-test.json").read_text())
        self.assertEqual(installed["extends"], "_base")
        self.assertEqual(set(installed["variants"]), {"dark"})
        args.action = "browse"
        args.refresh = True
        with patch.object(theme_catalog, "fetch_catalog", side_effect=OSError("offline")):
            result = theme_catalog.run(args, root, "", ctl.write_json_atomic)
        self.assertTrue(result["offline"])
        self.assertTrue(result["themes"][0]["installed"])
        self.assertFalse(result["themes"][0]["updateAvailable"])
        args.action = "remove"
        with self.assertRaises(ValueError):
            theme_catalog.run(args, root, "tinted-test", ctl.write_json_atomic)
        theme_catalog.run(args, root, "bifrost-fjord", ctl.write_json_atomic)
        self.assertFalse((root / "themes/tinted-test.json").exists())
        for bad in ("../config", "/tmp/pwn", "tinted-../../pwn"):
            args.theme = bad
            with self.assertRaises(ValueError):
                theme_catalog.run(args, root, "", ctl.write_json_atomic)
        with self.assertRaises(ValueError):
            theme_catalog.parse_scheme("bad", data.replace(b'base0F', b'base0E'))

    def test_hidden_network_validation(self):
        self.assertEqual(network_hidden.validate(dict(ssid="Hidden", password="", interface="wlan0")), ("Hidden", "", "wlan0"))
        for data in [None, {}, dict(ssid="x"*33, interface="wlan0"), dict(ssid="x", interface="wlan0", password="short"), dict(ssid="x", interface="wlan0", password=123), dict(ssid="x", interface="wlan0;bad")]:
            with self.assertRaises(ValueError):
                network_hidden.validate(data)

    def test_brightness_keeps_valid_displays_after_partial_detection_failure(self):
        detected = "  Display 1\n I2C bus: /dev/i2c-7\n Monitor: DEL:Panel\n"
        with patch.object(brightness.Path, "glob", return_value=[]), patch.object(brightness, "run", return_value=(1, detected)), patch.object(brightness, "read_ddc", side_effect=lambda d: dict(d, value=0.5)):
            self.assertEqual(brightness.discover()[0]["id"], "ddc:7")

    def test_physical_brightness_display_identity_and_raw_maximum(self):
        devices = brightness.ddc_devices("Display 1\n I2C bus: /dev/i2c-7\n Monitor: DEL:Panel A:123\nDisplay 2\n I2C bus: /dev/i2c-9\n Monitor: ACR:Panel B:456\n")
        self.assertEqual([d["id"] for d in devices], ["ddc:7", "ddc:9"])
        with patch.object(brightness, "run", side_effect=[(0, "VCP 10 C 64 255"), (0, "")]) as run:
            brightness.set_value("ddc:9", 0.5)
            self.assertEqual(run.call_args_list[1].args[0], ["ddcutil", "--bus", "9", "setvcp", "10", "128"])
        with self.assertRaises(ValueError):
            brightness.vcp("VCP 10 C 0 0")
        with self.assertRaises(ValueError):
            brightness.set_value("ddc:7;bad", 0.5)
        with patch.object(brightness, "run", return_value=(1, "")):
            with self.assertRaises(ValueError):
                brightness.set_value("backlight:intel_backlight", 0.5)

    def test_schema_has_no_errors(self):
        self.assertEqual(self.schema.errors, [])

    def test_set_is_sparse_and_default_removes(self):
        self.assertEqual(ctl.main(["set", "bar.height", "44"]), 0)
        self.assertEqual(self.file()["values"], {"bar": {"height": 44}})
        ctl.main(["set", "bar.height", "38"])
        self.assertEqual(self.file()["values"], {})

    def test_real_default_equality_ignores_int_float(self):
        ctl.main(["set", "appearance.radiusScale", "1"])
        self.assertEqual(self.file()["values"], {})

    def test_clamp_and_reject(self):
        ctl.main(["set", "bar.height", "999"])
        self.assertEqual(self.file()["values"]["bar"]["height"], 72)
        with self.assertRaises(SystemExit):
            ctl.main(["set", "bar.height", "tall"])
        with self.assertRaises(SystemExit):
            ctl.main(["set", "bar.nope", "1"])

    def test_reset_section_keeps_others(self):
        ctl.main(["set", "bar.height", "44"])
        ctl.main(["set", "appearance.radiusScale", "1.5"])
        ctl.main(["reset", "--section", "bar"])
        self.assertEqual(self.file()["values"], {"appearance": {"radiusScale": 1.5}})

    def test_unknown_keys_are_kept(self):
        (Path(self.tmp.name) / "config.json").write_text(json.dumps({"version": 1, "values": {"future": {"x": 1}}}))
        ctl.main(["set", "bar.height", "44"])
        self.assertEqual(self.file()["values"], {"future": {"x": 1}, "bar": {"height": 44}})

    def test_newer_version_is_refused(self):
        (Path(self.tmp.name) / "config.json").write_text(json.dumps({"version": 99, "values": {}}))
        with self.assertRaises(SystemExit):
            ctl.main(["set", "bar.height", "44"])

    def test_profile_roundtrip(self):
        ctl.main(["set", "bar.height", "44"])
        ctl.main(["profile", "save", "Test"])
        ctl.main(["reset", "--all"])
        ctl.main(["profile", "load", "Test"])
        self.assertEqual(self.file()["values"], {"bar": {"height": 44}})
        self.assertTrue(any(Path(self.tmp.name, "backups").glob("config.before-profile.*")))

    def test_preset_layer(self):
        ctl.main(["preset", "set", "compact"])
        self.assertEqual(self.file()["preset"], "compact")
        cfg = ctl.Config(ctl.Schema())
        self.assertEqual(ctl.deep_get(cfg.values, "appearance.density")[0], "compact")

    def test_bundle_export_import(self):
        ctl.main(["set", "appearance.radiusScale", "1.3"])
        out = Path(self.tmp.name, "b.bifrost.json")
        ctl.main(["export", str(out)])
        ctl.main(["reset", "--all"])
        ctl.main(["import", str(out)])                      # dry run
        self.assertEqual(self.file()["values"], {})
        ctl.main(["import", str(out), "--apply"])
        self.assertEqual(self.file()["values"], {"appearance": {"radiusScale": 1.3}})

    def test_import_rejects_foreign_json(self):
        bad = Path(self.tmp.name, "x.json")
        bad.write_text("{}")
        with self.assertRaises(SystemExit):
            ctl.main(["import", str(bad)])

    def test_dms_import_from_fixture(self):
        dms = Path(self.tmp.name, "dms")
        (dms / "cfg/themes/nord").mkdir(parents=True)
        (dms / "state").mkdir()
        (dms / "cfg/settings.json").write_text(json.dumps({
            "showDock": True, "dockIconSize": 54, "showWeekNumber": True,
            "barConfigs": [{"position": 0, "autoHide": True, "autoHideStrict": False,
                            "leftWidgets": [{"id": "powerMenuButton", "enabled": True}, {"id": "workspaceSwitcher", "enabled": True}],
                            "centerWidgets": [{"id": "clock", "enabled": True}],
                            "rightWidgets": [{"id": "diskUsage", "enabled": True}, {"id": "cpuUsage", "enabled": True},
                                             {"id": "memUsage", "enabled": True}, {"id": "systemTray", "enabled": True}]}]}))
        (dms / "state/session.json").write_text(json.dumps({"wallpaperPath": "/w.jpg", "pinnedApps": ["kitty"]}))
        (dms / "cfg/themes/nord/theme.json").write_text(json.dumps({"name": "nord", "dark": {"primary": "#81A1C1", "background": "#2E3440", "surfaceText": "#ECEFF4"}}))
        os.environ["BIFROST_DMS_CONFIG"] = str(dms / "cfg")
        os.environ["BIFROST_DMS_STATE"] = str(dms / "state")
        try:
            ctl.main(["import-dms"])                          # dry run writes nothing
            self.assertFalse(Path(self.tmp.name, "config.json").exists())
            ctl.main(["import-dms", "--apply", "--themes"])
            v = self.file()["values"]
            self.assertEqual(v["wallpaper"]["path"], "/w.jpg")
            self.assertEqual(v["dock"]["pinned"], ["kitty"])
            self.assertTrue(v["bar"]["autohide"]["enabled"])
            self.assertTrue(v["bar"]["autohide"]["pinWhilePopupOpen"])
            ids = {z: [w["id"] for w in ws] for z, ws in v["bar"]["widgets"].items()}
            self.assertEqual(ids["left"], ["power", "workspaces"])
            self.assertEqual(ids["right"], ["systemStats", "tray", "settings"])
            self.assertNotIn("appearance", v)                 # visuals untouched without --appearance
            theme = json.loads(Path(self.tmp.name, "themes/dms-nord.json").read_text())
            self.assertEqual(theme["variants"]["dark"]["palette"]["accent"], "#81A1C1")
        finally:
            os.environ.pop("BIFROST_DMS_CONFIG")
            os.environ.pop("BIFROST_DMS_STATE")

    def test_hypr_generate_follows_settings(self):
        cfg = ctl.Config(ctl.Schema())
        text = ctl.generate_hypr(cfg)
        self.assertIn('namespace = "^bifrost:.*"', text)
        self.assertIn('launcher toggle', text)
        self.assertIn("gaps_in = 6", text)                    # hyprland.manage is on by default
        self.assertNotIn(os.path.expanduser("~") + "/", text)  # no personal paths
        ctl.main(["set", "hyprland.manage", "false"])
        ctl.main(["set", "keybinds.enabled", "false"])
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertNotIn("gaps_in =", text)  # appearance disabled; input still applies
        self.assertNotIn('bind("', text)

    def test_vrr_mode_selector_reapplies_same_physical_mode(self):
        output = dict(width=5120, height=1440, refresh=239.761, vrr=False)
        off = ctl.output_mode(output)
        output["vrr"] = True
        on = ctl.output_mode(output)
        self.assertNotEqual(off, on)
        for mode in (off, on):
            self.assertLess(abs(float(mode.split("@")[1]) - output["refresh"]), 0.02)
        self.assertEqual(output["refresh"], 239.761)

    def test_settings_window_blur_follows_the_one_blur(self):
        for amount, disabled in [("30", "false"), ("0", "true")]:
            ctl.main(["set", "materials.blur", amount])
            text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
            rule = next(line for line in text.splitlines() if 'window_rule("bifrost-settings"' in line)
            self.assertIn("no_blur = " + disabled, rule)

    def test_unnamed_xwayland_menu_blur(self):
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertIn('class = "^$", title = "^$", xwayland = true, float = true }, no_blur = true', text)
        self.assertNotIn('class = "^Chatgpt$"', text)
        ctl.main(["set", "hyprland.manage", "false"])
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertNotIn('window_rule("bifrost-xwayland-menu-blur"', text)
        self.assertIn('popup_rule:set_enabled(false)', text)

    def test_window_look_is_fixed_standard(self):
        """App windows: opaque, standard shadow; left alone without hyprland.manage."""
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertIn("active_opacity = 1, inactive_opacity = 1,", text)
        self.assertIn("shadow = { enabled = true, range = 20,", text)
        ctl.main(["set", "hyprland.manage", "false"])
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertNotIn("shadow = { enabled", text)
        self.assertNotIn("active_opacity", text)

    def test_window_border_colours_override_and_restore_theme(self):
        ctl.main(["set", "appearance.mode", "dark"])
        ctl.main(["set", "appearance.accent.dark", "#112233"])
        ctl.main(["set", "appearance.accent.light", "#445566"])
        ctl.main(["set", "hyprland.activeBorderColor", "#ABCDEF"])
        ctl.main(["set", "hyprland.inactiveBorderColor", "#123456"])
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertIn('active_border = "rgb(abcdef)"', text)
        self.assertIn('inactive_border = "rgb(123456)"', text)
        ctl.main(["set", "hyprland.activeBorderColor", "null"])
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertIn('active_border = "rgb(112233)"', text)
        self.assertIn('inactive_border = "rgb(123456)"', text)

    def test_one_blur_for_every_surface(self):
        """One blur amount: the compositor strength and every Bifrost layer
        follow materials.blur (ThemeLogic does the same)."""
        rule = lambda text, ns: re.search(r'bifrost-blur-%s".*' % ns, text).group(0)
        ctl.main(["set", "materials.blur", "80"])
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertIn("size = 32, passes = 5", text)          # 80 → round(1 + 80 * 0.39), passes
        for ns in ctl.BLUR_NAMESPACES:
            self.assertIn("blur = true, ignore_alpha = 0.12, blur_popups = true", rule(text, ns))
        ctl.main(["set", "materials.blur", "0"])
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertIn("blur = { enabled = false", text)
        self.assertIn("blur = false", rule(text, "dock"))
        # The Settings window is its glass: rounded like it, up to Hyprland's maximum.
        self.assertRegex(text, r'bifrost-settings".*rounding = %d, rounding_power = 2' % round(14 * 1))
        ctl.main(["set", "appearance.radiusScale", "2"])
        self.assertRegex(ctl.generate_hypr(ctl.Config(ctl.Schema())), r'bifrost-settings".*rounding = 20,')

    def test_gesture_actions_catalogue(self):
        """Gesture actions come from one catalogue (keybinds.json): the schema
        allows exactly its values, Bifrost actions reuse a bind's ipc, and the
        generator runs them through bifrost-ipc (minimize = the SUPER+M bind)."""
        acts = ctl.gesture_actions()
        values = [a["value"] for a in acts]
        self.assertEqual(sorted(values), sorted(self.schema.entries["input.gestures"]["valueOptions"]))
        by = {a["value"]: a for a in acts}
        binds = {b["id"]: b for b in ctl.keybind_defaults()["binds"]}
        self.assertEqual(by["minimize"]["ipc"], binds["minimize"]["ipc"])
        self.assertEqual(by["restore-minimized"]["ipc"], "wm restoreLast")
        self.assertEqual(by["close"], {"value": "close", "label": "Close window", "native": "close"})
        cfg = ctl.Config(ctl.Schema())
        cfg.set("input.gestures", {"3:down": "minimize", "3:up": "restore-minimized", "4:horizontal": "workspace", "4:up": "launcher", "4:down": "none"})
        cfg.save()
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertIn('if pcall(hl.gesture, {fingers=3, direction="down", action=function() hl.exec_cmd(bin .. "bifrost-ipc wm minimizeActive") end}) then', text)
        self.assertIn('if pcall(hl.gesture, {fingers=3, direction="up", action=function() hl.exec_cmd(bin .. "bifrost-ipc wm restoreLast") end}) then', text)
        self.assertIn('if pcall(hl.gesture, {fingers=4, direction="horizontal", action="workspace"}) then', text)
        self.assertIn('bifrost-ipc launcher toggle', text)
        self.assertNotIn('direction="down", action="none"', text)
        path = Path(self.tmp.name) / "gestures.lua"
        path.write_text(text + "\n" + text)   # applied twice: no duplicate slots
        ok, msg = ctl.verify_hypr(path)
        self.assertTrue(ok, msg)

    def test_shadowed_gesture_does_not_abort_binds(self):
        """3:up with 3:swipe: Hyprland rejects a specific gesture after a
        general one, so the specific one is registered first and both load
        (and a rejected gesture would not stop the file, pcall)."""
        cfg = ctl.Config(ctl.Schema())
        cfg.set("input.gestures", {"3:swipe": "move", "3:up": "restore-minimized"})
        cfg.save()
        text = ctl.generate_hypr(ctl.Config(ctl.Schema()))
        self.assertLess(text.index('direction="up"'), text.index('direction="swipe"'))
        self.assertLess(text.index("restoreLast\") end})"), text.index('bind("SUPER + M"'))
        path = Path(self.tmp.name) / "shadowed.lua"
        path.write_text(text)
        ok, msg = ctl.verify_hypr(path)
        self.assertTrue(ok, msg)

    def test_binds_call_the_installed_shell(self):
        """IPC binds run the install's bifrost-ipc (it reaches the session's
        shell), also when bifrostctl runs from a checkout next to a copied
        install; a checkout's own bin only without any install."""
        data = Path(self.tmp.name) / "data"
        os.environ["XDG_DATA_HOME"] = str(data)
        try:
            self.assertIn(str(ctl.REPO / "bin"), ctl.install_bin_lua().replace('os.getenv("HOME") .. "', os.path.expanduser("~")).replace('"', ""))
            (data / "bifrost-shell" / "bin").mkdir(parents=True)
            (data / "bifrost-shell" / "bin" / "bifrost-ipc").write_text("#!/bin/sh\n")
            self.assertIn("bifrost-shell/bin/", ctl.install_bin_lua())
            self.assertNotIn(str(ctl.REPO), ctl.install_bin_lua())
        finally:
            del os.environ["XDG_DATA_HOME"]

    def test_migrate_4_to_6_blur_amounts(self):
        doc = {"version": 4, "values": {"materials": {"blurStrength": 49, "bar": {"blur": True}, "dock": {"blur": False}}}}
        self.assertEqual(ctl.migrate(doc)["values"]["materials"], {"blur": 49})

    def test_migrate_5_to_6_one_glass(self):
        """Same as Migrations.js step 5 (selftest testMigrations)."""
        doc = {"version": 5, "values": {
            "materials": {"link": True, "unlinked": ["dock"], "all": {"transparency": 44, "blur": 22, "tint": "#0F1516", "thickness": 0, "glow": 0.25}, "dock": {"transparency": 100}},
            "appearance": {"prism": {"enabled": False, "intensity": 2}, "spacingScale": 1.5, "radiusScale": 2},
            "hyprland": {"windows": {"activeTransparency": 10, "inactiveTransparency": 20}, "gapsIn": 3},
            "settingsUI": {"layout": "boxed"}}}
        out = ctl.migrate(doc)
        self.assertEqual(out["version"], ctl.FORMAT_VERSION)
        v = out["values"]
        self.assertEqual(v["materials"], {"transparency": 44, "blur": 22, "tint": {"light": "#0F1516", "dark": "#0F1516"}})
        self.assertEqual(v["appearance"], {"prism": {"intensity": 0}, "radiusScale": 2, "density": "spacious"})
        self.assertEqual(v["hyprland"], {"gapsIn": 3})
        self.assertNotIn("settingsUI", v)

    def test_migrate_7_to_8_faint_panel(self):
        doc = {"version": 7, "values": {"bar": {"background": "subtle", "height": 40}}}
        self.assertEqual(ctl.migrate(doc)["values"]["bar"], {"background": "panel", "height": 40})

    def test_bar_without_panel_blurs_by_its_boxes(self):
        rule = lambda: re.search(r'bifrost-blur-bar".*', ctl.generate_hypr(ctl.Config(ctl.Schema()))).group(0)
        ctl.main(["set", "materials.blur", "40"])
        self.assertIn("blur = true,", rule())
        ctl.main(["set", "bar.background", "none"])
        ctl.main(["set", "bar.widgetStyle", "boxed"])
        ctl.main(["set", "bar.boxes.blur", "false"])
        self.assertIn("blur = false,", rule())
        ctl.main(["set", "bar.boxes.blur", "true"])
        self.assertIn("blur = true,", rule())
        ctl.main(["set", "bar.background", "panel"])
        ctl.main(["set", "bar.boxes.blur", "false"])
        self.assertIn("blur = true,", rule())   # the panel decides

    def test_migrate_6_to_7_colours_per_mode(self):
        doc = {"version": 6, "values": {"appearance": {"accent": "#123456"}, "materials": {"tint": "#0F1516", "blur": 5}}}
        v = ctl.migrate(doc)["values"]
        self.assertEqual((v["appearance"]["accent"], v["materials"]["tint"]), ({"light": "#123456", "dark": "#123456"}, {"light": "#0F1516", "dark": "#0F1516"}))

    def test_panel_windows_mask_their_shadow(self):
        """A panel window grown by its glass's shadow reaches over the bar;
        without an input mask it takes the bar's hover (see LeaveWatch)."""
        for f in (ctl.REPO / "shell").rglob("*.qml"):
            s = f.read_text()
            if "PanelWindow" in s and re.search(r"margins\.\w+:.*- glass\.shadowExtent", s):
                self.assertRegex(s, r"\bmask:", f"{f.relative_to(ctl.REPO)} needs an input mask")

    def test_swedish_translation_is_complete(self):
        """Every schema text and every I18n.tr() literal has a Swedish entry."""
        sv = json.loads((ctl.REPO / "i18n/sv.json").read_text())
        texts = set()
        idx = json.loads((ctl.REPO / "schema/index.json").read_text())
        for c in idx["categories"]:
            texts.add(c["label"])
            texts.update(p["label"] for p in c.get("pages", []))
        for f in (ctl.REPO / "schema").glob("*.json"):
            if f.name in ("index.json", "widgets.json"):
                continue
            d = json.loads(f.read_text())
            texts.update(x for x in (d.get("label"), d.get("description")) if x)
            texts.update(d.get("groups", {}).values())
            for st in d.get("settings", []):
                texts.update(x for x in (st.get("label"), st.get("description"), st.get("nullLabel")) if x)
                texts.update(st.get("optionLabels", {}).values())
            t = d.get("template") or {}
            for inst in t.get("instances", []):
                texts.update(x for x in (inst.get("label"), inst.get("description")) if x)
            for st in t.get("settings", []):
                texts.update(x for x in (st.get("label"), st.get("description"), st.get("nullLabel")) if x)
        kb = json.loads((ctl.REPO / "hypr/keybinds.json").read_text())
        texts.update(kb["groups"].values())
        texts.update(b["description"] for b in kb["binds"] + kb["actions"])
        texts.update(g["label"] for g in ctl.gesture_actions())
        texts.update(b.get("label", b["description"]) for b in ctl.default_keybinds(ctl.Config(ctl.Schema())))
        for f in (ctl.REPO / "shell").rglob("*.qml"):
            if f.name in ("selftest.qml", "I18n.qml"):
                continue
            texts.update(re.findall(r'I18n\.tr\("((?:[^"\\]|\\.)*)"', f.read_text()))
        for f in (ctl.REPO / "shell").rglob("*.js"):
            texts.update(re.findall(r'\btr\("((?:[^"\\]|\\.)*)"', f.read_text()))
        same = {"Bifrost", "Bluetooth", "Shell", "System", "Launcher", "Dock", "OSD", "GPU", "GB", "Media", "Popups", "Layout", "Integration",
                "Workspaces", "Widgets", "Standard", "Terminal", "Boxed", "Integrated", "Top bar", "Control center", "Autohide", "Import & export",
                "Widgets & info", "Monospace", "Processor", "Version %1", "%1 min", "%1 h", "Bifrost Settings", "System & GPU",
                "Workspace %1"}
        missing = sorted(t for t in texts if t not in sv and t not in same)
        self.assertEqual(missing, [])

    def test_keybinds_have_no_duplicates_and_follow_settings(self):
        norm = lambda k: k.replace(" ", "").lower()
        binds = ctl.effective_keybinds(ctl.Config(ctl.Schema()))
        keys = [norm(b["keys"]) for b in binds]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertEqual(sum(1 for b in binds if b.get("run") == "bifrost-terminal"), 1)
        self.assertIn(norm("SUPER + space"), keys)
        ctl.main(["set", "keybinds.custom", '["SUPER + X: ipc controlcenter toggle", "SUPER + Z: run bifrost-settings"]'])
        ctl.main(["set", "keybinds.disabled", '["SUPER + Q"]'])
        ctl.main(["set", "keybinds.workspaceStyle", "moveFollow"])
        ctl.main(["set", "keybinds.groups.screenshots", "false"])
        binds = ctl.effective_keybinds(ctl.Config(ctl.Schema()))
        by = {norm(b["keys"]): b for b in binds}
        self.assertEqual(by[norm("SUPER + X")].get("ipc"), "controlcenter toggle")
        self.assertNotIn(norm("SUPER + Q"), by)
        self.assertNotIn(norm("Print"), by)
        self.assertIn("follow = true", by[norm("SUPER + code:10")]["dispatch"])
        self.assertIn(norm("SUPER + ALT + code:10"), by)
        self.assertEqual(len(by), len(binds))

    def test_login_status_and_switch_reject_uninstalled(self):
        root = Path(self.tmp.name)
        prefix = root / "share"
        conf = root / "config.toml"
        manager = root / "display-manager.service"
        unit = root / "gdm.service"
        unit.touch()
        manager.symlink_to(unit)
        conf.write_text('[default_session]\ncommand = "agreety"\nuser = "greeter"\n')
        status = ctl.greeter_status(prefix, conf, manager)
        self.assertFalse(status["installed"])
        self.assertFalse(status["canEnable"])
        self.assertEqual(status["displayManager"], "gdm")
        with patch.object(ctl, "greeter_status", return_value=status), patch.object(ctl.subprocess, "run") as run:
            self.assertFalse(ctl.greeter_switch("enable")["ok"])
            run.assert_not_called()
        (prefix / "bin").mkdir(parents=True)
        launcher = prefix / "bin/bifrost-greeter"
        launcher.write_text("#!/bin/sh\n")
        launcher.chmod(0o755)
        (prefix / "greeter").mkdir()
        (prefix / "greeter/manage-login.py").touch()
        self.assertTrue(ctl.greeter_status(prefix, conf, manager)["canEnable"])
        self.assertFalse(ctl.greeter_status(prefix, conf, manager)["enabled"])

    def test_login_manager_switch_and_rollback_do_not_stop_session(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("login_manager", ctl.REPO / "greeter/manage-login.py")
        manager = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(manager)
        root = Path(self.tmp.name)
        state = root / "state/previous.json"
        with patch.object(manager, "STATE", state), patch.object(manager, "current_manager", return_value="gdm.service"), patch.object(manager.Path, "is_file", return_value=True), patch.object(manager, "run") as run:
            manager.switch("enable")
            self.assertEqual(json.loads(state.read_text())["previous"], "gdm.service")
            calls = [c.args for c in run.call_args_list]
            self.assertIn(("/usr/bin/systemctl", "enable", "--force", "greetd.service"), calls)
            self.assertFalse(any(x in c for c in calls for x in ("--now", "stop", "restart")))
        with patch.object(manager, "STATE", state), patch.object(manager, "current_manager", return_value="greetd.service"), patch.object(manager, "run") as run:
            manager.switch("disable")
            self.assertFalse(state.exists())
            run.assert_any_call("/usr/bin/systemctl", "enable", "--force", "gdm.service")
        with patch.object(manager, "STATE", state), patch.object(manager, "current_manager", return_value="gdm.service"), patch.object(manager.Path, "is_file", return_value=True), patch.object(manager, "run") as run:
            run.side_effect = [None, None, RuntimeError("failed to enable"), None, None, None]
            with self.assertRaises(RuntimeError):
                manager.switch("enable")
            self.assertFalse(state.exists())
            run.assert_any_call("/usr/bin/systemctl", "enable", "--force", "gdm.service")

    def test_greeter_sync_copies_the_look_not_the_home(self):
        cache = Path(self.tmp.name) / "greeter-cache"
        self.assertFalse(ctl.greeter_sync(ctl.Config(ctl.Schema()), cache)["ok"])   # not installed
        cache.mkdir()
        wall = Path(self.tmp.name) / "wall.PNG"
        wall.write_bytes(b"png")
        face = Path(self.tmp.name) / "me.jpg"
        face.write_bytes(b"jpg")
        for k, val in (("wallpaper.path", str(wall)), ("greeter.avatar", str(face)), ("appearance.mode", "system"),
                       ("appearance.accent.dark", "#112233"), ("bar.height", 44)):
            self.assertEqual(ctl.main(["set", k, json.dumps(val)]), 0)
        (Path(self.tmp.name) / "themes").mkdir()
        (Path(self.tmp.name) / "themes" / "mine.json").write_text("{}")
        kb = {"layout": "se,us", "variant": "", "options": ""}
        r = ctl.greeter_sync(ctl.Config(ctl.Schema()), cache, keyboard=kb)
        self.assertTrue(r["ok"] and r["wallpaper"] and r["avatar"])
        values = json.loads((cache / "config/config.json").read_text())["values"]
        self.assertEqual(values["wallpaper"]["path"], str(cache / "wallpaper.png"))
        self.assertIn(values["appearance"]["mode"], ("light", "dark"))      # resolved, the greeter has no system setting
        self.assertEqual(values["appearance"]["accent"], {"dark": "#112233"})
        self.assertNotIn("bar", values)
        self.assertTrue((cache / "config/themes/mine.json").is_file())
        meta = json.loads((cache / "greeter.json").read_text())
        me = meta["users"][-1]
        self.assertEqual(me["avatar"], str(cache / "avatars" / (me["name"] + ".jpg")))
        self.assertEqual(meta["keyboard"], kb)
        self.assertIn('kb_layout = "se,us"', (cache / "hypr/local.lua").read_text())
        # Nothing in the cache points back into the home directory.
        for f in cache.rglob("*"):
            self.assertFalse(f.is_symlink(), f)
        self.assertNotIn(self.tmp.name + "/wall", (cache / "config/config.json").read_text())
        # A removed picture or wallpaper is removed from the copy too.
        ctl.main(["reset", "greeter.avatar"])
        ctl.main(["reset", "wallpaper.path"])
        r = ctl.greeter_sync(ctl.Config(ctl.Schema()), cache, keyboard=kb)
        self.assertFalse(r["wallpaper"] or r["avatar"])
        self.assertEqual(list(cache.glob("wallpaper.*")) + list((cache / "avatars").iterdir()), [])

    def test_greeter_install_enable_disable_restores_the_config(self):
        import subprocess
        root = Path(self.tmp.name) / "root"
        conf = root / "greetd.toml"
        root.mkdir()
        original = '[terminal]\nvt = 1\n\n[default_session]\ncommand = "/usr/bin/dms-greeter --command hyprland"\nuser = "greeter"\n'
        conf.write_text(original)
        env = dict(os.environ, BIFROST_GREETER_PREFIX=str(root / "share"), BIFROST_GREETER_CACHE=str(root / "cache"), GREETD_CONFIG=str(conf))
        script = str(Path(__file__).parent.parent / "greeter" / "install-greeter.sh")
        sh = lambda *a: subprocess.run([script, *a], env=env, capture_output=True, text=True)
        self.assertNotEqual(sh("--enable").returncode, 0)          # not installed yet
        self.assertEqual(conf.read_text(), original)
        self.assertEqual(sh().returncode, 0)
        self.assertTrue((root / "share/bin/bifrost-greeter").is_file() and (root / "share/shell/greeter.qml").is_file())
        self.assertEqual(conf.read_text(), original)               # install alone leaves greetd alone
        home = os.path.expanduser("~")
        leaks = [str(f) for f in (root / "share").rglob("*") if f.is_file() and home.encode() in f.read_bytes()]
        self.assertEqual(leaks, [])                                # nothing personal is installed
        self.assertEqual([f for f in (root / "share").rglob("*") if f.is_symlink()], [])
        self.assertEqual(sh("--enable").returncode, 0)
        self.assertIn(f'command = "{root}/share/bin/bifrost-greeter"', conf.read_text())
        self.assertIn('user = "greeter"', conf.read_text())
        self.assertEqual(len(list(root.glob("greetd.toml.before-bifrost-*"))), 1)
        self.assertEqual(sh("--disable").returncode, 0)
        self.assertEqual(conf.read_text(), original)
        self.assertIn("Nothing changed", sh("--disable").stdout)

    def test_screen_timeout_lets_input_wake_the_screens(self):
        self.assertNotIn("enables_dpms", ctl.generate_hypr(ctl.Config(ctl.Schema())))
        self.assertEqual(ctl.main(["set", "power.idle.screenOffMinutes", "5"]), 0)
        self.assertIn("key_press_enables_dpms = true, mouse_move_enables_dpms = true", ctl.generate_hypr(ctl.Config(ctl.Schema())))
        with self.assertRaises(SystemExit):
            ctl.main(["set", "power.idle.screenOffMinutes", "7"])
        self.assertEqual(ctl.main(["set", "power.idle.lockMinutes", "15"]), 0)
        self.assertEqual(self.file()["values"]["power"]["idle"], {"screenOffMinutes": 5, "lockMinutes": 15})

    def test_keybind_keys_are_canonical(self):
        self.assertEqual(ctl.canon_keys("shift + super + q"), "SUPER + SHIFT + Q")
        self.assertEqual(ctl.canon_keys("CONTROL+Print"), "CTRL + Print")
        self.assertIsNone(ctl.canon_keys("SUPER + A + B"))
        self.assertIsNone(ctl.canon_keys("SUPER + "))
        self.assertEqual(ctl.keys_id("SUPER + code:10"), ctl.keys_id("super + 1"))
        self.assertEqual(ctl.keys_id("SUPER + SHIFT + Space"), ctl.keys_id("shift+super+space"))

    def test_keybind_editor_set_off_reset_add_and_conflicts(self):
        cfg = lambda: ctl.Config(ctl.Schema())
        entries = lambda live=None: {e["id"]: e for e in ctl.keybind_entries(cfg(), live)}
        self.assertTrue(all(e["state"] == "default" for e in entries().values()))
        # A combination in use is refused with its user; --force turns the other off.
        r = ctl.keybind_edit(cfg(), "set", "launcher", "SUPER + Q")
        self.assertFalse(r["ok"])
        self.assertEqual([c["id"] for c in r["conflicts"]], ["close-window"])
        self.assertTrue(ctl.keybind_edit(cfg(), "set", "launcher", "q + super", force=True)["ok"])
        e = entries()
        self.assertEqual((e["launcher"]["keys"], e["launcher"]["state"]), ("SUPER + Q", "changed"))
        self.assertEqual(e["close-window"]["state"], "off")
        binds = {ctl.keys_id(b["keys"]): b for b in ctl.effective_keybinds(cfg())}
        self.assertEqual(binds[ctl.keys_id("SUPER + Q")].get("ipc"), "launcher toggle")
        self.assertNotIn(ctl.keys_id("SUPER + space"), binds)
        # Back to the default keys = no override stored.
        self.assertTrue(ctl.keybind_edit(cfg(), "set", "launcher", "SUPER + space")["ok"])
        self.assertNotIn("launcher", self.file()["values"]["keybinds"].get("overrides", {}))
        self.assertTrue(ctl.keybind_edit(cfg(), "reset", "close-window")["ok"])
        self.assertEqual(entries()["close-window"]["state"], "default")
        # Own binds: add, move, remove; a default on the same keys is "replaced".
        self.assertTrue(ctl.keybind_edit(cfg(), "add", keys="SUPER + K", action="ipc controlcenter toggle")["ok"])
        self.assertEqual(entries()["custom:0"]["label"], "Control center")
        self.assertFalse(ctl.keybind_edit(cfg(), "add", keys="SUPER + J", action="nonsense")["ok"])
        self.assertTrue(ctl.keybind_edit(cfg(), "set", "custom:0", "SUPER + N", force=True)["ok"])
        e = entries()
        self.assertEqual((e["custom:0"]["keys"], e["notifications"]["state"]), ("SUPER + N", "off"))
        self.assertTrue(ctl.keybind_edit(cfg(), "off", "custom:0")["ok"])
        self.assertNotIn("custom:0", entries())
        self.assertTrue(ctl.keybind_edit(cfg(), "reset", None)["ok"])
        self.assertTrue(all(e["state"] == "default" for e in entries().values()))
        # The compositor's own binds are shown read-only and count as conflicts.
        live = [("SUPER + W", "Wallpaper selector"), ("SUPER + space", "Launcher")]
        e = entries(live)
        self.assertEqual([x["label"] for x in e.values() if x["source"] == "external"], ["Wallpaper selector"])
        self.assertEqual([c["id"] for c in ctl.keybind_conflicts(cfg(), "launcher", "super + w", live)], ["external:0"])
        self.assertFalse(ctl.keybind_edit(cfg(), "off", "external:0", live=live)["ok"])
        # Workspace digits keep their ids when the style changes.
        ctl.main(["set", "keybinds.workspaceStyle", "moveFollow"])
        e = entries()
        self.assertEqual(e["workspace-3"]["keys"], "SUPER + ALT + code:12")
        self.assertEqual((e["move-follow-3"]["label"], e["move-follow-3"]["arg"]), ("Move window to workspace %1 and follow", "3"))

    @unittest.skipUnless(ctl.shutil.which("Hyprland"), "Hyprland not installed")
    def test_hypr_file_verifies_and_breakage_is_caught(self):
        self.assertEqual(ctl.main(["hypr", "generate", "--write"]), 0)
        ok, _ = ctl.verify_hypr(ctl.hypr_file())
        self.assertTrue(ok)
        # A saved display adds the VRR revisit timer; verification must not crash on it.
        self.assertEqual(ctl.main(["set", "displays.outputs", json.dumps({"DP-9": {"width": 1920, "height": 1080, "refresh": 60, "x": 0, "y": 0, "scale": 1, "vrr": False}})]), 0)
        self.assertEqual(ctl.main(["hypr", "generate", "--write"]), 0)
        self.assertIn("hl.timer", ctl.hypr_file().read_text())
        ok, msg = ctl.verify_hypr(ctl.hypr_file())
        self.assertTrue(ok, msg)
        ctl.hypr_file().write_text('hl.layer_rule({ match = { namespace = "x" }, not_a_field = true })')
        ok, msg = ctl.verify_hypr(ctl.hypr_file())
        self.assertFalse(ok)
        self.assertIn("not_a_field", msg)

    def test_production_checks_are_read_only(self):
        before = sorted(p.name for p in Path(self.tmp.name).rglob("*"))
        rows = ctl.production_checks(ctl.Config(ctl.Schema()))
        self.assertTrue(any(name == "bifrost.lua" for _, name, _ in rows))
        self.assertEqual(sorted(p.name for p in Path(self.tmp.name).rglob("*")), before)

    def test_terminal_wrapper_runs_a_command_in_any_terminal(self):
        import subprocess
        fake = Path(self.tmp.name) / "bin"
        fake.mkdir()
        for t in ("kitty", "alacritty", "wezterm", "gnome-terminal", "xfce4-terminal"):
            (fake / t).write_text(f'#!/bin/sh\nprintf "%s|" {t} "$@"\n')
            (fake / t).chmod(0o755)
        wrapper = Path(__file__).parent.parent / "bin" / "bifrost-terminal"
        def run(terminal, *args):
            env = dict(os.environ, TERMINAL=terminal, PATH=f"{fake}:/usr/bin:/bin")
            return subprocess.run([str(wrapper), *args], env=env, capture_output=True, text=True).stdout
        self.assertEqual(run("kitty", "btop"), "kitty|btop|")
        self.assertEqual(run("alacritty", "btop"), "alacritty|-e|btop|")
        self.assertEqual(run("wezterm", "btop"), "wezterm|start|--|btop|")
        self.assertEqual(run("gnome-terminal", "btop"), "gnome-terminal|--|btop|")
        self.assertEqual(run("xfce4-terminal", "sh", "-c", "a b"), "xfce4-terminal|-x|sh|-c|a b|")
        self.assertEqual(run("alacritty --class x"), "alacritty|--class|x|")
        self.assertEqual(self.schema.entries["bar.systemStatus.clickCommand"]["default"].split()[0], "bifrost-terminal")

    def test_bluetooth_agent_against_fake_bluez(self):
        import shutil
        import subprocess
        if not shutil.which("dbus-run-session"):
            self.skipTest("dbus-run-session missing")
        try:
            import gi  # noqa: F401
        except ImportError:
            self.skipTest("python-gobject missing")
        harness = Path(__file__).parent / "dev" / "bt_agent_harness.py"
        out = subprocess.run(["dbus-run-session", "--", sys.executable, str(harness)], capture_output=True, text=True, timeout=60)
        r = json.loads(out.stdout)
        self.assertEqual(r["registered"], ["/org/bifrost/bluetooth/agent", "KeyboardDisplay"])
        self.assertEqual(r["default"], "/org/bifrost/bluetooth/agent")
        self.assertEqual(r["confirm:request"], {"kind": "confirm", "name": "Test Keyboard", "passkey": "000042"})
        self.assertEqual(r["confirm"], {"value": []})
        self.assertEqual(r["confirm-reject"], {"error": "org.bluez.Error.Rejected"})
        self.assertEqual(r["passkey"], {"value": [123456]})
        self.assertEqual(r["passkey-bad"], {"error": "org.bluez.Error.Rejected"})
        self.assertEqual(r["pin"], {"value": ["0000"]})
        self.assertEqual(r["service-unknown:request"]["kind"], "service")
        self.assertNotIn("service-trusted:request", r)
        self.assertEqual([e["event"] for e in r["display"]], ["request", "update", "done"])
        self.assertEqual(r["display"][0]["passkey"], "001234")
        self.assertEqual(r["authorize"], {"error": "org.bluez.Error.Canceled"})
        self.assertEqual(r["exit"], 0)
        self.assertEqual(out.stderr.strip(), "")

    def test_version_tuple(self):
        self.assertLess(ctl.version_tuple("0.54.9"), ctl.version_tuple("0.55"))
        self.assertEqual(ctl.version_tuple("v0.56.2-dirty"), (0, 56, 2))


if __name__ == "__main__":
    unittest.main()
