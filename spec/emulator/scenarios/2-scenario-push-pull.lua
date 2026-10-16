-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/push_spec.lua. Active when KOPANDA_PUSH_ADDRESS is set: once the file
-- manager and KoPanda's modules are up it pulls KOPANDA_PUSH_PROFILE from the studio at that
-- address through the plugin's own pull (push_pull.lua), as Tools › KoPanda › Studio › Pull does
-- after its confirm, in the normal menu and in the refused one alike, then broadcasts Restart as
-- the restart offer does, which quits with 85. The emulator's Wi-Fi is off (driver.lua), so the
-- pull is called directly rather than through NetworkMgr:runWhenConnected. A failed pull logs
-- KOPANDA_SCENARIO: <message> and quits with status 5.
local address = os.getenv("KOPANDA_PUSH_ADDRESS")
if not address or address == "" then
    return
end

local logger = require("logger")

local POLL_S = 0.5
local POLL_TRIES = 40 -- 20 s for the file manager and KoPanda to load

local ok, err = pcall(function()
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")

    local function fail(message)
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        UIManager:quit(5)
    end

    -- KoPanda's folder, as the loader set it on the plugin module (frontend/pluginloader.lua:248).
    local function kopanda_path()
        for _, plugin in ipairs(PluginLoader:loadPlugins()) do
            if plugin.name == "kopanda" then
                return plugin.path
            end
        end
        error("KoPanda is not among the loaded plugins")
    end

    local function pull()
        local PushPull = package.loaded.push_pull
        local Guards = package.loaded.guards
        local pulled, why = PushPull.pull{
            address = address,
            profile = os.getenv("KOPANDA_PUSH_PROFILE"),
            data_dir = DataStorage:getDataDir(),
            plugin_dir = kopanda_path(),
            disable = Guards.enabled_shell_names(),
        }
        if not pulled then
            error(why, 0)
        end
        logger.info("KOPANDA_SCENARIO: pulled, restarting")
        UIManager:broadcastEvent(Event:new("Restart"))
    end

    local tries = 0
    local function wait_for_kopanda()
        tries = tries + 1
        if FileManager.instance and package.loaded.push_pull and package.loaded.guards then
            local run_ok, run_err = pcall(pull)
            if not run_ok then
                fail(run_err)
            end
        elseif tries >= POLL_TRIES then
            fail(string.format("KoPanda's pull did not load within %.0f s", POLL_S * POLL_TRIES))
        else
            UIManager:scheduleIn(POLL_S, wait_for_kopanda)
        end
    end
    UIManager:scheduleIn(POLL_S, wait_for_kopanda)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
