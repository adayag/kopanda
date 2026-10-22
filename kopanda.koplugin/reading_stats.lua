-- Reading stats from KOReader's Statistics plugin: its database, read-only, for the streak, minutes today and
-- books this month, for a book's reading speed and for the reading history of the last year, and its settings,
-- for whether it records at all and its cap on one page's time. Days are local calendar days, bounded by
-- os.time. State: the last numbers and history read, which a busy database reads as, and the memo of the reads,
-- which a home build reads instead of the database while Statistics hasn't written.
local DataStorage = require("datastorage")
local datetime = require("datetime")
local lfs = require("libs/libkoreader-lfs")
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
local last_insights

-- The last reads, each valid while the files' stamp is key: numbers, the result of read for the
-- local date of now, kept with no key when the stamp is nil so that a refresh reads the latest
-- date read; rate, seconds_per_page's for md5 under the cap (nil when none is found); insights,
-- the result of insights for the local date of now, and for now itself while the stamp is nil.
local memo = {}

-- The size and modification time of the database and of its WAL file, the two files Statistics writes, as one
-- string; nil when either is dated within the last two seconds, since a later write could leave both
-- unchanged: lfs's mtimes are whole seconds, and the Kindle's userstore is vfat under a fuse overlay
-- (platform/kindle/koreader.sh:13, :151-152), which dates files in two-second steps (an assumption until
-- mount on the device confirms the vfat). An empty file reads as none: a read-only open of a WAL database
-- leaves an empty WAL file behind.
local function stamp(path)
    local now = os.time()
    local parts = {}
    for i, file in ipairs{ path, path .. "-wal" } do
        local attributes = lfs.attributes(file)
        if attributes and attributes.size > 0 then
            if attributes.modification >= now - 1 then
                return nil
            end
            parts[i] = attributes.size .. "@" .. attributes.modification
        else
            parts[i] = "none"
        end
    end
    return table.concat(parts, " ")
end

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
        -- Required here, once a database exists: the binding ffi.cdef()s when it loads, which a process can do once
        -- (spec/emulator/driver.lua:87-88), and Busted unloads it after each spec file.
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

ReadingStats.INSIGHT_DAYS = 371
local HOUR_DAYS = 90
local SESSION_DAYS = 365
local SESSION_GAP = 1800

