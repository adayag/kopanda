-- The year's finished covers in an insight tile filling a page of the Stats window, oldest first, a month's name over
-- its first cover and over a page's first, from FinishedBooks. Covers come from CoverBrowser's cache through
-- FeaturedCover.framed, in the library's frame, a placeholder for one not cached; the tile names what to ask for.
local FeaturedCover = require("featured_cover")
local FinishedBooks = require("finished_books")
local Helpers = require("helpers")
local InsightTile = require("insight_tile")
local LibraryTiles = require("library_tiles")
local Paint = require("paint")
local Typeset = require("typeset")

local LABEL = "Finished"
local NONE = "Nothing finished yet this year"
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local COVER_H, COVER_W = 10, 7

local Wall = {
    id = "wall",
}

local function month_of(book)
    return MONTHS[tonumber(book.day:sub(6, 7))]
end

-- A label per book (each { day }, oldest first): its month's for the month's first book, "" for the rest.
function Wall.months(books)
    local labels, last = {}, nil
    for i, book in ipairs(books) do
        local month = month_of(book)
        labels[i] = month ~= last and month or ""
        last = month
    end
    return labels
end

-- The covers columns across inner_w and the rows of them, each under month_h, that fit room_h, at least one:
-- { columns, rows, cover_w, cover_h }.
function Wall.grid(inner_w, room_h, columns, gap, month_h)
    local cover_w = math.floor((inner_w - (columns - 1) * gap) / columns)
    local cover_h = math.floor(cover_w * COVER_H / COVER_W)
    local rows = math.max(1, math.floor((room_h + gap) / (month_h + cover_h + gap)))
    return { columns = columns, rows = rows, cover_w = cover_w, cover_h = cover_h }
end

-- books (each { record, day }) on pages per_page long, at least one: lists of { record, month }, month as Wall.months
-- gives it, but for a page's first cover, which always names its month.
function Wall.split(books, per_page)
    local pages, labels = { {} }, Wall.months(books)
    for i, book in ipairs(books) do
        if #pages[#pages] == per_page then
            pages[#pages + 1] = {}
        end
        local page = pages[#pages]
        page[#page + 1] = { record = book.record, month = #page == 0 and month_of(book) or labels[i] }
    end
    return pages
end

-- The finished books for ctx, kept on it, so a ctx and its copies read them once.
local function finished(ctx)
    ctx.finished = ctx.finished or FinishedBooks.list(ctx.now)
    return ctx.finished
end

-- The grid for a tile width wide filling ctx.room, its gap and the height of a month line with the space under it.
local function layout(width, ctx)
    local look = ctx.look
    local tokens = look.insights
    local scale = Paint.scaler(ctx)
    local columns = ctx.text_size == "extra_large" and tokens.wall_columns_extra_large or tokens.wall_columns
    local gap = scale(tokens.wall_gap)
    local month_h = Typeset.line_height(look.type.insight_caption, ctx) + scale(tokens.value_gap)
    local grid = Wall.grid(InsightTile.inner_width(width, ctx), InsightTile.content_room(width, ctx, ctx.room),
        columns, gap, month_h)
    return grid, gap, month_h
end

-- How many pages the finished books need at width under ctx.
function Wall.page_count(width, ctx)
    local grid = layout(width, ctx)
    return #Wall.split(finished(ctx), grid.columns * grid.rows)
end

local function compose(width, ctx)
    local books = finished(ctx)
    if #books == 0 then
        return InsightTile.compose(width, ctx, LABEL, NONE, 0, function() end)
    end
    local look = ctx.look
    local grid, gap, month_h = layout(width, ctx)
    local page = Wall.split(books, grid.columns * grid.rows)[ctx.wall_page or 1]
    local frame = LibraryTiles.cover_frame(look)
    local step_x, step_y = grid.cover_w + gap, month_h + grid.cover_h + gap
    local month_part = look.type.insight_caption
    local cells, records = {}, {}
    for i, entry in ipairs(page) do
        local column, row = (i - 1) % grid.columns, math.floor((i - 1) / grid.columns)
        cells[i] = {
            x = column * step_x,
            y = row * step_y,
            month = entry.month ~= "" and Typeset.line(month_part, entry.month, grid.cover_w, ctx) or nil,
            cover = FeaturedCover.framed(entry.record, grid.cover_w, grid.cover_h, ctx, frame),
        }
        records[i] = entry.record
    end

    local function paint(bb, x, y)
        for _, cell in ipairs(cells) do
            if cell.month then
                cell.month:paintTo(bb, x + cell.x, y + cell.y)
            end
            cell.cover:paintTo(bb, x + cell.x, y + cell.y + month_h)
        end
    end

    local rows = math.ceil(#page / grid.columns)
    local content_h = rows * step_y - gap
    local tile = InsightTile.compose(width, ctx, LABEL, Helpers.books_text(#books), content_h, paint)
    tile.cells, tile.grid = cells, grid
    tile.covers = { records = records, box = { max_cover_w = grid.cover_w, max_cover_h = grid.cover_h } }
    local free_tile = tile.free
    function tile:free()
        for _, cell in ipairs(self.cells) do
            if cell.month then
                cell.month:free()
            end
            cell.cover:free()
        end
        self.cells = {}
        free_tile(self)
    end
    return tile
end

Wall.height, Wall.build = Typeset.measured(compose)

return Wall
