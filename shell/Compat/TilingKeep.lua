-- Settings → Windows & compositor → Tiling: when a tiled window closes.
-- Hyprland 0.56: at "window.close" the other windows still have their old
-- geometry; the layout recalculates afterwards. When exactly one tiled window
-- is left on the workspace, "keep"/"keepResize" float it at that geometry
-- (resize before move: resizing a floating window keeps its centre). "keep"
-- tiles it again as soon as a new tiled window opens on that workspace, on
-- the side it was on and at its size, so the new window takes the free
-- space; "keepResize" leaves it floating (and freely resizable) until it is
-- tiled by hand. "fill" (Hyprland's own behaviour)
-- registers nothing. Every run replaces the previous run's event handlers,
-- so a new version or a change in Settings applies at once.
return function(state)
    for _, sub in ipairs(state.tiling_subs or {}) do pcall(function() sub:remove() end) end
    state.tiling_subs = {}
    -- tiling_keep, not tiling_kept: handlers of the first version (never
    -- removable, gone after a Hyprland restart) clear that table.
    state.tiling_keep = state.tiling_keep or {}
    if (state.tiling_close or "fill") == "fill" then
        state.tiling_keep = {}
        return
    end
    local kept = state.tiling_keep
    local subs = state.tiling_subs
    local function xy(v) return v.x or v[1], v.y or v[2] end

    subs[#subs + 1] = hl.on("window.close", function(w)
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
        kept[s.address] = { workspace = w.workspace.id, mode = mode, x = x, y = y, w = sw, h = sh }
    end)

    -- The layout puts a re-tiled window next to the focused one, on either
    -- side and at half the space: swap it back to the side it was on, then
    -- give it its size (dwindle moves the split), so the new window fills
    -- the free space.
    local function later(fn) hl.timer(fn, { timeout = 1, type = "oneshot" }) end

    -- Each step after the previous one has reached the layout: a resize
    -- right after a swap lands on the node the window just left. An exact
    -- resize moves a split from the window's left/top, so a window right of
    -- or below the new one gets its size by resizing the new one instead.
    local function resize_to(target, k, other)
        local o, n = hl.get_window(target), other and hl.get_window(other)
        if not o or o.floating then return end
        if not n or n.floating then
            hl.dispatch(hl.dsp.window.resize({ x = k.w, y = k.h, window = target }))
            return
        end
        local ox, oy = xy(o.at)
        local ow, oh = xy(o.size)
        local nx, ny = xy(n.at)
        local nw, nh = xy(n.size)
        if ox > nx or oy > ny then
            hl.dispatch(hl.dsp.window.resize({ x = ox > nx and nw + ow - k.w or nw, y = oy > ny and nh + oh - k.h or nh, window = other }))
        else
            hl.dispatch(hl.dsp.window.resize({ x = k.w, y = k.h, window = target }))
        end
    end

    local function restore(address, k, other)
        local target = "address:" .. address
        local o = hl.get_window(target)
        if not o or o.floating then return end
        local x, y = xy(o.at)
        local ow, oh = xy(o.size)
        local dx = (k.x + k.w / 2) - (x + ow / 2)
        local dy = (k.y + k.h / 2) - (y + oh / 2)
        if math.abs(dx) >= math.abs(dy) and math.abs(dx) > ow / 4 then
            hl.dispatch(hl.dsp.window.swap({ direction = dx < 0 and "l" or "r", window = target }))
        elseif math.abs(dy) > oh / 4 then
            hl.dispatch(hl.dsp.window.swap({ direction = dy < 0 and "u" or "d", window = target }))
        end
        later(function() resize_to(target, k, other) end)
    end

    -- Re-tiled after the new window has its place in the layout: tiling it
    -- inside the open event splits against a tree that doesn't hold the new
    -- window yet (both end up full size, side by side).
    subs[#subs + 1] = hl.on("window.open", function(w)
        if not w or w.floating or not w.workspace then return end
        local ws = w.workspace.id
        local back = {}
        for address, k in pairs(kept) do
            if k.mode == "keep" and k.workspace == ws then
                kept[address] = nil
                back[address] = k
            end
        end
        if next(back) == nil then return end
        later(function()
            for address, k in pairs(back) do
                local o = hl.get_window("address:" .. address)
                if o and o.floating and o.workspace and o.workspace.id == ws then
                    hl.dispatch(hl.dsp.window.float({ action = "unset", window = "address:" .. address }))
                end
            end
            later(function()
                for address, k in pairs(back) do restore(address, k, "address:" .. w.address) end
            end)
        end)
    end)
end
