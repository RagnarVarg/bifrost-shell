-- DMS user keybind overrides (edit via Control Center or dms; do not remove this header)

hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
hl.gesture({ fingers = 4, direction = "up", action = "float" })
hl.gesture({ fingers = 4, direction = "down", action = "close" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- Hyprland 0.56: pinchout = fingers together; pinchin = fingers apart.
hl.gesture({ fingers = 4, direction = "pinchout", action = function()
    hl.exec_cmd("qs ipc -p @HOME@/.config/DankMaterialShell/shell/shell.qml call hypr openOverview")
end })
hl.gesture({ fingers = 4, direction = "pinchin", action = function()
    hl.exec_cmd("qs ipc -p @HOME@/.config/DankMaterialShell/shell/shell.qml call hypr closeOverview")
end })

hl.unbind("SUPER + SHIFT + Space")
hl.bind("SUPER + SHIFT + Space", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/floatmode-toggle.sh"), { description = "Toggle global floating/tiling mode" })
hl.unbind("SUPER + W")
hl.bind("SUPER + W", hl.dsp.exec_cmd("quickshell -n -c wallpaper-selector"), { description = "Wallpaper selector" })
