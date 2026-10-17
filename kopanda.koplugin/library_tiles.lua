-- The library grid's tiles: the grid's geometry (three columns inside the side padding, the cover
-- box, a tile's height), the header's and the pager's heights the two-row fit adds up, and one
-- widget per book or folder, from the look's library tokens (Main.dc.html:30-83, GridA.dc.html:30-83
-- under .tiller/design/2026-10-16-kopanda-library-screens/). Lengths are board pixels, scaled by
-- ctx.screen. The library's text does not follow text_size (cover-grid D12), so every line here
-- is set in a ctx without one, as NavBar.height sets its labels.
--
-- A tile is the cover box's width and the geometry's height whatever it holds (D13): the cover,
-- the strip's slot, one title line. What reaches past the box, the cover's shadow and Diner's
-- overhanging badge, is painted past it into the gaps.
local FeaturedCover = require("featured_cover")
local Featured = require("widgets/featured")
local Geom = require("ui/geometry")
local Icons = require("icons")
local Layout = require("layout")
local Looks = require("looks")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")

local LibraryTiles = {}

local COLUMNS = 3
-- A line's height is its face's or its forced one, whatever its text
-- (frontend/ui/widget/textwidget.lua:112-113, :292-299), so one sample measures every line of a part.
local SAMPLE = "Library"

-- The tile: its children painted at their places from its top left, in order, so the badge and
-- the chip come after the cover they sit on.
local Tile = FeaturedCover.Box:extend{
    name = "kopanda_library_tile",
}

-- Where child is painted, from the tile's top left, or nil for a widget the tile doesn't hold.
function Tile:place(child)
    for i, held in ipairs(self) do
        if held == child then
            return self.places[i]
        end
    end
    return nil
end

