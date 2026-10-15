-- Reading stats from KOReader's Statistics plugin: its database, read-only, for the streak,
-- minutes today and books this month, and its settings, for whether it records at all.
-- Days are local calendar days: SQLite's 'localtime' and os.date both follow the process TZ.
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

-- The local date, as SQLite's date() writes it, offset days from the day of t (a *t table).
local function day_key(t, offset)
    return os.date("%Y-%m-%d", os.time{ year = t.year, month = t.month, day = t.day - offset, hour = 12 })
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

local function query(conn, now)
    local t = os.date("*t", now)
    local today = os.time{ year = t.year, month = t.month, day = t.day, hour = 0 }
    local month = os.time{ year = t.year, month = t.month, day = 1, hour = 0 }
    local scan = os.time{ year = t.year, month = t.month, day = t.day - MAX_STREAK, hour = 0 }

    local seconds = tonumber(column(conn,
        "SELECT coalesce(sum(duration), 0) FROM page_stat_data WHERE start_time >= ?", today)[1])
    local books = tonumber(column(conn,
        "SELECT count(DISTINCT id_book) FROM page_stat_data WHERE start_time >= ?", month)[1])
    local days = {}
    for _, day in ipairs(column(conn, "SELECT DISTINCT date(start_time, 'unixepoch', 'localtime') "
            .. "FROM page_stat_data WHERE start_time >= ? ORDER BY 1 DESC", scan)) do
        days[day] = true
    end

    -- From today, or from yesterday when nothing is read yet today.
    local start = days[day_key(t, 0)] and 0 or 1
    local streak = 0
    while streak < MAX_STREAK and days[day_key(t, start + streak)] do
        streak = streak + 1
    end
    return {
        streak = streak,
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
        local conn
        local read_ok, numbers = pcall(function()
            -- Required here, once a database exists, rather than at load: the binding ffi.cdef()s
            -- when it loads, which a process can do once (spec/emulator/driver.lua:87-88), and
            -- Busted unloads it after each spec file. On a device the require cache holds it.
            local SQ3 = require("lua-ljsqlite3/init")
            conn = SQ3.open(path, "ro")
            return query(conn, now)
        end)
        if conn then
            pcall(conn.close, conn)
        end
        if not read_ok then
            -- lj-sqlite3's errors carry a traceback after the first line (lua-ljsqlite3/init.lua:58-61).
            local message = tostring(numbers):match("^[^\n]*")
            logger.err("KoPanda: could not read the Statistics database:", message)
            local busy = message:find("ljsqlite3%[busy%]") or message:find("ljsqlite3%[locked%]")
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

return ReadingStats
