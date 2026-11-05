-- When you read: the busiest part of the day over the last 12 weeks' reading per hour of day as 24 bars scaled to the
-- busiest hour, captioned in KOReader's clock format, read as frontend/datetime.lua:298-300 reads it (unset is
-- 24-hour).
local InsightTile = require("insight_tile")
local Looks = require("looks")
local Math = require("optmath")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")

local Hours = {
    id = "hours",
}

-- The captions under hours 0, 6, 12 and 18.
function Hours.captions()
    if G_reader_settings:isTrue("twelve_hour_clock") then
        return { "Midnight", "6 am", "Noon", "6 pm" }
    end
    return { "00:00", "06:00", "12:00", "18:00" }
end

-- The parts of the day in tie-break order, each its hours as { from, to } inclusive.
local PARTS = {
    { name = "Mornings", { 5, 11 } },
    { name = "Afternoons", { 12, 16 } },
    { name = "Evenings", { 17, 21 } },
    { name = "Nights", { 22, 23 }, { 0, 4 } },
}

-- The busiest part of the day in hours (seconds per hour of day, hour 0 first): { part, share, peak }, share a whole
-- percent of all the reading and peak the busiest hour; nil with no reading.
function Hours.headline(hours)
    local total, peak = 0, 0
    for i, seconds in ipairs(hours) do
        total = total + seconds
        if seconds > hours[peak + 1] then
            peak = i - 1
        end
    end
    if total == 0 then
        return nil
    end
    local best, best_seconds
    for _, part in ipairs(PARTS) do
        local sum = 0
        for _, span in ipairs(part) do
            for hour = span[1], span[2] do
                sum = sum + hours[hour + 1]
            end
        end
        if not best or sum > best_seconds then
            best, best_seconds = part.name, sum
        end
    end
    return { part = best, share = Math.round(best_seconds * 100 / total), peak = peak }
end

function Hours.clock(hour)
    if not G_reader_settings:isTrue("twelve_hour_clock") then
        return string.format("%02d:00", hour)
    end
    if hour == 0 or hour == 12 then
        return hour == 0 and "Midnight" or "Noon"
    end
    return hour % 12 .. (hour < 12 and " am" or " pm")
end

-- The lines for headline (Hours.headline's) in inner_w, their height above the chart and the value's size.
local function headline_lines(headline, inner_w, ctx)
    local look = ctx.look
    local tokens = look.insights
    local scale = Paint.scaler(ctx)
    local caption = look.type.insight_caption
    local values, value_part = Typeset.fitted(look.type.insight_value, { headline.part }, inner_w, ctx)
    local value_h = Typeset.line_height(value_part, ctx)
    local value_gap = scale(tokens.value_gap)
    local text = string.format("%d%% of your reading, peak %s", headline.share, Hours.clock(headline.peak))
    return {
        value = values[1],
        caption = Typeset.line(caption, text, inner_w, ctx),
        caption_y = value_h + value_gap,
        height = value_h + value_gap + Typeset.line_height(caption, ctx) + scale(tokens.label_gap),
        value_size = value_part.size,
    }
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
    local list = InsightTile.bars(insights.hours, chart)
    local headline = Hours.headline(insights.hours)
    local lines = headline and headline_lines(headline, inner_w, ctx)
    local top = lines and lines.height or 0

    local part = look.type.insight_caption
    local captions = {}
    for i, text in ipairs(Hours.captions()) do
        local x = (i - 1) * 6 * step
        local room = i < 4 and 6 * step or inner_w - x
        captions[i] = { line = Typeset.line(part, text, room, ctx), x = x }
    end
    local content_h = top + chart + label_gap + Typeset.line_height(part, ctx)

    local function paint(bb, x, content_y)
        if lines then
            lines.value:paintTo(bb, x, content_y)
            lines.caption:paintTo(bb, x, content_y + lines.caption_y)
        end
        local y = content_y + top
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

    local tile = InsightTile.compose(width, ctx, "When you read", headline and "last 12 weeks" or "Nothing read yet",
        content_h, paint)
    tile.captions, tile.headline, tile.value_size = captions, lines, lines and lines.value_size
    local free_tile = tile.free
    function tile:free()
        for _, caption in ipairs(self.captions) do
            caption.line:free()
        end
        self.captions = {}
        if self.headline then
            self.headline.value:free()
            self.headline.caption:free()
            self.headline = nil
        end
        free_tile(self)
    end
    return tile
end

Hours.height, Hours.build = Typeset.measured(compose)

return Hours
