-- The featured book: the one module that knows where it comes from. The pinned book when it
-- still exists, else the most recent book in KOReader's reading history that does; its title,
-- authors, progress, status and pages from the book model (books.lua), its time left from the
-- Statistics reading speed, and its chapter as KoPanda recorded it when the book closed. Only
-- reads: never the settings file, a sidecar or the history is written. Every KOReader read is
-- caught; a failure is logged and that part reads as absent.
-- Module state: the pinned paths already logged as gone, so each is logged once per process.
local Books = require("books")
local ReadingStats = require("reading_stats")
local Settings = require("settings")
local State = require("state")
local ffiutil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local FeaturedBook = {}

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

local function text(value)
    if type(value) == "string" and value ~= "" then
        return value
    end
end

-- The file name without its extension.
local function file_title(file)
    local name = file:match("([^/]*)$")
    return name:match("^(.+)%.[^.]*$") or name
end

local function joined(authors)
    return #authors > 0 and table.concat(authors, ", ") or nil
end

-- The record of file from the model, or, for a file gone since it was chosen, one named by its
-- file name.
local function record(file)
    return Books.for_path(file) or { path = file, title = file_title(file), authors = {} }
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
        local book = record(file)
        local progress = Books.progress(book)
        local percent = progress.percent
        local has_percent = percent ~= nil
        percent = percent or 0

        -- Time left over the Statistics book row's pages, the pages page_stat rescales to
        -- (plugins/statistics.koplugin/main.lua:422-452), as its own popup sums it (:1579).
        local seconds_left
        if progress.md5 and has_percent then
            local rate, book_pages = ReadingStats.seconds_per_page(progress.md5)
            if rate and book_pages then
                seconds_left = (book_pages - math.floor(percent * book_pages + 0.5)) * rate
            end
        end

        return {
            file = file,
            title = book.title,
            authors = joined(book.authors),
            percent = percent,
            -- "new" is a book never opened; the featured book shows one from the history.
            status = progress.status == "new" and "reading" or progress.status,
            pages = progress.pages,
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
    local book = record(file)
    return {
        file = file,
        title = book.title,
        authors = joined(book.authors),
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
