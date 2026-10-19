-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/nav_capture_spec.lua beside the home fixture patch. Its name sorts before the
-- fixture's (frontend/userpatch.lua:60-61); that is harmless, since the only setting it writes,
-- home_dir, is one the fixture never touches. It does two things:
--   - At patch time, before any plugin loads (reader.lua:190), it stores the fixture library
--     (spec/fixtures/library/, the driver's default) as KOReader's home folder, realpath'd as
--     FileManager:showFiles realpaths the start directory (filemanager.lua:1320). The file
--     browser's subtitle is the folder abbreviated against the home folder
--     (filemanager.lua:108-112, filemanagerutil.lua:25-43), and without a stored home_dir the
--     home folder is the scratch profile (XDG_DOCUMENTS_DIR, frontend/device/sdl/device.lua:70),
--     so the subtitle showed the library's absolute path, cut on the left only where it ran out of
--     width (".../<the checkout's last folders>/spec/fixtures/library"): a capture that depends on
--     where the repo is checked out (open fact F3, candidate a). With the library as home, the
--     subtitle read "Home" in every checkout, as it does on the device. Since bars/title-bar,
--     KoPanda's title bar replaces KOReader's and draws no path: with the library as home its
--     title reads "Library" (title-bar D1), and the stored home_dir is what makes it so.
--   - On the first home's settled signal, from the next tick, it closes the home
--     (kopanda.koplugin/home.lua, Home.close), which leaves KOReader's file browser on top on the
--     library the driver started KOReader in; the file browser then sends its own settled signal.
-- CoverBrowser's list (open fact F4) needs nothing: the home fixture extracts only the featured
-- book's cover, the other two books show as file names, and three captures per profile matched
-- to the pixel with no masks.
-- Any failure is reported as a KoPandaSettled signal with error on the file_browser screen, the
-- one the capture shoots, so the spec fails with the message.
local logger = require("logger")

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")

    local function report_error(message)
        logger.warn("KOPANDA_SCENARIO: " .. message)
        UIManager.event_hook:execute("KoPandaSettled", { screen = "file_browser", error = message })
    end

    local store_ok, store_err = pcall(function()
        local root = assert(os.getenv("KOPANDA_ROOT"), "KOPANDA_ROOT unset")
        local library = assert(ffiutil.realpath(root .. "/spec/fixtures/library"), "no fixture library")
        G_reader_settings:saveSetting("home_dir", library)
    end)
    if not store_ok then
        UIManager:nextTick(function()
            report_error("storing home_dir failed: " .. tostring(store_err))
        end)
        return
    end

    local function close_home()
        local run_ok, run_err = pcall(function()
            -- The plugin's modules join package.path once PluginLoader has loaded it.
            local Home = require("home")
            if not Home.shown then
                error("no home is shown to close")
            end
            logger.info("KOPANDA_SCENARIO: close the home onto the file browser")
            Home.close()
        end)
        if not run_ok then
            report_error(tostring(run_err))
        end
    end

    local closed = false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if closed or not args or args.screen ~= "home" then
            return
        end
        closed = true
        UIManager:nextTick(close_home)
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
