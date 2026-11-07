-- The History and Favorites window: a window on the chrome (library_chrome.lua) showing one of KOReader's two book
-- lists (book_lists.lua) as tiles, a page at a time, with the nav bar. BookListsScreen.shown is the chrome's slot;
-- on_open records the return in LibraryChrome.return_to.
local BookLists = require("book_lists")
local BookSheet = require("book_sheet")
local Books = require("books")
local Geom = require("ui/geometry")
local Guards = require("guards")
local Helpers = require("helpers")
local LibraryChrome = require("library_chrome")
local LibraryOrder = require("library_order")
local LibraryTiles = require("library_tiles")
local Typeset = require("typeset")
local logger = require("logger")
local Screen = require("device").screen

local BookListsScreen = LibraryChrome.Window:extend{
    name = "kopanda_book_list",
    screen = "book_list",
    fields = { "showing", "count", "tiles", "note", "keys", "drawn" },
    showing = nil,
}

local HISTORY = { list = "history" }
local TITLES = { history = "History", favorites = "Favorites" }
local EMPTY = { history = "No books read yet", favorites = "No favorites yet" }

-- view's books, taken on the library's walk (LibraryChrome.books).
local function listed(view)
    return BookLists.records(BookLists[view.list](), LibraryChrome.books())
end

-- Run when a tap's book open goes ahead: the book closes back to view at page.
function BookListsScreen.on_open(view, page)
    LibraryChrome.return_to = { screen = "book_list", view = view, page = page }
end

function BookListsScreen:init()
    self.records = listed(self.showing)
    LibraryChrome.Window.init(self)
end

-- The view the window shows: { list = "history" } or { list = "favorites" }.
function BookListsScreen:view()
    return self.showing
end

local function scale(px)
    return Screen:scaleBySize(px)
end

-- Books.progress of a record, each read once for as long as the window keeps its records: a page turn or repaint
-- reads none again; a show, refresh() and a cover arrival's re-read read afresh.
local function progress_of(self)
    local kept = self.kept
    if not kept or kept.records ~= self.records then
        local seen = {}
        kept = { records = self.records, progress = function(record)
            if seen[record] == nil then
                seen[record] = Books.progress(record)
            end
            return seen[record]
        end }
        self.kept = kept
    end
    return kept.progress
end

