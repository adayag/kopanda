-- The sheet's layout: its spec laid out under a ctx in a variant into a panel widget, with the
-- rectangles sheet.lua matches taps against. sheet.lua's header comment gives the spec.
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local Icons = require("icons")
local Looks = require("looks")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local SheetLayout = {}

-- A filled rectangle; a colour goes through paintRectRGB32, since paintRect greys it
-- (base/ffi/blitbuffer.lua:1704-1724, :1827).
local function fill(bb, x, y, w, h, color)
    if Blitbuffer.isColor8(color) then
        bb:paintRect(x, y, w, h, color)
    else
        bb:paintRectRGB32(x, y, w, h, color)
    end
end

local function border(bb, x, y, w, h, width, color)
    if Blitbuffer.isColor8(color) then
        bb:paintBorder(x, y, w, h, width, color)
    else
        bb:paintBorderRGB32(x, y, w, h, width, color)
    end
end

-- The built panel: its fills and borders, then its widgets, each at its screen place. The
-- widgets it made are its array part, so free() reaches them; the header's cover is the
-- sheet's and is painted from self.cover.
local Panel = WidgetContainer:extend{
    name = "kopanda_sheet_panel",
}

function Panel:paintTo(bb, x, y)
    for _, part in ipairs(self.fills) do
        if part.border then
            border(bb, x + part.x, y + part.y, part.w, part.h, part.border, part.color)
        else
            fill(bb, x + part.x, y + part.y, part.w, part.h, part.color)
        end
    end
    for i, widget in ipairs(self) do
        widget:paintTo(bb, x + self.places[i].x, y + self.places[i].y)
    end
    if self.cover then
        self.cover:paintTo(bb, x + self.cover_place.x, y + self.cover_place.y)
    end
end

-- The look's type part name, in muted on a greyed row, as the launcher greys an entry.
local function part_of(look, name, muted)
    local part = look.type[name]
    if not muted then
        return part
    end
    local copy = {}
    for k, v in pairs(part) do
        copy[k] = v
    end
    copy.color = "muted"
    return copy
end

