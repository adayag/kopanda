-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/gesture_forward_spec.lua. At patch time, before any plugin loads
-- (reader.lua:190), it writes the Gestures plugin's settings file with the file manager's
-- bottom-right corner tap bound to History. On the first home it taps that corner just above the
-- nav bar, which takes every tap in its band (KoPanda's nav bar, D4), waits two ticks, and
-- reports, as a "scenario" KoPandaSettled signal, whether the file manager's History list is
-- shown and whether the home is still on the stack. Any failure is reported as a "scenario"
-- signal with error, so the spec fails with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local LuaSettings = require("luasettings")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local time = require("ui/time")

    -- The Gestures settings file (plugins/gestures.koplugin/main.lua:32) and its layout, one
    -- table per mode (:227-252); a non-empty file is used as it is (:231). history is the
    -- dispatcher action that sends ShowHist (frontend/dispatcher.lua:68).
    LuaSettings:open(DataStorage:getSettingsDir() .. "/gestures.lua")
        :saveSetting("gesture_fm", { tap_right_bottom_corner = { history = true } })
        :saveSetting("gesture_reader", {})
        :saveSetting("custom_multiswipes", {})
        :flush()

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    -- Runs fn from the UI loop, any error reported as the scenario's.
    local function guarded(fn)
        return function()
            local run_ok, run_err = pcall(fn)
            if not run_ok then
                logger.warn("KOPANDA_SCENARIO: " .. tostring(run_err))
                report{ error = tostring(run_err) }
            end
        end
    end

    local function home_shown()
        for widget in UIManager:topdown_widgets_iter() do
            if widget.name == "kopanda_home" then
                return true
            end
        end
        return false
    end

    local measure = guarded(function()
        local fm = require("apps/filemanager/filemanager").instance
        local list = fm and fm.history and fm.history.booklist_menu
        report{
            history_shown = list ~= nil and UIManager:isWidgetShown(list),
            home_shown = home_shown(),
        }
    end)

    -- A tap inside the bottom-right corner zone (DTAP_ZONE_BOTTOM_RIGHT, defaults.lua:69), 10 px
    -- above the nav bar's band, with the fields GestureRange:match reads
    -- (frontend/ui/gesturerange.lua:21-51). The bar's height is the active look's, as the home
    -- reserves it.
    local tap_corner = guarded(function()
        local size = Screen:getSize()
        local bar = require("nav_bar").height(require("looks").active(), Screen)
        UIManager:sendEvent(Event:new("Gesture", {
            ges = "tap",
            pos = Geom:new{ x = size.w - 10, y = size.h - bar - 10, w = 0, h = 0 },
            time = time.now(),
        }))
        UIManager:nextTick(function()
            UIManager:nextTick(measure)
        end)
    end)

    local tapped = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if tapped or not args or args.screen ~= "home" then
            return
        end
        tapped = true
        UIManager:nextTick(tap_corner)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
