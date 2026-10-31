-- The library search: SearchScreen.ask(from) asks for a query in KOReader's InputDialog
-- (frontend/ui/widget/inputdialog.lua:583 getInputText, :640 onShowKeyboard), and the window on the chrome
-- (library_chrome.lua) shows the books it matches (book_search.lua) as tiles, a page at a time. SearchScreen.shown is
-- the chrome's slot; a book opened from it records Library.return_to, the folder the search started from.
local BookSearch = require("book_search")
local Books = require("books")
local Geom = require("ui/geometry")
local Helpers = require("helpers")
local InputDialog = require("ui/widget/inputdialog")
local Library = require("library")
local LibraryChrome = require("library_chrome")
local LibraryOrder = require("library_order")
local LibraryTiles = require("library_tiles")
local Typeset = require("typeset")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local util = require("util")
local Screen = require("device").screen

local SearchScreen = LibraryChrome.Window:extend{
    name = "kopanda_search",
    screen = "search",
    fields = { "query", "tiles", "note", "keys", "drawn" },
    -- The query, with at least one word, and from, { dir, page } of the library the search started from.
    query = nil,
    from = nil,
}

-- The books are read once per show, and again when the metadata events re-list. A book opened from the
-- results closes back to the library at from (Window:open runs on_open with no self).
function SearchScreen:init()
    self.records = Books.all()
    local from = self.from
    self.on_open = function()
        Library.return_to = { dir = from.dir, page = from.page }
    end
    LibraryChrome.Window.init(self)
end

function SearchScreen:view()
    return { query = self.query }
end

local function scale(px)
    return Screen:scaleBySize(px)
end

-- Books.progress, each record read once per match.
local function progress_once()
    local seen = {}
    return function(record)
        if seen[record] == nil then
            seen[record] = Books.progress(record)
        end
        return seen[record]
    end
end

-- The window's matches for query, kept on the window as { records, query, matches, progress }: a page turn or
-- repaint matches nothing; a show, refresh() and a cover arrival's re-read match again.
local function matched(self, query)
    local kept = self.kept
    if not kept or kept.records ~= self.records or kept.query ~= query then
        kept = { records = self.records, query = query, matches = BookSearch.match(self.records, query),
            progress = progress_once() }
        self.kept = kept
    end
    return kept
end