-- Lays out the sheet's spec under ctx in variant into a Panel, and returns it with the panel's
-- rectangle, the rectangle with its shadow, the header's rectangle (or nil), the hint's (or nil),
-- a heading header's parts' rectangles ({ heading, aside, hint, label }, each nil without it) and
-- the rows' places ({ row, rect, label, sublabel, detail, check }) or the body's areas ({ rect,
-- tap, hold, close_first }), all in screen coordinates, how many rows it left out and whether its body is
-- too tall for the screen. A missing icon is logged once per build.
function SheetLayout.build(spec, ctx, variant)
    local look = ctx.look
    local tokens = look.sheet
    local palette = Looks.palette(look, variant)
    local bctx = {}
    for k, v in pairs(ctx) do
        bctx[k] = v
    end
    bctx.variant = variant
    local function color(role)
        return role and Looks.color(palette[role])
    end
    local function scale(px)
        return px and ctx.screen:scaleBySize(px) or 0
    end
    local size = ctx.screen:getSize()

    local panel = Panel:new{ fills = {}, places = {} }
    -- Parts are placed relative to the panel's box first and moved to the screen at the end.
    local fills = panel.fills
    local function add_fill(x, y, w, h, role)
        local c = color(role)
        if c and w > 0 and h > 0 then
            fills[#fills + 1] = { x = x, y = y, w = w, h = h, color = c }
        end
    end
    local function add(widget, x, y)
        panel[#panel + 1] = widget
        panel.places[#panel] = { x = x, y = y }
    end

    local box_w = size.w - 2 * scale(tokens.inset.side)
    local outline = tokens.outline_color and scale(tokens.outline_width) or 0
    local rule = tokens.rule_color and scale(tokens.rule_width) or 0
    local content_x = outline + scale(tokens.padding.side)
    local content_w = box_w - 2 * content_x
    local y = outline + rule + scale(tokens.padding.top)

    -- The header.
    local header_rect, hint_rect
    local header_parts = {}
    local header = spec.header
    if header then
        local book = header.cover ~= nil
        local pad = book and tokens.book_header_padding or tokens.header_padding
        local inner_x = content_x + scale(pad.side)
        local inner_w = content_w - 2 * scale(pad.side)
        local inner_y = y + scale(pad.top)
        local inner_h
        if book then
            local cover = header.cover
            local cover_size = cover:getSize()
            local column_x = inner_x + cover_size.w + scale(tokens.cover_gap)
            local column_w = inner_w - cover_size.w - scale(tokens.cover_gap)
            local lines = {}
            for _, line in ipairs({ { "sheet_title", header.title }, { "sheet_author", header.author },
                    { "sheet_meta", header.meta } }) do
                if line[2] then
                    lines[#lines + 1] = {
                        widget = Typeset.line(look.type[line[1]], line[2], column_w, bctx),
                        meta = line[1] == "sheet_meta",
                    }
                end
            end
            local column_h = 0
            for i, line in ipairs(lines) do
                if i > 1 then
                    line.gap = scale(tokens.line_gap) + (line.meta and scale(tokens.meta_gap) or 0)
                    column_h = column_h + line.gap
                end
                column_h = column_h + line.widget:getSize().h
            end
            inner_h = math.max(cover_size.h, column_h)
            panel.cover = cover
            panel.cover_place = { x = inner_x, y = inner_y + math.floor((inner_h - cover_size.h) / 2) }
            local line_y = inner_y + math.floor((inner_h - column_h) / 2)
            for _, line in ipairs(lines) do
                line_y = line_y + (line.gap or 0)
                add(line.widget, column_x, line_y)
                line_y = line_y + line.widget:getSize().h
            end
        else
            local gap = scale(tokens.aside_gap)
            -- The label at the header's right (SortC.dc.html:43), built first so the heading's
            -- column leaves room for it.
            local label, column_w = nil, inner_w
            if header.label then
                label = Typeset.line(look.type.sheet_label, header.label, inner_w, bctx)
                column_w = math.max(1, inner_w - label:getSize().w - gap)
            end
            local heading = Typeset.line(look.type.sheet_heading, header.heading or "", column_w, bctx)
            local heading_w = heading:getSize().w
            local parts = { { widget = heading, x = inner_x, name = "heading" } }
            if label then
                parts[#parts + 1] = { widget = label, x = inner_x + inner_w - label:getSize().w, name = "label" }
            end
            -- What the heading, and an aside beside it, leave on the header's left.
            local left_w = heading_w
            -- The aside stacked above the heading (SortC.dc.html:39-41), its own line.
            local above_h = 0
            if header.aside and header.aside_above then
                local above = Typeset.line(look.type.sheet_aside, header.aside, column_w, bctx)
                local above_size = above:getSize()
                add(above, inner_x, inner_y)
                header_parts.aside = { x = inner_x, y = inner_y, w = above_size.w, h = above_size.h }
                above_h = above_size.h + scale(tokens.aside_above_gap)
            elseif header.aside then
                local aside = Typeset.line(look.type.sheet_aside, header.aside,
                    math.max(1, inner_w - heading_w - gap), bctx)
                local aside_w = aside:getSize().w
                local x = header.aside_beside and inner_x + heading_w + gap or inner_x + inner_w - aside_w
                parts[#parts + 1] = { widget = aside, x = x, name = "aside" }
                if header.aside_beside then
                    left_w = heading_w + gap + aside_w
                end
            end
            -- The hint at the header's right (FolderOpen.dc.html:40).
            if header.hint then
                local hint = Typeset.line(look.type.sheet_aside, header.hint,
                    math.max(1, inner_w - left_w - gap), bctx)
                local hint_size = hint:getSize()
                local part = { widget = hint, x = inner_x + inner_w - hint_size.w, name = "hint" }
                parts[#parts + 1] = part
                hint_rect = part
            end
            -- On one baseline, as the boards align them (HoldHome:35-37), under an aside above.
            local ascent, descent = 0, 0
            for _, part in ipairs(parts) do
                part.baseline = Typeset.baseline(part.widget)
                ascent = math.max(ascent, part.baseline)
                descent = math.max(descent, part.widget:getSize().h - part.baseline)
            end
            inner_h = above_h + ascent + descent
            for _, part in ipairs(parts) do
                part.y = inner_y + above_h + ascent - part.baseline
                add(part.widget, part.x, part.y)
                local part_size = part.widget:getSize()
                header_parts[part.name] = { x = part.x, y = part.y, w = part_size.w, h = part_size.h }
            end
            if hint_rect then
                local hint_size = hint_rect.widget:getSize()
                hint_rect = { x = hint_rect.x, y = hint_rect.y, w = hint_size.w, h = hint_size.h }
            end
        end
        local header_h = scale(pad.top) + inner_h + scale(pad.bottom)
        if tokens.header_band and spec.band then
            add_fill(content_x, y, content_w, header_h, tokens[spec.band .. "_band_color"])
        end
        header_rect = { x = content_x, y = y, w = content_w, h = header_h }
        y = y + header_h
        local header_rule = scale(tokens.header_rule_width)
        add_fill(content_x, y, content_w, header_rule, tokens.header_rule_color)
        y = y + header_rule
    end

    -- A body in place of rows, for a spec with no rows: its widget under the header at the
    -- content's left, its areas moved from the body's top-left.
    local areas = {}
    local body = not spec.rows and spec.body
    if body then
        local made = body(bctx, content_w)
        add(made.widget, content_x, y)
        for i, area in ipairs(made.areas or {}) do
            local rect = area.rect
            areas[i] = { rect = { x = content_x + rect.x, y = y + rect.y, w = rect.w, h = rect.h },
                tap = area.tap, hold = area.hold, close_first = area.close_first }
        end
        y = y + made.widget:getSize().h
    end

    -- The rows, each built in full before any is placed.
    local pad_x, pad_y = scale(tokens.row_padding.x), scale(tokens.row_padding.y)
    local icon_size, row_gap = scale(tokens.icon_size), scale(tokens.row_gap)
    local row_w = content_w - 2 * pad_x
    local indent = spec.flush and 0 or icon_size + row_gap
    local built, unknown = {}, {}
    local function build_row(row)
        local b = { row = row }
        local ink = row.muted and "muted" or "ink"
        local icon_id = row.tick and "check" or row.icon
        local file = icon_id and Icons.path(icon_id)
        if file then
            b.icon = TintedIcon:new{ file = file, size = icon_size, color = color(ink) }
        elseif icon_id and not unknown[icon_id] then
            unknown[icon_id] = true
            logger.warn("KoPanda: the sheet", spec.name, "has no icon", icon_id, "; its place is left blank")
        end
        local room = row_w - indent
        -- The selected row's check at its right (SortC.dc.html:50).
        if row.selected then
            b.check = TintedIcon:new{ file = Icons.path("check"), size = icon_size, color = color("ink") }
            room = room - icon_size - row_gap
        end
        if row.detail then
            local chip_role = row.chip and tokens[row.chip .. "_chip_color"]
            if chip_role then
                local chip_outline = scale(tokens.chip_outline_width)
                local cx, cy = scale(tokens.chip_padding.x) + chip_outline, scale(tokens.chip_padding.y) + chip_outline
                -- A chip on paper sets its text in ink (HoldEmptyC.dc.html:47): sheet_chip's
                -- on_accent is the night paper itself by night.
                local chip_part = chip_role == "paper" and "sheet_chip_plain" or "sheet_chip"
                b.detail = Typeset.line(part_of(look, chip_part, row.muted), row.detail,
                    math.max(1, room - 2 * cx), bctx)
                local text = b.detail:getSize()
                b.chip = { w = text.w + 2 * cx, h = text.h + 2 * cy, inset_x = cx, inset_y = cy,
                    outline = chip_outline, fill = chip_role }
                b.detail_w, b.detail_h = b.chip.w, b.chip.h
            else
                b.detail = Typeset.line(part_of(look, "sheet_detail", row.muted), row.detail, math.max(1, room), bctx)
                local text = b.detail:getSize()
                b.detail_w, b.detail_h = text.w, text.h
            end
            room = room - b.detail_w - row_gap
        end
        b.label = Typeset.line(part_of(look, "sheet_row", row.muted), row.label or "", math.max(1, room), bctx)
        b.text_h = b.label:getSize().h
        -- The second line under the label (SortC.dc.html:46-48).
        if row.sublabel then
            b.sublabel = Typeset.line(part_of(look, "sheet_sublabel", row.muted), row.sublabel, math.max(1, room), bctx)
            b.text_h = b.text_h + scale(tokens.sublabel_gap) + b.sublabel:getSize().h
        end
        b.content_h = math.max(icon_size, b.text_h, b.detail_h or 0)
        return b
    end
    for _, row in ipairs(spec.rows or {}) do
        built[#built + 1] = build_row(row)
    end

    -- As many rows as fit above the screen's foot less the inset; the last kept one takes the
    -- last row's foot and no rule. height(n, tail) is the panel's with the first n rows, and
    -- tail, a built row, after them.
    local row_rule = scale(tokens.row_rule_width)
    local foot = scale(tokens.padding.bottom) + outline
    local last_bottom = scale(tokens.last_row_bottom)
    local max_h = size.h - scale(tokens.inset.bottom)
    local kept = #built
    local function height(n, tail)
        local count = n + (tail and 1 or 0)
        local h = y + foot
        for i = 1, count do
            local b = i <= n and built[i] or tail
            h = h + pad_y + b.content_h + (i < count and pad_y + row_rule or last_bottom)
        end
        return h
    end
    while kept > 0 and height(kept) > max_h do
        kept = kept - 1
    end
    local function free_row(b)
        for _, widget in pairs({ b.icon, b.detail, b.label, b.sublabel, b.check }) do
            widget:free()
        end
    end
    -- With spec.more, rows left out after at least one that fits are paged: the last slot that
    -- fits beside one or more rows takes a More row, whose run hands spec.more.run the rows
    -- after the ones kept, in order. Without a row beside it, it would page nothing, so the rows
    -- are left out as without more.
    local more
    if spec.more and kept > 0 and kept < #built then
        local has_icons = false
        for _, row in ipairs(spec.rows) do
            has_icons = has_icons or row.icon ~= nil
        end
        more = build_row({ label = spec.more.label or "More…", icon = has_icons and "list" or nil })
        local n = kept
        while n > 0 and height(n, more) > max_h do
            n = n - 1
        end
        if n > 0 then
            kept = n
            local rest = {}
            for i = kept + 1, #built do
                rest[#rest + 1] = built[i].row
            end
            local run = spec.more.run
            more.row.run = function()
                run(rest)
            end
        else
            free_row(more)
            more = nil
        end
    end
    local left_out = more and 0 or #built - kept
    for i = kept + 1, #built do
        free_row(built[i])
        built[i] = nil
    end
    built[#built + 1] = more

    local rows = {}
    for i, b in ipairs(built) do
        local last = i == #built
        local row_h = pad_y + b.content_h + (last and last_bottom or pad_y)
        local cy = y + pad_y
        local x = content_x + pad_x
        local function middle(h)
            return cy + math.floor((b.content_h - h) / 2)
        end
        add_fill(content_x, y, content_w, row_h, b.row.selected and tokens.selected_fill_color)
        if b.icon then
            add(b.icon, x, middle(icon_size))
        end
        local label_size = b.label:getSize()
        local label = { x = x + indent, y = middle(b.text_h), w = label_size.w, h = label_size.h }
        add(b.label, label.x, label.y)
        local sublabel
        if b.sublabel then
            local sub_size = b.sublabel:getSize()
            sublabel = { x = label.x, y = label.y + label.h + scale(tokens.sublabel_gap), w = sub_size.w,
                h = sub_size.h }
            add(b.sublabel, sublabel.x, sublabel.y)
        end
        local check
        if b.check then
            check = { x = x + row_w - icon_size, y = middle(icon_size), w = icon_size, h = icon_size }
            add(b.check, check.x, check.y)
        end
        local detail
        if b.detail then
            local right = x + row_w - (check and icon_size + row_gap or 0)
            detail = { x = right - b.detail_w, y = middle(b.detail_h), w = b.detail_w, h = b.detail_h }
            local chip = b.chip
            if chip then
                add_fill(detail.x, detail.y, detail.w, detail.h, chip.fill)
                local outline_color = color("outline")
                if chip.outline > 0 and outline_color then
                    fills[#fills + 1] = { x = detail.x, y = detail.y, w = detail.w, h = detail.h,
                        border = chip.outline, color = outline_color }
                end
                add(b.detail, detail.x + chip.inset_x, detail.y + chip.inset_y)
            else
                add(b.detail, detail.x, detail.y)
            end
        end
        rows[i] = { row = b.row, rect = { x = content_x, y = y, w = content_w, h = row_h }, label = label,
            sublabel = sublabel, detail = detail, check = check }
        y = y + row_h
        if not last then
            add_fill(content_x, y, content_w, row_rule, tokens.row_rule_color)
            y = y + row_rule
        end
    end
    local box_h = y + foot

    -- The box's chrome under everything placed so far: the shadow, the fill, Editorial's rule;
    -- Diner's outline over it all.
    local chrome = {}
    local shadow = look.shadow.sheet
    local shadow_x, shadow_y = 0, 0
    local shadow_color = color(shadow.color)
    if shadow_color then
        shadow_x, shadow_y = scale(shadow.x), scale(shadow.y)
        chrome[#chrome + 1] = { x = shadow_x, y = shadow_y, w = box_w, h = box_h, color = shadow_color }
    end
    local fill_color = color(tokens.fill_color)
    if fill_color then
        chrome[#chrome + 1] = { x = 0, y = 0, w = box_w, h = box_h, color = fill_color }
    end
    local rule_color = color(tokens.rule_color)
    if rule > 0 and rule_color then
        chrome[#chrome + 1] = { x = 0, y = 0, w = box_w, h = rule, color = rule_color }
    end
    for _, part in ipairs(fills) do
        chrome[#chrome + 1] = part
    end
    local outline_color = color(tokens.outline_color)
    if outline > 0 and outline_color then
        chrome[#chrome + 1] = { x = 0, y = 0, w = box_w, h = box_h, border = outline, color = outline_color }
    end
    panel.fills = chrome

    -- To the screen: the box on the bottom edge less the inset.
    local box_x = scale(tokens.inset.side)
    local box_y = size.h - scale(tokens.inset.bottom) - box_h
    -- A body can't be cut as rows are: one too tall sits at the screen's top.
    local too_tall = false
    if body and box_y < 0 then
        box_y, too_tall = 0, true
    end
    local function moved(rect)
        return rect and Geom:new{ x = box_x + rect.x, y = box_y + rect.y, w = rect.w, h = rect.h }
    end
    for _, part in ipairs(chrome) do
        part.x, part.y = box_x + part.x, box_y + part.y
    end
    for _, place in ipairs(panel.places) do
        place.x, place.y = box_x + place.x, box_y + place.y
    end
    if panel.cover_place then
        panel.cover_place.x, panel.cover_place.y = box_x + panel.cover_place.x, box_y + panel.cover_place.y
    end
    for _, row in ipairs(rows) do
        row.rect, row.label, row.detail = moved(row.rect), moved(row.label), moved(row.detail)
        row.sublabel, row.check = moved(row.sublabel), moved(row.check)
    end
    for name, rect in pairs(header_parts) do
        header_parts[name] = moved(rect)
    end
    for _, area in ipairs(areas) do
        area.rect = moved(area.rect)
    end
    panel.dimen = Geom:new{ x = box_x, y = box_y, w = box_w, h = box_h }
    return {
        widget = panel,
        panel = Geom:new{ x = box_x, y = box_y, w = box_w, h = box_h },
        rect = Geom:new{ x = box_x, y = box_y, w = box_w + shadow_x, h = box_h + shadow_y },
        header = moved(header_rect),
        hint = moved(hint_rect),
        header_parts = header_parts,
        rows = rows,
        areas = areas,
        left_out = left_out,
        too_tall = too_tall,
    }
end

return SheetLayout
