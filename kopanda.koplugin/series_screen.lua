-- The Series window (series-and-authors "Series"): a window on the chrome (library_chrome.lua)
-- showing the library's series, the list or one series, a page at a time. The list (SeriesC.dc.html)
-- heads D10's count over "Series" with "Under way first" at the right, then a page of series rows in
-- D12's order; one series (SeriesBooksC.dc.html) heads the back control "Series" over D10's aside and
-- the series' name, then a page of its book rows in series order with the next unread marked. Each
-- view pages by whole rows between its header and the pager (D14); the nav bar lights no tab. What
-- the series are, in what order and state, is shelf_order.lua's; the rows are shelf_rows.lua's.
-- Module state: SeriesScreen.shown, the chrome's slot. SeriesScreen.on_open(view, page), run when a
-- tap's book open goes ahead, records the return in the chrome's LibraryChrome.return_to.
local Books = require("books")
local Geom = require("ui/geometry")
local LibraryChrome = require("library_chrome")
local LibraryTiles = require("library_tiles")
local NavBar = require("nav_bar")
local ShelfOrder = require("shelf_order")
local ShelfRows = require("shelf_rows")
local Typeset = require("typeset")
local logger = require("logger")
local Screen = require("device").screen

local SeriesScreen = LibraryChrome.Window:extend{
    name = "kopanda_series",
    screen = "series",
    fields = { "showing", "rows", "note", "keys", "drawn" },
    showing = nil,
}

local LIST = { kind = "list" }

-- Run when a tap's book open goes ahead: the book closes back to view at page (D7).
function SeriesScreen.on_open(view, page)
    LibraryChrome.return_to = { screen = "series", view = view, page = page }
end

-- The books are read once per show (D8), and again when the metadata events re-list.
function SeriesScreen:init()
    self.records = Books.all()
    LibraryChrome.Window.init(self)
end

-- The view the window shows: { kind = "list" } or { kind = "series", name }.
function SeriesScreen:view()
    return self.showing or LIST
end

local function scale(px)
    return Screen:scaleBySize(px)
end

-- Books.progress, each record read once per sort: D3's states and the book rows share it.
local function progress_once()
    local seen = {}
    return function(record)
        if seen[record] == nil then
            seen[record] = Books.progress(record)
        end
        return seen[record]
    end
end

-- The window's series in D12's order and their progress, kept on the window as { records, entries
-- (ShelfOrder.series of records), progress }: a page turn, a view change or a repaint in another
-- variant or size sorts nothing; a show (a new window), refresh() and a cover arrival's re-read
-- records (window.records replaced) sort again.
local function sorted(self)
    local kept = self.kept
    if not kept or kept.records ~= self.records then
        local progress = progress_once()
        kept = { records = self.records, entries = ShelfOrder.series(self.records, progress), progress = progress }
        self.kept = kept
    end
    return kept
end

