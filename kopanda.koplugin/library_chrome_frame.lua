-- The drawing the library's windows share, stateless: the box its parts sit in, the tools of a build, the header frame
-- with its back control and chips, the pager, the foot and the build that fills a window at the screen's size.
-- library_chrome.lua re-exports what the windows call. It patches nothing of KOReader's.
local Device = require("device")
local FeaturedCover = require("featured_cover")
local Geom = require("ui/geometry")
local Icons = require("icons")
local Layout = require("layout")
local LibraryTiles = require("library_tiles")
local Looks = require("looks")
local NavBar = require("nav_bar")
local Paint = require("paint")
local Settings = require("settings")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local Screen = Device.screen

local ChromeFrame = {}

-- A box w by h in fill (a colour or nil) with an outline wide in outline_color, its children
-- painted at their places.
function ChromeFrame.box(w, h, fill, outline, outline_color)
    return FeaturedCover.Box:new{
        dimen = Geom:new{ w = w, h = h },
        box_w = w,
        box_h = h,
        fill_color = fill,
        outline = outline or 0,
        outline_color = outline_color,
        places = {},
    }
end

-- Adds child to box at (x, y) from its top left; returns its index.
function ChromeFrame.add(box, child, x, y)
    box[#box + 1] = child
    box.places[#box] = { x = x, y = y }
    return #box
end

local new_box, add = ChromeFrame.box, ChromeFrame.add

-- The tools a build draws with under ctx: lengths scaled, roles as colours (nil for a role the
-- look lacks), and a part's line height, which is its face's whatever the text
-- (frontend/ui/widget/textwidget.lua:112-113).
function ChromeFrame.tools(ctx)
    local function scale(px)
        return Screen:scaleBySize(px)
    end
    local function line_height(part)
        return Typeset.line_height(part, ctx)
    end
    return scale, Looks.colorer(ctx), line_height
end

local tools = ChromeFrame.tools

-- The detail header's back control under ctx: its outline and its height, the taller of its icon and its
-- label inside its padding and outline.
local function back_metrics(ctx)
    local scale, _, line_height = tools(ctx)
    local back = ctx.look.shelf.back
    local outline = scale(back.outline_width)
    return outline, math.max(scale(back.icon_size), line_height(ctx.look.type.shelf_back))
        + 2 * (scale(back.padding.y) + outline)
end

-- The one-series and one-author header's height under ctx: the detail padding, the back control,
-- the back gap, the count over the detail title at the header's line gap, and the edge.
function ChromeFrame.detail_header_height(ctx)
    local scale, _, line_height = tools(ctx)
    local look = ctx.look
    local detail, header = look.shelf.detail, look.library.header
    local _, back_h = back_metrics(ctx)
    return scale(detail.padding.top) + back_h + scale(detail.back_gap) + line_height(look.type.library_count)
        + scale(header.line_gap) + line_height(look.type.shelf_detail_title) + scale(detail.padding.bottom)
        + scale(header.edge_width)
end

-- The detail header's back control to text: the back icon and text in shelf_back inside shelf.back's
-- padding and outline on its fill, a chip in Diner, a plain link in Editorial. Returns it and its label.
local function back_control(ctx, text)
    local scale, color = tools(ctx)
    local look = ctx.look
    local back, part = look.shelf.back, look.type.shelf_back
    local outline, h = back_metrics(ctx)
    local label = Typeset.line(part, text, Screen:getWidth(), ctx)
    local icon = TintedIcon:new{ file = Icons.path("back"), size = scale(back.icon_size), color = color(part.color) }
    local icon_x = outline + scale(back.padding.left)
    local label_x = icon_x + icon.size + scale(back.gap)
    local box = new_box(label_x + label:getSize().w + scale(back.padding.right) + outline, h, color(back.fill_color),
        outline, color(look.library.header.picker_outline_color))
    add(box, icon, icon_x, math.floor((h - icon.size) / 2))
    add(box, label, label_x, math.floor((h - label:getSize().h) / 2))
    return box, label
end

-- A header chip: widgets side by side, top-aligned, inside the header's picker padding and outline, on fill, rounded
-- by the header's picker radius where it has one (Frosted's pills).
function ChromeFrame.chip(widgets, fill, ctx)
    local scale, color = tools(ctx)
    local tokens = ctx.look.library.header
    local outline_color = color(tokens.picker_outline_color)
    local outline = outline_color and scale(tokens.picker_outline_width) or 0
    local pad_y = outline + scale(tokens.picker_padding.y)
    local pad_x = outline + scale(tokens.picker_padding.x)
    local w, h = 0, 0
    for _, widget in ipairs(widgets) do
        local size = widget:getSize()
        w, h = w + size.w, math.max(h, size.h)
    end
    local box = new_box(w + 2 * pad_x, h + 2 * pad_y, color(fill), outline, outline_color)
    if tokens.picker_radius > 0 then
        box.radius = scale(tokens.picker_radius)
        box.fill_radius = box.radius
    end
    local x = pad_x
    for _, widget in ipairs(widgets) do
        add(box, widget, x, pad_y)
        x = x + widget:getSize().w
    end
    return box
end

-- The header frame under ctx, w wide and spec.height tall: the band in spec.band's colour; spec.right's
-- widgets laid right to left; the left column, spec.aside, if any, over spec.title, with the back mark before
-- the title when spec.back; then the edge. With spec.back_label, the detail header (ChromeFrame.detail_header_height
-- tall) puts the back control on its own row at the top. Returns the header and its parts: rect, aside,
-- title, back, back_place, title_place, title_rect, back_rect, back_label and right (each widget's rect).
function ChromeFrame.header(ctx, w, spec)
    local scale, color, line_height = tools(ctx)
    local tokens = ctx.look.library.header
    local padding = spec.back_label and ctx.look.shelf.detail.padding or tokens.padding
    local h = spec.height
    local box = new_box(w, h, color(spec.band))
    local parts = { rect = Geom:new{ x = 0, y = 0, w = w, h = h }, right = {} }
    local side, gap = scale(padding.side), scale(tokens.picker_gap)
    local edge = scale(tokens.edge_width)
    local bottom = h - edge - scale(padding.bottom)
    if spec.back_label then
        local control
        control, parts.back_label = back_control(ctx, spec.back_label)
        local size = control:getSize()
        parts.back_rect = Geom:new{ x = side, y = scale(padding.top), w = size.w, h = size.h }
        add(box, control, side, parts.back_rect.y)
    end
    local x = w - side
    for i, widget in ipairs(spec.right) do
        local size = widget:getSize()
        parts.right[i] = Geom:new{ x = x - size.w, y = bottom - size.h, w = size.w, h = size.h }
        x = parts.right[i].x - gap
    end
    for i = #spec.right, 1, -1 do
        add(box, spec.right[i], parts.right[i].x, parts.right[i].y)
    end
    local column_w = math.max(1, x - side)
    local title_h = line_height(spec.title.part)
    local title_y = bottom - title_h
    if spec.aside then
        parts.aside = Typeset.line(spec.aside.part, spec.aside.text, column_w, ctx)
        add(box, parts.aside, side, title_y - scale(tokens.line_gap) - parts.aside:getSize().h)
    end
    local title_x = side
    if spec.back then
        -- Sized to the title's line, as LibraryTiles.header_height counts it.
        parts.back = TintedIcon:new{ file = Icons.path("back"), size = title_h, color = color(spec.title.part.color) }
        parts.back_place = { x = side, y = title_y }
        add(box, parts.back, side, title_y)
        title_x = side + title_h
    end
    parts.title = Typeset.line(spec.title.part, spec.title.text, math.max(1, column_w - (title_x - side)), ctx)
    parts.title_place = { x = title_x, y = title_y }
    add(box, parts.title, title_x, title_y)
    if parts.back then
        parts.title_rect = Geom:new{ x = side, y = title_y, w = title_x - side + parts.title:getSize().w, h = title_h }
    end
    local edge_color = color(tokens.edge_color)
    if edge > 0 and edge_color then
        add(box, Paint.Fill:new{ dimen = Geom:new{ w = w, h = edge }, color = edge_color }, 0, h - edge)
    end
    return box, parts
end

-- The reader list header's height under ctx: the taller of the back control and the title, its padding and the edge.
function ChromeFrame.list_header_height(ctx)
    local scale, _, line_height = tools(ctx)
    local header = ctx.look.library.header
    local _, back_h = back_metrics(ctx)
    return 2 * scale(ctx.look.shelf.reader_list.header_padding_y)
        + math.max(back_h, line_height(ctx.look.type.reader_list_title)) + scale(header.edge_width)
end

-- The reader list header under ctx, w wide and h tall: the back control at the left and title at the right, both
-- centred on one row, then the edge. Returns the header and its parts: rect, title, title_place, back_rect and
-- back_label.
function ChromeFrame.list_header(ctx, w, h, title)
    local scale, color = tools(ctx)
    local tokens = ctx.look.library.header
    local side = scale(ctx.look.shelf.detail.padding.side)
    local edge = scale(tokens.edge_width)
    local box = new_box(w, h, color(tokens.fill_color))
    local parts = { rect = Geom:new{ x = 0, y = 0, w = w, h = h } }
    local control
    control, parts.back_label = back_control(ctx, "Book")
    local size = control:getSize()
    parts.back_rect = Geom:new{ x = side, y = math.floor((h - edge - size.h) / 2), w = size.w, h = size.h }
    add(box, control, side, parts.back_rect.y)
    parts.title = Typeset.line(ctx.look.type.reader_list_title, title, math.max(1, w - 2 * side), ctx)
    local title_size = parts.title:getSize()
    parts.title_place = { x = w - side - title_size.w, y = math.floor((h - edge - title_size.h) / 2) }
    add(box, parts.title, parts.title_place.x, parts.title_place.y)
    local edge_color = color(tokens.edge_color)
    if edge > 0 and edge_color then
        add(box, Paint.Fill:new{ dimen = Geom:new{ w = w, h = edge }, color = edge_color }, 0, h - edge)
    end
    return box, parts
end

-- One pager button, which ("prev" or "next"): its box in the pager's fill and outline and its arrow in the
-- look's arrow colour when live, dead_color when dead, none where the look has no dead colour. Returns the
-- box and { live, arrow }.
local function button(which, live, arrow_size, ctx)
    local scale, color = tools(ctx)
    local tokens = ctx.look.library.pager
    local w, h = scale(tokens.button_w), scale(tokens.button_h)
    local outline_color = color(tokens.outline_color)
    local box = new_box(w, h, color(tokens[which .. "_fill_color"]),
        outline_color and scale(tokens.outline_width) or 0, outline_color)
    local arrow_color = color(live and tokens[which .. "_icon_color"] or tokens.dead_color)
    local parts = { live = live }
    if arrow_color then
        parts.arrow = TintedIcon:new{ file = Icons.path(which == "prev" and "back" or "forward"), size = arrow_size,
            color = arrow_color }
        add(box, parts.arrow, math.floor((w - arrow_size) / 2), math.floor((h - arrow_size) / 2))
    end
    return box, parts
end

-- The pager, centred across w with its foot bottom above y: the previous button, the page label, the next
-- button. Adds them to frame and returns { prev, next, label }, each button with its rect.
local function pager(built, frame, w, y)
    local ctx = built.ctx
    local scale = tools(ctx)
    local look = ctx.look
    local tokens = look.library.pager
    local height = LibraryTiles.pager_height(ctx)
    local band = height - scale(tokens.bottom)
    local top = y - height
    local text = tokens.label_in_words and ("Page %d of %d"):format(built.page, built.pages)
        or ("%d / %d"):format(built.page, built.pages)
    local label = Typeset.line(look.type.pager_label, text, w, ctx)
    local label_size = label:getSize()
    local prev_box, prev = button("prev", built.page > 1, label_size.h, ctx)
    local next_box, next = button("next", built.page < built.pages, label_size.h, ctx)
    local bw, bh = prev_box:getSize().w, prev_box:getSize().h
    local gap = scale(tokens.gap)
    local x = math.floor((w - (2 * bw + 2 * gap + label_size.w)) / 2)
    local by = top + math.floor((band - bh) / 2)
    prev.rect = Geom:new{ x = x, y = by, w = bw, h = bh }
    next.rect = Geom:new{ x = x + bw + gap + label_size.w + gap, y = by, w = bw, h = bh }
    add(frame, prev_box, prev.rect.x, by)
    add(frame, label, x + bw + gap, top + math.floor((band - label_size.h) / 2))
    add(frame, next_box, next.rect.x, by)
    return { prev = prev, next = next, label = label }
end

-- The foot of built: the nav bar for where ("library": Library active) at the bottom in its band,
-- and the pager above it from built.page and built.pages, which the window sets first; with no where,
-- no nav bar and the pager at the screen's foot. Adds the pager to frame (the build adds the bar
-- last) and sets built.nav and built.pager.
function ChromeFrame.foot(built, frame, where)
    local w, h = built.dimen.w, built.dimen.h
    local ctx = built.ctx
    built.nav = nil
    if where then
        local nav = NavBar.new{ look = ctx.look, variant = ctx.variant, width = w, where = where, listen = false,
            text_size = ctx.text_size }
        nav.dimen.x, nav.dimen.y = 0, h - nav.dimen.h
        built.nav = nav
        h = nav.dimen.y
    end
    built.pager = pager(built, frame, w, h)
end

-- Fills built (the window's view and page) at the screen's size in the active look and variant at the shell's
-- text size: dimen, ctx, frame, the paper, then fill(built, frame, w, h), then the nav bar, if the foot built one.
-- A failure frees what was built and raises.
function ChromeFrame.build(built, fill)
    local size = Screen:getSize()
    built.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    built.ctx = { look = Looks.active(), variant = Looks.variant(), screen = Screen,
        text_size = Layout.shell_text_size(Settings.get("text_size")) }
    built.frame = new_box(size.w, size.h)
    local ok, err = pcall(function()
        local _, color = tools(built.ctx)
        built.frame.fill_color = color("paper")
        fill(built, built.frame, size.w, size.h)
        if built.nav then
            add(built.frame, built.nav, 0, built.nav.dimen.y)
        end
    end)
    if not ok then
        built.frame:free()
        error(err, 0)
    end
    return built
end

return ChromeFrame
