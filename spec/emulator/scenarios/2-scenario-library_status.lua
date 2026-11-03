-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile by
-- spec/emulator/book_status_capture_spec.lua after the home fixture patch (at empty), the library scenario patch
-- (2-scenario-library.lua, at its root step) and the library-hold patch (2-scenario-library_hold.lua, holding the
-- book), whose names sort before this one (frontend/userpatch.lua:82, natsort; "." before "_", "h" before "s"), so
-- the home fixture's clock is frozen, the capture library is the home folder and the-time-machine.epub's sidecar is
-- written before anything here runs. KOPANDA_LIBRARY_DIR is that capture library. At patch time it gives the book
-- what its page shows:
--   - its sidecar's partial_md5_checksum (util.partialMD5, frontend/util.lua:1094), the md5 Statistics keys it by
--     (plugins/statistics.koplugin/main.lua:2737), and doc_pages, the page count BookList reads first after page
--     labels (frontend/ui/widget/booklist.lua:298-306), so the page shows its length and the page reached;
--   - a Statistics database (main.lua:27) with the plugin's DDL (main.lua:405-496) at its current schema version
--     (:35), which checkInitDatabase takes as it is (:289-399): the book's row, 7 h 40 min in all and last opened
--     the evening before the frozen now, and twelve page rows of 300 s, one an evening from 14 days back, which
--     the plugin's 120 s max_sec caps (main.lua:30), so the page shows its history and a time left.
-- Once PluginLoader:loadPlugins has run and the library scenario extracted every cover, it extracts the book's
-- cover again at the page's cover box (book_status_screen.lua: a third of the content's width, at 2:3), so the
-- page draws it at once rather than after its own request, and gives the book's CoverBrowser row a description of
-- DESCRIPTION_PARAGRAPHS paragraphs through setBookInfoProperties
-- (plugins/coverbrowser.koplugin/bookinfomanager.lua:572-588), long enough to run over three pages.
-- On the book sheet's settled signal it taps the sheet's Book details row; then, on the book status page's own
-- settled signal, per KOPANDA_BOOK_STATUS_STEP:
--   - page1: nothing more; that signal is the capture's;
--   - page2: one mid-screen west swipe, and past the next repaint (UIManager:tickAfterNext) a "scenario" signal
--     with the page shown, the page count and the page's paint_ms;
--   - back: a tap at the centre of the back control, and on the library's next settled signal a "scenario" signal
--     with whether the library shows the folder the page was opened from, the page's paint_ms and the library's.
-- Any failure is reported as a settled signal with error on the screen the step's capture shoots, so the spec fails
-- with the message; a failure before the UI runs exits with status 4, as the library scenario does.
local logger = require("logger")

local READING = "the-time-machine.epub"
local DESCRIPTION_PARAGRAPHS = 14
local SHOT_SCREEN = { page1 = "book_status", page2 = "scenario", back = "scenario" }

