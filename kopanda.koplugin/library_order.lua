-- What a library folder shows, in what order, on which page, and what the library remembers.
-- The orders (cover-grid D3, D8, D9): folders first by the title order of their names, then the
-- books the status keeps, in the sort's order; every order ends on id, so it is total. Pages
-- hold six items. The memory (D11): the sort and status per folder, by its realpath, and the
-- folder and page the library was left at, under the runtime state file's one key `library`
-- = { folders = { [realpath] = { sort, status } }, at = { dir, page } }; never a setting.
-- Module state: this session's choices and folder left, read before the file, so a choice
-- whose write failed still holds until the plugin reloads.
local BookIndex = require("book_index")
local State = require("state")
local ffiutil = require("ffi/util")
local logger = require("logger")

local LibraryOrder = {}

local PER_PAGE = 6
local SORTS = { recent = true, title = true, author = true, series = true }
-- Each status's sidecar status (Books.progress); All keeps every book.
local STATUSES = { reading = "reading", finished = "complete", all = true }
local DEFAULT_SORT, DEFAULT_STATUS = "recent", "all"

local session = { folders = {} }

-- The title order's key: lowercase, one leading "the ", "a " or "an " dropped. Exported for the
-- series list's order (series-and-authors D12).
local function title_key(text)
    local key = text:lower()
    for _, article in ipairs({ "the ", "a ", "an " }) do
        if key:sub(1, #article) == article then
            return key:sub(#article + 1)
        end
    end
    return key
end
LibraryOrder.title_key = title_key

-- a before b by keys, each a string or nil, a nil after every string; nil when they are equal.
local function before(ka, kb)
    if ka == kb then
        return nil
    end
    if ka == nil or kb == nil then
        return kb == nil
    end
    return ka < kb
end

local function by_title(a, b)
    local first = before(a.title_key, b.title_key)
    if first ~= nil then
        return first
    end
    return a.record.id < b.record.id
end

local function index_of(record)
    local index = record.series_index
    return type(index) == "number" and index == index and index or nil
end

local function series_of(record)
    local series = record.series
    return type(series) == "string" and series ~= "" and series or nil
end

local function author_of(record)
    local authors = record.authors
    return type(authors) == "table" and BookIndex.surname(authors[1]) or nil
end

-- Each sort's order over entries { record, title_key, … }, the keys a sort needs made once.
local ORDERS = {
    recent = function(a, b)
        if a.time ~= b.time then
            if a.time == nil or b.time == nil then
                return b.time == nil
            end
            return a.time > b.time
        end
        return by_title(a, b)
    end,
    title = by_title,
    author = function(a, b)
        local first = before(a.author, b.author)
        if first ~= nil then
            return first
        end
        return by_title(a, b)
    end,
    series = function(a, b)
        local first = before(a.series_key, b.series_key)
        if first == nil then
            first = before(a.series, b.series)
        end
        if first == nil then
            first = before(a.index, b.index)
        end
        if first ~= nil then
            return first
        end
        return by_title(a, b)
    end,
}

local function by_folder_name(a, b)
    local ka, kb = title_key(a.name), title_key(b.name)
    if ka ~= kb then
        return ka < kb
    end
    return a.path < b.path
end

-- The items a folder shows: listing's folders ({ books, folders }, as Books.folder gives it) by
-- the title order of their names, then the books status keeps, in sort's order; the listing's
-- own tables. progress_of(record) is Books.progress, called at most once per book, and only
-- under a status that filters. history_times maps a book id to its history time. An unknown sort
-- or status reads as the default.
function LibraryOrder.view(listing, sort, status, progress_of, history_times)
    local order = ORDERS[sort] or ORDERS[DEFAULT_SORT]
    local wanted = STATUSES[status] or STATUSES[DEFAULT_STATUS]
    local folders = {}
    for i, folder in ipairs(listing.folders) do
        folders[i] = folder
    end
    table.sort(folders, by_folder_name)
    local entries = {}
    for _, record in ipairs(listing.books) do
        local progress = wanted ~= true and progress_of(record)
        if wanted == true or (type(progress) == "table" and progress.status == wanted) then
            local series = series_of(record)
            entries[#entries + 1] = {
                record = record,
                title_key = title_key(record.title),
                time = history_times[record.id],
                author = author_of(record),
                series = series,
                series_key = series and title_key(series),
                index = series and index_of(record) or nil,
            }
        end
    end
    table.sort(entries, order)
    local items = folders
    for _, entry in ipairs(entries) do
        items[#items + 1] = entry.record
    end
    return items
end

-- { [book id] = time }: each reading history entry's file realpathed to the id Books gives it,
-- its newest time kept (history is most recent first, frontend/readhistory.lua:332-333). An
-- entry whose file is gone, or with no file or time, is skipped. The history is required now, so
-- it is the one KOReader holds.
function LibraryOrder.history_times()
    local times = {}
    for _, entry in ipairs(require("readhistory").hist) do
        local path = type(entry.file) == "string" and type(entry.time) == "number" and ffiutil.realpath(entry.file)
        if path then
            local id = "file:" .. path
            if times[id] == nil then
                times[id] = entry.time
            end
        end
    end
    return times
end

-- Page n of items, six to a page; the page count, at least 1; and n clamped into 1 to the count,
-- a missing or NaN n read as 1.
function LibraryOrder.page(items, n)
    local count = math.max(1, math.ceil(#items / PER_PAGE))
    n = tonumber(n)
    if n == nil or n ~= n then
        n = 1
    end
    n = math.max(1, math.min(count, math.floor(n)))
    local slice = {}
    for i = PER_PAGE * (n - 1) + 1, math.min(#items, PER_PAGE * n) do
        slice[#slice + 1] = items[i]
    end
    return slice, count, n
end

local function real(dir)
    return ffiutil.realpath(dir) or dir
end

local function is_page(page)
    return type(page) == "number" and page >= 1 and page == math.floor(page)
end

-- The stored memory, its malformed parts left out and logged: { folders, at }, each entry a
-- { sort, status } with each field valid or nil, at a { dir, page } or nil.
local function stored()
    local value = State.get("library")
    local memory = { folders = {} }
    if value == nil then
        return memory
    end
    if type(value) ~= "table" then
        logger.warn("KoPanda: the library's memory is not a table; reading the defaults:", value)
        return memory
    end
    local bad = false
    if type(value.folders) == "table" then
        for path, choice in pairs(value.folders) do
            if type(path) == "string" and type(choice) == "table" then
                local sort = SORTS[choice.sort] and choice.sort or nil
                local status = STATUSES[choice.status] and choice.status or nil
                bad = bad or sort ~= choice.sort or status ~= choice.status
                memory.folders[path] = { sort = sort, status = status }
            else
                bad = true
            end
        end
    elseif value.folders ~= nil then
        bad = true
    end
    local at = value.at
    if type(at) == "table" and type(at.dir) == "string" and is_page(at.page) then
        memory.at = { dir = at.dir, page = at.page }
    elseif at ~= nil then
        bad = true
    end
    if bad then
        logger.warn("KoPanda: the library's memory has malformed parts; reading them as the defaults")
    end
    return memory
end

-- Writes the stored memory with this session's choices and folder left over it.
local function write()
    local memory = stored()
    for path, choice in pairs(session.folders) do
        memory.folders[path] = { sort = choice.sort, status = choice.status }
    end
    if session.at then
        memory.at = { dir = session.at.dir, page = session.at.page }
    end
    if next(memory.folders) == nil then
        memory.folders = nil
    end
    return State.set("library", memory)
end

-- { sort, status } for dir: this session's choice, else the stored one, else Recent and All.
function LibraryOrder.choice(dir)
    local path = real(dir)
    local choice = session.folders[path] or stored().folders[path] or {}
    return { sort = choice.sort or DEFAULT_SORT, status = choice.status or DEFAULT_STATUS }
end

-- Stores sort and status for dir; nil keeps that one's current choice. An unknown value is
-- refused, logged, and nothing is stored. Returns whether the state file took it; either way a
-- known choice holds for the session.
function LibraryOrder.choose(dir, sort, status)
    if (sort ~= nil and not SORTS[sort]) or (status ~= nil and not STATUSES[status]) then
        logger.warn("KoPanda: no library sort", sort, "or status", status)
        return false
    end
    local current = LibraryOrder.choice(dir)
    session.folders[real(dir)] = { sort = sort or current.sort, status = status or current.status }
    return write()
end

-- { dir, page } the library was left at: this session's, else the stored one, else nil.
function LibraryOrder.left()
    local at = session.at or stored().at
    return at and { dir = at.dir, page = at.page }
end

-- Stores dir and page as where the library was left. A dir that is not a string or a page that
-- is not a whole number from 1 is refused, logged, and nothing is stored. Returns whether the
-- state file took it; either way a well-formed one holds for the session.
function LibraryOrder.leave(dir, page)
    if type(dir) ~= "string" or not is_page(page) then
        logger.warn("KoPanda: no library folder", dir, "or page", page, "to leave at")
        return false
    end
    session.at = { dir = dir, page = page }
    return write()
end

return LibraryOrder
