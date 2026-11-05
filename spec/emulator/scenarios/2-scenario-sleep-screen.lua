-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile by
-- spec/emulator/sleep_screen_spec.lua. On the first home's settled signal it runs the step KOPANDA_SLEEP_STEP names,
-- then sleeps through Device:simulateSuspend (frontend/device/sdl/device.lua:462-468) and, once the sleep screen has
-- painted, reports on a "scenario" KoPandaSettled signal: margin and outline (the card's, in device pixels), width
-- and height (the screen's), screensaver_type, widget_shown, and tile_x, tile_y and tile_h, where the streak tile
-- painted, when it did. Any failure is reported there as error, so the spec fails with the message.
-- KOPANDA_SLEEP_BOOK names the book in a library of several.
--   book       opens the one book in the library and, once the reader has its document, sleeps.
--   landscape  as book, turning the reader to landscape first.
--   home       saves the book as lastfile and sleeps from the home.
local logger = require("logger")

local POLL_S = 0.5
local POLL_TRIES = 20 -- 10 s for the book to open

local ok, err = pcall(function()
    local Device = require("device")
    local Event = require("ui/event")
    local FileManager = require("apps/filemanager/filemanager")
    local ReaderUI = require("apps/reader/readerui")
    local Screensaver = require("ui/screensaver")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")

    local Screen = Device.screen
    local STEP = os.getenv("KOPANDA_SLEEP_STEP") or "book"

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local function fail(message)
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

    local function the_book()
        local dir = FileManager.instance.file_chooser.path
        local named = os.getenv("KOPANDA_SLEEP_BOOK")
        if named then
            return dir .. "/" .. named
        end
        local books = {}
        for entry in lfs.dir(dir) do
            if entry:match("%.epub$") then
                books[#books + 1] = dir .. "/" .. entry
            end
        end
        if #books ~= 1 then
            error(string.format("expected one .epub in %s, found %d", dir, #books))
        end
        return books[1]
    end

    -- Where the streak tile paints in the bitmap: the screen, since the bitmap is the screen's size in portrait.
    local tile_x, tile_y, tile_h

    local function watch_the_tile()
        local Streak = package.loaded["widgets/streak"]
        local build = Streak.build
        Streak.build = function(...)
            local tile = build(...)
            local paint_to = tile.paintTo
            tile.paintTo = function(self, bb, x, y)
                tile_x, tile_y, tile_h = x, y, self.dimen.h
                paint_to(self, bb, x, y)
            end
            return tile
        end
    end

    local measure = guarded(function()
        local look = package.loaded["looks"].active()
        report{
            tile_x = tile_x,
            tile_y = tile_y,
            tile_h = tile_h,
            margin = Screen:scaleBySize(look.sleep.margin),
            outline = Screen:scaleBySize(look.sleep.outline_width),
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            screensaver_type = Screensaver.screensaver_type,
            widget_shown = Screensaver.screensaver_widget ~= nil,
        }
    end)

    -- Reports from the next tick after the sleep screen's first paint: tickAfterNext can land before the repaint
    -- (frontend/ui/uimanager.lua:447-456).
    local sleep = guarded(function()
        watch_the_tile()
        Device:simulateSuspend()
        local widget = Screensaver.screensaver_widget
        if not widget then
            UIManager:nextTick(measure)
            return
        end
        local paint_to = widget.paintTo
        widget.paintTo = function(...)
            paint_to(...)
            widget.paintTo = paint_to
            UIManager:nextTick(measure)
        end
    end)

    local tries = 0
    local function wait_for_reader()
        tries = tries + 1
        local reader = ReaderUI.instance
        if reader and reader.document then
            if STEP == "landscape" then
                reader:handleEvent(Event:new("SetRotationMode", Screen.DEVICE_ROTATED_CLOCKWISE))
            end
            UIManager:tickAfterNext(sleep)
        elseif tries >= POLL_TRIES then
            fail(string.format("the book did not open within %.0f s", POLL_S * POLL_TRIES))
        else
            UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
        end
    end

    local start = guarded(function()
        if STEP == "home" then
            G_reader_settings:saveSetting("lastfile", the_book())
            sleep()
        else
            ReaderUI:showReader(the_book())
            UIManager:scheduleIn(POLL_S, guarded(wait_for_reader))
        end
    end)

    local homes = 0
    UIManager.event_hook:register("KoPandaSettled", function(args)
        if args and args.screen == "home" then
            homes = homes + 1
            if homes == 1 then
                UIManager:nextTick(start)
            end
        end
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
