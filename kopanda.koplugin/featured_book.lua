-- The featured book: the one module that knows where it comes from. The pinned book when it
-- still exists, else the most recent book in KOReader's reading history that does; its title
-- and authors from CoverBrowser or the sidecar, its progress, status and pages from the sidecar,
-- its time left from the Statistics reading speed, and its chapter as KoPanda recorded it when
-- the book closed. Only reads: never the settings file, a sidecar or the history is written.
-- Every KOReader read is caught; a failure is logged and that part reads as absent.
-- Module state: the pinned paths already logged as gone, so each is logged once per process.
local DocSettings = require("docsettings")
local ReadingStats = require("reading_stats")
local Settings = require("settings")
local State = require("state")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local FeaturedBook = {}

-- The statuses a sidecar's summary.status holds (frontend/ui/widget/booklist.lua:371-378).
local STATUSES = { reading = true, abandoned = true, complete = true }

local logged_gone = {}

local function is_file(path)
    return type(path) == "string" and lfs.attributes(path, "mode") == "file"
end

-- f(...) caught: its result, or nil with the failure logged as what.
local function try(what, f, ...)
    local ok, result = pcall(f, ...)
    if not ok then
        logger.err("KoPanda: could not read " .. what .. ":", result)
        return nil
    end
    return result
end

-- The reading history's files, most recent first (frontend/readhistory.lua:332-333), that are
-- still files, skipping entries KOReader marks unselectable and the QuickStart guide, as
-- ReaderUI:getLastDirFile skips it (frontend/apps/reader/readerui.lua:571-577), each passed to
-- each(file) until it returns true. Required on each call, not at load, so the history read is
-- the one KOReader holds now.
local function each_book(each)
    local quickstart = require("ui/quickstart").quickstart_filename
    for _, entry in ipairs(require("readhistory").hist) do
        local file = entry.file
        if entry.select_enabled ~= false and file ~= quickstart and is_file(file) then
            if each(file) then
                return
            end
        end
    end
end

-- The first of them.
local function most_recent()
    local first
    each_book(function(file)
        first = file
        return true
    end)
    return first
end

-- The featured file: the pin when it names a file, else the most recent book; nil with neither.
local function featured_file()
    local pinned = Settings.get("featured.pinned")
    if pinned then
        if is_file(pinned) then
            return pinned
        end
        if not logged_gone[pinned] then
            logged_gone[pinned] = true
            logger.warn("KoPanda: the pinned featured book is gone, featuring the last one opened:", pinned)
        end
    end
    return try("the reading history", most_recent)
end

-- The book's sidecar, opened light so nothing is written or removed: DocSettings:open removes
-- candidates it finds invalid (frontend/docsettings.lua:282-284). With no sidecar file,
-- openSettingsFile(nil) holds empty data (:301-315).
local function sidecar(file)
    return DocSettings.openSettingsFile((DocSettings:findSidecarFile(file)))
end

-- The book's title and authors from CoverBrowser's cache, without a cover, or nil when
-- CoverBrowser is disabled (its folder joins package.path only when enabled) or hasn't indexed
-- the book (plugins/coverbrowser.koplugin/bookinfomanager.lua:325-404).
local function cached_info(file)
    local ok, BookInfoManager = pcall(require, "bookinfomanager")
    if not ok then
        return nil
    end
    return BookInfoManager:getBookInfo(file, false)
end

local function text(value)
    if type(value) == "string" and value ~= "" then
        return value
    end
end

local function joined(authors)
    authors = text(authors)
    return authors and (authors:gsub("\n", ", "))
end

-- The file name without its extension.
local function file_title(file)
    local name = file:match("([^/]*)$")
    return name:match("^(.+)%.[^.]*$") or name
end

-- The pages the sidecar records, in the order BookList reads them
-- (frontend/ui/widget/booklist.lua:298-306): pagemap_doc_pages with page labels on, else
-- doc_pages, else stats.pages unless 0 (crengine with Statistics off stores 0).
local function sidecar_pages(doc)
    local pages = doc:isTrue("pagemap_use_page_labels") and doc:readSetting("pagemap_doc_pages")
        or doc:readSetting("doc_pages")
    if pages == nil then
        local stats = doc:readSetting("stats")
        if type(stats) == "table" and stats.pages and stats.pages ~= 0 then
            pages = stats.pages
        end
    end
    return tonumber(pages)