-- What view at page shows on a screen w by h under ctx, before any widget is built: the matches, the grid at the
-- one-author cover height in the room under the detail header, and the page of the rows that fit.
local function plan(self, view, page, w, h, ctx)
    local kept = matched(self, view.query)
    local p = { query = view.query, matches = kept.matches, progress = kept.progress }
    p.header_h = LibraryChrome.detail_header_height(ctx)
    p.box = LibraryTiles.geometry(w, ctx, { cover_h = ctx.look.shelf.author_grid.cover_h,
        room = LibraryTiles.room(h, ctx, p.header_h) })
    p.top = p.header_h + scale(ctx.look.library.grid.padding_top)
    p.slice, p.pages, p.page = LibraryOrder.page(p.matches, page, p.box.rows * #p.box.columns)
    return p
end

-- The keys of p's page in order (the query, page count, match count, each tile's record) and the ids of
-- the records the page draws.
local function page_keys(p)
    local keys, drawn = { table.concat({ "search", p.query, p.pages, #p.matches }, "\0") }, {}
    for _, record in ipairs(p.slice) do
        keys[#keys + 1] = record.id
        drawn[record.id] = true
    end
    return keys, drawn
end

-- The chrome's extraction helper reads these (LibraryChrome.request_records).
function SearchScreen:page_keys(view, page)
    return page_keys(plan(self, view, page, self.dimen.w, self.dimen.h, self.ctx))
end

-- The header, w wide: the back control to the library over the count and the query in curly quotes, on the
-- library's band (LibraryChrome.header's detail form).
local function header(p, w, ctx)
    local look = ctx.look
    return LibraryChrome.header(ctx, w, {
        height = p.header_h,
        band = look.library.header.fill_color,
        right = {},
        back_label = "Library",
        aside = { part = look.type.library_count, text = Helpers.count_text(#p.matches) },
        title = { part = look.type.shelf_detail_title, text = "“" .. p.query .. "”" },
    })
end

-- Fills built from the window's records: the frame and what gestures and the covers read (query, page,
-- pages, header, tiles, note, keys and drawn).
local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local p = plan(self, { query = built.query }, built.page, w, h, ctx)
    built.page, built.pages = p.page, p.pages
    built.keys, built.drawn = page_keys(p)
    local header_box
    header_box, built.header = header(p, w, ctx)
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
    LibraryChrome.foot(built, frame, "library")
    if #p.matches == 0 then
        local note = Typeset.line(look.type.shelf_empty, "No books match", w, ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        LibraryChrome.add(frame, note, math.floor((w - size.w) / 2), p.top + math.floor((below - p.top - size.h) / 2))
        built.note = note
    end
end

function SearchScreen:build(view, page)
    return LibraryChrome.build({ query = view.query, page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- The back control: the library at the folder and page the search started from.
function SearchScreen:back()
    Library.show{ dir = self.from.dir, page = self.from.page }
end

-- The action a tap at pos on the window's tiles runs, or nil: a downloaded book opens; a book without a file
-- does nothing.
function SearchScreen:action_at(pos)
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

-- What lies at (x, y) on the shown window: { kind = "book", record } or { kind = "empty" }; nil with no search
-- window shown.
function SearchScreen.hit(x, y)
    local screen = SearchScreen.shown
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

-- The covers of every book of the library, once per show.
function SearchScreen:request_covers()
    LibraryChrome.request_records(self)
end

-- The metadata events and the sheets re-list: the kept matches dropped, the books read again (a book just
-- downloaded kept in its place, LibraryChrome.keep_downloaded), then the view rebuilt. A failed read is logged
-- and the view rebuilt from the books as they were.
function SearchScreen:refresh()
    if SearchScreen.shown ~= self then
        return
    end
    self.kept = nil
    local ok, records = pcall(function()
        return LibraryChrome.keep_downloaded(self, Books.all())
    end)
    if ok then
        self.records = records
    else
        logger.err("KoPanda: could not re-read the search's books:", records)
    end
    LibraryChrome.Window.refresh(self)
end

-- opts: query, from ({ dir, page }), page and started (LibraryChrome.show's). Returns the window shown, or nil.
function SearchScreen.show(opts)
    return LibraryChrome.show(SearchScreen, opts, { query = opts.query, from = opts.from, page = opts.page })
end

function SearchScreen.close()
    if SearchScreen.shown then
        LibraryChrome.close()
    end
end

-- The "Search library" dialog: Cancel, or Search with no word in the query, closes it; Search with words closes
-- it and shows the results for the query trimmed, their back and a book's return going to from. Every step runs
-- guarded: an error is logged and the dialog closed.
function SearchScreen.ask(from)
    local dialog
    local function guarded(fn)
        return function()
            local ok, err = pcall(fn)
            if not ok then
                logger.err("KoPanda: the library search failed:", err)
                if dialog and UIManager:isWidgetShown(dialog) then
                    pcall(UIManager.close, UIManager, dialog)
                end
            end
        end
    end
    guarded(function()
        dialog = InputDialog:new{
            title = "Search library",
            buttons = { {
                {
                    text = "Cancel",
                    id = "close",
                    callback = guarded(function()
                        UIManager:close(dialog)
                    end),
                },
                {
                    text = "Search",
                    is_enter_default = true,
                    callback = guarded(function()
                        local text = dialog:getInputText()
                        UIManager:close(dialog)
                        if #BookSearch.words(text) > 0 then
                            SearchScreen.show{ query = util.trim(text), from = from }
                        end
                    end),
                },
            } },
        }
        UIManager:show(dialog)
        dialog:onShowKeyboard()
    end)()
end

return SearchScreen
