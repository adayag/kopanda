-- The Authors window (series-and-authors "Authors"): a window on the chrome (library_chrome.lua)
-- showing the library's authors, the list or one author, a page at a time. The list (AuthorsC.dc.html)
-- heads D10's count over "Authors" with "By surname" at the right, then a page of letter groups in
-- D13's order, a group split by the page break before starting the page with its letter again (D14);
-- one author (AuthorBooksA.dc.html) heads the back control "Authors" over D10's count and the name,
-- then a page of the library's book tiles, three columns and two rows, in D16's order, each series'
-- next unread carrying the Up next chip (D5, D19). The nav bar lights Authors. Who the authors are,
-- in what order, and which books are up next is shelf_order.lua's; the groups are shelf_rows.lua's
-- and the tiles library_tiles.lua's.
-- Module state: AuthorsScreen.shown, the chrome's slot.
-- AuthorsScreen.on_open(view, page), run when a tap's book open goes ahead, records the return in
-- the chrome's LibraryChrome.return_to.
local Books = require("books")
local Geom = require("ui/geometry")
local LibraryChrome = require("library_chrome")
local LibraryOrder = require("library_order")
local LibraryTiles = require("library_tiles")
local NavBar = require("nav_bar")
local ShelfOrder = require("shelf_order")
local ShelfRows = require("shelf_rows")
local Typeset = require("typeset")
local logger = require("logger")
local Screen = require("device").screen

local AuthorsScreen = LibraryChrome.Window:extend{
    name = "kopanda_authors",
    screen = "authors",
    fields = { "showing", "groups", "rows", "tiles", "note", "keys", "drawn" },
    showing = nil,
}

local LIST = { kind = "list" }

-- Run when a tap's book open goes ahead: the book closes back to view at page (D7).
function AuthorsScreen.on_open(view, page)
    LibraryChrome.return_to = { screen = "authors", view = view, page = page }
end

-- The books are read once per show (D8), and again when the metadata events re-list.
function AuthorsScreen:init()
    self.records = Books.all()
    LibraryChrome.Window.init(self)
end

-- The view the window shows: { kind = "list" } or { kind = "author", name }.
function AuthorsScreen:view()
    return self.showing or LIST
end

local function scale(px)
    return Screen:scaleBySize(px)
end

-- Books.progress, each record read once per build: the up-next marks, the finished count and the
-- tiles share it.
local function progress_once()
    local seen = {}
    return function(record)
        if seen[record] == nil then
            seen[record] = Books.progress(record)
        end
        return seen[record]
    end
end

-- One author's part of the plan: the author's books in D16's order and the up-next set, from the
-- whole library's series (D16); the finished count; the grid at the one-author cover height; and
-- view's page of six (LibraryOrder.page, the library's slicing).
local function plan_author(self, p, page, w, ctx)
    local progress = progress_once()
    local series = ShelfOrder.series(self.records, progress)
    p.progress = progress
    p.books, p.up_next = ShelfOrder.author_books(p.entry, series, progress)
    p.finished = 0
    for _, record in ipairs(p.books) do
        local status = progress(record)
        if type(status) == "table" and status.status == "complete" then
            p.finished = p.finished + 1
        end
    end
    p.header_h = LibraryChrome.detail_header_height(ctx)
    p.box = LibraryTiles.geometry(w, ctx, ctx.look.shelf.author_grid.cover_h)
    p.top = p.header_h + scale(ctx.look.library.grid.padding_top)
    p.slice, p.pages, p.page = LibraryOrder.page(p.books, page)
end

-- The list's part of the plan: a row per author, each a letter group's member with that group's
-- cost (ShelfRows.group_cost, the gap between groups in it), paged by whole rows between the header
-- and ShelfRows.pager_reserve above the pager (D14).
local function plan_list(p, page, w, h, ctx)
    local shelf = ctx.look.shelf
    p.width = w - 2 * scale(shelf.list.side)
    p.header_h = LibraryTiles.header_height(ctx)
    p.top = p.header_h + scale(shelf.groups.padding_top)
    local row_h = ShelfRows.height("author", p.width, ctx)
    local cost = ShelfRows.group_cost(p.width, ctx)
    local rows = {}
    for i, entry in ipairs(p.entries) do
        rows[i] = { h = row_h, group = entry.letter, group_cost = cost, entry = entry }
    end
    local available = h - NavBar.height(ctx.look, Screen) - LibraryTiles.pager_height(ctx) - p.top
        - ShelfRows.pager_reserve("author", ctx)
    p.paging = ShelfOrder.pages(rows, available, 0)
    p.pages = #p.paging
    p.page = math.max(1, math.min(page or 1, p.pages))
    p.run = p.paging[p.page]
end

