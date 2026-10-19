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
local Helpers = require("helpers")
local Icons = require("icons")
local Layout = require("layout")
local Looks = require("looks")
local Paint = require("paint")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")

local LibraryTiles = {}

local COLUMNS = 3

-- The tile: its children painted at their places from its top left, in order, so the badge and
-- the chip come after the cover they sit on.
local Tile = FeaturedCover.Box:extend{
    name = "kopanda_library_tile",
}

local function add(box, child, x, y)
    box[#box + 1] = child
    box.places[#box.places + 1] = { x = x, y = y }
    return child
end

-- ctx without its text size (D12).
local function fixed(ctx)
    return { look = ctx.look, variant = ctx.variant, screen = ctx.screen }
end

-- The grid across a screen screen_w wide under ctx, in device pixels: columns, three { x, w } from
-- the screen's left edge inside grid.side at grid.column_gap (Layout.columns), the cover box's
-- cover_w (the narrowest column's width) and cover_h, the strip's strip_y and strip_h and the
-- title's title_y from a tile's top, and height, the tile's: cover, strip gap, strip, title gap
-- and one tile_title line. cover_h, in board pixels, is the cover box's height where it is not the
-- grid's, as the one-author grid's (shelf.author_grid.cover_h). Raises when the title's face won't load.
function LibraryTiles.geometry(screen_w, ctx, cover_h)
    ctx = fixed(ctx)
    local scale = Paint.scaler(ctx)
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
        height = title_y + Typeset.line_height(ctx.look.type.tile_title, ctx),
    }
end

-- The header's height under ctx, in device pixels: its padding, the taller of the count over the
-- title and a picker (its label line inside its padding and outline; the picker's mark is drawn
-- no taller than its line), and its edge.
function LibraryTiles.header_height(ctx)
    ctx = fixed(ctx)
    local scale = Paint.scaler(ctx)
    local look = ctx.look
    local header = look.library.header
    local text = Typeset.line_height(look.type.library_count, ctx) + scale(header.line_gap)
        + Typeset.line_height(look.type.library_title, ctx)
    local picker = Typeset.line_height(look.type.library_picker, ctx)
        + 2 * (scale(header.picker_padding.y) + scale(header.picker_outline_width))
    return scale(header.padding.top) + math.max(text, picker) + scale(header.padding.bottom)
        + scale(header.edge_width)
end

-- The pager's height under ctx, in device pixels: the taller of a button and the page label, and
-- the space under it.
function LibraryTiles.pager_height(ctx)
    ctx = fixed(ctx)
    local scale = Paint.scaler(ctx)
    local look = ctx.look
    local pager = look.library.pager
    return math.max(scale(pager.button_h), Typeset.line_height(look.type.pager_label, ctx)) + scale(pager.bottom)
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
    local scale, color = Paint.scaler(ctx), Looks.colorer(ctx)
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

-- A chip on the cover's foot, at most max_w wide: text in part inside the library's not_downloaded
-- padding and outline colour at outline_width (board pixels), on fill_color. "Up next" takes the
-- shelf's up_next fill and outline width (series-and-authors D5).
local function chip(text, part, fill_color, outline_width, max_w, ctx)
    local scale, color = Paint.scaler(ctx), Looks.colorer(ctx)
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

-- Where the badge sits in a tile in box under ctx: its x and y from the tile's top left at the
-- corner badge.align names (the right one, top or bottom), inset from the cover's outline
-- (negative: overhanging), its size, the outline's width and whether it is on the cover's foot.
local function badge_place(box, ctx)
    local scale, color = Paint.scaler(ctx), Looks.colorer(ctx)
    local library = ctx.look.library
    local tokens = library.badge
    local edge = color(library.cover.outline_color) and scale(library.cover.outline_width) or 0
    local size = scale(tokens.size)
    local inset = Paint.scale_signed(scale, tokens.inset)
    local on_foot = tokens.align == "bottom"
    return {
        x = box.cover_w - edge - inset - size,
        y = on_foot and box.cover_h - edge - inset - size or edge + inset,
        size = size,
        edge = edge,
        on_foot = on_foot,
    }
end

-- Adds the caller's label, "Up next" (series-and-authors D19), as a chip on the cover's foot when
-- given, and for a book not downloaded (badged) the badge at its place (badge_place), its one sign
-- (tweaks/badge-only-not-downloaded). The chip sits left of the badge's place: beside it where both
-- are on the foot, at the placeholder's padding where the badge is on top.
local function foot(tile, box, ctx, badged, label)
    local scale = Paint.scaler(ctx)
    local look = ctx.look
    local library = look.library
    local place = badge_place(box, ctx)
    local size, edge, on_foot = place.size, place.edge, place.on_foot
    local badge_x, badge_y = place.x, place.y
    local pad = library.cover.padding
    local chip_x = edge + scale(pad.x)
    local room = on_foot and badge_x - scale(library.not_downloaded.padding.x) - chip_x or box.cover_w - 2 * chip_x
    if label then
        local up_next = look.shelf.up_next
        local the_chip = chip(label, look.type.shelf_chip_plain, up_next.fill_color, up_next.outline_width, room, ctx)
        local chip_h = the_chip:getSize().h
        local chip_y = on_foot and badge_y + math.floor((size - chip_h) / 2)
            or box.cover_h - edge - scale(pad.y) - chip_h
        tile.chip = add(tile, the_chip, chip_x, chip_y)
    end
    if badged then
        tile.badge = add(tile, badge(ctx), badge_x, badge_y)
    end
end

-- How far past its box a book's tile in box paints under ctx, in device pixels: { top, right,
-- bottom }, none on the left. The cover's shadow reaches right and below, the download badge
-- past the corner it overhangs (badge_place). Counts both whether the tile draws them or not.
function LibraryTiles.overhang(box, ctx)
    ctx = fixed(ctx)
    local shadow = ctx.look.library.cover.shadow
    local scale = Paint.scaler(ctx)
    local place = badge_place(box, ctx)
    return {
        top = math.max(0, -place.y),
        right = math.max(0, scale(shadow.x), place.x + place.size - box.cover_w),
        bottom = math.max(0, box.cover_h + scale(shadow.y) - box.height, place.y + place.size - box.height),
    }
end

-- A book's tile for record ({ path, title, authors }) at progress (Books.progress's { status,
-- percent }) in box, a LibraryTiles.geometry: its cover or placeholder, the strip when the book
-- has a file and a percent and is neither new nor complete, its title in one line, and for a book
-- not downloaded (a record with no path, or cwngsync's placeholder, cwng-placeholders D1) the
-- download badge on the cover, its one sign (tweaks/badge-only-not-downloaded). chip, optional, is
-- { label }, a chip drawn on the cover's foot, beside the badge on a book not downloaded (the
-- one-author grid's "Up next", series-and-authors D5, D19). The tile keeps cover, strip, title,
-- badge and chip, the last three nil where not drawn.
function LibraryTiles.book(record, progress, box, ctx, chip_spec)
    ctx = fixed(ctx)
    local look = ctx.look
    local tile = new_tile(box)
    tile.cover = add(tile, FeaturedCover.framed(record, box.cover_w, box.cover_h, ctx, cover_frame(look)), 0, 0)
    if record.path and progress.percent and progress.status ~= "new" and progress.status ~= "complete" then
        local outline_width = look.library.strip.outline_width
        local outline = Looks.colorer(ctx)(look.progress.outline_color) and Paint.scaler(ctx)(outline_width) or 0
        tile.strip = add(tile, Featured.bar(Featured.shown_percent(progress), box.cover_w, box.strip_h - 2 * outline,
            outline_width, ctx), 0, box.strip_y)
    end
    tile.title = add(tile, Typeset.line(look.type.tile_title, record.title or "", box.cover_w, ctx), 0, box.title_y)
    local not_downloaded = not record.path or record.placeholder == true
    if chip_spec or not_downloaded then
        foot(tile, box, ctx, not_downloaded, chip_spec and chip_spec.label)
    end
    return tile
end


-- A folder's tile for folder ({ name, path }) with counts ({ books, reading }, the books directly
-- in it and how many of them are reading) in box: the cover box filled in folder.fill_color with
-- its edge and the cover's shadow and radius, the folder icon at its top, the book count and the
-- reading count, when not zero, at its foot, then the strip's empty slot and the folder's name in
-- the title's place. The tile keeps cover and title.
function LibraryTiles.folder(folder, counts, box, ctx)
    ctx = fixed(ctx)
    local scale, color = Paint.scaler(ctx), Looks.colorer(ctx)
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
        shadow_outline = shadow.outline_width and scale(shadow.outline_width) or nil,
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
    local lines = { Typeset.line(look.type.folder_count, Helpers.count_text(counts.books or 0), inner_w, ctx) }
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
