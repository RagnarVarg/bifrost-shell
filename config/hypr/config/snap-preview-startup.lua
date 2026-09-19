-- Dedicated preview startup, without unrelated legacy autostart commands.
hl.on("hyprland.start", function()
    hl.exec_cmd('qs -n -d -p "@HOME@/.config/hypr/scripts/snap-preview/shell.qml"')
end)
