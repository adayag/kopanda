-- The reader's Contents and Bookmarks lists: a window on the chrome (library_chrome.lua) over the reader, with no nav
-- bar, listing the book's chapters, a parent's under it only while it is open, or its annotations, a page at a time by
-- whole rows between a one-row header and the pager. What the lists hold and how a tap jumps is goto_list.lua's; the
-- rows are goto_rows.lua's. GotoScreen.shown is the chrome's slot.
local Geom = require("ui/geometry")
local GotoList = require("goto_list")
local GotoRows = require("goto_rows")
local Helpers = require("helpers")
local LibraryChrome = require("library_chrome")
local LibraryTiles = require("library_tiles")
local ShelfOrder = require("shelf_order")
local Sheet = require("sheet")
local Typeset = require("typeset")
local Screen = require("device").screen

local GotoScreen = LibraryChrome.Window:extend{
    name = "kopanda_goto",
    screen = "goto",
    fields = { "list", "rows", "note", "count" },
    list = nil,
}

local TITLES = { chapters = "Contents", bookmarks = "Bookmarks" }
local NOTES = { chapters = "No chapters in this book", bookmarks = "No bookmarks or highlights yet" }
local REMOVALS = { bookmark = "Remove bookmark", highlight = "Remove highlight", note = "Remove note" }

local function scale(px)
    return Screen:scaleBySize(px)
end

-- The list the window shows, read once per show and again at each refresh.
local function read(self)
    if self.list == "chapters" then
        self.chapters = GotoList.chapters(self.ui)
    else
        self.bookmarks = GotoList.bookmarks(self.ui)
    end
end

-- Contents opens the current chapter's parents, so its row is shown, and closes every other.
function GotoScreen:init()
    read(self)
    if self.list == "chapters" then
        self.expanded = {}
        local rows = self.chapters.rows
        local here = rows[self.chapters.current]
        local parent = here and here.parent
        while parent do
            self.expanded[parent] = true
            parent = rows[parent].parent
        end
    end
    LibraryChrome.Window.init(self)
end

-- The view the window shows: { list = "chapters" | "bookmarks" }.
function GotoScreen:view()
    return { list = self.list }
end

