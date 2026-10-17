-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/quick_settings_golden_spec.lua after the home fixture patch. It writes nothing.
-- On the first home's settled signal, from the next tick, it stubs the power device's capacity at
-- 84 (an instance field, so the emulator's reading of the Mac's battery,
-- frontend/device/sdl/powerd.lua:28-33, stays out) and opens the quick-settings sheet through the
-- loaded module, as the launcher's quick_settings target does. The capture is taken on the sheet's
-- own settled signal. Any failure is reported as a "sheet" KoPandaSettled signal with error, the
-- screen the capture shoots on, so the spec fails with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local Device = require("device")
    local UIManager = require("ui/uimanager")
    local time = require("ui/time")

    local function report_error(message)
        logger.warn("KOPANDA_SCENARIO: " .. message)
        UIManager.event_hook:execute("KoPandaSettled", { screen = "sheet", error = message })
    end

    local open = function()
        local run_ok, run_err = pcall(function()
            -- main.lua requires every KoPanda module at load; a userpatch can't require it by name
            -- once the plugin's path is gone (HOOKS.md, "`package.path` during plugin load").
            local QuickSettings = package.loaded["quick_settings"]
            if type(QuickSettings) ~= "table" then
                error("the quick_settings module is not loaded")
            end
            Device:getPowerDevice().getCapacity = function()
                return 84
            end
            logger.info("KOPANDA_SCENARIO: open quick settings")
            QuickSettings.open{ started = time.monotonic() }
        end)
        if not run_ok then
            report_error(tostring(run_err))
        end
    end

    local opened = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if opened or not args or args.screen ~= "home" then
            return
        end
        opened = true
        UIManager:nextTick(open)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
