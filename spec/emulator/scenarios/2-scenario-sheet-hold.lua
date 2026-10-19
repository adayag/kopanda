-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/sheet_capture_spec.lua after the home fixture patch. It writes nothing. On the
-- first home's settled signal, from the next tick, it sends one hold to the home, where
-- KOPANDA_SHEET_HOLD says:
--   - book: the centre of the featured slot's rectangle, which opens the book sheet;
--   - home: x = 4, inside the side margin, at half the screen's height, outside every slot and
--     every DTAP_ZONE_* corner (defaults.lua:66-69), which opens the home sheet.
-- No hold_release follows: the capture is taken on the sheet's own settled signal, before a lift
-- would come. Any failure is reported as a "sheet" KoPandaSettled signal with error, the screen
-- the capture shoots on, so the spec fails with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local time = require("ui/time")

    local function report_error(message)
        logger.warn("KOPANDA_SCENARIO: " .. message)
        UIManager.event_hook:execute("KoPandaSettled", { screen = "sheet", error = message })
    end

    local target = os.getenv("KOPANDA_SHEET_HOLD")
    if target ~= "book" and target ~= "home" then
        UIManager:nextTick(function()
            report_error("KOPANDA_SHEET_HOLD must be book or home, not " .. tostring(target))
        end)
        return
    end

    local CORNERS = { "DTAP_ZONE_TOP_LEFT", "DTAP_ZONE_TOP_RIGHT", "DTAP_ZONE_BOTTOM_LEFT", "DTAP_ZONE_BOTTOM_RIGHT" }

    local function shown_home()
        for widget in UIManager:topdown_widgets_iter() do
            if widget.name == "kopanda_home" then
                return widget
            end
        end
        error("no kopanda_home window is shown")
    end

    -- The corner zone pos lies in, as the screen ratios G_defaults holds, or nil.
    local function corner_at(pos)
        local size = Screen:getSize()
        for _, name in ipairs(CORNERS) do
            local zone = G_defaults:readSetting(name)
            local rect = Geom:new{ x = zone.x * size.w, y = zone.y * size.h, w = zone.w * size.w, h = zone.h * size.h }
            if rect:contains(pos) then
                return name
            end
        end
    end

    local function hold_point(home)
        if target == "book" then
            for _, slot in ipairs(home.slots) do
                if slot.widget == "featured" then
                    local r = slot.rect
                    return Geom:new{ x = r.x + math.floor(r.w / 2), y = r.y + math.floor(r.h / 2), w = 0, h = 0 }
                end
            end
            error("the home has no featured slot")
        end
        local pos = Geom:new{ x = 4, y = math.floor(Screen:getHeight() / 2), w = 0, h = 0 }
        for _, slot in ipairs(home.slots) do
            if slot.rect:contains(pos) then
                error("the home sheet's hold point lies in the slot of " .. tostring(slot.widget))
            end
        end
        return pos
    end

    local hold = function()
        local run_ok, run_err = pcall(function()
            local pos = hold_point(shown_home())
            local corner = corner_at(pos)
            if corner then
                error("the hold point lies in " .. corner)
            end
            logger.info(string.format("KOPANDA_SCENARIO: hold %s at %d,%d", target, pos.x, pos.y))
            -- The fields GestureRange:match reads (frontend/ui/gesturerange.lua:21-51).
            UIManager:sendEvent(Event:new("Gesture", { ges = "hold", pos = pos, time = time.now() }))
        end)
        if not run_ok then
            report_error(tostring(run_err))
        end
    end

    local held = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if held or not args or args.screen ~= "home" then
            return
        end
        held = true
        UIManager:nextTick(hold)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
