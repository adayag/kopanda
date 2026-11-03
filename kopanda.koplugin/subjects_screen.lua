-- The Subjects window: a window on the chrome (library_chrome.lua) showing the library's subjects, the list
-- by count or one subject's books, a page at a time. Which subjects there are and in what order is
-- shelf_order.lua's; the rows are shelf_rows.lua's, the tiles library_tiles.lua's. SubjectsScreen.shown is the
-- chrome's slot; on_open records the return in LibraryChrome.return_to.
local Books = require("books")
local Geom = require("ui/geometry")
local Helpers = require("helpers")
local LibraryChrome = require("library_chrome")
local LibraryOrder = require("library_order")
local LibraryTiles = require("library_tiles")
local NavBar = require("nav_bar")
local ShelfOrder = require("shelf_order")
local ShelfRows = require("shelf_rows")
local Typeset = require("typeset")
local logger = require("logger")
local Screen = require("device").screen

local SubjectsScreen = LibraryChrome.Window:extend{
    name = "kopanda_subjects",
    screen = "subjects",
    fields = { "showing", "rows", "tiles", "note", "keys", "drawn" },
    showing = nil,
}

local LIST = { kind = "list" }

-- Run when a tap's book open goes ahead: the book closes back to view at page.
function SubjectsScreen.on_open(view, page)
    LibraryChrome.return_to = { screen = "subjects", view = view, page = page }
end

-- The library's books are taken once per show (LibraryChrome.books), and again when the metadata events re-list.
function SubjectsScreen:init()
    self.records = LibraryChrome.books()
    LibraryChrome.Window.init(self)
end

-- The view the window shows: { kind = "list" } or { kind = "subject", name }.
function SubjectsScreen:view()
    return self.showing or LIST
end

local function scale(px)
    return Screen:scaleBySize(px)
end

-- Books.progress, each record read once per sort: the tiles share it.
local function progress_once()
    local seen = {}
    return function(record)
        if seen[record] == nil then
            seen[record] = Books.progress(record)
        end
        return seen[record]
    end
end

-- The window's subjects in order and their books' progress, kept on the window as { records, entries
-- (ShelfOrder.subjects of records), progress }: a page turn or repaint sorts nothing; a show, refresh() and a
-- cover arrival's re-read sort again.
local function sorted(self)
    local kept = self.kept
    if not kept or kept.records ~= self.records then
        kept = { records = self.records, entries = ShelfOrder.subjects(self.records), progress = progress_once() }
        self.kept = kept
    end
    return kept
end

