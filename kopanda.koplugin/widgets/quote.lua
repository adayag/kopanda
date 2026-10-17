-- The quote of the day: one entry of the quote source a day, changing at local midnight, drawn
-- in curly quotes with no attribution in at most four lines, a longer text ending in an
-- ellipsis. Editorial draws it between hairline rules (Main.dc.html:56), Diner in its tile.
-- Module state: the memo of the text box last composed, which every build of the day draws.
local Device = require("device")
local Font = require("ui/font")
local Fonts = require("fonts")
local Geom = require("ui/geometry")
local Layout = require("layout")
local Looks = require("looks")
local Math = require("optmath")
local Paint = require("paint")
local Settings = require("settings")
local TextBoxWidget = require("ui/widget/textboxwidget")
local Typeset = require("typeset")
local Widget = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local LINES = 4
-- Between the chrome and the text, board pixels (Main.dc.html:56).
local PADDING = 18

local Quote = {
    id = "quote",
    settings_prefix = "quote",
}

-- The entry lists by quote.source value; the spec puts lists of its own here.
Quote.sources = {
    builtin = require("quotes"),
}

local function entries()
    return Quote.sources[Settings.get("quote.source")] or {}
end

-- Local calendar days from 1970-01-01 to t's day. Counted from the day's noon, so a DST change
-- never moves the day.
local function local_days(t)
    local day = os.date("*t", t)
    return math.floor(os.time{ year = day.year, month = day.month, day = day.day, hour = 12 } / 86400)
end

-- The index of the entry for the day of t, or nil when the source has none.
function Quote.index(t)
    local count = #entries()
    if count == 0 then
        return nil
    end
    return local_days(t) % count + 1
end

-- The text box last composed, as { key, box, holders }. key is what the box is drawn from, all
-- fixed for a day: the text; the face's hash, which holds its file and scaled size
-- (frontend/ui/font.lua:286-288); the text width; the look and variant, which fix the colours and
-- line height; and whether the screen renders colour, which picks the box's buffer type
-- (frontend/ui/widget/textboxwidget.lua:853-860). holders counts the quotes built on the box that
-- haven't let it go. A box the memo has moved on from is freed when its last holder lets go, so
-- the memo holds one box and a quote still shown never paints a freed one.
local memo

local function same(a, b)
    for name, value in pairs(a) do
        if b[name] ~= value then
            return false
        end
    end
    return true
end

-- The memo's entry for key, its box made by make when the memo holds another, taken by one more
-- holder.
local function hold(key, make)
    if not (memo and same(memo.key, key)) then
        local old = memo
        memo = { key = key, box = make(), holders = 0 }
        if old and old.holders == 0 then
            old.box:free()
        end
    end
    memo.holders = memo.holders + 1
    return memo
end

local function release(entry)
    entry.holders = entry.holders - 1
    if entry.holders == 0 and entry ~= memo then
        entry.box:free()
    end
end

-- The text box (self.text_box, the memo's) at self.text_x, self.text_y inside its chrome: rules
-- across the top and bottom, or a tile with a hard shadow. The box is shared by every quote drawn
-- from the memo's entry, so it is held outside the container's list, which WidgetContainer's free
-- and event propagation walk (frontend/ui/widget/container/widgetcontainer.lua:110-117, :80-89):
-- a TextBoxWidget frees itself on the CloseWidget that UIManager:close sends
-- (frontend/ui/widget/textboxwidget.lua:1280-1283, frontend/ui/uimanager.lua:300).
local QuoteBox = WidgetContainer:extend{
    name = "kopanda_quote",
}

-- Lets go of the memo's box, once, on free or on close.
function QuoteBox:free()
    local held = self.held
    if held then
        self.held = nil
        release(held)
    end
end

function QuoteBox:onCloseWidget()
    self:free()
end

function QuoteBox:paintTo(bb, x, y)
    local w, h = self.dimen.w, self.dimen.h
    local c = self.chrome
    if c.rule then
        Paint.fill(bb, x, y, w, c.rule, c.rule_color)
        Paint.fill(bb, x, y + h - c.rule, w, c.rule, c.rule_color)
    else
        local box_w, box_h = w - c.shadow_x, h - c.shadow_y
        Paint.backing(bb, x, y, box_w, box_h, c)
        Paint.outline(bb, x, y, box_w, box_h, c)
    end
    self.text_box:paintTo(bb, x + self.text_x, y + self.text_y)
end

-- The quote laid out at width under ctx: a QuoteBox, or a blank box of height 0 when the source
-- has no entry.
local function compose(width, ctx)
    local list = entries()
    local index = Quote.index(ctx.now)
    if not index then
        return Widget:new{ dimen = Geom:new{ w = width, h = 0 } }
    end
    local look = ctx.look
    local palette = Looks.palette(look, ctx.variant)
    local function color(role)
        return role and Looks.color(palette[role])
    end
    local function scale(px)
        return ctx.screen:scaleBySize(px)
    end

    local style = look.type.quote
    local size = Layout.font_size(style.size, ctx.text_size)
    local face = Fonts.face(look.faces[style.face].file, size) or Font:getFace("cfont", size)
    local padding = scale(PADDING)

    local chrome, text_x, text_y, text_w, extra_h
    if look.tile.box then
        local shadow = look.shadow.tile
        local outline = scale(look.stroke.outline)
        chrome = {
            outline = outline,
            outline_color = color(look.tile.outline_color),
            fill_color = color(look.tile.fill_color),
            shadow_color = color(shadow.color),
            shadow_x = shadow.color and scale(shadow.x) or 0,
            shadow_y = shadow.color and scale(shadow.y) or 0,
        }
        text_x, text_y = outline + padding, outline + padding
        text_w = width - chrome.shadow_x - 2 * (outline + padding)
        extra_h = 2 * (outline + padding) + chrome.shadow_y
    else
        local rule = scale(look.stroke.hairline)
        chrome = { rule = rule, rule_color = color("hairline") }
        text_x, text_y = 0, rule + padding
        text_w = width
        extra_h = 2 * (rule + padding)
    end

    -- TextBoxWidget's line is (1 + line_height) em, rounded (frontend/ui/widget/textboxwidget.lua:151).
    local line_px = Math.round((1 + style.line_height) * face.size)
    local text = "“" .. list[index].text .. "”"
    local key = {
        text = text,
        face = face.hash,
        width = text_w,
        look = look,
        variant = ctx.variant,
        color = Device.screen:isColorEnabled(),
    }
    local held = hold(key, function()
        return TextBoxWidget:new{
            text = text,
            face = face,
            width = text_w,
            line_height = style.line_height,
            fgcolor = color(style.color),
            bgcolor = chrome.fill_color or color("paper"),
            height = LINES * line_px,
            height_adjust = true,
            height_overflow_show_ellipsis = true,
        }
    end)
    return QuoteBox:new{
        dimen = Geom:new{ w = width, h = held.box:getSize().h + extra_h },
        chrome = chrome,
        text_box = held.box,
        held = held,
        text_x = text_x,
        text_y = text_y,
    }
end

-- The height at width is the laid-out text and its chrome; the build that follows hands over
-- the box height laid out.
Quote.height, Quote.build = Typeset.measured(compose)

return Quote
