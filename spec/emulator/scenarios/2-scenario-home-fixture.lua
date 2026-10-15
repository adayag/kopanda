-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/home_golden_spec.lua and home_capture_spec.lua. Applied by reader.lua:190
-- before any plugin code runs, it makes the home deterministic for a golden:
--   - os.time() and os.date(format) with no time argument answer 2026-10-13 08:42 in the run's
--     TZ (a Tuesday, the boards' date); calls with a time pass through, and ui/time's monotonic
--     clock is untouched, so paint_ms stays real;
--   - KOPANDA_HOME_FIXTURE=populated writes a weather cache fetched 20 minutes earlier, a
--     Statistics database with a 4-day streak, 23 minutes today and 3 books this month, and the
--     featured book: frankenstein.epub from the fixture library in the reading history, 62 % read
--     at 90 s a page with "Letter IV" as its chapter, its cover extracted into CoverBrowser's cache
--     before the home is built; "typecover" is the same with CoverBrowser disabled, so the
--     featured book has its typographic cover; "empty" writes none of it, and stores
--     launcher.entries as the default five without Settings and a sixth entry for a plugin
--     named kopanda_absent, which no profile has, so it shows greyed as "plugin missing";
--   - KOPANDA_HOME_LOOK, when set, is stored as the look (Diner is the default).
-- No fetch runs: the capture driver turns the emulator's fake Wi-Fi off, so
-- NetworkMgr:isConnected() is false (frontend/device/sdl/device.lua:478-500).
-- Writes only under the scratch KO_HOME. Any failure exits with status 4.
local logger = require("logger")

local ok, err = pcall(function()
    local DataStorage = require("datastorage")
    local LuaSettings = require("luasettings")
    local lfs = require("libs/libkoreader-lfs")

    local fixture = os.getenv("KOPANDA_HOME_FIXTURE")
    if fixture ~= "populated" and fixture ~= "typecover" and fixture ~= "empty" then
        error("KOPANDA_HOME_FIXTURE must be populated, typecover or empty, not " .. tostring(fixture))
    end

    local real_time, real_date = os.time, os.date
    local NOW = real_time{ year = 2026, month = 10, day = 13, hour = 8, min = 42, sec = 0 }

    os.time = function(...) -- luacheck: ignore 122
        if select("#", ...) == 0 then
            return NOW
        end
        return real_time(...)
    end
    os.date = function(format, t) -- luacheck: ignore 122
        if t == nil then
            return real_date(format or "%c", NOW)
        end
        return real_date(format, t)
    end

    local settings_dir = DataStorage:getSettingsDir()
    local kopanda_dir = settings_dir .. "/kopanda"
    if lfs.attributes(kopanda_dir, "mode") ~= "directory" then
        assert(lfs.mkdir(kopanda_dir))
    end

    -- settings/kopanda/settings.lua as kopanda.koplugin/settings.lua writes it: the keys and
    -- schema_version beside them, the file opened once for whichever keys the scenario sets.
    local stored = {}
    local look = os.getenv("KOPANDA_HOME_LOOK")
    if look and look ~= "" then
        stored.look = look
    end
    if fixture == "empty" then
        -- The schema's default five without Settings, then a plugin entry no plugin answers to,
        -- so it is missing on every profile: the EmptyStates board's launcher.
        stored["launcher.entries"] = {
            { kind = "kopanda", target = "library" },
            { kind = "kopanda", target = "series" },
            { kind = "kopanda", target = "authors" },
            { kind = "koreader", target = "history" },
            { kind = "koreader", target = "wifi" },
            { kind = "plugin", plugin = "kopanda_absent", action = "terminal", label = "Terminal", icon = "terminal" },
        }
    end
    if next(stored) then
        local settings = LuaSettings:open(kopanda_dir .. "/settings.lua")
        for key, value in pairs(stored) do
            settings:saveSetting(key, value)
        end
        settings:saveSetting("schema_version", 1):flush()
    end

    if fixture == "empty" then
        return
    end

    -- The featured book. Its sidecar goes under <KO_HOME>/docsettings/ rather than beside the
    -- book (document_metadata_folder "dir", frontend/docsettings.lua:118-136, :317-339), so
    -- nothing is written into spec/fixtures/library/. G_reader_settings is held in memory and
    -- read when DocSettings looks for a sidecar, so the setting holds for the whole run.
    G_reader_settings:saveSetting("document_metadata_folder", "dir")
    local ffiutil = require("ffi/util")
    local util = require("util")
    local root = assert(os.getenv("KOPANDA_ROOT"), "KOPANDA_ROOT unset")
    -- History holds realpaths (frontend/readhistory.lua:26).
    local book = assert(ffiutil.realpath(root .. "/spec/fixtures/library/frankenstein.epub"),
        "no frankenstein.epub in the fixture library")
    local md5 = assert(util.partialMD5(book)) -- frontend/util.lua:1094
    local FEATURED_PAGES = 220

    -- <DataDir>/history.lua as ReadHistory:_flush writes it (frontend/readhistory.lua:12,
    -- :89-97), one entry opened an hour before the frozen now. ReadHistory reads it when first
    -- required (:369-373); one already loaded is made to read it again (:359-367).
    util.writeToFile(string.format("return {\n    { time = %d, file = %q },\n}\n", NOW - 3600, book),
        DataStorage:getDataDir() .. "/history.lua")
    if package.loaded["readhistory"] then
        package.loaded["readhistory"]:reload(true)
    end

    -- The sidecar keys ReaderUI saves (readerrolling.lua:338 percent_finished, readerui.lua:493
    -- doc_props, :497-501 partial_md5_checksum), written through DocSettings:flush.
    require("docsettings"):open(book)
        :saveSetting("percent_finished", 0.62)
        :saveSetting("doc_pages", FEATURED_PAGES)
        :saveSetting("doc_props", { title = "Frankenstein", authors = "Mary Shelley" })
        :saveSetting("summary", { status = "reading" })
        :saveSetting("partial_md5_checksum", md5)
        :flush()

    -- The chapter KoPanda records when the book closes, in its runtime state file.
    LuaSettings:open(kopanda_dir .. "/state.lua")
        :saveSetting("featured_chapter_file", book)
        :saveSetting("featured_chapter", "Letter IV")
        :flush()

    if fixture == "typecover" then
        -- Read by PluginLoader:_discover in FileManager:init (frontend/pluginloader.lua:175),
        -- long after this patch: CoverBrowser loads only its _meta.lua (:210-216).
        local disabled = G_reader_settings:readSetting("plugins_disabled") or {}
        disabled.coverbrowser = true
        G_reader_settings:saveSetting("plugins_disabled", disabled)
    else
        -- The cover goes into CoverBrowser's cache before the home is built, so the capture
        -- shows it and the widget asks for no extraction after the show. bookinfomanager joins
        -- package.path only once PluginLoader:loadPlugins has run (frontend/pluginloader.lua:283-287),
        -- which FileManager:init calls before it instantiates any plugin
        -- (frontend/apps/filemanager/filemanager.lua:418); KoPanda's show starts its paint_ms
        -- clock only on the file manager's Show, later still. extractBookInfo is synchronous
        -- (plugins/coverbrowser.koplugin/bookinfomanager.lua:422-570); run here rather than in its
        -- subprocess it points crengine's cache at CoverBrowser's tmpcr3cache (:423-439) for the
        -- rest of the run, which the home, drawing nothing with crengine, never reads.
        local PluginLoader = require("pluginloader")
        local load_plugins = PluginLoader.loadPlugins
        local extracted = false
        PluginLoader.loadPlugins = function(self, ...)
            local enabled, disabled = load_plugins(self, ...)
            if not extracted then
                extracted = true
                local extract_ok, extract_err = pcall(function()
                    local time = require("ui/time")
                    local started = time.monotonic()
                    local BookInfoManager = require("bookinfomanager")
                    local Screen = require("device").screen
                    -- The widget's own box (featured_cover.lua), in a full-width column, so
                    -- isCachedCoverInvalid finds the cached cover big enough
                    -- (bookinfomanager.lua:1013-1030).
                    local box_w, box_h = require("featured_cover").box(Screen:getWidth(),
                        { look = require("looks").active(), screen = Screen })
                    if not BookInfoManager:extractBookInfo(book, { max_cover_w = box_w, max_cover_h = box_h }) then
                        error("CoverBrowser could not read " .. book)
                    end
                    local info = BookInfoManager:getBookInfo(book, false)
                    if not (info and info.has_cover) then
                        error("CoverBrowser found no cover in " .. book)
                    end
                    logger.info(string.format("KOPANDA_SCENARIO: cover of %s extracted for %dx%d in %d ms",
                        book, box_w, box_h, time.to_ms(time.monotonic() - started)))
                end)
                if not extract_ok then
                    logger.warn("KOPANDA_SCENARIO: home fixture failed", extract_err)
                    os.exit(4)
                end
            end
            return enabled, disabled
        end
    end

    -- The cache kopanda.koplugin/weather.lua writes after a fetch, for the schema's default
    -- location (Chicago) and units (fahrenheit): 61.4°, partly cloudy, by day.
    LuaSettings:open(kopanda_dir .. "/weather.lua"):reset({
        fetched_at = NOW - 20 * 60,
        temperature = 61.4,
        weather_code = 2,
        is_day = 1,
        units = "fahrenheit",
        latitude = 41.85003,
        longitude = -87.65005,
    }):flush()

    -- The Statistics database (plugins/statistics.koplugin/main.lua:27) with the plugin's DDL
    -- (main.lua:405-496) at its current schema version (:35), which its checkInitDatabase
    -- takes as it is (:289-399).
    local SQ3 = require("lua-ljsqlite3/init")
    local conn = SQ3.open(settings_dir .. "/statistics.sqlite3")
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
    for id = 1, 4 do
        conn:exec(string.format("INSERT INTO book (id, title, pages) VALUES (%d, 'Book %d', 300);", id, id))
    end
    -- The featured book's row: its sidecar's md5, the pages its sidecar records, opened last on
    -- 2025-01-01, and ten pages of 90 s each that day, under the plugin's 120 s max_sec
    -- (main.lua:30) and with total_pages equal to pages, so the page_stat view keeps each row as
    -- it is (main.lua:438-451). 90 s a page over 220 - round(0.62 * 220) = 84 pages left is
    -- 2 h 6 min. 2025 is outside this month and the stats widget's 400-day streak window.
    local featured_day = real_time{ year = 2025, month = 1, day = 1, hour = 10, min = 0 }
    local book_stmt = conn:prepare("INSERT INTO book (id, title, authors, last_open, pages, md5)"
        .. " VALUES (5, 'Frankenstein', 'Mary Shelley', ?, ?, ?);")
    book_stmt:bind(featured_day, FEATURED_PAGES, md5):step()
    book_stmt:close()
    -- { id_book, day of the month (October unless month is given), hour, minute, seconds }:
    -- 23 minutes today over two books; read on the three days before, then a gap on the 9th,
    -- so the streak is 4; books 1-3 this month, book 4 only in September.
    local rows = {
        { 1, 13, 7, 10, 600 },
        { 2, 13, 7, 30, 780 },
        { 1, 12, 21, 0, 900 },
        { 3, 11, 21, 0, 1200 },
        { 1, 10, 21, 0, 600 },
        { 1, 8, 21, 0, 600 },
        { 4, 28, 21, 0, 600, 9 },
    }
    local stmt = conn:prepare("INSERT INTO page_stat_data VALUES (?, ?, ?, ?, ?);")
    conn:exec("BEGIN;")
    for page, row in ipairs(rows) do
        local start = real_time{ year = 2026, month = row[6] or 10, day = row[2], hour = row[3], min = row[4] }
        stmt:reset():bind(row[1], page, start, row[5], 300):step()
    end
    for page = 1, 10 do
        stmt:reset():bind(5, page, featured_day + (page - 1) * 90, 90, FEATURED_PAGES):step()
    end
    conn:exec("COMMIT;")
    stmt:close()
    conn:close()
end)

-- A half-applied fixture would be captured as if it were the golden's state, so a failure
-- ends the run at once; the driver reports the exit status with this line in the log tail.
if not ok then
    logger.warn("KOPANDA_SCENARIO: home fixture failed", err)
    os.exit(4)
end