local function add(box, child, x, y)
    box[#box + 1] = child
    box.places[#box.places + 1] = { x = x, y = y }
    return child
end

-- ctx without its text size (D12).
local function fixed(ctx)
    return { look = ctx.look, variant = ctx.variant, screen = ctx.screen }
end

local function scaler(ctx)
    return function(px)
        return ctx.screen:scaleBySize(px)
    end
end

-- A negative length, an overhang, scaled as its size is, so a corner overhangs as far as it insets.
local function scale_signed(scale, px)
    if px < 0 then
        return -scale(-px)
    end
    return scale(px)
end

local function colorer(ctx)
    local palette = Looks.palette(ctx.look, ctx.variant)
    return function(role)
        return role and palette[role] and Looks.color(palette[role]) or nil
    end
end

local function line_height(part, ctx)
    local line = Typeset.line(part, SAMPLE, math.huge, ctx)
    local h = line:getSize().h
    line:free()
    return h
end

-- The grid across a screen screen_w wide under ctx, in device pixels: columns, three { x, w } from
-- the screen's left edge inside grid.side at grid.column_gap (Layout.columns), the cover box's
-- cover_w (the narrowest column's width) and cover_h, the strip's strip_y and strip_h and the
-- title's title_y from a tile's top, and height, the tile's: cover, strip gap, strip, title gap
-- and one tile_title line. cover_h, in board pixels, is the cover box's height where it is not the
-- grid's, as the one-author grid's (shelf.author_grid.cover_h). Raises when the title's face won't load.
function LibraryTiles.geometry(screen_w, ctx, cover_h)
    ctx = fixed(ctx)
    local scale = scaler(ctx)
    local library = ctx.look.library
    local grid = library.grid
    local side = scale(grid.side)
    local slots = {}
    for i = 1, COLUMNS do
        slots[i] = { share = 1 }
    end
    local columns = Layout.columns(screen_w - 2 * side, slots, grid.column_gap)
    local cover_w = columns[1].w
    for _, column in ipairs(columns) do
        column.x = column.x + side
        cover_w = math.min(cover_w, column.w)
    end
    cover_h = scale(cover_h or grid.cover_h)
    local strip_y = cover_h + scale(grid.strip_gap)
    local strip_h = scale(library.strip.height)
    local title_y = strip_y + strip_h + scale(grid.title_gap)
    return {
        columns = columns,
        cover_w = cover_w,
        cover_h = cover_h,
        strip_y = strip_y,
        strip_h = strip_h,
        title_y = title_y,
        height = title_y + line_height(ctx.look.type.tile_title, ctx),
    }
end

-- The header's height under ctx, in device pixels: its padding, the taller of the count over the
-- title and a picker (its label line inside its padding and outline; the picker's mark is drawn
-- no taller than its line), and its edge.
function LibraryTiles.header_height(ctx)
    ctx = fixed(ctx)
    local scale = scaler(ctx)
    local look = ctx.look
    local header = look.library.header
    local text = line_height(look.type.library_count, ctx) + scale(header.line_gap)
        + line_height(look.type.library_title, ctx)
    local picker = line_height(look.type.library_picker, ctx)
        + 2 * (scale(header.picker_padding.y) + scale(header.picker_outline_width))
    return scale(header.padding.top) + math.max(text, picker) + scale(header.padding.bottom)
        + scale(header.edge_width)
end

-- The pager's height under ctx, in device pixels: the taller of a button and the page label, and
-- the space under it.
function LibraryTiles.pager_height(ctx)
    ctx = fixed(ctx)
    local scale = scaler(ctx)
    local look = ctx.look
    local pager = look.library.pager
    return math.max(scale(pager.button_h), line_height(look.type.pager_label, ctx)) + scale(pager.bottom)
end

local function new_tile(box)
    return Tile:new{
        dimen = Geom:new{ w = box.cover_w, h = box.height },
        box_w = box.cover_w,
        box_h = box.height,
        outline = 0,
        places = {},
    }
end

-- The book's cover box: FeaturedCover.framed in the grid's cover tokens and placeholder title.
local function cover_frame(look)
    local cover = look.library.cover
    return {
        outline_color = cover.outline_color,
        outline_width = cover.outline_width,
        radius = cover.radius,
        shadow = cover.shadow,
        padding = cover.padding,
        title = look.type.tile_cover_title,
    }
end

-- The download badge: a circle of badge.size in fill_color with an outline, the download icon
-- centred in it.
local function badge(ctx)
    local scale, color = scaler(ctx), colorer(ctx)
    local tokens = ctx.look.library.badge
    local size = scale(tokens.size)
    local radius = math.floor(size / 2)
    local outline_color = color(tokens.outline_color)
    local icon = TintedIcon:new{
        file = Icons.path("download"),
        size = scale(tokens.icon_size),
        color = color(tokens.icon_color),
    }
    local offset = math.floor((size - icon.size) / 2)
    return FeaturedCover.Box:new{
        name = "kopanda_library_badge",
        dimen = Geom:new{ w = size, h = size },
        box_w = size,
        box_h = size,
        fill_color = color(tokens.fill_color),
        fill_radius = radius,
        outline = outline_color and scale(tokens.outline_width) or 0,
        outline_color = outline_color,
        radius = radius,
        places = { { x = offset, y = offset } },
        icon,
    }
end

-- A chip on the cover's foot, at most max_w wide: text in part inside not_downloaded's padding and
-- outline colour at outline_width (board pixels), on fill_color. "Not downloaded" takes the
-- library's not_downloaded tokens; "Up next" the shelf's up_next ones (series-and-authors D5).
local function chip(text, part, fill_color, outline_width, max_w, ctx)
    local scale, color = scaler(ctx), colorer(ctx)
    local tokens = ctx.look.library.not_downloaded
    local outline_color = color(tokens.outline_color)
    local outline = outline_color and scale(outline_width) or 0
    local pad_x, pad_y = outline + scale(tokens.padding.x), outline + scale(tokens.padding.y)
    local line = Typeset.line(part, text, math.max(1, max_w - 2 * pad_x), ctx)
    local size = line:getSize()
    local w, h = size.w + 2 * pad_x, size.h + 2 * pad_y
    return FeaturedCover.Box:new{
        name = "kopanda_library_chip",
        dimen = Geom:new{ w = w, h = h },
        box_w = w,
        box_h = h,
        fill_color = color(fill_color),
        outline = outline,
        outline_color = outline_color,
        places = { { x = pad_x, y = pad_y } },
        line,
    }
end

-- Adds the chip on the cover's foot and, for a path-less record (badged), the badge at the corner
-- badge.align names (the right one, top or bottom) inset from the cover's outline (negative:
-- overhanging). The chip sits left of the badge's place: beside it where both are on the foot, at
-- the placeholder's padding where the badge is on top. The chip is "Not downloaded", or the
-- caller's label, "Up next", which takes its place (series-and-authors D19).
local function foot(tile, box, ctx, badged, label)
    local scale, color = scaler(ctx), colorer(ctx)
    local look = ctx.look
    local library = look.library
    local tokens = library.badge
    local edge = color(library.cover.outline_color) and scale(library.cover.outline_width) or 0
    local size = scale(tokens.size)
    local inset = scale_signed(scale, tokens.inset)
    local badge_x = box.cover_w - edge - inset - size
    local on_foot = tokens.align == "bottom"
    local badge_y = on_foot and box.cover_h - edge - inset - size or edge + inset
    local pad = library.cover.padding
    local chip_x = edge + scale(pad.x)
    local room = on_foot and badge_x - scale(library.not_downloaded.padding.x) - chip_x or box.cover_w - 2 * chip_x
    local the_chip
    if label then
        local up_next = look.shelf.up_next
        the_chip = chip(label, look.type.shelf_chip_plain, up_next.fill_color, up_next.outline_width, room, ctx)
    else
        local not_downloaded = library.not_downloaded
        the_chip = chip("Not downloaded", look.type.not_downloaded, not_downloaded.fill_color,
            not_downloaded.outline_width, room, ctx)
    end
    local chip_h = the_chip:getSize().h
    local chip_y = on_foot and badge_y + math.floor((size - chip_h) / 2) or box.cover_h - edge - scale(pad.y) - chip_h
    tile.chip = add(tile, the_chip, chip_x, chip_y)
    if badged then
        tile.badge = add(tile, badge(ctx), badge_x, badge_y)
    end
end

-- A book's tile for record ({ path, title, authors }) at progress (Books.progress's { status,
-- percent }) in box, a LibraryTiles.geometry: its cover or placeholder, the strip when the book
-- has a file and a percent and is neither new nor complete, its title in one line, and for a
-- record with no path the download badge and the Not downloaded chip on the cover. chip, optional,
-- is { label }, a chip drawn on the cover's foot in Not downloaded's place, which it replaces on a
-- path-less record while the badge stays (the one-author grid's "Up next", series-and-authors D5,
-- D19). The tile keeps cover, strip, title, badge and chip, the last three nil where not drawn.
function LibraryTiles.book(record, progress, box, ctx, chip_spec)
    ctx = fixed(ctx)
    local look = ctx.look
    local tile = new_tile(box)
    tile.cover = add(tile, FeaturedCover.framed(record, box.cover_w, box.cover_h, ctx, cover_frame(look)), 0, 0)
    if record.path and progress.percent and progress.status ~= "new" and progress.status ~= "complete" then
        local outline_width = look.library.strip.outline_width
        local outline = colorer(ctx)(look.progress.outline_color) and scaler(ctx)(outline_width) or 0
        tile.strip = add(tile, Featured.bar(Featured.shown_percent(progress), box.cover_w, box.strip_h - 2 * outline,
            outline_width, ctx), 0, box.strip_y)
    end
    tile.title = add(tile, Typeset.line(look.type.tile_title, record.title or "", box.cover_w, ctx), 0, box.title_y)
    if chip_spec or not record.path then
        foot(tile, box, ctx, not record.path, chip_spec and chip_spec.label)
    end
    return tile
end

-- A folder's book count in words: "No books", "1 book", "14 books"; the folder sheet's meta reads
-- it so (context-menu D12).
local function books_text(n)
    if n == 0 then
        return "No books"
    elseif n == 1 then
        return "1 book"
    end
    return n .. " books"
end
LibraryTiles.books_text = books_text

-- A folder's tile for folder ({ name, path }) with counts ({ books, reading }, the books directly
-- in it and how many of them are reading) in box: the cover box filled in folder.fill_color with
-- its edge and the cover's shadow and radius, the folder icon at its top, the book count and the
-- reading count, when not zero, at its foot, then the strip's empty slot and the folder's name in
-- the title's place. The tile keeps cover and title.
function LibraryTiles.folder(folder, counts, box, ctx)
    ctx = fixed(ctx)
    local scale, color = scaler(ctx), colorer(ctx)
    local look = ctx.look
    local tokens = look.library.folder
    local shadow = look.library.cover.shadow
    local radius = scale(look.library.cover.radius)
    local outline_color = color(tokens.outline_color)
    local outline = outline_color and scale(tokens.outline_width) or 0
    local shadow_x, shadow_y = scale(shadow.x), scale(shadow.y)
    local art = FeaturedCover.Box:new{
        name = "kopanda_library_folder",
        dimen = Geom:new{ w = box.cover_w + shadow_x, h = box.cover_h + shadow_y },
        box_w = box.cover_w,
        box_h = box.cover_h,
        shadow_color = color(shadow.color),
        shadow_x = shadow_x,
        shadow_y = shadow_y,
        fill_color = color(tokens.fill_color),
        fill_radius = radius,
        outline = outline,
        outline_color = outline_color,
        radius = radius,
        places = {},
    }
    local pad_x, pad_y = outline + scale(tokens.padding.x), outline + scale(tokens.padding.y)
    local inner_w = box.cover_w - 2 * pad_x
    add(art, TintedIcon:new{
        file = Icons.path("folder"),
        size = scale(tokens.icon_size),
        color = color(tokens.icon_color),
    }, pad_x, pad_y)
    local lines = { Typeset.line(look.type.folder_count, books_text(counts.books or 0), inner_w, ctx) }
    if counts.reading and counts.reading > 0 then
        lines[2] = Typeset.line(look.type.folder_reading, counts.reading .. " reading", inner_w, ctx)
    end
    local y = box.cover_h - pad_y
    for i = #lines, 1, -1 do
        y = y - lines[i]:getSize().h
        add(art, lines[i], pad_x, y)
        y = y - scale(tokens.count_gap)
    end
    local tile = new_tile(box)
    tile.cover = add(tile, art, 0, 0)
    tile.title = add(tile, Typeset.line(look.type.tile_title, folder.name or "", box.cover_w, ctx), 0, box.title_y)
    return tile
end

return LibraryTiles
