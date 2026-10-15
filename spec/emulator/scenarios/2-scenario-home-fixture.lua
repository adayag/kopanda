-- KOReader userpatch (late priority, frontend/userpatch.lua:13), copied into a scratch profile
-- by spec/emulator/home_golden_spec.lua and home_capture_spec.lua. Applied by reader.lua:190
-- before any plugin code runs, it makes the home deterministic for a golden:
--   - os.time() and os.date(format) with no time argument answer 2026-10-13 08:42 in the run's
--     TZ (a Tuesday, the boards' date); calls with a time pass through, and ui/time's monotonic
--     clock is untouched, so paint_ms stays real;
--   - KOPANDA_HOME_FIXTURE=populated writes a weather cache fetched 20 minutes earlier and a
--     Statistics database with a 4-day streak, 23 minutes today and 3 books this month;
--     "empty" writes neither;
--   - KOPANDA_HOME_LOOK, when set, is stored as the look (Diner is the default).
-- No fetch runs: the capture driver turns the emulator's fake Wi-Fi off, so
-- NetworkMgr:isConnected() is false (frontend/device/sdl/device.lua:478-500).
-- Writes only under the scratch KO_HOME's settings directory. Any failure exits with status 4.
local logger = require("logger")

local ok, err = pcall(function()
    local DataStorage = require("datastorage")
    local LuaSettings = require("luasettings")
    local lfs = require("libs/libkoreader-lfs")

    local fixture = os.getenv("KOPANDA_HOME_FIXTURE")
    if fixture ~= "populated" and fixture ~= "empty" then
        error("KOPANDA_HOME_FIXTURE must be populated or empty, not " .. tostring(fixture))
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

    local look = os.getenv("KOPANDA_HOME_LOOK")
    if look and look ~= "" then
        -- settings/kopanda/settings.lua as kopanda.koplugin/settings.lua writes it: the key and
        -- schema_version beside it.
        LuaSettings:open(kopanda_dir .. "/settings.lua")
            :saveSetting("look", look)
            :saveSetting("schema_version", 1)
            :flush()
    end

    if fixture == "empty" then
        return
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
    local stmt = conn:prepare("INSERT INTO page_stat_data VALUES (?, ?, ?, ?, 300);")
    conn:exec("BEGIN;")
    for page, row in ipairs(rows) do
        local start = real_time{ year = 2026, month = row[6] or 10, day = row[2], hour = row[3], min = row[4] }
        stmt:reset():bind(row[1], page, start, row[5]):step()
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
