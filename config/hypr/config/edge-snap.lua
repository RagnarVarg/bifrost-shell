-- GNOME-style edge snapping for floating windows: a live preview while
-- dragging, snapping only on a REAL release (never on a pause), and
-- restoring the pre-snap floating size when a snapped window is grabbed
-- again. Replaces the old settle-based polling approximation.
--
-- Release detection, verified against Hyprland 0.56.2's own source
-- (not guessed):
--   - Mouse (SUPER + drag): hl.bind supports a genuine release-phase
--     callback on the same button already used for dragging
--     ({ mouse = true, release = true }), confirmed by testing it live
--     against the running compositor - it coexists with the existing
--     press-triggered drag bind without conflict.
--   - 3-finger trackpad swipe: hl.gesture accepts a custom
--     { start, update, finish } callback table (instead of the built-in
--     action = "move" string). Confirmed from Hyprland's own source
--     (src/managers/input/trackpad/gestures/LuaFunctionGesture.cpp +
--     LuaBindingsConfigRules.cpp): the `finish` callback receives a real
--     `cancelled` boolean from the input backend - a true release signal,
--     not a heuristic.
--
-- Only the one window being dragged is ever touched; nothing else is
-- reflowed or refocused. The preview rectangle is drawn by a fully
-- separate Quickshell process (scripts/snap-preview/shell.qml, launched
-- from autostart.lua) controlled via a small state file - zero
-- dependency on, or risk to, the main DMS shell/topbar/dock.

local MOD = "SUPER" -- matches dms/binds.lua's mainMod; kept local since that
-- file's `local mainMod` isn't visible from here.

local EDGE_THRESHOLD = 48 -- px from a usable-area edge that counts as "at the edge"
local MOUSE_PREVIEW_POLL_MS = 33 -- ~30fps live preview during mouse drag only
local PREVIEW_STATE_FILE = assert(os.getenv("XDG_RUNTIME_DIR"), "XDG_RUNTIME_DIR is required") .. "/dms-snap-preview.state"
local POSITION_EPSILON = 2

-- Must match general.border_size (hyprland.lua / config/decorations.lua /
-- dms/layout.lua all set this to 2 - there's no hl.get_option()-style
-- runtime reader available to this Lua layer, so it's a manual constant
-- like those three already are). Hyprland's window position/size dispatches
-- operate on the *content* box; the border is drawn an extra BORDER_SIZE
-- px outward from it on every side. Two windows whose content boxes touch
-- at the same point therefore have borders that overlap by 2*BORDER_SIZE.
-- Pulling each half's inner edge back by BORDER_SIZE makes the visible
-- (bordered) edges meet exactly instead.
local BORDER_SIZE = 2

local function approxEqual(a, b, eps)
    return math.abs(a - b) <= (eps or POSITION_EPSILON)
end

local function usableArea(monitor)
    local reserved = monitor.reserved
    return {
        x = monitor.x + reserved.left,
        y = monitor.y + reserved.top,
        w = monitor.width - reserved.left - reserved.right,
        h = monitor.height - reserved.top - reserved.bottom,
    }
end

-- target half-geometry for a window's current usable area, or nil if it
-- isn't currently near a left/right edge. Both halves are derived from the
-- same `area` and the same floored midline, whichever side is asked for and
-- whichever window (or drag) triggers the calculation, so a left snap and a
-- right snap always agree on exactly where the shared edge is.
local function edgeTarget(winAt, winSize, area)
    local mid = math.floor(area.x + area.w / 2)

    if approxEqual(winAt.x, area.x, EDGE_THRESHOLD) then
        return {
            x = area.x,
            y = area.y,
            w = (mid - BORDER_SIZE) - area.x,
            h = area.h,
            side = "left",
        }
    end

    if approxEqual(winAt.x + winSize.x, area.x + area.w, EDGE_THRESHOLD) then
        local x = mid + BORDER_SIZE
        return {
            x = x,
            y = area.y,
            w = (area.x + area.w) - x,
            h = area.h,
            side = "right",
        }
    end

    return nil
end

local function writePreviewFile(text)
    hl.exec_cmd("sh -c \"echo '" .. text .. "' > " .. PREVIEW_STATE_FILE .. "\"")
end

-- address -> { x, y, w, h } pre-snap floating geometry. Kept in _G so it
-- (and the timer below) survive `hyprctl reload`.
_G.__dmsSnapOriginal = _G.__dmsSnapOriginal or {}

