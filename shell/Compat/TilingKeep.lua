-- Settings → Windows & compositor → Tiling: when a tiled window closes.
-- Hyprland 0.56: at "window.close" the other windows still have their old
-- geometry; the layout recalculates afterwards. When exactly one tiled window
-- is left on the workspace, "keep"/"keepResize" float it at that geometry
-- (resize before move: resizing a floating window keeps its centre). "keep"
-- tiles it again as soon as a new tiled window opens on that workspace, so
-- the normal layout comes back; "keepResize" leaves it floating (and freely
-- resizable) until it is tiled by hand. "fill" (Hyprland's own behaviour)
-- registers nothing. state.tiling_close is read at every event, so a change
-- in Settings applies without re-registering.
return function(state)
    state.tiling_kept = state.tiling_kept or {}
    if state.tiling_hooks or (state.tiling_close or "fill") == "fill" then return end
    state.tiling_hooks = true
    local kept = state.tiling_kept
    local function xy(v) return v.x or v[1], v.y or v[2] end

    hl.on("window.close", function(w)
        if not w then return end
        kept[w.address] = nil
        local mode = state.tiling_close or "fill"
        if mode == "fill" or w.floating or not w.workspace then return end
        local left = {}
        for _, o in ipairs(hl.get_workspace_windows(w.workspace.id)) do
            if o.address ~= w.address and o.mapped and not o.hidden and not o.floating then
                left[#left + 1] = o
            end
        end
        if #left ~= 1 or (left[1].fullscreen or 0) ~= 0 then return end
        local s = left[1]
        local x, y = xy(s.at)
        local sw, sh = xy(s.size)
        local target = "address:" .. s.address
        hl.dispatch(hl.dsp.window.float({ action = "set", window = target }))
        hl.dispatch(hl.dsp.window.resize({ x = sw, y = sh, window = target }))
        hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = target }))
        kept[s.address] = { workspace = w.workspace.id, mode = mode }
    end)

    -- Re-tiled after the new window has its place in the layout: tiling it
    -- inside the open event splits against a tree that doesn't hold the new
    -- window yet (both end up full size, side by side).
    hl.on("window.open", function(w)
        if not w or w.floating or not w.workspace then return end
        local ws = w.workspace.id
        local back = {}
        for address, k in pairs(kept) do
            if k.mode == "keep" and k.workspace == ws then
                kept[address] = nil
                back[#back + 1] = address
            end
        end
        if #back == 0 then return end
        hl.timer(function()
            for _, address in ipairs(back) do
                local o = hl.get_window("address:" .. address)
                if o and o.floating and o.workspace and o.workspace.id == ws then
                    hl.dispatch(hl.dsp.window.float({ action = "unset", window = "address:" .. address }))
                end
            end
        end, { timeout = 1, type = "oneshot" })
    end)
end
