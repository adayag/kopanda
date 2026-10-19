-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/screens_capture_spec.lua after the home fixture patch, whose name sorts first
-- (frontend/userpatch.lua:60-61), so the fixture's settings are written before this one runs.
-- KOPANDA_SCREEN says what it opens:
--   - layout: on the first home's settled signal, from the next tick, edit layout with row 2
--     selected; it writes nothing.
--   - launcher: at patch time, before any plugin loads (reader.lua:190), it stores
--     launcher.entries in settings/kopanda/settings.lua, keeping what the fixture stored there:
--     Library, Series, Authors, History, a folder "Tools" of three dispatcher actions
--     (frontend/dispatcher.lua:86, :138, :141, all unconditional on the emulator) and Settings.
--     On the first home's settled signal, from the next tick, it checks that list against the
--     plugin's own launcher validator, then opens launcher management.
-- Any failure is reported as a KoPandaSettled signal with error, on the screen the capture
-- shoots (edit_layout or launcher; both when KOPANDA_SCREEN is neither), so the spec fails with
-- the message.
local logger = require("logger")

local SHOT_SCREENS = { layout = "edit_layout", launcher = "launcher" }

local TOOLS = {
    { kind = "action", action = "screenshot", label = "Screenshot", icon = "action" },
    { kind = "action", action = "night_mode", label = "Night mode", icon = "action" },
    { kind = "action", action = "full_refresh", label = "Full refresh", icon = "action" },
}

local LAUNCHER = {
    { kind = "kopanda", target = "library" },
    { kind = "kopanda", target = "series" },
    { kind = "kopanda", target = "authors" },
    { kind = "koreader", target = "history" },
    { kind = "folder", label = "Tools", entries = TOOLS },
    { kind = "kopanda", target = "settings" },
}

local ok, err = pcall(function()
    local DataStorage = require("datastorage")
    local LuaSettings = require("luasettings")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")

    local target = os.getenv("KOPANDA_SCREEN")

    local function report_error(message)
        logger.warn("KOPANDA_SCENARIO: " .. message)
        local screens = SHOT_SCREENS[target] and { SHOT_SCREENS[target] } or { "edit_layout", "launcher" }
        for _, screen in ipairs(screens) do
            UIManager.event_hook:execute("KoPandaSettled", { screen = screen, error = message })
        end
    end

    if not SHOT_SCREENS[target] then
        UIManager:nextTick(function()
            report_error("KOPANDA_SCREEN must be layout or launcher, not " .. tostring(target))
        end)
        return
    end

    if target == "launcher" then
        -- settings/kopanda/settings.lua as kopanda.koplugin/settings.lua writes it, as the home
        -- fixture writes it (2-scenario-home-fixture.lua:56-79), its other keys kept.
        local store_ok, store_err = pcall(function()
            local kopanda_dir = DataStorage:getSettingsDir() .. "/kopanda"
            if lfs.attributes(kopanda_dir, "mode") ~= "directory" then
                assert(lfs.mkdir(kopanda_dir))
            end
            LuaSettings:open(kopanda_dir .. "/settings.lua")
                :saveSetting("launcher.entries", LAUNCHER)
                :saveSetting("schema_version", 1)
                :flush()
        end)
        if not store_ok then
            UIManager:nextTick(function()
                report_error("storing launcher.entries failed: " .. tostring(store_err))
            end)
            return
        end
    end

    local open = function()
        local run_ok, run_err = pcall(function()
            if target == "layout" then
                logger.info("KOPANDA_SCENARIO: open edit layout with row 2 selected")
                require("edit_layout").open{ selected = 2 }
                return
            end
            -- The plugin's modules join package.path once PluginLoader has loaded it.
            local Settings = require("settings")
            local entry
            for _, key in ipairs(require("schema").keys) do
                if key.id == "launcher.entries" then
                    entry = key
                end
            end
            if not (entry and Settings.validators.launcher(entry, LAUNCHER)) then
                error("the scenario's launcher.entries is refused by Settings.validators.launcher")
            end
            logger.info("KOPANDA_SCENARIO: open launcher management")
            require("launcher_manage").open{}
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
