-- The book status page's content: a Books record, its progress, its details (Books.details) and its Statistics
-- history in, the page's sections out, each left out when it has nothing to show; and the description split into
-- pages of whole lines for given heights. The description is made plain text by util.htmlToPlainTextIfHtml
-- (frontend/util.lua:1295), as KOReader's own details page does (filemanagerbookinfo.lua:450).
local Featured = require("widgets/featured")
local Helpers = require("helpers")
local Math = require("optmath")
local logger = require("logger")
local util = require("util")

local BookStatus = {}

local JOIN = " · "
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local HOUR = 3600
-- The time left's step from an hour up.
local LEFT_STEP = 600

-- t (epoch seconds) as "3 Oct", with its year when that isn't now's.
local function date_text(t, now)
    local date = os.date("*t", t)
    local text = date.day .. " " .. MONTHS[date.month]
    if date.year ~= os.date("*t", now).year then
        text = text .. " " .. date.year
    end
    return text
end

-- A sidecar's summary.modified, written as %Y-%m-%d (frontend/apps/filemanager/filemanagerutil.lua:111), as the
-- local noon of that day; nil for anything else, a day that isn't on the calendar included.
local function modified_time(modified)
    if type(modified) ~= "string" then
        return nil
    end
    local year, month, day = modified:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if not year then
        return nil
    end
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if month < 1 or month > 12 or day < 1 then
        return nil
    end
    local t = os.time{ year = year, month = month, day = day, hour = 12 }
    local back = os.date("*t", t)
    if back.year ~= year or back.month ~= month or back.day ~= day then
        return nil
    end
    return t
end

local function pages_text(n)
    return n == 1 and "1 page" or n .. " pages"
end

-- A time read or left: "Under a minute" below 60 s, else Helpers.duration's.
local function duration(seconds)
    if seconds < 60 then
        return "Under a minute"
    end
    return Helpers.duration(seconds)
end

-- seconds left, to the minute below an hour and to the nearest ten minutes from one.
local function left_text(seconds)
    if seconds < 60 then
        return "Under a minute left"
    end
    if seconds >= HOUR then
        seconds = Math.round(seconds / LEFT_STEP) * LEFT_STEP
    end
    return "About " .. Helpers.duration(seconds) .. " left"
end

local function book_section(record, pages)
    local series = record.series
    if series and record.series_index then
        local index = record.series_index
        series = series .. JOIN .. "#" .. (index == math.floor(index) and ("%d"):format(index) or ("%g"):format(index))
    end
    return {
        kind = "book",
        title = record.title,
        author = #record.authors > 0 and table.concat(record.authors, ", ") or nil,
        series = series,
        length = pages and pages_text(pages) or nil,
        subjects = record.subjects or {},
    }
end

-- Seconds per page × the pages to go, over the Statistics book row's pages, which its page times are rescaled
-- to (plugins/statistics.koplugin/main.lua:422-452), as the featured book counts them (featured_book.lua).
local function seconds_left(percent, history)
    local rate, pages = history and history.rate, history and history.rate_pages
    if not (rate and pages) then
        return nil
    end
    return math.max(0, pages - math.floor(percent * pages + 0.5)) * rate
end

local function progress_section(progress, pages, details, history, now)
    if progress.status == "complete" then
        local finished = modified_time(details.modified)
        return { kind = "progress", shown = 100, caption = finished and "Finished " .. date_text(finished, now)
            or "Finished" }
    end
    local percent = progress.percent
    if progress.status == "new" or type(percent) ~= "number" then
        return nil
    end
    local shown = Featured.shown_percent(progress)
    local caption = shown .. "%"
    if pages then
        caption = caption .. JOIN .. "page " .. math.max(1, Math.round(percent * pages)) .. " of " .. pages
    end
    local left = seconds_left(percent, history)
    return { kind = "progress", shown = shown, caption = caption, left = left and left_text(left) or nil }
end

local function history_section(history, now)
    if not history then
        return nil
    end
    local seconds, days = tonumber(history.seconds) or 0, tonumber(history.days) or 0
    local total
    if seconds > 0 or days > 0 then
        total = duration(seconds)
        if days > 0 then
            total = total .. " over " .. (days == 1 and "1 day" or days .. " days")
        end
    end
    local dates = {}
    if type(history.first) == "number" then
        dates[#dates + 1] = "Started " .. date_text(history.first, now)
    end
    if type(history.last) == "number" then
        dates[#dates + 1] = "Last read " .. date_text(history.last, now)
    end
    if not total and #dates == 0 then
        return nil
    end
    return { kind = "history", total = total, dates = #dates > 0 and table.concat(dates, JOIN) or nil }
end

-- The description as plain text, one paragraph a line, each trimmed; nil when nothing is left.
local function plain(description)
    if type(description) ~= "string" then
        return nil
    end
    local paragraphs = {}
    for line in (util.htmlToPlainTextIfHtml(description) .. "\n"):gmatch("([^\n]*)\n") do
        local paragraph = util.trim(line)
        if paragraph ~= "" then
            paragraphs[#paragraphs + 1] = paragraph
        end
    end
    return #paragraphs > 0 and table.concat(paragraphs, "\n") or nil
end

-- The page's sections, in order: book { title, author, series, length, subjects }, progress { shown (0 to 100),
-- caption, left }, history { total, dates } and description { text }, each left out when it has nothing to show
-- and its own fields nil when unknown. record is a Books record, progress Books.progress's, details
-- Books.details', history ReadingStats.book_history's with seconds_per_page's rate and rate_pages (nil with
-- Statistics off), now epoch seconds. A description whose conversion raises is logged and left out.
function BookStatus.sections(record, progress, details, history, now)
    local pages = details.pages
    if not pages and type(progress.pages) == "number" and progress.pages > 0 then
        pages = progress.pages
    end
    local list = { book_section(record, pages) }
    list[#list + 1] = progress_section(progress, pages, details, history, now)
    list[#list + 1] = history_section(history, now)
    local ok, text = pcall(plain, details.description)
    if not ok then
        logger.err("KoPanda: could not read the book's description:", text)
    elseif text then
        list[#list + 1] = { kind = "description", text = text }
    end
    return list
end

-- text's paragraphs (one a line) as pages of parts, each { paragraph, text, first, count }: count lines of
-- paragraph number paragraph from its line first. Page 1 is first_h high and every later page rest_h, a line
-- measure.line_h and measure.gap between two paragraphs on a page; measure.lines(paragraph) is its line count.
-- Page 1 is empty when it holds no line; a later page holds at least one, so the text always ends. No pages for
-- an empty text.
function BookStatus.split(text, first_h, rest_h, measure)
    local pages = {}
    if type(text) ~= "string" or text == "" then
        return pages
    end
    local page, room = {}, first_h
    local function turn()
        pages[#pages + 1] = page
        page, room = {}, rest_h
    end
    local i = 0
    for paragraph in text:gmatch("[^\n]+") do
        i = i + 1
        local total, first = measure.lines(paragraph), 1
        while first <= total do
            local gap = #page > 0 and measure.gap or 0
            local fit = math.min(total - first + 1, math.floor((room - gap) / measure.line_h))
            if fit < 1 and #page == 0 and #pages > 0 then
                fit = 1
            end
            if fit < 1 then
                turn()
            else
                page[#page + 1] = { paragraph = i, text = paragraph, first = first, count = fit }
                room = room - gap - fit * measure.line_h
                first = first + fit
            end
        end
    end
    if #page > 0 then
        pages[#pages + 1] = page
    end
    return pages
end

return BookStatus