local function saveOriginal(address, at, size)
    _G.__dmsSnapOriginal[address] = { x = at.x, y = at.y, w = size.x, h = size.y }
end

local function popOriginal(address)
    local o = _G.__dmsSnapOriginal[address]
    _G.__dmsSnapOriginal[address] = nil
    return o
end

local function snapWindow(address, target)
    local addr = "address:" .. address
    -- Resize before move: resize anchors from the window's center, so
    -- moving afterward is what actually lands the top-left corner exactly
    -- on the target position.
    hl.dispatch(hl.dsp.window.resize({ x = target.w, y = target.h, relative = false, window = addr }))
    hl.dispatch(hl.dsp.window.move({ x = target.x, y = target.y, relative = false, window = addr }))
end

-- Pops a window back to its saved pre-snap size, centered on the cursor,
-- if it's currently snapped. Called right as a new drag starts (mouse
-- press / gesture start), so grabbing a snapped window makes it "detach"
-- immediately and then follow the pointer naturally.
local function restoreIfSnapped(address)
    local orig = popOriginal(address)
    if not orig then
        return false
    end

    local addr = "address:" .. address
    hl.dispatch(hl.dsp.window.resize({ x = orig.w, y = orig.h, relative = false, window = addr }))

    local pos = hl.get_cursor_pos()
    if pos then
        hl.dispatch(hl.dsp.window.move({ x = pos.x - orig.w / 2, y = pos.y - orig.h / 2, relative = false, window = addr }))
    end

    return true
end

local function findFloatingWindowUnderCursor()
    local pos = hl.get_cursor_pos()
    if not pos then
        return nil
    end

    local windows = hl.get_windows()
    local best = nil
    for _, w in ipairs(windows) do
        if w.floating and w.at and w.size and pos.x >= w.at.x and pos.x <= w.at.x + w.size.x and pos.y >= w.at.y and pos.y <= w.at.y + w.size.y then
            best = w
        end
    end
    return best
end

------------------------------------------------------------------------
-- Mouse path: SUPER + mouse:272
------------------------------------------------------------------------

_G.__dmsMouseDrag = _G.__dmsMouseDrag or { active = false, address = nil, target = nil, previewSide = nil, timer = nil }
local mouseDrag = _G.__dmsMouseDrag

local function hideMousePreview()
    if mouseDrag.previewSide ~= nil then
        writePreviewFile("hide")
        mouseDrag.previewSide = nil
    end
end

local function mouseDragTick()
    if not mouseDrag.active or not mouseDrag.address then
        return
    end

    local win = hl.get_window("address:" .. mouseDrag.address)
    if not win or not win.floating or not win.monitor then
        mouseDrag.target = nil
        hideMousePreview()
        return
    end

    local area = usableArea(win.monitor)
    local target = edgeTarget(win.at, win.size, area)
    mouseDrag.target = target

    local side = target and target.side or nil
    if side ~= mouseDrag.previewSide then
        mouseDrag.previewSide = side
        if target then
            writePreviewFile(win.monitor.name .. "," .. target.x .. "," .. target.y .. "," .. target.w .. "," .. target.h)
        else
            writePreviewFile("hide")
        end
    end
end

if mouseDrag.timer then
    mouseDrag.timer:stop()
    mouseDrag.timer = nil
end

-- Replace (not add to) dms/binds.lua's plain `hl.dsp.window.drag()` press
-- bind on this combo: hl.bind does not overwrite an existing bind on the
-- same key/mods, it stacks another one alongside it, so without this the
-- native drag would double-fire together with our wrapper below.
pcall(function()
    hl.unbind(MOD .. " + mouse:272")
end)

hl.bind(MOD .. " + mouse:272", function()
    local win = findFloatingWindowUnderCursor()
    local address = win and win.address or nil

    if address then
        restoreIfSnapped(address)
    end

    mouseDrag.active = true
    mouseDrag.address = address
    mouseDrag.target = nil
    mouseDrag.previewSide = nil

    if mouseDrag.timer then
        mouseDrag.timer:stop()
    end
    mouseDrag.timer = hl.timer(mouseDragTick, { timeout = MOUSE_PREVIEW_POLL_MS, type = "repeat" })

    hl.dispatch(hl.dsp.window.drag())
end, { mouse = true })

