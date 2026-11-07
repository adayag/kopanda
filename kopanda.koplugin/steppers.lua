-- The steppers: bars of a label and its value over a − / + pair, one or two to a row, each row closed by a section
-- rule, and rows of icon-over-label cells, drawn into a body in the look's quick_settings tokens as the quick-settings
-- sheet draws its light and toggles. The minus and plus are "−" (U+2212) and "+" in the quick_button part: U+2212
-- draws in every look's face, where U+0378, an unassigned code point, draws the missing-glyph box.
local Icons = require("icons")
local Layout = require("layout")
local Looks = require("looks")
local Paint = require("paint")
local TintedIcon = require("tinted_icon")
local Typeset = require("typeset")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Steppers = {}

local MINUS, PLUS = "\u{2212}", "+"

-- A body: its fills and outlines ({ x, y, w, h, color, border }), then its lines and icons, the array part, each at
-- places[i], all from the body's top-left; free() reaches the array part.
local Body = WidgetContainer:extend{
    name = "kopanda_steppers",
}

function Body:paintTo(bb, x, y)
    for _, part in ipairs(self.fills) do
        if part.border then
            Paint.border(bb, x + part.x, y + part.y, part.w, part.h, part.border, part.color)
        else
            Paint.fill(bb, x + part.x, y + part.y, part.w, part.h, part.color)
        end
    end
    for i, widget in ipairs(self) do
        widget:paintTo(bb, x + self.places[i].x, y + self.places[i].y)
    end
end

Steppers.Body = Body