local ok, err = pcall(function()
    local DataStorage = require("datastorage")
    local DocSettings = require("docsettings")
    local Event = require("ui/event")
    local Geom = require("ui/geometry")
    local PluginLoader = require("pluginloader")
    local UIManager = require("ui/uimanager")
    local ffiutil = require("ffi/util")
    local lfs = require("libs/libkoreader-lfs")
    local time = require("ui/time")
    local util = require("util")
    local Screen = require("device").screen

    local step = os.getenv("KOPANDA_BOOK_STATUS_STEP")
    if not SHOT_SCREEN[step] then
        error("KOPANDA_BOOK_STATUS_STEP must be page1, page2 or back, not " .. tostring(step))
    end
    local library_dir = os.getenv("KOPANDA_LIBRARY_DIR")
    local root = library_dir and library_dir ~= "" and ffiutil.realpath(library_dir)
    local reading = root and root .. "/" .. READING
    if not reading or lfs.attributes(reading, "mode") ~= "file" then
        error("no " .. READING .. " in KOPANDA_LIBRARY_DIR " .. tostring(library_dir))
    end

    local PAGES = 200
    local md5 = assert(util.partialMD5(reading))
    DocSettings:open(reading):saveSetting("partial_md5_checksum", md5):saveSetting("doc_pages", PAGES):flush()

    -- os.time() is the home fixture's frozen now; os.time with a table converts as ever.
    local now = os.time()
    local today = os.date("*t", now)
    local SQ3 = require("lua-ljsqlite3/init")
    local conn = SQ3.open(DataStorage:getSettingsDir() .. "/statistics.sqlite3")
    conn:exec("PRAGMA journal_mode=WAL;")
    conn:exec([[
        CREATE TABLE IF NOT EXISTS book
            (
                id integer PRIMARY KEY autoincrement,
                title text,
                authors text,
                notes      integer,
                last_open  integer,
                highlights integer,
                pages      integer,
                series text,
                language text,
                md5 text,
                total_read_time  integer,
                total_read_pages integer
            );
        CREATE UNIQUE INDEX IF NOT EXISTS book_title_authors_md5 ON book(title, authors, md5);
        CREATE TABLE IF NOT EXISTS page_stat_data
            (
                id_book     integer,
                page        integer NOT NULL DEFAULT 0,
                start_time  integer NOT NULL DEFAULT 0,
                duration    integer NOT NULL DEFAULT 0,
                total_pages integer NOT NULL DEFAULT 0,
                UNIQUE (id_book, page, start_time),
                FOREIGN KEY(id_book) REFERENCES book(id)
            );
        CREATE INDEX IF NOT EXISTS page_stat_data_start_time ON page_stat_data(start_time);
        CREATE TABLE IF NOT EXISTS numbers
            (
                number INTEGER PRIMARY KEY
            );
        WITH RECURSIVE counter AS
            (
                SELECT 1 as N UNION ALL
                SELECT N + 1 FROM counter WHERE N < 1000
            )
            INSERT INTO numbers SELECT N AS number FROM counter;
        CREATE VIEW IF NOT EXISTS page_stat AS
            SELECT id_book, first_page + idx - 1 AS page, start_time,
                duration / (last_page - first_page + 1) AS duration
            FROM (
                SELECT id_book, page, total_pages, pages, start_time, duration,
                    ((page - 1) * pages) / total_pages + 1 AS first_page,
                    max(((page - 1) * pages) / total_pages + 1, (page * pages) / total_pages) AS last_page,
                    idx
                FROM page_stat_data
                JOIN book ON book.id = id_book
                JOIN (SELECT number as idx FROM numbers) AS N ON idx <= (last_page - first_page + 1)
            );
        PRAGMA user_version = 20221111;
    ]])
    local last_open = os.time{ year = today.year, month = today.month, day = today.day - 1, hour = 21 }
    local book = conn:prepare("INSERT INTO book (id, title, authors, last_open, pages, md5, total_read_time,"
        .. " total_read_pages) VALUES (1, 'The Time Machine', 'H. G. Wells', ?, ?, ?, 27600, 12);")
    book:bind(last_open, PAGES, md5):step()
    book:close()
    local rows = conn:prepare("INSERT INTO page_stat_data VALUES (1, ?, ?, ?, ?);")
    conn:exec("BEGIN;")
    for page = 1, 12 do
        local start = os.time{ year = today.year, month = today.month, day = today.day - 15 + page, hour = 21 }
        rows:reset():bind(page, start, 300, PAGES):step()
    end
    conn:exec("COMMIT;")
    rows:close()
    conn:close()

    local paragraphs = {}
    for i = 1, DESCRIPTION_PARAGRAPHS do
        paragraphs[i] = ("<p>Paragraph %d. The Time Traveller (for so it will be convenient to speak of him) was "
            .. "expounding a recondite matter to us. His grey eyes shone and twinkled, and his usually pale face "
            .. "was flushed and animated. The fire burned brightly, and the soft radiance of the incandescent "
            .. "lights in the lilies of silver caught the bubbles that flashed and passed in our glasses."
            .. "</p>"):format(i)
    end
    local load_plugins = PluginLoader.loadPlugins
    local described = false
    PluginLoader.loadPlugins = function(self, ...)
        local enabled, disabled = load_plugins(self, ...)
        if not described then
            described = true
            local set_ok, set_err = pcall(function()
                local BookInfoManager = require("bookinfomanager")
                local side = Screen:scaleBySize(require("looks").active().shelf.list.side)
                local cover_w = math.floor((Screen:getWidth() - 2 * side) / 3)
                if not BookInfoManager:extractBookInfo(reading, { max_cover_w = cover_w,
                        max_cover_h = math.floor(cover_w * 3 / 2) }) then
                    error("CoverBrowser could not read " .. reading)
                end
                BookInfoManager:setBookInfoProperties(reading, { description = table.concat(paragraphs) })
            end)
            if not set_ok then
                logger.warn("KOPANDA_SCENARIO: book status fixture failed", set_err)
                os.exit(4)
            end
        end
        return enabled, disabled
    end

    local function report(args)
        UIManager.event_hook:execute("KoPandaSettled", args)
    end

    local function fail(message)
        logger.warn("KOPANDA_SCENARIO: " .. tostring(message))
        report{ screen = SHOT_SCREEN[step], error = tostring(message) }
    end

    local function guarded(fn)
        return function(...)
            local run_ok, run_err = pcall(fn, ...)
            if not run_ok then
                fail(run_err)
            end
        end
    end

    -- A gesture at the centre of rect, or at the screen's middle, through the UI's gesture path (the fields
    -- GestureRange:match reads, frontend/ui/gesturerange.lua:21-51).
    local function gesture(ges, rect, direction)
        rect = rect or Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
        local pos = Geom:new{ x = rect.x + math.floor(rect.w / 2), y = rect.y + math.floor(rect.h / 2), w = 0, h = 0 }
        logger.info(string.format("KOPANDA_SCENARIO: %s at %d,%d", ges, pos.x, pos.y))
        UIManager:sendEvent(Event:new("Gesture", { ges = ges, pos = pos, direction = direction, time = time.now() }))
    end

    local tap_details = guarded(function()
        local sheet = require("sheet").shown
        if not sheet then
            error("no sheet is shown")
        end
        for _, place in ipairs(sheet.rows) do
            if place.row.label == "Book details" then
                gesture("tap", place.rect)
                return
            end
        end
        error("the sheet has no Book details row")
    end)

    local function shown_status()
        local screen = require("book_status_screen").shown
        if not screen then
            error("no book status page is shown")
        end
        return screen
    end

    local status_ms
    local turn = guarded(function()
        local screen = shown_status()
        gesture("swipe", nil, "west")
        UIManager:tickAfterNext(guarded(function()
            report{ screen = "scenario", page = screen.page, pages = screen.pages, paint_ms = status_ms }
        end))
    end)

    local back = guarded(function()
        gesture("tap", shown_status().header.back_rect)
    end)

    local tapped, statuses, libraries = false, 0, 0
    UIManager.event_hook:register("KoPandaSettled", guarded(function(args)
        if not args or args.error then
            return
        end
        if args.screen == "sheet" and args.name == "book" and not tapped then
            tapped = true
            UIManager:nextTick(tap_details)
        elseif args.screen == "book_status" then
            statuses = statuses + 1
            status_ms = args.paint_ms
            if statuses == 1 and step == "page2" then
                UIManager:nextTick(turn)
            elseif statuses == 1 and step == "back" then
                UIManager:nextTick(back)
            end
        elseif args.screen == "library" then
            libraries = libraries + 1
            if libraries == 2 and step == "back" then
                local library = require("library").shown
                report{
                    screen = "scenario",
                    same_dir = library ~= nil and require("library_view").same_dir(library.dir, root),
                    paint_ms = status_ms,
                    library_ms = args.paint_ms,
                }
            end
        end
    end))
end)

if not ok then
    logger.warn("KOPANDA_SCENARIO: book status patch failed", err)
    os.exit(4)
end
