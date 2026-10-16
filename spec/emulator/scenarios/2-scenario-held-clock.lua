-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/capture_spec.lua. Within each UIManager:_checkTasks pass, time.now() returns
-- the value the pass sampled as _now (frontend/ui/uimanager.lua:1082), as a clock that does not
-- tick during the pass would: CLOCK_MONOTONIC_COARSE on a device (frontend/ui/time.lua:185-199),
-- or macOS's µs CLOCK_MONOTONIC when the pass takes under a microsecond. A nextTick queued
-- inside the pass is then due at _now and runs in the same pass, before the next _repaint
-- (uimanager.lua:1088-1097), so tickAfterNext lands ahead of the paint it was meant to follow.
local logger = require("logger")

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local time = require("ui/time")
    local real_now = time.now
    local held

    time.now = function()
        return held or real_now()
    end

    local check_tasks = UIManager._checkTasks
    UIManager._checkTasks = function(self)
        held = real_now()
        local pass_ok, wait_until, now = pcall(check_tasks, self)
        held = nil
        if not pass_ok then
            error(wait_until, 0)
        end
        return wait_until, now
    end
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: held clock patch failed", err)
end
