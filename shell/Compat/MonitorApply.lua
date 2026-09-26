-- Hyprland 0.56 refreshes VRR before installing the new monitor rule.
-- Revisit it once after the monitor update. Cancel superseded previews/reverts.
return function(rule)
    _G.__bifrost_output_timers = _G.__bifrost_output_timers or {}
    local timers = _G.__bifrost_output_timers
    local old = timers[rule.output]
    if old then old:set_enabled(false) end
    hl.monitor(rule)
    -- Hyprland 0.56.2 --verify-config crashes tearing down a pending timer
    -- (CConfigManager::cleanTimers); verification needs no revisit.
    if __bifrost_verify then return end
    timers[rule.output] = hl.timer(function()
        timers[rule.output] = nil
        hl.monitor(rule)
    end, {timeout = 250, type = "oneshot"})
end