-- What the list at page shows on a screen w by h under ctx, before any widget is built: its rows paged by
-- ShelfOrder.pages between the header and the pager, at the page holding the current chapter when page is nil. A
-- chapter is listed when every parent above it is open; nested is whether any chapter has children.
local function plan(self, list, page, w, h, ctx)
    local shelf = ctx.look.shelf
    local p = { list = list, rows = {}, width = w - 2 * scale(shelf.list.side),
        header_h = LibraryChrome.list_header_height(ctx) }
    p.top = p.header_h + scale(shelf.reader_list.padding_top)
    local row_h = GotoRows.height(ctx)
    if list == "chapters" then
        local current = self.chapters.current
        local listed = {}
        for i, chapter in ipairs(self.chapters.rows) do
            local parent = chapter.parent
            listed[i] = parent == nil or (listed[parent] and self.expanded[parent] == true)
            p.nested = p.nested or chapter.has_children
            if listed[i] then
                p.rows[#p.rows + 1] = { h = row_h, chapter = chapter, current = i == current }
            end
        end
    else
        for i, entry in ipairs(self.bookmarks) do
            p.rows[i] = { h = row_h, entry = entry }
        end
    end
    local available = h - LibraryTiles.pager_height(ctx) - p.top - scale(shelf.list.pager_gap)
    p.pages = ShelfOrder.pages(p.rows, available, 0)
    if page == nil and list == "chapters" then
        page = ShelfOrder.page_of(p.pages, function(row)
            return row.current
        end)
    end
    p.page = math.max(1, math.min(page or 1, #p.pages))
    return p
end

-- Fills built: the header, the page's rows, the pager with no nav bar, and the list's note when it has no rows.
local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local p = plan(self, built.list, built.page, w, h, ctx)
    built.page, built.pages, built.count = p.page, #p.pages, #p.rows
    local header_box
    header_box, built.header = LibraryChrome.list_header(ctx, w, p.header_h, TITLES[p.list])
    LibraryChrome.add(frame, header_box, 0, 0)
    local x, y = scale(look.shelf.list.side), p.top
    built.rows = {}
    local toggle_w = GotoRows.toggle_width(ctx)
    for i, row in ipairs(p.pages[p.page].rows) do
        local widget, toggle
        if row.chapter then
            local chapter = row.chapter
            widget = GotoRows.chapter(chapter, row.current, p.width, ctx, p.nested, self.expanded[chapter.index])
            if chapter.has_children then
                toggle = Geom:new{ x = x + GotoRows.toggle_x(chapter.depth, ctx), y = y, w = toggle_w, h = row.h }
            end
        else
            widget = GotoRows.bookmark(row.entry, p.width, ctx)
        end
        built.rows[i] = { rect = Geom:new{ x = x, y = y, w = p.width, h = row.h }, chapter = row.chapter,
            entry = row.entry, current = row.current, toggle = toggle, widget = widget }
        LibraryChrome.add(frame, widget, x, y)
        y = y + row.h
    end
    LibraryChrome.foot(built, frame, nil)
    built.note = nil
    if #p.rows == 0 then
        local note = Typeset.line(look.type.shelf_empty, NOTES[p.list], math.max(1, p.width), ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        LibraryChrome.add(frame, note, math.floor((w - size.w) / 2), p.top + math.floor((below - p.top - size.h) / 2))
        built.note = note
    end
end

function GotoScreen:build(view, page)
    return LibraryChrome.build({ list = view.list, page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- The back control: the book again, as it was.
function GotoScreen:back()
    GotoScreen.close()
end

-- The action a tap at pos on the window's rows runs, or nil: a parent's toggle opens or closes it on the same page,
-- which still holds its row since the rows before it are unchanged; elsewhere on a row closes the screen, then jumps
-- there.
function GotoScreen:action_at(pos)
    local ui = self.ui
    for _, row in ipairs(self.rows) do
        if row.toggle and Helpers.inside(row.toggle, pos) then
            return function()
                local index = row.chapter.index
                self.expanded[index] = not self.expanded[index] or nil
                self:go(self:view(), self.page)
            end
        end
        if Helpers.inside(row.rect, pos) then
            return function()
                GotoScreen.close()
                if row.chapter then
                    GotoList.jump_chapter(ui, row.chapter)
                else
                    GotoList.jump_bookmark(ui, row.entry)
                end
            end
        end
    end
    return nil
end

-- What lies at (x, y) on the shown window: { kind = "chapter", chapter }, { kind = "bookmark", entry } or
-- { kind = "empty" }; nil with neither list shown.
function GotoScreen.hit(x, y)
    local screen = GotoScreen.shown
    if not screen then
        return nil
    end
    local pos = { x = x, y = y }
    for _, row in ipairs(screen.rows) do
        if Helpers.inside(row.rect, pos) then
            if row.chapter then
                return { kind = "chapter", chapter = row.chapter }
            end
            return { kind = "bookmark", entry = row.entry }
        end
    end
    return { kind = "empty" }
end

-- The hold sheet's text block for entry: a highlight's or note's text, then a note's note; nil with neither.
local function paragraphs(entry)
    if entry.kind == "bookmark" then
        return nil
    end
    local text = {}
    if entry.text:find("%S") then
        text[1] = { part = "quote", text = entry.text }
    end
    if entry.kind == "note" then
        text[#text + 1] = { part = "book_description", text = entry.item.note }
    end
    return #text > 0 and text or nil
end

-- A hold on a bookmark, highlight or note shows a one-row sheet over the window that removes it, headed by its chapter
-- and page, with a highlight's or note's words above the row; its row removes it and lists the rest again. A hold
-- anywhere else does nothing.
function GotoScreen:hold_sheet(hit, started)
    if not (hit and hit.kind == "bookmark") then
        return
    end
    local entry = hit.entry
    Sheet.show({
        name = "goto_bookmark",
        band = "home",
        header = { heading = entry.chapter, aside = "Page " .. entry.page_label, aside_above = true,
            label = "Bookmarks" },
        text = paragraphs(entry),
        rows = { {
            label = REMOVALS[entry.kind],
            run = function()
                GotoList.remove_bookmark(self.ui, entry)
                self:refresh()
            end,
        } },
        flush = true,
    }, self.ctx, { beneath = GotoScreen, started = started })
end

-- Re-reads the list from the reader, then rebuilds the page shown, clamped to the pages left.
function GotoScreen:refresh()
    if GotoScreen.shown ~= self then
        return
    end
    read(self)
    LibraryChrome.Window.refresh(self)
end

-- opts: ui (the reader), list ("chapters", opening at the page holding the current chapter, or "bookmarks", at its
-- first page), and started (LibraryChrome.show's). Returns the window shown, or nil.
function GotoScreen.show(opts)
    return LibraryChrome.show(GotoScreen, opts, { ui = opts.ui, list = opts.list })
end

function GotoScreen.close()
    if GotoScreen.shown then
        LibraryChrome.close()
    end
end

return GotoScreen