-- What view at page shows on a screen w by h under ctx, before any widget is built: the grid at the one-author cover
-- height in the room under the title header, and the page of the rows that fit.
local function plan(self, view, page, w, h, ctx)
    local p = { view = view, records = self.records, progress = progress_of(self) }
    p.header_h = LibraryTiles.header_height(ctx)
    p.box = LibraryTiles.geometry(w, ctx, { cover_h = ctx.look.shelf.author_grid.cover_h,
        room = LibraryTiles.room(h, ctx, p.header_h) })
    p.top = p.header_h + scale(ctx.look.library.grid.padding_top)
    p.slice, p.pages, p.page = LibraryOrder.page(p.records, page, p.box.rows * #p.box.columns)
    return p
end

-- The keys of p's page in order (the list, page count, book count, each tile's record) and the ids of the records
-- the page draws.
local function page_keys(p)
    local keys, drawn = { table.concat({ "book_list", p.view.list, p.pages, #p.records }, "\0") }, {}
    for _, record in ipairs(p.slice) do
        keys[#keys + 1] = record.id
        drawn[record.id] = true
    end
    return keys, drawn
end

-- The chrome's extraction helper reads these (LibraryChrome.request_records).
function BookListsScreen:page_keys(view, page)
    return page_keys(plan(self, view, page, self.dimen.w, self.dimen.h, self.ctx))
end

-- Fills built from the window's records: the frame and what gestures and the covers read (showing, count, page, pages,
-- header, tiles, note, keys and drawn).
local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local view = built.showing
    local p = plan(self, view, built.page, w, h, ctx)
    built.page, built.pages = p.page, p.pages
    built.keys, built.drawn = page_keys(p)
    built.count = Typeset.line(look.type.library_count, Helpers.count_text(#p.records), w, ctx)
    local header_box
    header_box, built.header = LibraryChrome.header(ctx, w, {
        height = p.header_h,
        band = look.library.header.fill_color,
        right = { built.count },
        title = { part = look.type.library_title, text = TITLES[view.list] },
    })
    LibraryChrome.add(frame, header_box, 0, 0)
    built.tiles = {}
    local box, row_gap = p.box, scale(look.library.grid.row_gap)
    for i, record in ipairs(p.slice) do
        local x = box.columns[(i - 1) % #box.columns + 1].x
        local y = p.top + math.floor((i - 1) / #box.columns) * (box.height + row_gap)
        local widget = LibraryTiles.book(record, p.progress(record), box, ctx)
        built.tiles[i] = { rect = Geom:new{ x = x, y = y, w = box.cover_w, h = box.height }, record = record,
            widget = widget }
        LibraryChrome.add(frame, widget, x, y)
    end
    LibraryChrome.foot(built, frame, view.list)
    if #p.records == 0 then
        local note = Typeset.line(look.type.shelf_empty, EMPTY[view.list], w, ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        LibraryChrome.add(frame, note, math.floor((w - size.w) / 2), p.top + math.floor((below - p.top - size.h) / 2))
        built.note = note
    end
end

function BookListsScreen:build(view, page)
    return LibraryChrome.build({ showing = view, page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- The action a tap at pos on the window's tiles runs, or nil: a book opens.
function BookListsScreen:action_at(pos)
    for _, tile in ipairs(self.tiles) do
        if Helpers.inside(tile.rect, pos) then
            return function()
                self:open(tile.record)
            end
        end
    end
    return nil
end

-- What lies at (x, y) on the shown window: { kind = "book", record } or { kind = "empty" }; nil with no book list
-- shown.
function BookListsScreen.hit(x, y)
    local screen = BookListsScreen.shown
    if not screen then
        return nil
    end
    local pos = { x = x, y = y }
    for _, tile in ipairs(screen.tiles) do
        if Helpers.inside(tile.rect, pos) then
            return { kind = "book", record = tile.record }
        end
    end
    return { kind = "empty" }
end

-- The hold: a book's sheet over the window, History's with Remove from history after the sheet's own rows.
function BookListsScreen:hold_sheet(hit, started)
    if not hit or hit.kind ~= "book" then
        return
    end
    local opts = { started = started, beneath = self }
    if self.showing.list == "history" then
        opts.extra_rows = { {
            icon = "history",
            label = "Remove from history",
            run = Guards.guarded("the removal from history", function()
                BookLists.remove_from_history(hit.record.path)
                self:refresh()
            end),
        } }
    end
    BookSheet.open_record(hit.record, self, self.ctx, opts)
end

-- The covers of the list's books, once per show.
function BookListsScreen:request_covers()
    LibraryChrome.request_records(self)
end

-- The re-read of a refresh (the metadata events', the sheets'), once the chrome dropped the library's books: the list
-- taken again (a book just downloaded kept in its place, LibraryChrome.keep_downloaded). A failed read is logged and
-- the view rebuilt from the books as they were.
function BookListsScreen:relist()
    self.kept = nil
    local ok, records = pcall(function()
        return LibraryChrome.keep_downloaded(self, listed(self.showing))
    end)
    if ok then
        self.records = records
    else
        logger.err("KoPanda: could not re-read the " .. self.showing.list .. " list:", records)
    end
end

-- opts: view ({ list = "history" }, the default, or { list = "favorites" }), page and started (LibraryChrome.show's).
-- Returns the window shown, or nil.
function BookListsScreen.show(opts)
    return LibraryChrome.show(BookListsScreen, opts, { showing = opts.view or HISTORY, page = opts.page })
end

function BookListsScreen.close()
    if BookListsScreen.shown then
        LibraryChrome.close()
    end
end

return BookListsScreen