-- One subject's part of the plan: its books in the library's title order, the grid at the one-author cover
-- height in the room under the detail header, and view's page of the rows that fit (LibraryOrder.page).
local function plan_subject(p, page, w, h, ctx)
    p.books = ShelfOrder.subject_books(p.entry)
    p.header_h = LibraryChrome.detail_header_height(ctx)
    p.box = LibraryTiles.geometry(w, ctx, { cover_h = ctx.look.shelf.author_grid.cover_h,
        room = LibraryTiles.room(h, ctx, p.header_h) })
    p.top = p.header_h + scale(ctx.look.library.grid.padding_top)
    p.slice, p.pages, p.page = LibraryOrder.page(p.books, page, p.box.rows * #p.box.columns)
end

-- The list's part of the plan: a row per subject, paged by whole rows between the header and
-- ShelfRows.pager_reserve.
local function plan_list(p, page, w, h, ctx)
    local shelf = ctx.look.shelf
    p.width = w - 2 * scale(shelf.list.side)
    p.header_h = LibraryTiles.header_height(ctx)
    p.top, p.gap = p.header_h + scale(shelf.list.padding_top), scale(shelf.list.row_gap)
    local row_h = ShelfRows.height("series", p.width, ctx)
    local rows = {}
    for i, entry in ipairs(p.entries) do
        rows[i] = { h = row_h, entry = entry }
    end
    local available = h - NavBar.height(ctx.look, Screen, ctx.text_size) - LibraryTiles.pager_height(ctx) - p.top
        - ShelfRows.pager_reserve("series", ctx)
    p.paging = ShelfOrder.pages(rows, available, p.gap)
    p.pages = #p.paging
    p.page = math.max(1, math.min(page or 1, p.pages))
    p.run = p.paging[p.page]
end

-- What view at page shows from the window's records on a screen w by h under ctx, before any widget
-- is built. Falls back to the list for a subject no entry has any more.
local function plan(self, view, page, w, h, ctx)
    local kept = sorted(self)
    local entries = kept.entries
    local entry
    if view.kind == "subject" then
        for _, candidate in ipairs(entries) do
            if candidate.name == view.name then
                entry = candidate
            end
        end
        if not entry then
            view, page = LIST, 1
        end
    end
    local p = { view = view, entry = entry, entries = entries, progress = kept.progress }
    if entry then
        plan_subject(p, page, w, h, ctx)
    else
        plan_list(p, page, w, h, ctx)
    end
    return p
end

-- The keys of p's page in order (the view, page count, header count, each row's or tile's identity)
-- and the ids of the records the page draws anything of.
local function page_keys(p)
    local keys, drawn = {}, {}
    if p.entry then
        keys[1] = table.concat({ "subject", p.view.name, p.pages, #p.books }, "\0")
        for _, record in ipairs(p.slice) do
            keys[#keys + 1] = record.id
            drawn[record.id] = true
        end
    else
        keys[1] = table.concat({ "list", p.pages, #p.entries }, "\0")
        for _, row in ipairs(p.run.rows) do
            local ids = { row.entry.name }
            for _, record in ipairs(row.entry.books) do
                ids[#ids + 1] = record.id
                drawn[record.id] = true
            end
            keys[#keys + 1] = table.concat(ids, "\0")
        end
    end
    return keys, drawn
end

-- The chrome's extraction helper reads these (LibraryChrome.request_records).
function SubjectsScreen:page_keys(view, page)
    return page_keys(plan(self, view, page, self.dimen.w, self.dimen.h, self.ctx))
end

-- The count: the subjects, or one subject's books.
local function count_text(p)
    if p.entry then
        return Helpers.books_text(#p.books)
    end
    local n = #p.entries
    return n == 0 and "No subjects" or n == 1 and "1 subject" or n .. " subjects"
end

-- The header, w wide: for the list, the count over "Subjects" with the inert "Most books first" at the
-- right; for one subject, the back control over the count and the name (LibraryChrome.header's detail form).
local function header(p, w, ctx)
    local look = ctx.look
    local spec = {
        height = p.header_h,
        band = look.shelf.subjects_fill_color,
        right = {},
        aside = { part = look.type.library_count, text = count_text(p) },
    }
    if p.entry then
        spec.title = { part = look.type.shelf_detail_title, text = p.entry.name }
        spec.back_label = "Subjects"
        return LibraryChrome.header(ctx, w, spec)
    end
    local label = Typeset.line(look.type.shelf_label, "Most books first", w, ctx)
    spec.title = { part = look.type.library_title, text = "Subjects" }
    spec.right = { label }
    local box, parts = LibraryChrome.header(ctx, w, spec)
    parts.label = label
    return box, parts
end

-- The list's page: a series row per subject, its book count the sub-line. Fills built.rows.
local function fill_list(p, built, frame, ctx)
    local x, y = scale(ctx.look.shelf.list.side), p.top
    for i, row in ipairs(p.run.rows) do
        local entry = row.entry
        local row_entry = { name = entry.name, books = entry.books, sub = Helpers.books_text(entry.count) }
        local widget = ShelfRows.series(row_entry, p.width, ctx)
        built.rows[i] = { rect = Geom:new{ x = x, y = y, w = p.width, h = row.h }, entry = entry, widget = widget }
        LibraryChrome.add(frame, widget, x, y)
        y = y + row.h + p.gap
    end
end

-- One subject's page: its slice's tiles at the grid's boxes. Fills built.tiles.
local function fill_subject(p, built, frame, ctx)
    local box, row_gap = p.box, scale(ctx.look.library.grid.row_gap)
    for i, record in ipairs(p.slice) do
        local x = box.columns[(i - 1) % #box.columns + 1].x
        local y = p.top + math.floor((i - 1) / #box.columns) * (box.height + row_gap)
        local widget = LibraryTiles.book(record, p.progress(record), box, ctx)
        built.tiles[i] = { rect = Geom:new{ x = x, y = y, w = box.cover_w, h = box.height }, record = record,
            widget = widget }
        LibraryChrome.add(frame, widget, x, y)
    end
end

-- Fills built from the window's records: the frame and what gestures and the covers read (showing,
-- page, pages, header, rows, tiles, note, keys and drawn).
local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local p = plan(self, built.showing or LIST, built.page, w, h, ctx)
    built.showing, built.page, built.pages = p.view, p.page, p.pages
    built.keys, built.drawn = page_keys(p)
    local header_box
    header_box, built.header = header(p, w, ctx)
    LibraryChrome.add(frame, header_box, 0, 0)
    built.rows, built.tiles = {}, {}
    if p.entry then
        fill_subject(p, built, frame, ctx)
    else
        fill_list(p, built, frame, ctx)
    end
    LibraryChrome.foot(built, frame, "subjects")
    if not p.entry and #p.entries == 0 then
        local note = Typeset.line(look.type.shelf_empty, "No subjects yet", math.max(1, p.width), ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        LibraryChrome.add(frame, note, math.floor((w - size.w) / 2), p.top + math.floor((below - p.top - size.h) / 2))
        built.note = note
    end
end

function SubjectsScreen:build(view, page)
    return LibraryChrome.build({ showing = view, page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- The back control, on one subject: the list at the page holding that subject.
function SubjectsScreen:back()
    local name = self.showing.name
    local p = plan(self, LIST, 1, self.dimen.w, self.dimen.h, self.ctx)
    self:go(LIST, ShelfOrder.page_of(p.paging, function(row)
        return row.entry.name == name
    end))
end

-- The action a tap at pos on the window's rows or tiles runs, or nil: a subject row shows that
-- subject at its first page; a downloaded book opens; a book without a file does nothing.
function SubjectsScreen:action_at(pos)
    for _, row in ipairs(self.rows) do
        if Helpers.inside(row.rect, pos) then
            return function()
                self:go({ kind = "subject", name = row.entry.name }, 1)
            end
        end
    end
    for _, tile in ipairs(self.tiles) do
        if Helpers.inside(tile.rect, pos) then
            return function()
                if tile.record.path then
                    self:open(tile.record)
                end
            end
        end
    end
    return nil
end

-- What lies at (x, y) on the shown window: { kind = "subject", entry }, { kind = "book", record } or
-- { kind = "empty" }; nil with no Subjects window shown.
function SubjectsScreen.hit(x, y)
    local screen = SubjectsScreen.shown
    if not screen then
        return nil
    end
    local pos = { x = x, y = y }
    for _, row in ipairs(screen.rows) do
        if Helpers.inside(row.rect, pos) then
            return { kind = "subject", entry = row.entry }
        end
    end
    for _, tile in ipairs(screen.tiles) do
        if Helpers.inside(tile.rect, pos) then
            return { kind = "book", record = tile.record }
        end
    end
    return { kind = "empty" }
end

-- The covers of every book of the library, once per show.
function SubjectsScreen:request_covers()
    LibraryChrome.request_records(self)
end

-- The re-read of a refresh (the metadata events', the sheets'), once the chrome dropped the library's books: the
-- kept sort dropped, the books taken again (a book just downloaded kept in its place, LibraryChrome.keep_downloaded).
-- A failed read is logged and the view rebuilt from the books as they were.
function SubjectsScreen:relist()
    self.kept = nil
    local ok, records = pcall(function()
        return LibraryChrome.keep_downloaded(self, LibraryChrome.books())
    end)
    if ok then
        self.records = records
    else
        logger.err("KoPanda: could not re-read the subjects' books:", records)
    end
end

-- opts: view ({ kind = "list" }, the default, or { kind = "subject", name }), page and started
-- (LibraryChrome.show's). Returns the window shown, or nil.
function SubjectsScreen.show(opts)
    opts = opts or {}
    return LibraryChrome.show(SubjectsScreen, opts, { showing = opts.view, page = opts.page })
end

function SubjectsScreen.close()
    if SubjectsScreen.shown then
        LibraryChrome.close()
    end
end

return SubjectsScreen
