-- Reading stats from KOReader's Statistics plugin: its database, read-only, for a book's reading speed and history
-- and for the reading history of the last year, and its settings, for whether it records at all and its cap on one
-- page's time. Days are local calendar days, bounded by os.time. State: the last history read, which a busy database
-- reads as, and the memo of the reads, which a build reads instead of the database while Statistics hasn't written.
local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local util = require("util")

local ReadingStats = {}

-- The plugin's database (plugins/statistics.koplugin/main.lua:27).
local function db_path()
    return DataStorage:getSettingsDir() .. "/statistics.sqlite3"
end

local last_insights

-- The last reads, each valid while the files' stamp is key: rate, seconds_per_page's for md5 under the cap (nil when
-- none is found); history, book_history's for md5; insights, the result of insights for the local date of now, and
-- for now itself while the stamp is nil.
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

ReadingStats.INSIGHT_DAYS = 371
local HOUR_DAYS = 84
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

-- The history of the book row for md5 that was opened last, as rate picks it: its total_read_time, the local
-- dates and first start of its page rows (main.lua:405-419) and its last_open (:462-477); nil for no row.
local function history(conn, md5)
    local stmt = conn:prepare("SELECT id, total_read_time, last_open FROM book WHERE md5 = ? "
        .. "ORDER BY last_open DESC LIMIT 1")
    local book = stmt:bind(md5):step()
    stmt:close()
    if not book then
        return nil
    end
    stmt = conn:prepare("SELECT count(DISTINCT strftime('%Y-%m-%d', start_time, 'unixepoch', 'localtime')), "
        .. "min(start_time) FROM page_stat_data WHERE id_book = ?")
    local row = stmt:bind(book[1]):step()
    stmt:close()
    return {
        seconds = tonumber(book[2]) or 0,
        days = row and tonumber(row[1]) or 0,
        first = row and tonumber(row[2]),
        last = tonumber(book[3]),
    }
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

-- The reading history at now (epoch seconds): { state, days, hours, sessions }, as insight_query reads them. state
-- is "off" when Statistics doesn't record, "empty" (zeros, no sessions) with no database or no reading in the days,
-- "ok" otherwise. The database is opened read-only and only when it exists, since an open that creates it would leave
-- an empty file the plugin then fails to open (main.lua:292-317). A failed read is logged and reads as empty, or, when
-- the database is busy, as the last history read. Kept for now's local date while the files' stamp holds. Never
-- raises.
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
            return rate(conn, md5, cap)
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

-- The Statistics plugin's history of the book whose partial md5 is md5: { seconds, days, first, last }, its time
-- read in seconds, the local days it was read on, the start of its first page read (nil with none) and when it
-- was last opened; nil when Statistics doesn't record, there is no database, the book has no row, or the read
-- fails (logged). Opened read-only and only when the database exists. Kept for md5 while the files' stamp
-- holds. Never raises.
function ReadingStats.book_history(md5)
    local ok, result = pcall(function()
        if off() then
            return nil
        end
        local path = db_path()
        if not util.fileExists(path) then
            return nil
        end
        local key = stamp(path)
        local held = memo.history
        if key and held and held.key == key and held.md5 == md5 then
            return held.value
        end
        local read_ok, found = with_db(path, function(conn)
            return history(conn, md5)
        end)
        if not read_ok then
            return nil
        end
        if key then
            memo.history = { key = key, md5 = md5, value = found }
        end
        return found
    end)
    if not ok then
        logger.err("KoPanda: could not read the book's reading history:", result)
        return nil
    end
    return result
end

return ReadingStats
