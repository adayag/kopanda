-- KOReader userpatch (late priority, frontend/userpatch.lua:13) applied from <KO_HOME>/patches
-- by reader.lua:190, before any plugin code runs. It saves the framebuffer once the plugin
-- under test signals "KoPandaSettled" on UIManager.event_hook, writes a JSON sidecar next to
-- the PNG, and quits. A watchdog shoots and quits with exit code 3 if the signal never comes.
-- Inactive unless KOPANDA_SHOT names the PNG to write; KOPANDA_SHOT_CAP_S bounds the wait.
local shot = os.getenv("KOPANDA_SHOT")
if not shot or shot == "" then
    return
end

local logger = require("logger")

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local Screen = require("device").screen
    local cap_s = tonumber(os.getenv("KOPANDA_SHOT_CAP_S")) or 20
    local saved = false

    -- The names of the enabled plugins. PluginLoader:loadPlugins() is memoised
    -- (frontend/pluginloader.lua:274), so after FileManager:init this call is free.
    local function plugin_names()
        local PluginLoader = require("pluginloader")
        local names = {}
        for _, plugin in ipairs(PluginLoader:loadPlugins()) do
            names[#names + 1] = plugin.name
        end
        return names
    end

    local function save(args)
        local shot_ok, shot_err = Screen:shot(shot)
        if not shot_ok then
            error("Screen:shot failed: " .. tostring(shot_err))
        end
        local rapidjson = require("rapidjson")
        local sidecar = assert(io.open(shot .. ".json", "w"))
        sidecar:write(rapidjson.encode({
            screen = args.screen,
            paint_ms = args.paint_ms,
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            color = require("device"):hasColorScreen(),
            plugins = plugin_names(),
            koreader = "e1fe1ac",
        }))
        sidecar:close()
    end

    UIManager.event_hook:register("KoPandaSettled", function(args)
        if saved then
            return
        end
        local save_ok, save_err = pcall(save, args or {})
        if not save_ok then
            logger.warn("KOPANDA_SHOT: failed", save_err)
            return
        end
        saved = true
        logger.info("KOPANDA_SHOT: saved " .. shot .. " paint_ms=" .. tostring((args or {}).paint_ms))
        UIManager:scheduleIn(0.5, function() UIManager:quit() end)
    end)

    UIManager:scheduleIn(cap_s, function()
        if saved then
            return
        end
        logger.warn("KOPANDA_SHOT: settle cap after " .. cap_s .. " s, no KoPandaSettled signal")
        local shot_ok, shot_err = Screen:shot(shot)
        if not shot_ok then
            logger.warn("KOPANDA_SHOT: diagnostic shot failed", shot_err)
        end
        UIManager:quit(3)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SHOT: patch failed", err)
end
