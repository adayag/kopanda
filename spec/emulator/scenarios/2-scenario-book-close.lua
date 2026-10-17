-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/book_close_spec.lua. Once the home is up it opens the one book in the
-- library, closes it from a scheduled task, and on the next home reports, as a "scenario"
-- KoPandaSettled signal, how often the file manager was painted between the close and that
-- home's settled signal, the home's share of the close from the file manager's Show to its
-- paint, its build included (paint_ms, and cpu_ms on the CPU clock), the home's share to its
-- settled signal (settle_ms) and the whole close to that signal (close_to_paint_ms). Any failure
-- is reported as a "scenario" signal with error, so the spec fails with the message.
local logger = require("logger")

local POLL_S = 0.5
local POLL_TRIES = 20 -- 10 s for the book to open

local ok, err = pcall(function()
    local UIManager = require("ui/uimanager")
    local FileManager = require("apps/filemanager/filemanager")
    local ReaderUI = require("apps/reader/readerui")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")

    local armed = false
    local fm_paints = 0
    local closed_at
    local homes = 0

    -- FileManager has no paintTo of its own; this wraps the one it inherits from InputContainer
    -- (frontend/ui/widget/container/inputcontainer.lua:73), installed before any plugin runs
    -- (reader.lua:190).
    local inherited_paint = FileManager.paintTo
    FileManager.paintTo = function(self, ...)
        if armed then
            fm_paints = fm_paints + 1
        end
        return inherited_paint(self, ...)
    end

    local function report(args)
        args.screen = "scenario"
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local function fail(message)
        armed = false
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

    -- The close runs inside _checkTasks, as KOReader's end-of-book file-browser action does
    -- (frontend/apps/reader/modules/readerstatus.lua:144-148).
    local close_book = guarded(function()
        armed = true
        closed_at = time.monotonic()
        ReaderUI.instance:onHome()
    end)

    local tries = 0
    local function wait_for_reader()
        tries = tries + 1
        local reader = ReaderUI.instance
        if reader and reader.document then
            UIManager:nextTick(close_book)
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

    UIManager.event_hook:register("KoPandaSettled", function(args)
        if not args or args.screen ~= "home" then
            return
        end
        homes = homes + 1
        if homes == 1 then
            UIManager:nextTick(open_book)
        elseif homes == 2 and closed_at then
            armed = false
            local close_to_paint_ms = time.to_ms(time.monotonic() - closed_at)
            report{
                fm_paints = fm_paints,
                paint_ms = args.paint_ms,
                cpu_ms = args.cpu_ms,
                settle_ms = args.settle_ms,
                close_to_paint_ms = close_to_paint_ms,
            }
        end
    end)
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: patch failed", err)
end