-- What view at page shows from the window's records on a screen w by h under ctx, before any widget
-- is built: { view, the list instead for a series no entry has any more (D23); entry, the series
-- shown or nil; entries and progress, the kept sort's; header_h; top, the rows' first y; gap; width;
-- rows, each { h, entry or record }; pages, ShelfOrder.pages of them between the header and
-- ShelfRows.pager_reserve above the pager; page, clamped }.
local function plan(self, view, page, w, h, ctx)
    local kept = sorted(self)
    local entries, progress = kept.entries, kept.progress
    local entry
    if view.kind == "series" then
        for _, candidate in ipairs(entries) do
            if candidate.name == view.name then
                entry = candidate
            end
        end
        if not entry then
            view, page = LIST, 1
        end
    end
    local shelf = ctx.look.shelf
    local p = { view = view, entry = entry, entries = entries, progress = progress, rows = {},
        width = w - 2 * scale(shelf.list.side) }
    local kind = entry and "book" or "series"
    if entry then
        p.header_h = LibraryChrome.detail_header_height(ctx)
        p.top, p.gap = p.header_h + scale(shelf.books.padding_top), scale(shelf.books.row_gap)
        local row_h = ShelfRows.height("book", p.width, ctx)
        for i, record in ipairs(entry.books) do
            p.rows[i] = { h = row_h, record = record }
        end
    else
        p.header_h = LibraryTiles.header_height(ctx)
        p.top, p.gap = p.header_h + scale(shelf.list.padding_top), scale(shelf.list.row_gap)
        local row_h = ShelfRows.height("series", p.width, ctx)
        for i, candidate in ipairs(entries) do
            p.rows[i] = { h = row_h, entry = candidate }
        end
    end
    local available = h - NavBar.height(ctx.look, Screen) - LibraryTiles.pager_height(ctx) - p.top
        - ShelfRows.pager_reserve(kind, ctx)
    p.pages = ShelfOrder.pages(p.rows, available, p.gap)
    p.page = math.max(1, math.min(page or 1, #p.pages))
    return p
end

-- The number of entries under way, D10's second count.
local function under_way_count(entries)
    local n = 0
    for _, candidate in ipairs(entries) do
        if candidate.state == "under_way" then
            n = n + 1
        end
    end
    return n
end

-- The keys of p's page in order, the view, the page count and the header's counts first (the
-- list's series and under-way counts; one series' author part and book count), then a series row's
-- name and its books' ids, a book row's id; and the ids of the records the page draws anything of:
-- every book of a series row, each book row's.
local function page_keys(p)
    local head = { p.view.kind, p.view.name or "", #p.pages }
    if p.entry then
        head[4], head[5], head[6] = p.entry.author or "", tostring(p.entry.others), p.entry.total
    else
        head[4], head[5] = #p.entries, under_way_count(p.entries)
    end
    local keys, drawn = { table.concat(head, "\0") }, {}
    for _, row in ipairs(p.pages[p.page].rows) do
        if row.entry then
            local ids = { row.entry.name }
            for _, record in ipairs(row.entry.books) do
                ids[#ids + 1] = record.id
                drawn[record.id] = true
            end
            keys[#keys + 1] = table.concat(ids, "\0")
        else
            keys[#keys + 1] = row.record.id
            drawn[row.record.id] = true
        end
    end
    return keys, drawn
end

-- The chrome's extraction helper reads these (LibraryChrome.request_records).
function SeriesScreen:page_keys(view, page)
    return page_keys(plan(self, view, page, self.dimen.w, self.dimen.h, self.ctx))
end

local function books_text(n)
    return n == 1 and "1 book" or n .. " books"
end

-- D10's count: the series and those under way, or one series' author part (D15) and its books,
-- joined in each look's words as the library's count is worded (title_bar.count_on_shelf).
local function count_text(p, look)
    local join = look.title_bar.count_on_shelf and ", " or " · "
    local entry = p.entry
    if entry then
        if not entry.author then
            return books_text(entry.total)
        end
        return (entry.others and entry.author .. " and others" or entry.author) .. join .. books_text(entry.total)
    end
    if #p.entries == 0 then
        return "No series"
    end
    local under_way = under_way_count(p.entries)
    local text = #p.entries .. " series"
    return under_way > 0 and text .. join .. under_way .. " under way" or text
end

-- The header, w wide, on the series band: for the list, the count over "Series" with the inert
-- "Under way first" (D11) at the right, its parts' label; for one series, the back control over
-- the aside and the series' name (LibraryChrome.header's detail form).
local function header(p, w, ctx)
    local look = ctx.look
    local spec = {
        height = p.header_h,
        band = look.shelf.series_fill_color,
        right = {},
        aside = { part = look.type.library_count, text = count_text(p, look) },
    }
    if p.entry then
        spec.title = { part = look.type.shelf_detail_title, text = p.entry.name }
        spec.back_label = "Series"
        return LibraryChrome.header(ctx, w, spec)
    end
    local label = Typeset.line(look.type.shelf_label, "Under way first", w, ctx)
    spec.title = { part = look.type.library_title, text = "Series" }
    spec.right = { label }
    local box, parts = LibraryChrome.header(ctx, w, spec)
    parts.label = label
    return box, parts
end

-- Fills built (showing, page, ctx) from the window's records: the frame (the header, the page's
-- rows or the empty note, the chrome's foot) and what gestures and the covers read: showing, page
-- and pages, header, rows ({ rect, entry or record, widget }), note, keys and drawn (page_keys).
local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local p = plan(self, built.showing or LIST, built.page, w, h, ctx)
    built.showing, built.page, built.pages = p.view, p.page, #p.pages
    built.keys, built.drawn = page_keys(p)
    local header_box
    header_box, built.header = header(p, w, ctx)
    LibraryChrome.add(frame, header_box, 0, 0)
    local x, y = scale(look.shelf.list.side), p.top
    built.rows = {}
    for i, row in ipairs(p.pages[p.page].rows) do
        local widget
        if row.entry then
            widget = ShelfRows.series(row.entry, p.width, ctx)
        else
            local next_unread = p.entry.next
            widget = ShelfRows.book(row.record, p.progress(row.record),
                next_unread ~= nil and next_unread.id == row.record.id, p.width, ctx)
        end
        built.rows[i] = { rect = Geom:new{ x = x, y = y, w = p.width, h = row.h }, entry = row.entry,
            record = row.record, widget = widget }
        LibraryChrome.add(frame, widget, x, y)
        y = y + row.h + p.gap
    end
    LibraryChrome.foot(built, frame, "series")
    if #p.rows == 0 then
        local note = Typeset.line(look.type.shelf_empty, "No books in a series yet", math.max(1, p.width), ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        LibraryChrome.add(frame, note, math.floor((w - size.w) / 2), p.top + math.floor((below - p.top - size.h) / 2))
        built.note = note
    end
end

function SeriesScreen:build(view, page)
    return LibraryChrome.build({ showing = view, page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- Opens record's file as the file browser's own tap does (cover-grid D15; filemanager.lua:160-169),
-- as the library does (library.lua), running SeriesScreen.on_open with the view and page once the
-- open goes ahead (filemanagerutil.lua:498-502).
function SeriesScreen:open(record)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if not fm then
        return
    end
    local view, page = self.showing, self.page
    require("apps/filemanager/filemanagerutil").openFile(fm, record.path, function()
        SeriesScreen.on_open(view, page)
    end)
end

-- The back control, on one series: the list at the page holding that series (D17).
function SeriesScreen:back()
    local name = self.showing.name
    local p = plan(self, LIST, 1, self.dimen.w, self.dimen.h, self.ctx)
    self:go(LIST, ShelfOrder.page_of(p.pages, function(row)
        return row.entry.name == name
    end))
end

-- The action a tap at pos on the window's rows runs, or nil: a series row shows that series at its
-- first page; a downloaded book opens; a book without a file does nothing.
function SeriesScreen:action_at(pos)
    for _, row in ipairs(self.rows) do
        if LibraryChrome.inside(row.rect, pos) then
            if row.entry then
                return function()
                    self:go({ kind = "series", name = row.entry.name }, 1)
                end
            end
            return function()
                if row.record.path then
                    self:open(row.record)
                end
            end
        end
    end
    return nil
end

-- What lies at (x, y) on the shown window (D9): { kind = "series", entry }, { kind = "book",
-- record } or { kind = "empty" }; nil with no Series window shown.
function SeriesScreen.hit(x, y)
    local screen = SeriesScreen.shown
    if not screen then
        return nil
    end
    local pos = { x = x, y = y }
    for _, row in ipairs(screen.rows) do
        if LibraryChrome.inside(row.rect, pos) then
            if row.entry then
                return { kind = "series", entry = row.entry }
            end
            return { kind = "book", record = row.record }
        end
    end
    return { kind = "empty" }
end

-- The covers of every book of the library, once per show (series-and-authors D2).
function SeriesScreen:request_covers()
    LibraryChrome.request_records(self)
end

-- The metadata events and the sheets re-list: the kept sort dropped, the books read again, then the
-- view rebuilt. A failed read is logged and the view rebuilt from the books as they were.
function SeriesScreen:refresh()
    if SeriesScreen.shown ~= self then
        return
    end
    self.kept = nil
    local ok, records = pcall(Books.all)
    if ok then
        self.records = records
    else
        logger.err("KoPanda: could not re-read the series' books:", records)
    end
    LibraryChrome.Window.refresh(self)
end

-- opts: view ({ kind = "list" }, the default, or { kind = "series", name }), page and started
-- (LibraryChrome.show's). Returns the window shown, or nil.
function SeriesScreen.show(opts)
    opts = opts or {}
    return LibraryChrome.show(SeriesScreen, opts, { showing = opts.view, page = opts.page })
end

function SeriesScreen.close()
    if SeriesScreen.shown then
        LibraryChrome.close()
    end
end

return SeriesScreen
