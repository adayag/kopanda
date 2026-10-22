-- When you read: the last 90 days' reading per hour of day as 24 bars scaled to the busiest hour, captioned in
-- KOReader's clock format, read as frontend/datetime.lua:298-300 reads it (unset is 24-hour).
local InsightTile = require("insight_tile")
local Looks = require("looks")
local Math = require("optmath")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")

local HIGH = 0.6 -- of the busiest hour, the share at which a bar takes the high colour
local MIN_BAR = 2 -- the height of a bar for any reading at all

local Hours = {
    id = "hours",
    settings_prefix = "stats",
}

-- The captions under hours 0, 6, 12 and 18.
function Hours.captions()
    if G_reader_settings:isTrue("twelve_hour_clock") then
        return { "Midnight", "6 am", "Noon", "6 pm" }
    end
    return { "00:00", "06:00", "12:00", "18:00" }
end

-- The bars for hours (24 seconds, hour h at index h + 1) in a chart chart tall: each { h, high }, h 0 for none.
local function bars(hours, chart)
    local busiest = math.max(unpack(hours))
    local list = {}
    for i, seconds in ipairs(hours) do
        local h = 0
        if seconds > 0 then
            h = math.max(MIN_BAR, Math.round(chart * seconds / busiest))
        end
        list[i] = { h = h, high = seconds >= HIGH * busiest }
    end
    return list
end

local function compose(width, ctx)
    local look = ctx.look
    local tokens = look.insights
    local insights = ReadingStats.insights(ctx.now)
    if insights.state == "off" then
        return InsightTile.compose(width, ctx, "When you read", "Reading stats are off", 0, function() end)
    end

    local scale = Paint.scaler(ctx)
    local color = Looks.colorer(ctx)
    local fill, high = color(tokens.bar_fill_color), color(tokens.bar_high_color)
    local outline = scale(tokens.bar_outline_width)
    local outline_color = color(look.tile.outline_color)
    local gap = scale(tokens.gap)
    local chart = scale(tokens.chart_height)
    local label_gap = scale(tokens.label_gap)
    local inner_w = InsightTile.inner_width(width, ctx)
    local bar_w = math.floor((inner_w - 23 * gap) / 24)
    local step = bar_w + gap
    local list = bars(insights.hours, chart)
    local nothing = math.max(unpack(insights.hours)) == 0

    local part = look.type.insight_caption
    local captions = {}
    for i, text in ipairs(Hours.captions()) do
        local x = (i - 1) * 6 * step
        local room = i < 4 and 6 * step or inner_w - x
        captions[i] = { line = Typeset.line(part, text, room, ctx), x = x }
    end
    local content_h = chart + label_gap + Typeset.line_height(part, ctx)

    local function paint(bb, x, y)
        for i, bar in ipairs(list) do
            if bar.h > 0 then
                local bx, by = x + (i - 1) * step, y + chart - bar.h
                Paint.fill(bb, bx, by, bar_w, bar.h, bar.high and high or fill)
                if outline > 0 then
                    Paint.border(bb, bx, by, bar_w, bar.h, outline, outline_color)
                end
            end
        end
        for _, caption in ipairs(captions) do
            caption.line:paintTo(bb, x + caption.x, y + chart + label_gap)
        end
    end

    local tile = InsightTile.compose(width, ctx, "When you read", nothing and "Nothing read yet" or "last 90 days",
        content_h, paint)
    tile.captions = captions
    local free_tile = tile.free
    function tile:free()
        for _, caption in ipairs(self.captions) do
            caption.line:free()
        end
        self.captions = {}
        free_tile(self)
    end
    return tile
end

Hours.height, Hours.build = Typeset.measured(compose)

return Hours
