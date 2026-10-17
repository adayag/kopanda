-- The series and authors screens' rows: a series row (its stacked covers, name, sub-line and state
-- chip), a one-series book row (its index, cover, title, bar or note, and chip) and an author letter
-- group (the letter column beside its authors' rows), from the look's shelf tokens (SeriesC.dc.html,
-- SeriesBooksC.dc.html, AuthorsC.dc.html under .tiller/design/2026-10-16-kopanda-library-screens/;
-- series-and-authors D3, D15, D19 to D22). Lengths are board pixels, scaled by ctx.screen. The rows'
-- text does not follow text_size (D22), so every line is set in a ctx without one, as the library's
-- tiles are.
--
-- Each widget is its width and a fixed height for its kind, whatever it holds, so the screens page
-- by ShelfRows.height without building a page. What reaches past a row's box, its shadow and
-- Diner's overhanging badge, is painted past it into the gaps.
local BookCovers = require("book_covers")
local CenterContainer = require("ui/widget/container/centercontainer")
local Featured = require("widgets/featured")
local FeaturedCover = require("featured_cover")
local Geom = require("ui/geometry")
local Icons = require("icons")
local ImageWidget = require("ui/widget/imagewidget")
local Looks = require("looks")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")

local ShelfRows = {}

-- A series row stacks the first three books' covers (D21).
local STACK = 3
-- A line's height is its face's or its forced one, whatever its text, so one sample measures every
-- line of a part (frontend/ui/widget/textwidget.lua:112-113, :292-299).
local SAMPLE = "Library"

-- A row, a group or a stack: its children painted at their places from its top left, in order,
-- inside its shadow, fill and outline (FeaturedCover.Box).
local Box = FeaturedCover.Box:extend{
    name = "kopanda_shelf_row",
}

-- Where child is painted, from the box's top left, or nil for a widget the box doesn't hold.
function Box:place(child)
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

-- ctx without its text size (D22).
local function fixed(ctx)
    return { look = ctx.look, variant = ctx.variant, screen = ctx.screen }
end

local function scaler(ctx)
    return function(px)
        return ctx.screen:scaleBySize(px)
    end
end

-- A negative length, an overhang, scaled as its size is.
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

-- A stroke width in board pixels where its colour role is drawn, else 0, in device pixels.
local function stroke(width, role, ctx)
    return colorer(ctx)(role) and scaler(ctx)(width) or 0
end

local function new_box(w, h, fields)
    local box = Box:new{
        dimen = Geom:new{ w = w, h = h },
        box_w = w,
        box_h = h,
        outline = 0,
        places = {},
    }
    for k, v in pairs(fields or {}) do
        box[k] = v
    end
    return box
end

-- A plain rectangle of color, for rules and the letter column.
local function rect(w, h, color)
    return new_box(w, h, { fill_color = color })
end

-- A row's box, w by h: fill_role's fill, the tile's outline at outline_width and the tile's shadow at
-- shadow ({ x, y } board pixels), Diner's "filled box with an outline and a hard shadow".
local function row_box(w, h, fill_role, outline_width, shadow, ctx)
    local look = ctx.look
    local scale, color = scaler(ctx), colorer(ctx)
    local shadow_x, shadow_y = scale(shadow.x), scale(shadow.y)
    local shadow_color = (shadow_x > 0 or shadow_y > 0) and color(look.shadow.tile.color) or nil
    return new_box(w, h, {
        fill_color = color(fill_role),
        outline = stroke(outline_width, look.tile.outline_color, ctx),
        outline_color = color(look.tile.outline_color),
        shadow_color = shadow_color,
        shadow_x = shadow_x,
        shadow_y = shadow_y,
    })
end

-- The row frame's lengths in device pixels: outline, padding, the column gap and the rule below.
local function frame(ctx)
    local scale = scaler(ctx)
    local look = ctx.look
    local row = look.shelf.row
    return {
        outline = stroke(row.outline_width, look.tile.outline_color, ctx),
        pad_x = scale(row.padding.x),
        pad_y = scale(row.padding.y),
        gap = scale(row.gap),
        rule = stroke(row.rule_width, row.rule_color, ctx),
    }
end

-- The row's rule along its foot, where the look rules its rows.
local function add_rule(box, w, h, rule, role, ctx)
    if rule > 0 then
        add(box, rect(w, rule, colorer(ctx)(role)), 0, h - rule)
    end
end

-- A small cover w by h for record (D21): its cached cover fitted inside the outline, or a plain
-- cover-role fill with no lettering, outlined at outline_width in outline_role, the library's
-- cover radius. Reads the cover through BookCovers.read, the bitmap freed with the widget.
local function small_cover(record, w, h, outline_width, outline_role, ctx)
    local scale, color = scaler(ctx), colorer(ctx)
    local radius = scale(ctx.look.library.cover.radius)
    local outline = stroke(outline_width, outline_role, ctx)
    local box = new_box(w, h, { outline = outline, outline_color = color(outline_role), radius = radius })
    local cover_bb = BookCovers.read(record, w, h)
    if cover_bb then
        local inner_w, inner_h = w - 2 * outline, h - 2 * outline
        box.fill_color = color("paper")
        box.fill_radius = 0
        add(box, CenterContainer:new{
            dimen = Geom:new{ w = inner_w, h = inner_h },
            ImageWidget:new{ image = cover_bb, width = inner_w, height = inner_h, scale_factor = 0 },
        }, outline, outline)
    else
        box.fill_color = color("cover")
        box.fill_radius = radius
    end
    return box
end

-- The chips by kind: the fill token and the part, shelf_chip_plain for the chips on paper
-- (SeriesC.dc.html:88, SeriesBooksC.dc.html:49) and shelf_chip for those on a fill.
local CHIPS = {
    under_way = { fill = "under_way_fill_color", part = "shelf_chip" },
    finished = { fill = "finished_fill_color", part = "shelf_chip" },
    not_started = { fill = "not_started_fill_color", part = "shelf_chip_plain" },
    up_next = { fill = "up_next_fill_color", part = "shelf_chip_plain" },
    not_downloaded = { fill = "not_downloaded_fill_color", part = "shelf_chip" },
}

local function chip_pads(ctx)
    local scale = scaler(ctx)
    local tokens = ctx.look.shelf.chip
    local outline = stroke(tokens.outline_width, ctx.look.chip.outline_color, ctx)
    return outline, outline + scale(tokens.padding.x), outline + scale(tokens.padding.y)
end

-- A chip's height: the taller of its two parts' lines inside its padding and outline.
local function chip_height(ctx)
    local types = ctx.look.type
    local _, _, pad_y = chip_pads(ctx)
    return math.max(line_height(types.shelf_chip, ctx), line_height(types.shelf_chip_plain, ctx)) + 2 * pad_y
end

-- text in kind's chip, at most max_w wide: its line inside the chip's padding and the chip's
-- outline, on kind's fill.
local function chip(kind, text, max_w, ctx)
    local color = colorer(ctx)
    local look = ctx.look
    local spec = CHIPS[kind]
    local outline, pad_x, pad_y = chip_pads(ctx)
    local line = Typeset.line(look.type[spec.part], text, math.max(1, max_w - 2 * pad_x), ctx)
    local w = line:getSize().w + 2 * pad_x
    local box = new_box(w, chip_height(ctx), {
        fill_color = color(look.shelf.chip[spec.fill]),
        outline = outline,
        outline_color = color(look.chip.outline_color),
    })
    add(box, line, pad_x, pad_y)
    return box
end

-- The stack's lengths in device pixels: a cover's w and h, the offsets, and the stack's own size,
-- the room three covers take.
local function stack_metrics(ctx)
    local scale = scaler(ctx)
    local tokens = ctx.look.shelf.stack
    local w, h = scale(tokens.cover_w), scale(tokens.cover_h)
    local ox, oy = scale(tokens.offset_x), scale(tokens.offset_y)
    return w, h, ox, oy, w + (STACK - 1) * ox, h + (STACK - 1) * oy
end

-- The first covers of books, at most three, the first in front: each one offset_x right of and
-- offset_y above the one before it, so the first is left-most and lowest (SeriesC.dc.html:29-33).
-- Returns the stack and its covers, first first.
local function stack(books, ctx)
    local tokens = ctx.look.shelf.stack
    local w, h, ox, oy, stack_w, stack_h = stack_metrics(ctx)
    local box = new_box(stack_w, stack_h)
    local covers = {}
    for i = math.min(STACK, #books), 1, -1 do
        covers[i] = small_cover(books[i], w, h, tokens.outline_width, tokens.outline_color, ctx)
        add(box, covers[i], (i - 1) * ox, (STACK - i) * oy)
    end
    return box, covers
end

local function books_text(n)
    if n == 1 then
        return "1 book"
    end
    return n .. " books"
end

-- D15's sub-line: the author, " and others" when another first author is in the series, then
-- "next: <title>" while under way with a next unread, else the series' book count.
local function sub_line(entry)
    local parts = {}
    if entry.author then
        parts[1] = entry.others and entry.author .. " and others" or entry.author
    end
    if entry.state == "under_way" and entry.next then
        parts[#parts + 1] = "next: " .. (entry.next.title or "")
    else
        parts[#parts + 1] = books_text(entry.total or #entry.books)
    end
    return table.concat(parts, " · ")
end

local SERIES_CHIPS = {
    finished = { kind = "finished", text = "Finished" },
    not_started = { kind = "not_started", text = "Not started" },
}

local function series_content_h(ctx)
    local look = ctx.look
    local _, _, _, _, _, stack_h = stack_metrics(ctx)
    local text = line_height(look.type.series_name, ctx) + scaler(ctx)(look.shelf.row.line_gap)
        + line_height(look.type.series_sub, ctx)
    return math.max(stack_h, text, chip_height(ctx))
end

-- The series list's row for entry (ShelfOrder.series's { name, books, state, complete, total, next,
-- author, others }), width wide (SeriesC.dc.html:28-40): the stack, the name and D15's sub-line each
-- in one line cut with an ellipsis, and the state's chip, "N of M" under way (D3). The row keeps
-- stack, covers (first first), name, sub and chip.
function ShelfRows.series(entry, width, ctx)
    ctx = fixed(ctx)
    local look = ctx.look
    local f = frame(ctx)
    local content_h = series_content_h(ctx)
    local h = 2 * (f.outline + f.pad_y) + content_h + f.rule
    local row = row_box(width, h, look.tile.fill_color, look.shelf.row.outline_width, look.shelf.row.shadow, ctx)
    local x0, y0 = f.outline + f.pad_x, f.outline + f.pad_y
    local right = width - f.outline - f.pad_x

    local the_stack, covers = stack(entry.books or {}, ctx)
    local stack_size = the_stack:getSize()
    row.stack = add(row, the_stack, x0, y0 + math.floor((content_h - stack_size.h) / 2))
    row.covers = covers

    local spec = SERIES_CHIPS[entry.state] or { kind = "under_way",
        text = (entry.complete or 0) .. " of " .. (entry.total or #(entry.books or {})) }
    local text_x = x0 + stack_size.w + f.gap
    local the_chip = chip(spec.kind, spec.text, math.max(1, right - text_x), ctx)
    local chip_size = the_chip:getSize()
    local chip_x = right - chip_size.w

    local text_w = math.max(1, chip_x - f.gap - text_x)
    row.name = Typeset.line(look.type.series_name, entry.name or "", text_w, ctx)
    row.sub = Typeset.line(look.type.series_sub, sub_line(entry), text_w, ctx)
    local name_h, line_gap = row.name:getSize().h, scaler(ctx)(look.shelf.row.line_gap)
    local text_y = y0 + math.floor((content_h - (name_h + line_gap + row.sub:getSize().h)) / 2)
    add(row, row.name, text_x, text_y)
    add(row, row.sub, text_x, text_y + name_h + line_gap)
    row.chip = add(row, the_chip, chip_x, y0 + math.floor((content_h - chip_size.h) / 2))
    add_rule(row, width, h, f.rule, look.shelf.row.rule_color, ctx)
    return row
end

-- The one-series list's lengths in device pixels: the bar's height with its outline.
local function bar_height(ctx)
    local look = ctx.look
    local book = look.shelf.book
    return scaler(ctx)(book.bar_height) + 2 * stroke(book.bar_outline_width, look.progress.outline_color, ctx)
end

local function book_content_h(ctx)
    local look = ctx.look
    local shelf, types = look.shelf, look.type
    local scale = scaler(ctx)
    local second = math.max(bar_height(ctx), line_height(types.book_next_note, ctx),
        line_height(types.book_row_note, ctx))
    local text = line_height(types.book_row_title, ctx) + math.max(scale(shelf.book.line_gap),
        scale(shelf.next.line_gap)) + second
    return math.max(line_height(types.book_index, ctx), scale(shelf.book.cover_h), text, chip_height(ctx))
end

-- D20's index: a whole series_index without decimals, any other as Lua writes it.
local function index_text(index)
    if index == math.floor(index) then
        return string.format("%d", index)
    end
    return tostring(index)
end

-- The download badge on a book row's cover: a circle of badge_size in the library badge's fill with
-- its outline, the download icon centred in it.
local function badge(ctx)
    local scale, color = scaler(ctx), colorer(ctx)
    local look = ctx.look
    local book, colours = look.shelf.book, look.library.badge
    local size = scale(book.badge_size)
    local radius = math.floor(size / 2)
    local icon = TintedIcon:new{
        file = Icons.path("download"),
        size = scale(book.badge_icon_size),
        color = color(colours.icon_color),
    }
    local offset = math.floor((size - icon.size) / 2)
    local box = new_box(size, size, {
        fill_color = color(colours.fill_color),
        fill_radius = radius,
        outline = stroke(book.badge_outline_width, colours.outline_color, ctx),
        outline_color = color(colours.outline_color),
        radius = radius,
    })
    add(box, icon, offset, offset)
    return box
end

-- D20's chip for a book: Finished, else Not downloaded for a path-less book (D19), else Up next.
local function book_chip(record, progress, marked)
    if progress.status == "complete" then
        return "finished", "Finished"
    elseif not record.path then
        return "not_downloaded", "Not downloaded"
    elseif marked then
        return "up_next", "Up next"
    end
    return nil
end

-- The one-series list's row for record at progress (Books.progress's { status, percent }), marked
-- when mark says it is the series' next unread, width wide (SeriesBooksC.dc.html:33-63, D20): the
-- index column (blank for a book with no series_index), the cover with the download badge on a
-- path-less book's, the title in one line, then the bar (full for complete, at its percent for
-- reading or abandoned), "read this one next" for the marked book, "Not on the Kindle yet" for a
-- path-less one, or nothing, and the chip. The marked row takes shelf.next's fill, shadow and text
-- colour. The row keeps index, cover, badge, title, bar, note, chip (nil where not drawn) and marked.
function ShelfRows.book(record, progress, mark, width, ctx)
    ctx = fixed(ctx)
    local scale = scaler(ctx)
    local look = ctx.look
    local shelf = look.shelf
    local marked = mark and true or false
    local f = frame(ctx)
    local content_h = book_content_h(ctx)
    local h = 2 * (f.outline + f.pad_y) + content_h + f.rule
    local fill = marked and shelf.next.fill_color or look.tile.fill_color
    local row = row_box(width, h, fill, shelf.row.outline_width,
        marked and shelf.next.shadow or shelf.row.shadow, ctx)
    row.marked = marked
    local x0, y0 = f.outline + f.pad_x, f.outline + f.pad_y
    local right = width - f.outline - f.pad_x
    -- The marked row's text in copies of the look's parts set in shelf.next.text_color.
    local function part(name)
        local base = look.type[name]
        if not marked then
            return base
        end
        local copy = {}
        for k, v in pairs(base) do
            copy[k] = v
        end
        copy.color = shelf.next.text_color
        return copy
    end
    local function middle(item_h)
        return y0 + math.floor((content_h - item_h) / 2)
    end

    local index_w = scale(shelf.book.index_w)
    if record.series_index then
        row.index = Typeset.line(part("book_index"), index_text(record.series_index), index_w, ctx)
        local size = row.index:getSize()
        add(row, row.index, x0 + math.floor((index_w - size.w) / 2), middle(size.h))
    end

    local cover_w, cover_h = scale(shelf.book.cover_w), scale(shelf.book.cover_h)
    local cover_x, cover_y = x0 + index_w + f.gap, middle(cover_h)
    row.cover = add(row, small_cover(record, cover_w, cover_h, shelf.book.cover_outline_width,
        look.library.cover.outline_color, ctx), cover_x, cover_y)

    local text_x = cover_x + cover_w + f.gap
    local text_right = right
    local kind, label = book_chip(record, progress, marked)
    if kind then
        row.chip = chip(kind, label, math.max(1, right - text_x), ctx)
        local size = row.chip:getSize()
        text_right = right - size.w - f.gap
        add(row, row.chip, right - size.w, middle(size.h))
    end

    local text_w = math.max(1, text_right - text_x)
    row.title = Typeset.line(part("book_row_title"), record.title or "", text_w, ctx)
    local second
    local status = progress.status
    if status == "complete" or ((status == "reading" or status == "abandoned") and progress.percent) then
        row.bar = Featured.bar(Featured.shown_percent(progress), text_w, scale(shelf.book.bar_height),
            shelf.book.bar_outline_width, ctx)
        second = row.bar
    elseif marked then
        row.note = Typeset.line(part("book_next_note"), "read this one next", text_w, ctx)
        second = row.note
    elseif not record.path then
        row.note = Typeset.line(part("book_row_note"), "Not on the Kindle yet", text_w, ctx)
        second = row.note
    end
    local title_h = row.title:getSize().h
    local line_gap = scale(marked and shelf.next.line_gap or shelf.book.line_gap)
    local block_h = second and title_h + line_gap + second:getSize().h or title_h
    local text_y = middle(block_h)
    add(row, row.title, text_x, text_y)
    if second then
        add(row, second, text_x, text_y + title_h + line_gap)
    end

    if not record.path then
        local edge = stroke(shelf.book.cover_outline_width, look.library.cover.outline_color, ctx)
        local inset = scale_signed(scale, shelf.book.badge_inset)
        local size = scale(shelf.book.badge_size)
        local badge_y = look.library.badge.align == "bottom" and cover_y + cover_h - edge - inset - size
            or cover_y + edge + inset
        row.badge = add(row, badge(ctx), cover_x + cover_w - edge - inset - size, badge_y)
    end
    add_rule(row, width, h, f.rule, shelf.row.rule_color, ctx)
    return row
end

-- An author group's lengths in device pixels: its outline, letter column and rule, its rows' padding,
-- the rule between rows and the group's rule.
local function group_frame(ctx)
    local scale = scaler(ctx)
    local look = ctx.look
    local shelf = look.shelf
    return {
        outline = stroke(shelf.group.outline_width, look.tile.outline_color, ctx),
        letter_w = scale(shelf.group.letter_w),
        letter_rule = stroke(shelf.group.letter_rule_width, look.tile.outline_color, ctx),
        pad_x = scale(shelf.author.padding.x),
        pad_y = scale(shelf.author.padding.y),
        author_rule = stroke(shelf.author.rule_width, shelf.author.rule_color, ctx),
        group_rule = stroke(shelf.group.rule_width, shelf.group.rule_color, ctx),
    }
end

local function author_row_h(ctx)
    local types = ctx.look.type
    local g = group_frame(ctx)
    return 2 * g.pad_y + math.max(line_height(types.author_name, ctx), line_height(types.author_count, ctx))
        + g.author_rule
end

local function count_text(n)
    return books_text(n) .. " ›"
end

-- The authors list's letter group, width wide (AuthorsC.dc.html:28-75): the letter column (its fill
-- and rule) beside one row per author of authors (ShelfOrder.authors's entries { name, count }), the
-- name in one line cut with an ellipsis and "N books ›" or "1 book ›" at the right, a rule between
-- rows, inside the group's outline and shadow or over its rule. repeats marks a group continued from
-- the page before, drawn with its letter again (D14). The group keeps letter, repeats and rows, each
-- { entry, name, count, y, h }: its band from the group's top, the last without the rule below it.
function ShelfRows.group(letter, authors, repeats, width, ctx)
    ctx = fixed(ctx)
    local look = ctx.look
    local shelf = look.shelf
    local color = colorer(ctx)
    local g = group_frame(ctx)
    local row_h = author_row_h(ctx)
    local h = 2 * g.outline + #authors * row_h - g.author_rule + g.group_rule
    local group = row_box(width, h, look.tile.fill_color, shelf.group.outline_width, shelf.group.shadow, ctx)
    group.repeats = repeats and true or false
    local inner_h = h - 2 * g.outline - g.group_rule

    local letter_fill = color(shelf.group.letter_fill_color)
    if letter_fill then
        add(group, rect(g.letter_w, inner_h, letter_fill), g.outline, g.outline)
    end
    if g.letter_rule > 0 then
        add(group, rect(g.letter_rule, inner_h, color(look.tile.outline_color)), g.outline + g.letter_w, g.outline)
    end
    group.letter = Typeset.line(look.type.author_letter, letter or "", g.letter_w, ctx)
    local letter_size = group.letter:getSize()
    add(group, group.letter, g.outline + math.floor((g.letter_w - letter_size.w) / 2),
        g.outline + math.floor((inner_h - letter_size.h) / 2))

    local rows_x = g.outline + g.letter_w + g.letter_rule
    local rows_w = width - g.outline - rows_x
    local text_h = row_h - g.author_rule - 2 * g.pad_y
    group.rows = {}
    for i, author in ipairs(authors) do
        local y = g.outline + (i - 1) * row_h
        local last = i == #authors
        local count = Typeset.line(look.type.author_count, count_text(author.count or 0),
            math.max(1, rows_w - 2 * g.pad_x), ctx)
        local count_size = count:getSize()
        local count_x = rows_x + rows_w - g.pad_x - count_size.w
        local name = Typeset.line(look.type.author_name, author.name or "",
            math.max(1, count_x - g.pad_x - (rows_x + g.pad_x)), ctx)
        local name_h = name:getSize().h
        add(group, name, rows_x + g.pad_x, y + g.pad_y + math.floor((text_h - name_h) / 2))
        add(group, count, count_x, y + g.pad_y + math.floor((text_h - count_size.h) / 2))
        if not last and g.author_rule > 0 then
            add(group, rect(rows_w, g.author_rule, color(shelf.author.rule_color)), rows_x, y + row_h - g.author_rule)
        end
        group.rows[i] = { entry = author, name = name, count = count, y = y,
            h = last and row_h - g.author_rule or row_h }
    end
    if g.group_rule > 0 then
        add(group, rect(width, g.group_rule, color(shelf.group.rule_color)), 0, h - g.group_rule)
    end
    return group
end

-- A row's height for kind under ctx, width wide, in device pixels: "series" and "book" a whole row,
-- "author" one author's row in a group, the rule below it included. A group of n authors is
-- n × height("author") + group_cost less the groups' gap.
function ShelfRows.height(kind, width, ctx)
    ctx = fixed(ctx)
    if kind == "author" then
        return author_row_h(ctx)
    end
    local f = frame(ctx)
    local content_h = kind == "series" and series_content_h(ctx) or book_content_h(ctx)
    return 2 * (f.outline + f.pad_y) + content_h + f.rule
end

-- What a letter group adds to its authors' rows on a page, in device pixels: its outline at top and
-- bottom and its rule, less the rule its last row has none of, and the gap after it.
function ShelfRows.group_cost(width, ctx)
    ctx = fixed(ctx)
    local g = group_frame(ctx)
    return 2 * g.outline - g.author_rule + g.group_rule + scaler(ctx)(ctx.look.shelf.groups.gap)
end

return ShelfRows