end

-- The chapter recorded when file last closed under KoPanda: the recorded file compared through
-- realpath, since history holds realpaths (frontend/readhistory.lua:26) while the reader's
-- document.file is the path the book was opened with.
local function recorded_chapter(file)
    local chapter = text(State.get("featured_chapter"))
    local recorded = State.get("featured_chapter_file")
    if not (chapter and type(recorded) == "string") then
        return nil
    end
    local here = ffiutil.realpath(file) or file
    if (ffiutil.realpath(recorded) or recorded) == here then
        return chapter
    end
end

-- The featured book, or nil with none: { file, title, authors, percent, status, pages,
-- seconds_left, chapter }. percent is 0 to 1, 0 when unread; status is reading, abandoned or
-- complete; authors, pages, seconds_left and chapter may be nil. Never raises.
function FeaturedBook.current()
    local ok, result = pcall(function()
        local file = featured_file()
        if not file then
            return nil
        end
        local doc = try("the sidecar of " .. file, sidecar, file) or DocSettings.openSettingsFile(nil)
        local info = try("CoverBrowser's book info for " .. file, cached_info, file) or {}
        local props = doc:readSetting("doc_props")
        if type(props) ~= "table" then
            props = {}
        end

        local percent = doc:readSetting("percent_finished")
        local has_percent = type(percent) == "number"
        percent = has_percent and math.max(0, math.min(1, percent)) or 0

        local summary = doc:readSetting("summary")
        local status = type(summary) == "table" and summary.status
        if not STATUSES[status] then
            status = "reading"
        end

        -- Time left over the Statistics book row's pages, the pages page_stat rescales to
        -- (plugins/statistics.koplugin/main.lua:422-452), as its own popup sums it (:1579).
        local seconds_left
        local md5 = doc:readSetting("partial_md5_checksum")
        if type(md5) == "string" and has_percent then
            local rate, book_pages = ReadingStats.seconds_per_page(md5)
            if rate and book_pages then
                seconds_left = (book_pages - math.floor(percent * book_pages + 0.5)) * rate
            end
        end

        return {
            file = file,
            title = text(info.title) or text(props.title) or file_title(file),
            authors = joined(info.authors) or joined(props.authors),
            percent = percent,
            status = status,
            pages = sidecar_pages(doc),
            seconds_left = seconds_left,
            chapter = try("the recorded chapter", recorded_chapter, file),
        }
    end)
    if not ok then
        logger.err("KoPanda: could not read the featured book:", result)
        return nil
    end
    return result
end

-- One book for the picker: { file, title, authors }, read as current() reads them, a raising
-- read logged and left out. authors may be nil.
function FeaturedBook.describe(file)
    local doc = try("the sidecar of " .. file, sidecar, file) or DocSettings.openSettingsFile(nil)
    local info = try("CoverBrowser's book info for " .. file, cached_info, file) or {}
    local props = doc:readSetting("doc_props")
    if type(props) ~= "table" then
        props = {}
    end
    return {
        file = file,
        title = text(info.title) or text(props.title) or file_title(file),
        authors = joined(info.authors) or joined(props.authors),
    }
end

-- Up to n of the history's books the featured book would take, most recent first, each as
-- describe gives it. A book whose describe raises is left out and logged; a history that can't
-- be read gives what was read before it, logged. Never raises.
function FeaturedBook.recent(n)
    local books = {}
    local ok, err = pcall(each_book, function(file)
        if #books >= n then
            return true
        end
        local described, book = pcall(FeaturedBook.describe, file)
        if described then
            books[#books + 1] = book
        else
            logger.err("KoPanda: could not read the book", file, ":", book)
        end
        return #books >= n
    end)
    if not ok then
        logger.err("KoPanda: could not read the reading history:", err)
    end
    return books
end

-- For specs: forget which gone pins were logged.
function FeaturedBook.reset()
    logged_gone = {}
end

return FeaturedBook
