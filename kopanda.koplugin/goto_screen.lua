-- The Go to screen: a window on the chrome (library_chrome.lua) over the reader, with no nav bar, listing the book's
-- chapters, a parent's under it only while it is open, or its bookmarks a page at a time by whole rows between the
-- header and the pager. What the lists hold and how a tap jumps is goto_list.lua's; the rows are goto_rows.lua's.
-- GotoScreen.shown is the chrome's slot.
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
    fields = { "tab", "rows", "chips", "note", "count" },
    tab = nil,
}

local NOTES = { chapters = "No chapters in this book", bookmarks = "No bookmarks yet" }

local function scale(px)
    return Screen:scaleBySize(px)
end

-- The reader's lists, read once per show and again at each refresh.
local function read(self)
    self.chapters = GotoList.chapters(self.ui)
    self.bookmarks = GotoList.bookmarks(self.ui)
end

-- Opens the current chapter's parents, so its row is shown, and closes every other.
function GotoScreen:init()
    read(self)
    self.expanded = {}
    local rows = self.chapters.rows
    local here = rows[self.chapters.current]
    local parent = here and here.parent
    while parent do
        self.expanded[parent] = true
        parent = rows[parent].parent
    end
    LibraryChrome.Window.init(self)
end

-- The view the window shows: { tab = "chapters" | "bookmarks" }, Chapters unless the book has none.
function GotoScreen:view()
    return { tab = self.tab or (#self.chapters.rows > 0 and "chapters" or "bookmarks") }
end

-- What view at page shows on a screen w by h under ctx, before any widget is built: its rows paged by
-- ShelfOrder.pages between the header and the pager, at the page holding the current chapter when page is nil. A
-- chapter is listed when every parent above it is open; nested is whether any chapter has children.
local function plan(self, view, page, w, h, ctx)
    local shelf = ctx.look.shelf
    local tab = view.tab or self:view().tab
    local p = { tab = tab, rows = {}, width = w - 2 * scale(shelf.list.side),
        header_h = LibraryChrome.detail_header_height(ctx) }
    p.top, p.gap = p.header_h + scale(shelf.list.padding_top), scale(shelf.list.row_gap)
    local current = self.chapters.current
    if tab == "chapters" then
        local listed = {}
        for i, chapter in ipairs(self.chapters.rows) do
            local parent = chapter.parent
            listed[i] = parent == nil or (listed[parent] and self.expanded[parent] == true)
            p.nested = p.nested or chapter.has_children
            if listed[i] then
                local is_current = i == current
                p.rows[#p.rows + 1] = { h = GotoRows.height("chapter", is_current, ctx), chapter = chapter,
                    current = is_current }
            end
        end
    else
        local row_h = GotoRows.height("bookmark", false, ctx)
        for i, entry in ipairs(self.bookmarks) do
            p.rows[i] = { h = row_h, entry = entry }
        end
    end
    local available = h - LibraryTiles.pager_height(ctx) - p.top - scale(shelf.list.pager_gap)
    p.pages = ShelfOrder.pages(p.rows, available, p.gap)
    if page == nil and tab == "chapters" then
        page = ShelfOrder.page_of(p.pages, function(row)
            return row.current
        end)
    end
    p.page = math.max(1, math.min(page or 1, #p.pages))
    return p
end

-- A tab's chip: the active one inverted, its label in paper on ink; the other on the header's sort fill.
local function chip(text, active, ctx)
    local look = ctx.look
    if not active then
        local label = Typeset.line(look.type.library_picker, text, Screen:getWidth(), ctx)
        local tokens = look.library.header
        return LibraryChrome.chip({ label }, tokens.sort_fill_color, ctx, tokens.tab_padding_x)
    end
    local part = {}
    for k, v in pairs(look.type.library_picker_status) do
        part[k] = v
    end
    part.color = "paper"
    return LibraryChrome.chip({ Typeset.line(part, text, Screen:getWidth(), ctx) }, "ink", ctx,
        look.library.header.tab_padding_x)
end

-- The header, w wide: the back control ("Book") over the book's title and "Go to", the Chapters and Bookmarks chips
-- at the right. Returns it, its parts and the chips' rects by tab.
local function header(self, p, w, ctx)
    local look = ctx.look
    local title = self.ui.doc_props and self.ui.doc_props.display_title or ""
    local box, parts = LibraryChrome.header(ctx, w, {
        height = p.header_h,
        band = look.library.header.fill_color,
        back_label = "Book",
        right = { chip("Bookmarks", p.tab == "bookmarks", ctx), chip("Chapters", p.tab == "chapters", ctx) },
        aside = { part = look.type.library_count, text = title },
        title = { part = look.type.shelf_detail_title, text = "Go to" },
    })
    return box, parts, { bookmarks = parts.right[1], chapters = parts.right[2] }
end

-- Fills built: the header, the page's rows, the pager with no nav bar, and the tab's note when it has no rows.
local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local p = plan(self, { tab = built.tab }, built.page, w, h, ctx)
    built.tab, built.page, built.pages, built.count = p.tab, p.page, #p.pages, #p.rows
    local header_box
    header_box, built.header, built.chips = header(self, p, w, ctx)
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
        y = y + row.h + p.gap
    end
    LibraryChrome.foot(built, frame, nil)
    built.note = nil
    if #p.rows == 0 then
        local note = Typeset.line(look.type.shelf_empty, NOTES[p.tab], math.max(1, p.width), ctx)
        local size = note:getSize()
        local below = built.pager.prev.rect.y
        LibraryChrome.add(frame, note, math.floor((w - size.w) / 2), p.top + math.floor((below - p.top - size.h) / 2))
        built.note = note
    end
end

function GotoScreen:build(view, page)
    return LibraryChrome.build({ tab = view.tab, page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- The back control: the book again, as it was.
function GotoScreen:back()
    GotoScreen.close()
end

-- The action a tap at pos on the window's chips and rows runs, or nil: a chip shows its tab, Chapters at the current
-- chapter's page; a parent's toggle opens or closes it on the same page, which still holds its row since the rows
-- before it are unchanged; elsewhere on a row closes the screen, then jumps there.
function GotoScreen:action_at(pos)
    for tab, rect in pairs(self.chips) do
        if Helpers.inside(rect, pos) then
            return function()
                self:go({ tab = tab }, tab == "bookmarks" and 1 or nil)
            end
        end
    end
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
-- { kind = "empty" }; nil with no Go to screen shown.
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

-- A hold on a bookmark shows a one-row sheet over the window, Remove bookmark, headed by the bookmark's chapter and
-- page; its row removes the bookmark and lists the bookmarks again. A hold anywhere else does nothing.
function GotoScreen:hold_sheet(hit, started)
    if not (hit and hit.kind == "bookmark") then
        return
    end
    local entry = hit.entry
    Sheet.show({
        name = "goto_bookmark",
        band = "home",
        header = { heading = entry.chapter, aside = "Page " .. entry.page_label, aside_above = true, label = "Go to" },
        rows = { {
            label = "Remove bookmark",
            run = function()
                GotoList.remove_bookmark(self.ui, entry)
                self:refresh()
            end,
        } },
        flush = true,
    }, self.ctx, { beneath = GotoScreen, started = started })
end

-- Re-reads both lists from the reader, then rebuilds the page shown, clamped to the pages left.
function GotoScreen:refresh()
    if GotoScreen.shown ~= self then
        return
    end
    read(self)
    LibraryChrome.Window.refresh(self)
end

-- opts: ui (the reader), and started (LibraryChrome.show's). Opens on Chapters at the page holding the current
-- chapter, or on Bookmarks when the book has no chapters. Returns the window shown, or nil.
function GotoScreen.show(opts)
    return LibraryChrome.show(GotoScreen, opts, { ui = opts.ui })
end

function GotoScreen.close()
    if GotoScreen.shown then
        LibraryChrome.close()
    end
end

return GotoScreen