-- What draws into body under bctx: color(role), scale(px), add(widget, x, y), fill(x, y, w, h, role) and
-- outline(x, y, w, h, width, role), which returns its width in pixels, 0 without a colour. A role without a
-- colour, or a fill with no area, draws nothing.
function Steppers.pen(body, bctx)
    local palette = Looks.palette(bctx.look, bctx.variant)
    local pen = {}
    function pen.color(role)
        return role and Looks.color(palette[role])
    end
    function pen.scale(px)
        return bctx.screen:scaleBySize(px)
    end
    function pen.add(widget, x, y)
        body[#body + 1] = widget
        body.places[#body] = { x = x, y = y }
    end
    function pen.fill(x, y, w, h, role)
        local c = pen.color(role)
        if c and w > 0 and h > 0 then
            body.fills[#body.fills + 1] = { x = x, y = y, w = w, h = h, color = c }
        end
    end
    function pen.outline(x, y, w, h, width, role)
        local c = pen.color(role)
        if not c then
            return 0
        end
        local px = pen.scale(width)
        if px > 0 then
            body.fills[#body.fills + 1] = { x = x, y = y, w = w, h = h, border = px, color = c }
        end
        return px
    end
    return pen
end

-- Draws bars into body from y down, content_w wide, under bctx (the sheet's build ctx), a bar's beside sharing its row.
-- Returns the y under the last bar and the areas { id, rect, tap, hold }, rect from the body's top-left, each bar's
-- id .. "_minus" then id .. "_plus", a bar before the one beside it. A greyed bar's areas are inert.
function Steppers.draw(body, bctx, content_w, y, bars)
    local look = bctx.look
    local qs = look.quick_settings
    local pen = Steppers.pen(body, bctx)
    local scale, add, fill, outline = pen.scale, pen.add, pen.fill, pen.outline
    local pad_x = scale(qs.padding_x)
    local inner_w = content_w - 2 * pad_x
    local label_part, button_part = look.type.quick_label, look.type.quick_button
    local bw = Layout.size_at(scale(qs.button_w), bctx.text_size)
    local bh = Layout.size_at(scale(qs.button_h), bctx.text_size)
    local gap = scale(qs.control_gap)
    local pair_gap = scale(qs.pair_gap)
    local level_outline = qs.level_outline_color and scale(qs.level_outline_width) or 0
    local level_h = Layout.size_at(scale(qs.level_h), bctx.text_size) + 2 * level_outline
    local areas = {}

    -- Draws bar at left, width wide, from top: returns the y under its buttons.
    local function one(bar, left, width, top)
        local mid_x, mid_w = left + bw + gap, width - 2 * (bw + gap)
        -- The label and value on one line.
        local value = Typeset.line(label_part, bar.value_text, width, bctx)
        local value_size = value:getSize()
        local label = Typeset.line(label_part, bar.label, math.max(1, width - value_size.w), bctx)
        local label_size = label:getSize()
        local row_h = math.max(label_size.h, value_size.h)
        add(label, left, top + row_h - label_size.h)
        add(value, left + width - value_size.w, top + row_h - value_size.h)
        local row_y = top + row_h + scale(qs.section_gap)

        -- The control row: minus, the level bar centred on the buttons, plus.
        for _, button in ipairs({ { "minus", left, MINUS }, { "plus", left + width - bw, PLUS } }) do
            local x = button[2]
            fill(x, row_y, bw, bh, qs.button_fill_color)
            outline(x, row_y, bw, bh, qs.button_outline_width, qs.button_outline_color)
            local glyph = Typeset.line(button_part, button[3], bw, bctx)
            local size = glyph:getSize()
            add(glyph, x + math.floor((bw - size.w) / 2), row_y + math.floor((bh - size.h) / 2))
            -- A greyed bar's buttons are inert: their touch is consumed.
            local actions = not bar.greyed and bar[button[1]] or {}
            areas[#areas + 1] = { id = bar.id .. "_" .. button[1], rect = { x = x, y = row_y, w = bw, h = bh },
                tap = actions.tap, hold = actions.hold }
        end
        local level = bar.level
        if level then
            local level_y = row_y + math.floor((bh - level_h) / 2)
            fill(mid_x, level_y, mid_w, level_h, qs.level_track_color)
            if not bar.greyed and level.max > level.min then
                local share = math.min(1, math.max(0, (level.value - level.min) / (level.max - level.min)))
                fill(mid_x + level_outline, level_y + level_outline,
                    math.floor((mid_w - 2 * level_outline) * share), level_h - 2 * level_outline,
                    qs.level_fill_color)
            end
            outline(mid_x, level_y, mid_w, level_h, qs.level_outline_width, qs.level_outline_color)
        end
        return row_y + bh
    end

    for i, bar in ipairs(bars) do
        local pad = i == 1 and qs.first_section_padding or qs.section_padding
        y = y + scale(pad.top)
        if bar.beside then
            local half = math.floor((inner_w - pair_gap) / 2)
            one(bar, pad_x, half, y)
            y = one(bar.beside, pad_x + half + pair_gap, half, y)
        else
            y = one(bar, pad_x, inner_w, y)
        end
        y = y + scale(pad.bottom)
        local rule = qs.section_rule_color and scale(qs.section_rule_width) or 0
        fill(0, y, content_w, rule, qs.section_rule_color)
        y = y + rule
    end
    return y, areas
end

-- A copy of a type part in another palette role.
local function in_role(part, role)
    local copy = {}
    for k, v in pairs(part) do
        copy[k] = v
    end
    copy.color = role
    return copy
end

-- Draws one row of cells into body at y, content_w wide, under bctx, in equal columns as tall as the tallest cell.
-- A cell is { label, icon, on, greyed }: on fills it, greyed mutes it, and its icon sits over its label. Returns the
-- y under the row and each cell's rect, from the body's top-left.
function Steppers.cells(body, bctx, content_w, y, cells)
    local look = bctx.look
    local qs = look.quick_settings
    local pen = Steppers.pen(body, bctx)
    local color, scale, add, fill, outline = pen.color, pen.scale, pen.add, pen.fill, pen.outline
    local pad_x = scale(qs.padding_x)
    local shares = {}
    for i = 1, #cells do
        shares[i] = { share = 1 }
    end
    local columns = Layout.columns(content_w - 2 * pad_x, shares, qs.grid_gap)
    local icon_size = Layout.size_at(scale(qs.cell_icon_size), bctx.text_size)
    local cell_outline = qs.cell_outline_color and scale(qs.cell_outline_width) or 0
    local cell_top = cell_outline + scale(qs.cell_padding.top)
    local cell_bottom = scale(qs.cell_padding.bottom) + cell_outline
    local built, row_h = {}, 0
    for c, cell in ipairs(cells) do
        local w = columns[c].w
        local filled = cell.on and not cell.greyed
        local role = cell.greyed and "muted" or filled and qs.on_text_color or look.type.quick_cell.color
        local label = Typeset.line(in_role(look.type.quick_cell, role), cell.label,
            math.max(1, w - 2 * cell_outline), bctx)
        local file = Icons.path(cell.icon)
        local icon = file and TintedIcon:new{ file = file, size = icon_size, color = color(role) }
        built[c] = { label = label, icon = icon, filled = filled }
        local label_h = label:getSize().h
        row_h = math.max(row_h, cell_top + icon_size + scale(qs.cell_gap) + label_h + cell_bottom)
    end
    local rects = {}
    for c, b in ipairs(built) do
        local x, w = pad_x + columns[c].x, columns[c].w
        fill(x, y, w, row_h, b.filled and qs.on_fill_color or qs.cell_fill_color)
        outline(x, y, w, row_h, qs.cell_outline_width, qs.cell_outline_color)
        local size = b.label:getSize()
        if b.icon then
            add(b.icon, x + math.floor((w - icon_size) / 2), y + cell_top)
        end
        add(b.label, x + math.floor((w - size.w) / 2), y + cell_top + icon_size + scale(qs.cell_gap))
        rects[c] = { x = x, y = y, w = w, h = row_h }
    end
    return y + row_h, rects
end

return Steppers
