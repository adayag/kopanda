-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/library_hold_capture_spec.lua beside the home fixture patch (at empty) and the
-- library scenario patch (2-scenario-library.lua, at its root step), whose names sort before this
-- one (frontend/userpatch.lua:82, natsort; "." before "_"), so the capture library is the home
-- folder and the-time-machine.epub's sidecar is written before anything here runs.
-- KOPANDA_LIBRARY_DIR is that capture library. On the first home's settled signal, before the
-- library scenario opens the library from the next tick, it writes one reading history entry for
-- the-time-machine.epub at its root, three calendar days before the fixture's frozen now, as the
-- home fixture writes its own (2-scenario-home-fixture.lua), so the book sheet's meta reads both
-- its percent and when it was opened.
-- On the first library's settled signal, from the next tick, it sends one hold where
-- KOPANDA_LIBRARY_HOLD says, at the centre of:
--   - book: the tile of the-time-machine.epub, the reading book, which opens the book sheet;
--   - remote: the tile of the path-less source book, which opens the not-downloaded book sheet;
--   - folder: the sub-folder's tile, which opens the folder sheet;
--   - empty: the page's sixth cell, past its five tiles, which opens the empty-space sheet.
-- The point is checked with Library.hit (library.lua) for the kind the target names, and against
-- every DTAP_ZONE_* corner (defaults.lua:66-69), since a hold corner bound on the file manager
-- wins over the hold (library_chrome.lua, Window:routeGesture). No hold_release follows: the
-- capture is taken on the sheet's own settled signal. Any failure is reported as a "sheet"
-- KoPandaSettled signal with error, the screen the capture shoots on, so the spec fails with the
-- message; a failure before the UI runs exits with status 4, as the library scenario does.
local logger = require("logger")

local TARGETS = { book = "book", remote = "book", folder = "folder", empty = "empty" }
local READING = "the-time-machine.epub"
local DAYS_AGO = 3

local ok, err = pcall(function()
    local DataStorage = require("datastorage")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")
    local util = require("util")
    local Screen = require("device").screen

    local function report_error(message)
        logger.warn("KOPANDA_SCENARIO: " .. message)
        UIManager.event_hook:execute("KoPandaSettled", { screen = "sheet", error = message })
    end

    local target = os.getenv("KOPANDA_LIBRARY_HOLD")
    if not TARGETS[target] then
        UIManager:nextTick(function()
            report_error("KOPANDA_LIBRARY_HOLD must be book, remote, folder or empty, not " .. tostring(target))
        end)
        return
    end

    local library_dir = os.getenv("KOPANDA_LIBRARY_DIR")
    local root = library_dir and library_dir ~= "" and ffiutil.realpath(library_dir)
    local reading = root and root .. "/" .. READING
    if not reading or lfs.attributes(reading, "mode") ~= "file" then
        error("no " .. READING .. " in KOPANDA_LIBRARY_DIR " .. tostring(library_dir))
    end

    -- <DataDir>/history.lua as ReadHistory:_flush writes it (frontend/readhistory.lua:12, :89-97),
    -- its file a realpath (:26), at the same clock time DAYS_AGO calendar days before the frozen
    -- now, read again at once (:359-367). Written on the home's settled signal, not at patch time:
    -- with no Statistics database, the Statistics plugin's init, run when the file manager starts,
    -- converts a non-empty history into a new one and leaves "Conversion complete." on screen
    -- (plugins/statistics.koplugin/main.lua:147, :371-397), over the library and taking the hold.
    -- The library scenario opens the library from the tick after that signal, so it reads this.
    local function write_history()
        local now = os.date("*t")
        local opened = os.time{ year = now.year, month = now.month, day = now.day - DAYS_AGO,
            hour = now.hour, min = now.min, sec = now.sec }
        util.writeToFile(string.format("return {\n    { time = %d, file = %q },\n}\n", opened, reading),
            DataStorage:getDataDir() .. "/history.lua")
        require("readhistory"):reload(true)
        logger.info(string.format("KOPANDA_SCENARIO: history entry for %s at %s", reading,
            os.date("%Y-%m-%d %H:%M", opened)))
    end

    local CORNERS = { "DTAP_ZONE_TOP_LEFT", "DTAP_ZONE_TOP_RIGHT", "DTAP_ZONE_BOTTOM_LEFT", "DTAP_ZONE_BOTTOM_RIGHT" }

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

    local function centre(rect)
        return Geom:new{ x = rect.x + math.floor(rect.w / 2), y = rect.y + math.floor(rect.h / 2), w = 0, h = 0 }
    end

    -- The rectangle of the tile or cell target names on the shown library (library_view.lua: its
    -- tiles' rects, and box.columns, the grid's three columns).
    local function target_rect(library)
        local tiles = library.tiles
        if target == "empty" then
            if #tiles ~= 5 then
                error(string.format("the library's page shows %d tiles, not five", #tiles))
            end
            local columns = library.box.columns
            local last = columns[#columns]
            return Geom:new{ x = last.x, y = tiles[4].rect.y, w = library.box.cover_w, h = library.box.height }
        end
        for _, tile in ipairs(tiles) do
            local record = tile.record
            if target == "folder" and tile.folder
                    or target == "remote" and record and not record.path
                    or target == "book" and record and record.path == reading then
                return tile.rect
            end
        end
        error("the library shows no tile for " .. target)
    end

    local hold = function()
        local run_ok, run_err = pcall(function()
            local Library = require("library")
            local library = Library.shown
            if not library then
                error("no library is shown")
            end
            local pos = centre(target_rect(library))
            local corner = corner_at(pos)
            if corner then
                error("the hold point lies in " .. corner)
            end
            local hit = Library.hit(pos.x, pos.y)
            if not hit or hit.kind ~= TARGETS[target] then
                error(string.format("Library.hit at %d,%d is %s, not %s", pos.x, pos.y,
                    tostring(hit and hit.kind), TARGETS[target]))
            end
            if target == "book" and hit.record.path ~= reading
                    or target == "remote" and hit.record.path then
                error(string.format("Library.hit at %d,%d is %s", pos.x, pos.y, tostring(hit.record.path)))
            end
            logger.info(string.format("KOPANDA_SCENARIO: hold %s at %d,%d", target, pos.x, pos.y))
            -- The fields GestureRange:match reads (frontend/ui/gesturerange.lua:21-51).
            UIManager:sendEvent(Event:new("Gesture", { ges = "hold", pos = pos, time = time.now() }))
        end)
        if not run_ok then
            report_error(tostring(run_err))
        end
    end

    local wrote, held = false, false
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if not args then
            return
        end
        if args.screen == "home" and not wrote then
            wrote = true
            local write_ok, write_err = pcall(write_history)
            if not write_ok then
                report_error("could not write the history entry: " .. tostring(write_err))
            end
        elseif args.screen == "library" and not held then
            held = true
            UIManager:nextTick(hold)
        end
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: library hold patch failed", err)
    os.exit(4)
end
