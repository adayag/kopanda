-- The current year's finished books: KOReader's history (frontend/readhistory.lua:25-35, newest first) walked to the
-- year's start, each book's status and summary date from its sidecar through Books, and the date corrected by the
-- Statistics reading days, since any save of a summary rewrites it (filemanagerutil.lua:111).
local Books = require("books")
local ReadingStats = require("reading_stats")
local logger = require("logger")

local FinishedBooks = {}

-- The last of days (sorted "YYYY-MM-DD") on or before stamped, or stamped with none.
function FinishedBooks.finish_day(stamped, days)
    local day
    for _, candidate in ipairs(days or {}) do
        if candidate > stamped then
            break
        end
        day = candidate
    end
    return day or stamped
end

-- { record, day } for the book at path when it was finished in year (a "YYYY"), else nil. The summary's date comes
-- from a sidecar, so one that isn't a date reads as none.
local function finished(path, year, days)
    local record, progress = Books.with_progress(path)
    if not (record and progress and progress.status == "complete") then
        return nil
    end
    local stamped = Books.details(record).modified
    if not (stamped and stamped:match("^%d%d%d%d%-%d%d%-%d%d$")) then
        return nil
    end
    local day = FinishedBooks.finish_day(stamped, days[progress.md5])
    if day:sub(1, 4) == year then
        return { record = record, day = day }
    end
end

local function collect(now)
    local year = os.date("%Y", now)
    local start = os.time{ year = tonumber(year), month = 1, day = 1, hour = 0 }
    local days = ReadingStats.reading_days(now)
    local list, seen = {}, {}
    for _, entry in ipairs(require("readhistory").hist) do
        -- KOReader lets a nil time through (frontend/readhistory.lua:25-36, frontend/datetime.lua:297).
        local dated = type(entry.time) == "number"
        if dated and entry.time < start then
            break
        end
        if dated and not entry.dim and not seen[entry.file] then
            seen[entry.file] = true
            local ok, book = pcall(finished, entry.file, year, days)
            if not ok then
                logger.err("KoPanda: could not read the finished book", entry.file, book)
            elseif book then
                list[#list + 1] = book
            end
        end
    end
    table.sort(list, function(a, b)
        if a.day ~= b.day then
            return a.day < b.day
        end
        return (a.record.title or "") < (b.record.title or "")
    end)
    return list
end

-- The books finished in now's year, oldest first, each { record, day }. Never raises.
function FinishedBooks.list(now)
    local ok, list = pcall(collect, now)
    if not ok then
        logger.err("KoPanda: could not list the finished books:", list)
        return {}
    end
    return list
end

return FinishedBooks