-- What view at page shows from the window's records on a screen w by h under ctx, before any widget
-- is built: { view, the list instead for an author no entry has any more (D23); entry, the author
-- shown or nil; entries, ShelfOrder.authors; header_h; top, the page's first y; pages and page,
-- clamped }, and the list's paging and run (its page of rows) or one author's books, up_next,
-- finished, progress, box and slice.
local function plan(self, view, page, w, h, ctx)
    local entries = ShelfOrder.authors(self.records)
    local entry
    if view.kind == "author" then
        for _, candidate in ipairs(entries) do
            if candidate.name == view.name then
                entry = candidate
            end
        end
        if not entry then
            view, page = LIST, 1
        end
    end
    local p = { view = view, entry = entry, entries = entries }
    if entry then
        plan_author(self, p, page, w, ctx)
    else
        plan_list(p, page, w, h, ctx)
    end
    return p
end

-- The keys of p's page in order, the view, the page count and the header's count first (an
-- author row's letter, name and count; a tile's id and its up-next mark), and the ids of the records
-- the page draws anything of: each tile's. The list draws no book.
local function page_keys(p)
    local keys, drawn = {}, {}
    if p.entry then
        keys[1] = table.concat({ "author", p.view.name, p.pages, #p.books, p.finished }, "\0")
        for _, record in ipairs(p.slice) do
            keys[#keys + 1] = record.id .. (p.up_next[record.id] and "\0up next" or "")
            drawn[record.id] = true
        end
    else
        keys[1] = table.concat({ "list", p.pages, #p.entries, tostring(p.run.repeats) }, "\0")
        for _, row in ipairs(p.run.rows) do
            keys[#keys + 1] = table.concat({ row.entry.letter, row.entry.name, row.entry.count }, "\0")
        end
    end
    return keys, drawn
end

-- The chrome's extraction helper reads these (LibraryChrome.request_records).
function AuthorsScreen:page_keys(view, page)
    return page_keys(plan(self, view, page, self.dimen.w, self.dimen.h, self.ctx))
end

local function books_text(n)
    return n == 1 and "1 book" or n .. " books"
end

-- D10's count: the authors, "on the shelf" after them in a look whose title bar says so; or one
-- author's books and those finished, joined in each look's words as the library's count is worded
-- (title_bar.count_on_shelf).
local function count_text(p, look)
    local on_shelf = look.title_bar.count_on_shelf
    if p.entry then
        local text = books_text(#p.books)
        if p.finished > 0 then
            text = text .. (on_shelf and ", " or " · ") .. p.finished .. " finished"
        end
        return text
    end
    local n = #p.entries
    local text = n == 0 and "No authors" or n == 1 and "1 author" or n .. " authors"
    return on_shelf and text .. " on the shelf" or text
end

-- The header, w wide, on the authors band: for the list, the count over "Authors" with the inert
-- "By surname" (D11) at the right, its parts' label; for one author, the back control over the
-- count and the author's name (LibraryChrome.header's detail form).
local function header(p, w, ctx)
    local look = ctx.look
    local spec = {
        height = p.header_h,
        band = look.shelf.authors_fill_color,
        right = {},
        aside = { part = look.type.library_count, text = count_text(p, look) },
    }
    if p.entry then
        spec.title = { part = look.type.shelf_detail_title, text = p.entry.name }
        spec.back_label = "Authors"
        return LibraryChrome.header(ctx, w, spec)
    end
    local label = Typeset.line(look.type.shelf_label, "By surname", w, ctx)
    spec.title = { part = look.type.library_title, text = "Authors" }
    spec.right = { label }
    local box, parts = LibraryChrome.header(ctx, w, spec)
    parts.label = label
    return box, parts
end

-- The list's page: each run of the page's rows under one letter as one group, the first continued
-- from the page before when the page repeats it, the groups the groups' gap apart. Fills
-- built.groups ({ letter, repeats, widget, rect }) and built.rows ({ rect, entry, group, band }, each
-- author row's band of its group across the group's width).
local function fill_list(p, built, frame, ctx)
    local x, y = scale(ctx.look.shelf.list.side), p.top
    local gap = scale(ctx.look.shelf.groups.gap)
    local rows = p.run.rows
    local i = 1
    while i <= #rows do
        local letter, members = rows[i].entry.letter, {}
        while i <= #rows and rows[i].entry.letter == letter do
            members[#members + 1] = rows[i].entry
            i = i + 1
        end
        local repeats = #built.groups == 0 and p.run.repeats
        local widget = ShelfRows.group(letter, members, repeats, p.width, ctx)
        local group = { letter = letter, repeats = repeats, widget = widget,
            rect = Geom:new{ x = x, y = y, w = p.width, h = widget:getSize().h } }
        built.groups[#built.groups + 1] = group
        LibraryChrome.add(frame, widget, x, y)
        for _, band in ipairs(widget.rows) do
            built.rows[#built.rows + 1] = { rect = Geom:new{ x = x, y = y + band.y, w = p.width, h = band.h },
                entry = band.entry, group = group, band = band }
        end
        y = y + group.rect.h + gap
    end
end

-- One author's page: its slice's tiles at the grid's boxes, two rows of three. Fills built.tiles
-- ({ rect, record, up_next, widget }).
local function fill_author(p, built, frame, ctx)
    local box, row_gap = p.box, scale(ctx.look.library.grid.row_gap)
    for i, record in ipairs(p.slice) do
        local x = box.columns[(i - 1) % #box.columns + 1].x
        local y = p.top + math.floor((i - 1) / #box.columns) * (box.height + row_gap)
        local up_next = p.up_next[record.id] == true
        local widget = LibraryTiles.book(record, p.progress(record), box, ctx, up_next and { label = "Up next" } or nil)
        built.tiles[i] = { rect = Geom:new{ x = x, y = y, w = box.cover_w, h = box.height }, record = record,
            up_next = up_next, widget = widget }
        LibraryChrome.add(frame, widget, x, y)
    end
end

-- Fills built (showing, page, ctx) from the window's records: the frame (the header, the page's
-- groups or tiles or the empty note, the chrome's foot) and what gestures and the covers read:
-- showing, page and pages, header, groups, rows, tiles, note, keys and drawn (page_keys).
local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local p = plan(self, built.showing or LIST, built.page, w, h, ctx)
    built.showing, built.page, built.pages = p.view, p.page, p.pages
    built.keys, built.drawn = page_keys(p)
    local header_box
    header_box, built.header = header(p, w, ctx)
    LibraryChrome.add(frame, header_box, 0, 0)
    built.groups, built.rows, built.tiles = {}, {}, {}
    if p.entry then
        fill_author(p, built, frame, ctx)
    else
        fill_list(p, built, frame, ctx)
    end
    LibraryChrome.foot(built, frame, "authors")
    if not p.entry and #p.entries == 0 then
        local note = Typeset.line(look.type.shelf_empty, "No authors yet", math.max(1, p.width), ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        LibraryChrome.add(frame, note, math.floor((w - size.w) / 2), p.top + math.floor((below - p.top - size.h) / 2))
        built.note = note
    end
end

function AuthorsScreen:build(view, page)
    return LibraryChrome.build({ showing = view, page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- Opens record's file as the file browser's own tap does (cover-grid D15; filemanager.lua:160-169),
-- as the library does (library.lua), running AuthorsScreen.on_open with the view and page once the
-- open goes ahead (filemanagerutil.lua:498-502).
function AuthorsScreen:open(record)
    local FileManager = package.loaded["apps/filemanager/filemanager"]
    local fm = FileManager and FileManager.instance
    if not fm then
        return
    end
    local view, page = self.showing, self.page
    require("apps/filemanager/filemanagerutil").openFile(fm, record.path, function()
        AuthorsScreen.on_open(view, page)
    end)
end

-- The back control, on one author: the list at the page holding that author (D17).
function AuthorsScreen:back()
    local name = self.showing.name
    local p = plan(self, LIST, 1, self.dimen.w, self.dimen.h, self.ctx)
    self:go(LIST, ShelfOrder.page_of(p.paging, function(row)
        return row.entry.name == name
    end))
end

-- The action a tap at pos on the window's rows or tiles runs, or nil: an author row shows that
-- author at their first page; a downloaded book opens; a book without a file does nothing.
function AuthorsScreen:action_at(pos)
    for _, row in ipairs(self.rows) do
        if LibraryChrome.inside(row.rect, pos) then
            return function()
                self:go({ kind = "author", name = row.entry.name }, 1)
            end
        end
    end
    for _, tile in ipairs(self.tiles) do
        if LibraryChrome.inside(tile.rect, pos) then
            return function()
                if tile.record.path then
                    self:open(tile.record)
                end
            end
        end
    end
    return nil
end

-- What lies at (x, y) on the shown window (D9): { kind = "author", entry }, { kind = "book",
-- record } or { kind = "empty" }; nil with no Authors window shown.
function AuthorsScreen.hit(x, y)
    local screen = AuthorsScreen.shown
    if not screen then
        return nil
    end
    local pos = { x = x, y = y }
    for _, row in ipairs(screen.rows) do
        if LibraryChrome.inside(row.rect, pos) then
            return { kind = "author", entry = row.entry }
        end
    end
    for _, tile in ipairs(screen.tiles) do
        if LibraryChrome.inside(tile.rect, pos) then
            return { kind = "book", record = tile.record }
        end
    end
    return { kind = "empty" }
end

-- The covers of every book of the library, once per show (series-and-authors D2).
function AuthorsScreen:request_covers()
    LibraryChrome.request_records(self)
end

-- The metadata events re-list: the books read again, then the view rebuilt. A failed read is logged
-- and the view rebuilt from the books as they were.
function AuthorsScreen:refresh()
    if AuthorsScreen.shown ~= self then
        return
    end
    local ok, records = pcall(Books.all)
    if ok then
        self.records = records
    else
        logger.err("KoPanda: could not re-read the authors' books:", records)
    end
    LibraryChrome.Window.refresh(self)
end

-- opts: view ({ kind = "list" }, the default, or { kind = "author", name }), page and started
-- (LibraryChrome.show's). Returns the window shown, or nil.
function AuthorsScreen.show(opts)
    opts = opts or {}
    return LibraryChrome.show(AuthorsScreen, opts, { showing = opts.view, page = opts.page })
end

function AuthorsScreen.close()
    if AuthorsScreen.shown then
        LibraryChrome.close()
    end
end

return AuthorsScreen
