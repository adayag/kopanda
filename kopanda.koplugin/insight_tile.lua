-- The chrome the insight widgets share: the quote's tile (a box with its outline and shadow, rules in a look
-- without a tile box, nothing on a plate) around a label line, with an optional right-aligned aside, and the
-- content each widget paints beneath it.
local Geom = require("ui/geometry")
local Looks = require("looks")
local Paint = require("paint")
local Typeset = require("typeset")
local Widget = require("ui/widget/widget")

local InsightTile = {}

-- The chrome at width under ctx, the inset of its inner box and that box's width, and the height it adds.
local function chrome_of(width, ctx)
    local look = ctx.look
    local color = Looks.colorer(ctx)
    local scale = Paint.scaler(ctx)
    local padding = scale(look.insights.padding)
    if Typeset.on_plate(ctx) then
        return { plain = true }, 0, padding, width, 2 * padding
    end
    if look.tile.box then
        local shadow = look.shadow.tile
        local outline = scale(look.stroke.outline)
        local chrome = {
            outline = outline,
            outline_color = color(look.tile.outline_color),
            fill_color = color(look.tile.fill_color),
            shadow_color = color(shadow.color),
            shadow_x = shadow.color and scale(shadow.x) or 0,
            shadow_y = shadow.color and scale(shadow.y) or 0,
        }
        local inset = outline + padding
        return chrome, inset, inset, width - chrome.shadow_x - 2 * inset, 2 * inset + chrome.shadow_y
    end
    local rule = scale(look.stroke.hairline)
    return { rule = rule, rule_color = color(look.tile.rule_color) }, 0, rule + padding, width,
        2 * (rule + padding)
end

local Tile = Widget:extend{
    name = "kopanda_insight_tile",
}

function Tile:free()
    for _, name in ipairs({ "label", "aside" }) do
        local line = self[name]
        if line then
            self[name] = nil
            line:free()
        end
    end
end

function Tile:onCloseWidget()
    self:free()
end

function Tile:paintTo(bb, x, y)
    local w, h = self.dimen.w, self.dimen.h
    local c = self.chrome
    if c.rule then
        Paint.fill(bb, x, y, w, c.rule, c.rule_color)
        Paint.fill(bb, x, y + h - c.rule, w, c.rule, c.rule_color)
    elseif not c.plain then
        Paint.backing(bb, x, y, w - c.shadow_x, h - c.shadow_y, c)
    end
    local inner_x, inner_y = x + self.inner_x, y + self.inner_y
    if self.label then
        self.label:paintTo(bb, inner_x, inner_y)
    end
    if self.aside then
        self.aside:paintTo(bb, x + self.aside_x, inner_y + self.aside_y)
    end
    self.paint(bb, inner_x, inner_y + self.content_y, self.inner_w, self.content_h, self.ctx)
    if not (c.rule or c.plain) then
        Paint.outline(bb, x, y, w - c.shadow_x, h - c.shadow_y, c)
    end
end

-- The content's width inside the chrome and padding of a tile width wide under ctx.
function InsightTile.inner_width(width, ctx)
    local _, _, _, inner_w = chrome_of(width, ctx)
    return inner_w
end

-- A tile width wide holding label (and aside, right-aligned on its line, when given) above content_h of content,
-- which paint(bb, x, y, inner_w, content_h, ctx) draws at its top-left; and inner, { w, label_h }. The label is
-- cut to the room the aside leaves it, label_gap short of it.
function InsightTile.compose(width, ctx, label, aside, content_h, paint)
    local look = ctx.look
    local chrome, inner_x, inner_y, inner_w, extra_h = chrome_of(width, ctx)
    local label_part = look.type.insight_label
    local label_h = Typeset.line_height(label_part, ctx)
    local gap = Paint.scaler(ctx)(look.insights.label_gap)

    local aside_line, aside_x, aside_y
    local label_room = inner_w
    if aside then
        aside_line = Typeset.line(look.type.insight_caption, aside, inner_w, ctx)
        local aside_w = aside_line:getSize().w
        aside_x = inner_x + inner_w - aside_w
        label_room = inner_w - aside_w - gap
    end
    local label_line = Typeset.line(label_part, label, label_room, ctx)
    if aside_line then
        aside_y = Typeset.baseline(label_line) - Typeset.baseline(aside_line)
    end

    return Tile:new{
        dimen = Geom:new{ w = width, h = extra_h + label_h + gap + content_h },
        chrome = chrome,
        ctx = ctx,
        label = label_line,
        aside = aside_line,
        aside_x = aside_x,
        aside_y = aside_y,
        inner_x = inner_x,
        inner_y = inner_y,
        inner_w = inner_w,
        content_y = label_h + gap,
        content_h = content_h,
        paint = paint,
    }, { w = inner_w, label_h = label_h }
end

return InsightTile
