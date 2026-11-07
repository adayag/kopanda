-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile by
-- spec/emulator/focused_end_spec.lua. Once the home is up it opens the one book in the library, goes to the last
-- page and turns past it (frontend/apps/reader/modules/readerrolling.lua:943). On the sheet's settled signal it
-- records header_label, rows (joined by |), status and popup_shown (KOReader's pop-up up), turns past the end again,
-- recording sheet_kept, and taps Book details. On the window's settled signal it taps the back control, recording
-- details_closed, then turns past the end again. On the second sheet it records status_again and taps Back to the
-- start, and on the next tick reports reader_shown, page and sheet_closed on the "scenario" screen. Any failure is
-- reported there as error, so the spec fails with the message.
local logger = require("logger")

local POLL_S = 0.5
local POLL_TRIES = 20 -- 10 s for the book to open

local ok, err = pcall(function()
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local Geom = require("ui/geometry")
    local ReaderUI = require("apps/reader/readerui")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local reported = false
    local function fail(message)
        if reported then
            return
        end
        reported = true
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        report{ error = tostring(message) }
    end

    -- Runs fn from the UI loop, any error reported as the scenario's.
    local function guarded(fn)
        return function()
            local run_ok, run_err = pcall(fn)
            if not run_ok then
                fail(run_err)
            end
        end
    end

    local function loaded(name)
        local module = package.loaded[name]
        if type(module) ~= "table" then
            error("the " .. name .. " module is not loaded")
        end
        return module
    end

    local function the_book()
        local dir = FileManager.instance.file_chooser.path
        for entry in lfs.dir(dir) do
            if entry:match("%.epub$") then
                return dir .. "/" .. entry
            end
        end
        error("no .epub in " .. dir)
    end

    local result = {}

    local function tap(r)
        local pos = Geom:new{ x = r.x + math.floor(r.w / 2), y = r.y + math.floor(r.h / 2), w = 0, h = 0 }
        UIManager:sendEvent(Event:new("Gesture", { ges = "tap", pos = pos, time = time.now() }))
    end

    local function tap_row(label)
        for _, place in ipairs(loaded("sheet").shown.rows) do
            if place.row.label == label then
                return tap(place.rect)
            end
        end
        error("the sheet has no row " .. label)
    end

    local function status()
        return ReaderUI.instance.doc_settings:readSetting("summary").status
    end

    local function turn_past_the_end()
        ReaderUI.instance:handleEvent(Event:new("GotoViewRel", 1))
    end

    local measure_start = guarded(function()
        local reader = ReaderUI.instance
        result.reader_shown = reader ~= nil and UIManager:isWidgetShown(reader)
        result.page = reader:getCurrentPage()
        result.sheet_closed = loaded("sheet").shown == nil
        reported = true
        report(result)
    end)

    local sheets = 0
    local on_sheet = guarded(function()
        sheets = sheets + 1
        local Sheet = loaded("sheet")
        if sheets == 1 then
            local shown = Sheet.shown
            result.header_label = shown.spec.header.label
            local rows = {}
            for i, row in ipairs(shown.spec.rows) do
                rows[i] = row.label
            end
            result.rows = table.concat(rows, "|")
            result.status = status()
            result.popup_shown = (UIManager:getTopmostVisibleWidget() or {}).name == "end_document"
            turn_past_the_end()
            result.sheet_kept = Sheet.shown == shown
            tap_row("Book details")
        else
            result.status_again = status()
            tap_row("Back to the start")
            UIManager:nextTick(measure_start)
        end
    end)

    local check_details_closed = guarded(function()
        result.details_closed = loaded("book_status_screen").shown == nil
        turn_past_the_end()
    end)

    local on_details = guarded(function()
        local screen = loaded("book_status_screen").shown
        if not screen then
            error("the book details are not shown at their settled signal")
        end
        tap(screen.header.back_rect)
        UIManager:nextTick(check_details_closed)
    end)

    local to_the_end = guarded(function()
        local reader = ReaderUI.instance
        reader:handleEvent(Event:new("GotoPage", reader.document:getPageCount()))
        turn_past_the_end()
    end)

    local tries = 0
    local function wait_for_reader()
        tries = tries + 1
        local reader = ReaderUI.instance
        if reader and reader.document then
            UIManager:nextTick(to_the_end)
        elseif tries >= POLL_TRIES then
            fail(string.format("the book did not open within %.0f s", POLL_S * POLL_TRIES))
        else
            UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
        end
    end

    local open_book = guarded(function()
        ReaderUI:showReader(the_book())
        UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
    end)

    local homes = 0
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if not args then
            return
        end
        if args.screen == "home" then
            homes = homes + 1
            if homes == 1 then
                UIManager:nextTick(open_book)
            end
        elseif args.screen == "sheet" and args.name == "end_of_book" then
            UIManager:nextTick(on_sheet)
        elseif args.screen == "book_status" then
            UIManager:nextTick(on_details)
        end
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
