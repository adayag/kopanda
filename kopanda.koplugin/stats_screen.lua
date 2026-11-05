-- The Stats window: rows of insight tiles on the chrome (library_chrome.lua), flowed onto pages by fit and turned by a
-- swipe or the pager, read-only, with the nav bar. Tiles take the stored text size and a box of their own; the chrome
-- stays at the shell's size. A tile that fails to measure or build is logged and its slot stays blank; like the home,
-- the window reads the stats again on wake. The wall of finished covers repeats its row once per page it needs, and
-- is built only when shown, its covers asked of CoverBrowser after the paint (book_covers.lua).
local BookCovers = require("book_covers")
local LibraryChrome = require("library_chrome")
local LibraryTiles = require("library_tiles")
local Settings = require("settings")
local Widgets = require("widgets")
local logger = require("logger")
local Screen = require("device").screen

local StatsScreen = LibraryChrome.Window:extend{
    name = "kopanda_stats",
    screen = "stats",
    fields = { "covers" },
}

-- Each row's widget ids, left to right, sharing the row's width; its name, which names a page it starts; stack, for a
-- row whose tiles run full width at the sizes in STACKED; and wall, for the row repeated once per page of the wall.
local ROWS = {
    { name = "Now", "reading" },
    { name = "Now", "streak", "forecast" },
    { name = "Now", "device" },
    { name = "Habits", stack = true, "hours", "records" },
    { name = "Habits", "months" },
    { name = "This year", wall = true, "wall" },
}
-- Text sizes at which a stack row's tiles run full width, their labels cut off side by side.
local STACKED = { extra_large = true }
local VIEW = { kind = "stats" }

local function scale(px)
    return Screen:scaleBySize(px)
end

-- The pages the wall needs at width under ctx: one, logged, when it can't say.
local function wall_pages(width, ctx)
    local ok, count = pcall(function()
        return Widgets.get("wall").page_count(width, ctx)
    end)
    if ok then
        return count
    end
    logger.err("KoPanda: the Stats tile wall failed to count its pages:", count)
    return 1
end

