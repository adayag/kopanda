-- What the Series and Authors screens list, in what order, in what state and on which page
-- (series-and-authors D3, D12 to D17): the series with their state, chip counts, next unread and
-- author line; the authors by surname under their letters; one author's books with their up-next
-- marks; and the pagings by rows that fit whole. Pure: records in, tables out, nothing kept
-- between calls. The count wordings are the screens' (D10).
local BookIndex = require("book_index")
local LibraryOrder = require("library_order")

local ShelfOrder = {}

local function first_author(record)
    local authors = record.authors
    local name = type(authors) == "table" and authors[1]
    return type(name) == "string" and name ~= "" and name or nil
end

local function status_of(progress)
    return type(progress) == "table" and progress.status or nil
end

-- D15: the first author of the first book that has one, and whether any book's first author differs.
local function author_line(books)
    local author, others = nil, false
    for _, record in ipairs(books) do
        local name = first_author(record)
        if name then
            if author == nil then
                author = name
            elseif name ~= author then
                others = true
            end
        end
    end
    return author, others
end

-- D3: the state, the complete count and the next unread of books in series order, each book's
-- progress asked once.
local function series_state(books, progress_of)
    local complete, started, next_unread = 0, false, nil
    for _, record in ipairs(books) do
        local status = status_of(progress_of(record))
        if status == "complete" then
            complete = complete + 1
            started = true
        else
            if status == "reading" then
                started = true
            end
            if next_unread == nil and status ~= "abandoned" then
                next_unread = record
            end
        end
    end
    local state
    if complete == #books then
        state = "finished"
    elseif started then
        state = "under_way"
    else
        state = "not_started"
    end
    return state, complete, next_unread
end

-- D12: the under-way series first, then the rest, each part by the title order of the name, then
-- the name.
local function by_series(a, b)
    local wa, wb = a.state == "under_way", b.state == "under_way"
    if wa ~= wb then
        return wa
    end
    if a.key ~= b.key then
        return a.key < b.key
    end
    return a.name < b.name
end

-- One entry { name, books, state, complete, total, next, author, others } per series of records:
-- books in BookIndex.series' order; state "under_way", "finished" or "not_started" (D3); complete
-- and total the chip's N of M; next the next unread record or nil (D3); author the series' author
-- or nil and others whether any book's first author differs from it (D15). Entries in D12's
-- order. progress_of(record) is Books.progress, called once per book per call.
function ShelfOrder.series(records, progress_of)
    local entries = {}
    for _, group in ipairs(BookIndex.series(records)) do
        local state, complete, next_unread = series_state(group.books, progress_of)
        local author, others = author_line(group.books)
        entries[#entries + 1] = {
            name = group.name,
            books = group.books,
            state = state,
            complete = complete,
            total = #group.books,
            next = next_unread,
            author = author,
            others = others,
            key = LibraryOrder.title_key(group.name),
        }
    end
    table.sort(entries, by_series)
    for _, entry in ipairs(entries) do
        entry.key = nil
    end
    return entries
end

-- D13's letter of a surname key: its first byte uppercased when an ASCII letter, else "#".
local function letter_of(key)
    local first = key:sub(1, 1)
    return first:match("^%a$") and first:upper() or "#"
end

-- D13: by letter, "#" after Z, then surname key, then lowercase name, then name.
local function by_author(a, b)
    if a.letter ~= b.letter then
        if a.letter == "#" or b.letter == "#" then
            return b.letter == "#"
        end
        return a.letter < b.letter
    end
    if a.key ~= b.key then
        return a.key < b.key
    end
    local la, lb = a.name:lower(), b.name:lower()
    if la ~= lb then
        return la < lb
    end
    return a.name < b.name
end

-- BookIndex.authors' entries { name, books, letter, count } in D13's order: letter the group the
-- author is under (A to Z, then "#"), count the number of their books.
function ShelfOrder.authors(records)
    local entries = {}
    for _, group in ipairs(BookIndex.authors(records)) do
        local key = BookIndex.surname(group.name) or group.name:lower()
        entries[#entries + 1] = {
            name = group.name,
            books = group.books,
            letter = letter_of(key),
            count = #group.books,
            key = key,
        }
    end
    table.sort(entries, by_author)
    for _, entry in ipairs(entries) do
        entry.key = nil
    end
    return entries
end

-- An author entry's books in cover-grid's Series order (D16), and { [id] = true } for those of
-- them that are their series' next in series_entries (ShelfOrder.series over the whole library),
-- so a series' next by another author marks none of this author's books.
function ShelfOrder.author_books(entry, series_entries, progress_of)
    local books = LibraryOrder.view({ books = entry.books, folders = {} }, "series", "all", progress_of, {})
    local mine = {}
    for _, record in ipairs(books) do
        mine[record.id] = true
    end
    local up_next = {}
    for _, series in ipairs(series_entries) do
        if series.next and mine[series.next.id] then
            up_next[series.next.id] = true
        end
    end
    return books, up_next
end

-- D14: rows ({ h, group, group_cost }) as pages { first, last, rows, repeats } of runs that fit
-- whole in available, at least one row a page. A page's cost is its rows' heights, gap between
-- each two of them, and once per group started or continued on it that group's group_cost (none
-- for a row with no group). repeats is true when the page's first group continues from the page
-- before. No rows give one empty page.
function ShelfOrder.pages(rows, available, gap)
    gap = gap or 0
    local pages = {}
    local page, cost, groups
    local function open(i)
        page = { first = i, last = i - 1, rows = {}, repeats = false }
        pages[#pages + 1] = page
        cost, groups = 0, {}
    end
    open(1)
    for i, row in ipairs(rows) do
        local group = row.group
        local extra = row.h
        if #page.rows > 0 then
            extra = extra + gap
        end
        if group ~= nil and not groups[group] then
            extra = extra + (row.group_cost or 0)
        end
        if #page.rows > 0 and cost + extra > available then
            local previous = rows[i - 1].group
            open(i)
            page.repeats = group ~= nil and group == previous
            extra = row.h + (group ~= nil and row.group_cost or 0)
        end
        if group ~= nil then
            groups[group] = true
        end
        page.rows[#page.rows + 1] = row
        page.last = i
        cost = cost + extra
    end
    return pages
end

-- The number of the page holding the first row predicate(row) is true for; 1 when none is.
function ShelfOrder.page_of(pages, predicate)
    for n, page in ipairs(pages) do
        for _, row in ipairs(page.rows) do
            if predicate(row) then
                return n
            end
        end
    end
    return 1
end

return ShelfOrder
