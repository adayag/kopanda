-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/home_page_spec.lua after the home fixture. On the first home's settled signal
-- it sends, from nextTick, one mid-screen west swipe through UIManager:sendEvent
-- (frontend/ui/uimanager.lua:962), with the fields GestureRange:match reads
-- (frontend/ui/gesturerange.lua:21-51); past the next repaint (UIManager:tickAfterNext) it
-- reports, as a "scenario" signal, the shown home's page. Any failure is reported as a
-- "scenario" signal with error, so the spec fails with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local function fail(message)
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        report{ error = tostring(message) }
    end

    local function swipe()
        local Home = assert(package.loaded["home"], "the home module isn't loaded")
        local Event = require("ui/event")
        local Geom = require("ui/geometry")
        local Screen = require("device").screen
        local w, h = Screen:getWidth(), Screen:getHeight()
        UIManager:sendEvent(Event:new("Gesture", {
            ges = "swipe",
            direction = "west",
            pos = Geom:new{ x = math.floor(w / 2), y = math.floor(h / 2), w = 0, h = 0 },
            time = require("ui/time").now(),
        }))
        UIManager:tickAfterNext(function()
            report{ page = Home.shown and Home.shown.page }
        end)
    end

    local swiped = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if swiped or not args or args.screen ~= "home" then
            return
        end
        swiped = true
        UIManager:nextTick(function()
            local run_ok, run_err = pcall(swipe)
            if not run_ok then
                fail(run_err)
            end
        end)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