-- The rows to flow at width under ctx, each a table of its own, since a flow notes its height there and ROWS outlives
-- the window: a stack row's tiles each a row under its name when text_size stacks, and the wall's row once per page,
-- each starting one and naming its wall_page.
local function rows_at(text_size, width, ctx)
    local rows = {}
    for _, row in ipairs(ROWS) do
        if row.wall then
            for page = 1, wall_pages(width, ctx) do
                rows[#rows + 1] = { name = row.name, wall_page = page, row[1] }
            end
        elseif row.stack and STACKED[text_size] then
            for _, id in ipairs(row) do
                rows[#rows + 1] = { name = row.name, id }
            end
        else
            rows[#rows + 1] = { name = row.name, unpack(row) }
        end
    end
    return rows
end

local function tile_width(row, width, gaps)
    return math.floor((width - (#row - 1) * gaps.column) / #row)
end

-- The row's height, the ids that failed to measure added to failed.
local function row_height(row, width, gaps, ctx, failed)
    local h = 0
    for _, id in ipairs(row) do
        local ok, tile_h = pcall(function()
            return Widgets.get(id).height(tile_width(row, width, gaps), ctx)
        end)
        if ok then
            h = math.max(h, tile_h)
        else
            failed[id] = true
            logger.err("KoPanda: the Stats tile", id, "failed to measure:", tile_h)
        end
    end
    return h
end

-- The rows on pages room tall: a wall row, or one that would run past the room, starts the next page. A wall row has
-- its page to itself, so it goes unmeasured, which would read the covers of every page of it.
local function flow(rows, room, width, gaps, ctx)
    local pages, failed, y = { {} }, {}, 0
    for _, row in ipairs(rows) do
        local h = row.wall_page and 0 or row_height(row, width, gaps, ctx, failed)
        if #pages[#pages] > 0 and (row.wall_page or y + h > room) then
            pages[#pages + 1] = {}
            y = 0
        end
        local page = pages[#pages]
        page[#page + 1] = row
        row.h = h
        y = y + h + gaps.row
    end
    return pages, failed
end

-- ctx for row's tiles: a row of several holds them to its height, and a wall row names its page.
local function row_ctx(row, ctx)
    if #row < 2 and not row.wall_page then
        return ctx
    end
    local copy = {}
    for key, value in pairs(ctx) do
        copy[key] = value
    end
    copy.row_h = #row > 1 and row.h or nil
    copy.wall_page = row.wall_page
    return copy
end

-- Adds row's tiles at y. Returns their bottom, and the covers a tile wants asked for ({ records, box }), if any.
local function add_row(row, frame, x, y, width, gaps, ctx, failed)
    local w = tile_width(row, width, gaps)
    local bottom, covers = y, nil
    local tile_ctx = row_ctx(row, ctx)
    for i, id in ipairs(row) do
        if not failed[id] then
            local ok, tile = pcall(function()
                return Widgets.get(id).build(w, tile_ctx)
            end)
            if ok and tile then
                LibraryChrome.add(frame, tile, x + (i - 1) * (w + gaps.column), y)
                bottom = math.max(bottom, y + tile:getSize().h)
                covers = tile.covers or covers
            else
                logger.err("KoPanda: the Stats tile", id, "failed to build:", tile)
            end
        end
    end
    return bottom, covers
end

local function fill(self, built, frame, w, h)
    local ctx = built.ctx
    local look = ctx.look
    local text_size = Settings.get("text_size")
    local tile_ctx = { look = look, variant = ctx.variant, screen = ctx.screen, text_size = text_size,
        now = os.time(), boxed = true }
    local header_h = LibraryTiles.header_height(ctx)
    local x = scale(look.shelf.list.side)
    local width = w - 2 * x
    local top = header_h + scale(look.library.grid.padding_top)
    local gaps = { row = scale(look.home.row_gap), column = scale(look.home.column_gap) }
    tile_ctx.room = LibraryTiles.room(h, ctx, header_h)
    local key = table.concat({ w, h, tostring(text_size), tostring(look) }, " ")
    if not (self.kept and self.kept.key == key) then
        local rows = rows_at(text_size, width, tile_ctx)
        local pages, failed = flow(rows, tile_ctx.room, width, gaps, tile_ctx)
        self.kept = { key = key, pages = pages, failed = failed, finished = tile_ctx.finished }
    end
    tile_ctx.finished = self.kept.finished
    local pages = self.kept.pages
    built.pages = #pages
    built.page = math.max(1, math.min(built.page or 1, #pages))
    local page = pages[built.page]

    local header_box
    header_box, built.header = LibraryChrome.header(ctx, w, {
        height = header_h,
        band = look.library.header.fill_color,
        right = {},
        aside = { part = look.type.library_count, text = page[1].name },
        title = { part = look.type.library_title, text = "Stats" },
    })
    LibraryChrome.add(frame, header_box, 0, 0)

    local y = top
    for _, row in ipairs(page) do
        local bottom, covers = add_row(row, frame, x, y, width, gaps, tile_ctx, self.kept.failed)
        y = bottom + gaps.row
        built.covers = covers or built.covers
    end
    LibraryChrome.foot(built, frame, "stats")
end

function StatsScreen:view()
    return VIEW
end

function StatsScreen:build(_, page)
    return LibraryChrome.build({ page = page }, function(built, frame, w, h)
        fill(self, built, frame, w, h)
    end)
end

-- The wall page's covers, asked of CoverBrowser after a paint. Each arrival rebuilds the page while it holds the wall.
function StatsScreen:request_covers()
    if LibraryChrome.shown ~= self or not self.covers then
        return
    end
    local ok, err = pcall(BookCovers.request, self.covers.records, self.covers.box, function()
        if self.covers then
            self:go(self:view(), self.page)
        end
    end, function()
        return LibraryChrome.shown == self
    end)
    if not ok then
        logger.err("KoPanda: the wall's cover request failed:", err)
    end
end

-- Read-only: nothing on a page acts on a tap but the chrome's pager.
function StatsScreen.action_at()
    return nil
end

-- Nothing here changes with a book's metadata, which the chrome's events would otherwise repaint.
function StatsScreen:refresh() end

-- Broadcast to every window on wake (frontend/device/generic/device.lua:1125). Returns nothing, so the event reaches
-- the other windows.
function StatsScreen:onResume()
    self.kept = nil
    self:go(self:view(), self.page)
end

-- opts: page and started (LibraryChrome.show's). Returns the window shown, or nil.
function StatsScreen.show(opts)
    return LibraryChrome.show(StatsScreen, opts, { page = opts.page })
end

function StatsScreen.close()
    if StatsScreen.shown then
        LibraryChrome.close()
    end
end

return StatsScreen