hl.bind(MOD .. " + mouse:272", function()
    if mouseDrag.timer then
        mouseDrag.timer:stop()
        mouseDrag.timer = nil
    end

    local target = mouseDrag.target
    local address = mouseDrag.address
    hideMousePreview()

    if address and target then
        local win = hl.get_window("address:" .. address)
        if win and win.floating then
            saveOriginal(address, win.at, win.size)
            snapWindow(address, target)
        end
    end

    mouseDrag.active = false
    mouseDrag.address = nil
    mouseDrag.target = nil
end, { mouse = true, release = true })

------------------------------------------------------------------------
-- Gesture path: 3-finger swipe (fingers = 3, direction = "swipe")
-- Replaces the built-in action = "move" with a custom callback table so
-- we get real start/update/finish(cancelled) phases. Floating windows are
-- snap-aware (mirrors the mouse path); tiled windows fall back to a
-- simplified version of the built-in swap-on-release behavior (no live
-- partial-follow animation while dragging, since that specific visual
-- relies on internal state not exposed to Lua) so gesture-driven tiled
-- window reordering still works, just without the native's cosmetic
-- mid-drag nudge.
------------------------------------------------------------------------

_G.__dmsGestureDrag = _G.__dmsGestureDrag or { mode = nil, address = nil, target = nil, previewSide = nil, tiledDelta = { x = 0, y = 0 } }
local gestureDrag = _G.__dmsGestureDrag

local function hideGesturePreview()
    if gestureDrag.previewSide ~= nil then
        writePreviewFile("hide")
        gestureDrag.previewSide = nil
    end
end

local ok, unsetErr = pcall(function()
    hl.gesture({ fingers = 3, direction = "swipe", action = "unset" })
end)
-- ok may be false the first time this config is ever loaded on a system
-- where dms/binds-user.lua's default "move" gesture hasn't registered yet
-- for some reason; harmless either way, we're about to (re)define it.

hl.gesture({
    fingers = 3,
    direction = "swipe",
    action = {
        start = function(e)
            local win = hl.get_active_window()
            gestureDrag.address = win and win.address or nil
            gestureDrag.target = nil
            gestureDrag.previewSide = nil
            gestureDrag.tiledDelta = { x = 0, y = 0 }

            if not win then
                gestureDrag.mode = nil
                return
            end

            if win.floating then
                gestureDrag.mode = "floating"
                restoreIfSnapped(win.address)
            else
                gestureDrag.mode = "tiled"
            end
        end,

        update = function(e)
            if not gestureDrag.address or not e.delta then
                return
            end

            if gestureDrag.mode == "floating" then
                local addr = "address:" .. gestureDrag.address
                hl.dispatch(hl.dsp.window.move({ x = e.delta.x, y = e.delta.y, relative = true, window = addr }))

                local win = hl.get_window(addr)
                if win and win.monitor then
                    local area = usableArea(win.monitor)
                    local target = edgeTarget(win.at, win.size, area)
                    gestureDrag.target = target

                    local side = target and target.side or nil
                    if side ~= gestureDrag.previewSide then
                        gestureDrag.previewSide = side
                        if target then
                            writePreviewFile(win.monitor.name .. "," .. target.x .. "," .. target.y .. "," .. target.w .. "," .. target.h)
                        else
                            writePreviewFile("hide")
                        end
                    end
                end
            elseif gestureDrag.mode == "tiled" then
                gestureDrag.tiledDelta.x = gestureDrag.tiledDelta.x + e.delta.x
                gestureDrag.tiledDelta.y = gestureDrag.tiledDelta.y + e.delta.y
            end
        end,

        finish = function(e)
            hideGesturePreview()

            if gestureDrag.mode == "floating" and gestureDrag.address then
                if not e.cancelled and gestureDrag.target then
                    local win = hl.get_window("address:" .. gestureDrag.address)
                    if win and win.floating then
                        saveOriginal(gestureDrag.address, win.at, win.size)
                        snapWindow(gestureDrag.address, gestureDrag.target)
                    end
                end
            elseif gestureDrag.mode == "tiled" and gestureDrag.address then
                if not e.cancelled then
                    local d = gestureDrag.tiledDelta
                    if math.abs(d.x) > 5 or math.abs(d.y) > 5 then
                        local addr = "address:" .. gestureDrag.address
                        local direction
                        if math.abs(d.x) > math.abs(d.y) then
                            direction = d.x > 0 and "r" or "l"
                        else
                            direction = d.y > 0 and "d" or "u"
                        end
                        hl.dispatch(hl.dsp.window.move({ direction = direction, window = addr }))
                    end
                end
            end

            gestureDrag.mode = nil
            gestureDrag.address = nil
            gestureDrag.target = nil
        end,
    },
})
