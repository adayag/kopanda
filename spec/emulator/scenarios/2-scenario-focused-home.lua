-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/focused_home_spec.lua after the home fixture patch. It writes nothing; focused.on
-- keeps its default, on. On the first home's settled signal it runs the step KOPANDA_FOCUSED_STEP
-- names, from the next tick:
--   - "top" taps the top centre, inside KOReader's top menu zone (DTAP_ZONE_MENU, defaults.lua:59);
--     the capture is taken on the quick-settings sheet's own "sheet" settled signal;
--   - "empty" taps the first point, scanned for in 10 px steps below the top menu zones
--     (DTAP_ZONE_MENU_EXT, defaults.lua:60) and above the nav bar's band, outside the corner
--     eighths, that no tappable slot holds, waits two ticks and reports, as a "scenario" signal,
--     whether the home is still shown and on top, and the point.
-- Each tap carries the fields GestureRange:match reads (frontend/ui/gesturerange.lua:21-51). Any
-- failure is reported as a signal with error on the step's screen, so the spec fails with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local time = require("ui/time")

    local step = os.getenv("KOPANDA_FOCUSED_STEP")
    local screen = step == "top" and "sheet" or "scenario"

    local function report(args)
        args.screen = screen
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

    local function tap(x, y)
        UIManager:sendEvent(Event:new("Gesture", {
            ges = "tap",
            pos = Geom:new{ x = x, y = y, w = 0, h = 0 },
            time = time.now(),
        }))
    end

    -- The home module, loaded by main.lua; a userpatch can't require it by name once the plugin's
    -- path is gone (HOOKS.md, "`package.path` during plugin load").
    local function home()
        local Home = package.loaded["home"]
        if type(Home) ~= "table" or not Home.shown then
            error("no home shown")
        end
        return Home.shown
    end

    local function empty_point(shown)
        local size = Screen:getSize()
        local bottom = shown.nav and shown.nav.dimen.y or size.h * 7 / 8
        for y = math.floor(size.h / 5) + 10, math.floor(bottom) - 10, 10 do
            for x = math.floor(size.w / 8) + 10, math.floor(size.w * 7 / 8) - 10, 10 do
                if not shown:tappableSlotAt(Geom:new{ x = x, y = y, w = 0, h = 0 }) then
                    return x, y
                end
            end
        end
        error("no point outside every tappable slot")
    end

    local function measure(shown, x, y)
        return guarded(function()
            local Home = package.loaded["home"]
            local top = UIManager:topdown_widgets_iter()()
            report{
                home_shown = Home.shown == shown,
                home_on_top = top == shown,
                tapped_x = x,
                tapped_y = y,
            }
        end)
    end

    local run = guarded(function()
        local shown = home()
        if step == "top" then
            local size = Screen:getSize()
            logger.info("KOPANDA_SCENARIO: tap the top centre")
            tap(math.floor(size.w / 2), math.floor(size.h / 16))
        elseif step == "empty" then
            local x, y = empty_point(shown)
            logger.info("KOPANDA_SCENARIO: tap an empty spot at", x, y)
            tap(x, y)
            UIManager:nextTick(function()
                UIManager:nextTick(measure(shown, x, y))
            end)
        else
            error("unknown KOPANDA_FOCUSED_STEP " .. tostring(step))
        end
    end)

    local ran = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if ran or not args or args.screen ~= "home" then
            return
        end
        ran = true
        UIManager:nextTick(run)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