-- Seconds per local day for the INSIGHT_DAYS days ending today, oldest first; per hour of the day over the last
-- HOUR_DAYS days; and the sessions of the last SESSION_DAYS days: runs of page rows each starting within
-- SESSION_GAP of the latest end before it. SQLite groups by the C library's local zone, the one os.date uses.
local function insight_query(conn, now)
    local t = os.date("*t", now)
    local days, index = {}, {}
    for i = 1, ReadingStats.INSIGHT_DAYS do
        days[i] = 0
        index[os.date("%Y-%m-%d", day_start(t, ReadingStats.INSIGHT_DAYS - i) + 43200)] = i
    end
    local stmt = conn:prepare("SELECT strftime('%Y-%m-%d', start_time, 'unixepoch', 'localtime'), sum(duration)"
        .. " FROM page_stat_data WHERE start_time >= ? GROUP BY 1")
    local row = stmt:bind(day_start(t, ReadingStats.INSIGHT_DAYS - 1)):step()
    while row do
        local i = index[row[1]]
        if i then
            days[i] = tonumber(row[2]) or 0
        end
        row = stmt:step()
    end
    stmt:close()

    local hours = {}
    for i = 1, 24 do
        hours[i] = 0
    end
    stmt = conn:prepare("SELECT strftime('%H', start_time, 'unixepoch', 'localtime'), sum(duration)"
        .. " FROM page_stat_data WHERE start_time >= ? GROUP BY 1")
    row = stmt:bind(day_start(t, HOUR_DAYS - 1)):step()
    while row do
        hours[tonumber(row[1]) + 1] = tonumber(row[2]) or 0
        row = stmt:step()
    end
    stmt:close()

    local sessions, current, pages, total = {}, nil, 0, 0
    stmt = conn:prepare("SELECT start_time, duration FROM page_stat_data WHERE start_time >= ? ORDER BY start_time")
    row = stmt:bind(day_start(t, SESSION_DAYS - 1)):step()
    while row do
        local start, duration = tonumber(row[1]), tonumber(row[2]) or 0
        if not current or start - current.ends > SESSION_GAP then
            current = { seconds = 0, ends = start }
            sessions[#sessions + 1] = current
        end
        current.seconds = current.seconds + duration
        current.ends = math.max(current.ends, start + duration)
        pages, total = pages + 1, total + duration
        row = stmt:step()
    end
    stmt:close()
    local summary
    if #sessions > 0 then
        local longest = 0
        for _, s in ipairs(sessions) do
            longest = math.max(longest, s.seconds)
        end
        summary = {
            count = #sessions,
            longest = longest,
            average = math.floor(total / #sessions + 0.5),
            pages_per_hour = total > 0 and math.floor(pages * 3600 / total + 0.5) or 0,
        }
    end
    return { state = "ok", days = days, hours = hours, sessions = summary }
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

-- What query read at now, as read gives it: empty with no streak and no minutes today.
local function finish(numbers, now)
    if numbers.streak == 0 and numbers.minutes_today == 0 then
        return empty(now)
    end
    numbers.state = "ok"
    last = numbers
    return numbers
end

-- The numbers again, on a connection opened for a book's rate, when the memo holds them for an older stamp or
-- none: a home build after a Statistics write opens the database once when the files are settled. With no
-- stamp, as right after a book closes, nothing is refreshed and read and seconds_per_page each open it. They
-- are read for the latest date read, so a busy database's last numbers stay that date's. A failure leaves
-- them stale.
local function refresh_numbers(conn, key)
    local held = memo.numbers
    if key and held and held.key ~= key then
        local ok, numbers = pcall(query, conn, held.now)
        if ok then
            memo.numbers = { key = key, date = held.date, now = held.now, value = finish(numbers, held.now) }
        end
    end
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

-- The book row's id and pages for md5, the most recently opened row winning: md5 alone isn't unique
-- (main.lua:462-484). Then the plugin's capped average over the pages read (main.lua:40-49), from the
-- page_stat view, which rescales every row to the book row's pages (main.lua:422-452), each page's time
-- capped at cap seconds.
local function rate(conn, md5, cap)
    local stmt = conn:prepare("SELECT id, pages FROM book WHERE md5 = ? ORDER BY last_open DESC LIMIT 1")
    local book = stmt:bind(md5):step()
    stmt:close()
    if not book then
        return nil
    end
    local id, pages = book[1], tonumber(book[2])
    stmt = conn:prepare("SELECT count(*), sum(durations) FROM (SELECT min(sum(duration), ?) AS durations "
        .. "FROM page_stat WHERE id_book = ? GROUP BY page)")
    local row = stmt:bind(cap, id):step()
    stmt:close()
    local count = row and tonumber(row[1])
    if not count or count == 0 then
        return nil
    end
    return { tonumber(row[2]) / count, pages }
end

-- The book's rate again, on a connection opened for the numbers, when the memo holds it for an
-- older stamp, as refresh_numbers reads the numbers again.
local function refresh_rate(conn, key)
    local held = memo.rate
    if key and held and held.key ~= key then
        local cap = max_sec()
        local ok, found = pcall(rate, conn, held.md5, cap)
        if ok then
            memo.rate = { key = key, md5 = held.md5, cap = cap, value = found }
        end
    end
end

-- The reading stats at now (epoch seconds): { state, streak, minutes_today, books_month, month_name }. state
-- is "off" when Statistics doesn't record, "empty" with no database or nothing read, "ok" otherwise. The
-- database is opened read-only and only when it exists, since an open that creates it would leave an empty
-- file the plugin then fails to open (main.lua:292-317). A failed read is logged and reads as empty, or, when
-- the database is busy, as the last numbers read. Kept for now's local date while the files' stamp holds.
-- Never raises.
function ReadingStats.read(now)
    local ok, result = pcall(function()
        if off() then
            return { state = "off" }
        end
        local path = db_path()
        if not util.fileExists(path) then
            return empty(now)
        end
        local key = stamp(path)
        local date = os.date("%Y-%m-%d", now)
        local held = memo.numbers
        if key and held and held.key == key and held.date == date then
            return held.value
        end
        local read_ok, numbers = with_db(path, function(conn)
            local numbers = finish(query(conn, now), now)
            refresh_rate(conn, key)
            return numbers
        end)
        if not read_ok then
            local busy = numbers:find("ljsqlite3%[busy%]") or numbers:find("ljsqlite3%[locked%]")
            if busy and last then
                return last
            end
            return empty(now)
        end
        memo.numbers = { key = key, date = date, now = now, value = numbers }
        return numbers
    end)
    if not ok then
        logger.err("KoPanda: could not read the reading stats:", result)
        return empty(now)
    end
    return result
end

local function empty_insights()
    local days, hours = {}, {}
    for i = 1, ReadingStats.INSIGHT_DAYS do
        days[i] = 0
    end
    for i = 1, 24 do
        hours[i] = 0
    end
    return { state = "empty", days = days, hours = hours }
end

-- The reading history at now (epoch seconds): { state, days, hours, sessions }, as insight_query reads them, with
-- state as read gives it, "empty" (zeros, no sessions) also when the days hold no reading. Opened, kept and read
-- when busy as read does. Never raises.
function ReadingStats.insights(now)
    local ok, result = pcall(function()
        if off() then
            return { state = "off" }
        end
        local path = db_path()
        if not util.fileExists(path) then
            return empty_insights()
        end
        local key = stamp(path)
        local date = os.date("%Y-%m-%d", now)
        local held = memo.insights
        if held and (key and held.key == key and held.date == date or not key and held.now == now) then
            return held.value
        end
        local read_ok, insights = with_db(path, function(conn)
            return insight_query(conn, now)
        end)
        if not read_ok then
            local busy = insights:find("ljsqlite3%[busy%]") or insights:find("ljsqlite3%[locked%]")
            if busy and last_insights then
                return last_insights
            end
            return empty_insights()
        end
        if math.max(unpack(insights.days)) == 0 then
            insights = empty_insights()
        else
            last_insights = insights
        end
        memo.insights = { key = key, date = date, now = now, value = insights }
        return insights
    end)
    if not ok then
        logger.err("KoPanda: could not read the reading history:", result)
        return empty_insights()
    end
    return result
end

-- The Statistics plugin's reading speed for the book whose partial md5 is md5, as seconds per page, and the
-- pages its book row holds; nil when Statistics doesn't record, there is no database, the book has no row or
-- no page read, or the read fails (logged). Opened read-only and only when the database exists. Kept for md5
-- and the cap while the files' stamp holds. Never raises.
function ReadingStats.seconds_per_page(md5)
    local ok, result = pcall(function()
        if off() then
            return nil
        end
        local path = db_path()
        if not util.fileExists(path) then
            return nil
        end
        local key = stamp(path)
        local cap = max_sec()
        local held = memo.rate
        if key and held and held.key == key and held.md5 == md5 and held.cap == cap then
            return held.value
        end
        local read_ok, found = with_db(path, function(conn)
            local found = rate(conn, md5, cap)
            refresh_numbers(conn, key)
            return found
        end)
        if not read_ok then
            return nil
        end
        if key then
            memo.rate = { key = key, md5 = md5, cap = cap, value = found }
        end
        return found
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
