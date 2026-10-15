-- Reading stats from KOReader's Statistics plugin: its database, read-only, for the streak,
-- minutes today and books this month and for a book's reading speed, and its settings, for
-- whether it records at all and its cap on one page's time.
-- Days are local calendar days, bounded by os.time, which follows the process TZ.
-- Module state: the last numbers read, which a busy database reads as.
local DataStorage = require("datastorage")
local datetime = require("datetime")
local logger = require("logger")
local util = require("util")

local ReadingStats = {}

-- The plugin's database (plugins/statistics.koplugin/main.lua:27).
local function db_path()
    return DataStorage:getSettingsDir() .. "/statistics.sqlite3"
end

-- The streak scan's reach in days; a longer streak reads as this.
local MAX_STREAK = 400

local MONTHS = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
}

local last

-- Whether the Statistics plugin is disabled, or enabled but not recording. Both settings are
-- read without a default, which readSetting would write back (frontend/luasettings.lua:89-99).
local function off()
    local disabled = G_reader_settings:readSetting("plugins_disabled")
    if type(disabled) == "table" and disabled.statistics then
        return true
    end
    local settings = G_reader_settings:readSetting("statistics")
    return type(settings) == "table" and settings.is_enabled == false
end

-- The start of the local day offset days before the day of t (a *t table). Each day's start
-- comes from its calendar date, not from 86400-second steps, so days around a change to or
-- from daylight saving time keep their 23 or 25 hours.
local function day_start(t, offset)
    return os.time{ year = t.year, month = t.month, day = t.day - offset, hour = 0 }
end

-- The run of consecutive local days with any reading, ending today, or yesterday when nothing
-- is read yet today, up to MAX_STREAK. One indexed probe per day, newest first, stopping at the
-- first day without reading.
local function streak(conn, t)
    local stmt = conn:prepare("SELECT 1 FROM page_stat_data WHERE start_time >= ? AND start_time < ? LIMIT 1")
    local function read_on(offset)
        return stmt:reset():bind(day_start(t, offset), day_start(t, offset - 1)):step() ~= nil
    end
    local start = read_on(0) and 0 or 1
    local days = 0
    while days < MAX_STREAK and read_on(start + days) do
        days = days + 1
    end
    stmt:close()
    return days
end

