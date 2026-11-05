-- The Stats window: rows of insight tiles on the chrome (library_chrome.lua), flowed onto pages by fit and turned by a
-- swipe or the pager, read-only, with the nav bar. Tiles take the stored text size and a box of their own; the chrome
-- stays at the shell's size. A tile that fails to measure or build is logged and its slot stays blank; like the home,
-- the window reads the stats again on wake.
local LibraryChrome = require("library_chrome")
local LibraryTiles = require("library_tiles")
local Settings = require("settings")
local Widgets = require("widgets")
local logger = require("logger")
local Screen = require("device").screen

local StatsScreen = LibraryChrome.Window:extend{
    name = "kopanda_stats",
    screen = "stats",
}

-- Each row's widget ids, left to right, sharing the row's width; its name, which names a page it starts; page, for a
-- row that always starts one; and stack, for a row whose tiles run full width at the sizes in STACKED.
local ROWS = {
    { name = "Now", "reading" },
    { name = "Now", "streak", "forecast" },
    { name = "Habits", stack = true, "hours", "records" },
    { name = "Over time", page = true, "months" },
}
-- Text sizes at which a stack row's tiles run full width, their labels cut off side by side.
local STACKED = { extra_large = true }
local VIEW = { kind = "stats" }

local function scale(px)
    return Screen:scaleBySize(px)
end

-- ROWS at text_size: a stack row's tiles each a row of their own under its name, when text_size stacks.
local function rows_at(text_size)
    if not STACKED[text_size] then
        return ROWS
    end
    local rows = {}
    for _, row in ipairs(ROWS) do
        if row.stack then
            for _, id in ipairs(row) do
                rows[#rows + 1] = { name = row.name, id }
            end
        else
            rows[#rows + 1] = row
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

-- The rows on pages room tall: a row marked page, or one that would run past the room, starts the next page.
local function flow(rows, room, width, gaps, ctx)
    local pages, failed, y = { {} }, {}, 0
    for _, row in ipairs(rows) do
        local h = row_height(row, width, gaps, ctx, failed)
        if #pages[#pages] > 0 and (row.page or y + h > room) then
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

-- ctx for row's tiles: a row of several holds them to its height.
local function row_ctx(row, ctx)
    if #row < 2 then
        return ctx
    end
    local copy = {}
    for key, value in pairs(ctx) do
        copy[key] = value
    end
    copy.row_h = row.h
    return copy
end

local function add_row(row, frame, x, y, width, gaps, ctx, failed)
    local w = tile_width(row, width, gaps)
    local bottom = y
    local tile_ctx = row_ctx(row, ctx)
    for i, id in ipairs(row) do
        if not failed[id] then
            local ok, tile = pcall(function()
                return Widgets.get(id).build(w, tile_ctx)
            end)
            if ok and tile then
                LibraryChrome.add(frame, tile, x + (i - 1) * (w + gaps.column), y)
                bottom = math.max(bottom, y + tile:getSize().h)
            else
                logger.err("KoPanda: the Stats tile", id, "failed to build:", tile)
            end
        end
    end
    return bottom
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
    local key = table.concat({ w, h, tostring(text_size), tostring(look) }, " ")
    if not (self.kept and self.kept.key == key) then
        local pages, failed = flow(rows_at(text_size), LibraryTiles.room(h, ctx, header_h), width, gaps, tile_ctx)
        self.kept = { key = key, pages = pages, failed = failed }
    end
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
        y = add_row(row, frame, x, y, width, gaps, tile_ctx, self.kept.failed) + gaps.row
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
