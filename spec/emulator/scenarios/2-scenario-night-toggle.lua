-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/night_toggle_spec.lua. On the first home's settled signal it counts the
-- home's paints from then on and toggles night mode by KOPANDA_NIGHT_ROUTE:
--   - menu: UIManager:broadcastEvent(Event:new("ToggleNightMode")), as KOReader's menu item does
--     (frontend/ui/elements/common_settings_menu_table.lua:266-271);
--   - dispatcher: Dispatcher:execute({ night_mode = true }), the action a gesture runs
--     (frontend/dispatcher.lua:138, :1549-1598), through the plugin's dispatch bridge.
-- Past the next repaint (UIManager:tickAfterNext) it reports, as a "scenario" signal,
-- home_paints, night_mode (the screen's flag after the toggle) and the screen. Any failure is
-- reported as a "scenario" signal with error, so the spec fails with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local Event = require("ui/event")
    local Screen = require("device").screen

    local route = os.getenv("KOPANDA_NIGHT_ROUTE")
    if route ~= "menu" and route ~= "dispatcher" then
        error("KOPANDA_NIGHT_ROUTE must be menu or dispatcher, not " .. tostring(route))
    end

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local function fail(message)
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        report{ error = tostring(message) }
    end

    local home_paints = 0

    -- Home:paintTo is the class's (kopanda.koplugin/home.lua); the shown home inherits it.
    local function count_paints()
        local Home = assert(package.loaded["home"], "the home module isn't loaded")
        local paint = Home.paintTo
        Home.paintTo = function(self, ...)
            home_paints = home_paints + 1
            return paint(self, ...)
        end
    end

    local function toggle()
        count_paints()
        if route == "menu" then
            UIManager:broadcastEvent(Event:new("ToggleNightMode"))
        else
            require("dispatcher"):execute({ night_mode = true })
        end
        UIManager:tickAfterNext(function()
            report{ home_paints = home_paints, night_mode = Screen.night_mode == true }
        end)
    end

    local toggled = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if toggled or not args or args.screen ~= "home" then
            return
        end
        toggled = true
        UIManager:nextTick(function()
            local run_ok, run_err = pcall(toggle)
            if not run_ok then
                fail(run_err)
            end
        end)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