-- The first column of each row of sql run with the one value bound.
local function column(conn, sql, value)
    local stmt = conn:prepare(sql)
    local values = {}
    local row = stmt:bind(value):step()
    while row do
        values[#values + 1] = row[1]
        row = stmt:step()
    end
    stmt:close()
    return values
end

-- f(conn) run on the database at path, opened read-only and closed after: true and f's result,
-- or false and the error's first line, logged.
local function with_db(path, f)
    local conn
    local ok, result = pcall(function()
        -- Required here, once a database exists, rather than at load: the binding ffi.cdef()s
        -- when it loads, which a process can do once (spec/emulator/driver.lua:87-88), and
        -- Busted unloads it after each spec file. On a device the require cache holds it.
        local SQ3 = require("lua-ljsqlite3/init")
        conn = SQ3.open(path, "ro")
        return f(conn)
    end)
    if conn then
        pcall(conn.close, conn)
    end
    if not ok then
        -- lj-sqlite3's errors carry a traceback after the first line (lua-ljsqlite3/init.lua:58-61).
        result = tostring(result):match("^[^\n]*")
        logger.err("KoPanda: could not read the Statistics database:", result)
    end
    return ok, result
end

local function query(conn, now)
    local t = os.date("*t", now)
    local month = os.time{ year = t.year, month = t.month, day = 1, hour = 0 }

    local seconds = tonumber(column(conn,
        "SELECT coalesce(sum(duration), 0) FROM page_stat_data WHERE start_time >= ?", day_start(t, 0))[1])
    local books = tonumber(column(conn,
        "SELECT count(DISTINCT id_book) FROM page_stat_data WHERE start_time >= ?", month)[1])
    return {
        streak = streak(conn, t),
        minutes_today = math.floor(seconds / 60),
        books_month = books,
        month_name = datetime.longMonthTranslation[MONTHS[t.month]],
    }
end

local function empty(now)
    return {
        state = "empty",
        streak = 0,
        minutes_today = 0,
        books_month = 0,
        month_name = datetime.longMonthTranslation[MONTHS[os.date("*t", now).month]],
    }
end

-- The reading stats at now (epoch seconds): { state, streak, minutes_today, books_month,
-- month_name }. state is "off" when Statistics doesn't record, "empty" with no database or
-- nothing read (no streak and no minutes today), "ok" otherwise. The database is opened
-- read-only and only when it exists, since an open that creates it would leave an empty file
-- the plugin then fails to open (main.lua:292-317). A failed read is logged and reads as empty,
-- or, when the database is busy (Statistics writing), as the last numbers read. Never raises.
function ReadingStats.read(now)
    local ok, result = pcall(function()
        if off() then
            return { state = "off" }
        end
        local path = db_path()
        if not util.fileExists(path) then
            return empty(now)
        end
        local read_ok, numbers = with_db(path, function(conn)
            return query(conn, now)
        end)
        if not read_ok then
            local busy = numbers:find("ljsqlite3%[busy%]") or numbers:find("ljsqlite3%[locked%]")
            if busy and last then
                return last
            end
            return empty(now)
        end
        if numbers.streak == 0 and numbers.minutes_today == 0 then
            return empty(now)
        end
        numbers.state = "ok"
        last = numbers
        return numbers
    end)
    if not ok then
        logger.err("KoPanda: could not read the reading stats:", result)
        return empty(now)
    end
    return result
end

-- The Statistics plugin's cap on one page's reading time, in seconds: max_sec from its settings,
-- read without a default, else its default of 120 (plugins/statistics.koplugin/main.lua:30,
-- :83, :143).
local function max_sec()
    local settings = G_reader_settings:readSetting("statistics")
    if type(settings) == "table" and type(settings.max_sec) == "number" then
        return settings.max_sec
    end
    return 120
end

-- The book row's id and pages for md5, the most recently opened row winning: md5 alone isn't
-- unique (main.lua:462-484). Then the plugin's capped average over the pages read
-- (main.lua:40-49), from the page_stat view, which rescales every row to the book row's pages
-- (main.lua:422-452).
local function rate(conn, md5)
    local stmt = conn:prepare("SELECT id, pages FROM book WHERE md5 = ? ORDER BY last_open DESC LIMIT 1")
    local book = stmt:bind(md5):step()
    stmt:close()
    if not book then
        return nil
    end
    local id, pages = book[1], tonumber(book[2])
    stmt = conn:prepare("SELECT count(*), sum(durations) FROM (SELECT min(sum(duration), ?) AS durations "
        .. "FROM page_stat WHERE id_book = ? GROUP BY page)")
    local row = stmt:bind(max_sec(), id):step()
    stmt:close()
    local count = row and tonumber(row[1])
    if not count or count == 0 then
        return nil
    end
    return { tonumber(row[2]) / count, pages }
end

-- The Statistics plugin's reading speed for the book whose partial md5 is md5, as seconds per
-- page, and the pages its book row holds; nil when Statistics doesn't record, there is no
-- database, the book has no row or no page read, or the read fails (logged). The database is
-- opened read-only and only when it exists, as ReadingStats.read opens it. Never raises.
function ReadingStats.seconds_per_page(md5)
    local ok, result = pcall(function()
        if off() then
            return nil
        end
        local path = db_path()
        if not util.fileExists(path) then
            return nil
        end
        local read_ok, found = with_db(path, function(conn)
            return rate(conn, md5)
        end)
        return read_ok and found or nil
    end)
    if not ok then
        logger.err("KoPanda: could not read the reading speed:", result)
        return nil
    end
    if result then
        return result[1], result[2]
    end
    return nil
end

return ReadingStats
