-- The last twelve months' reading: one bar per calendar month from ReadingStats.insights' days, this month last,
-- each under its initial, in an insight tile with the hours read aside.
local Helpers = require("helpers")
local InsightTile = require("insight_tile")
local Looks = require("looks")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")

local COUNT = 12
local INITIALS = "JFMAMJJASOND"
local LABEL = "Last 12 months"

local Months = {
    id = "months",
}

-- Each of the COUNT months ending at now's as { month, seconds }, oldest first, from days (seconds per local day,
-- today last). Noon, so a DST change never moves a day.
function Months.totals(days, now)
    local t = os.date("*t", now)
    local list, by_month = {}, {}
    for back = COUNT - 1, 0, -1 do
        local offset = t.month - back - 1
        local entry = { month = offset % 12 + 1, seconds = 0 }
        list[#list + 1] = entry
        by_month[(t.year + math.floor(offset / 12)) * 12 + entry.month] = entry
    end
    for i, seconds in ipairs(days) do
        local day = os.date("*t", os.time{ year = t.year, month = t.month, day = t.day - (#days - i), hour = 12 })
        local entry = by_month[day.year * 12 + day.month]
        if entry then
            entry.seconds = entry.seconds + seconds
        end
    end
    return list
end

local function compose(width, ctx)
    local look = ctx.look
    local tokens = look.insights
    local insights = ReadingStats.insights(ctx.now)
    if insights.state == "off" then
        return InsightTile.compose(width, ctx, LABEL, "Reading stats are off", 0, function() end)
    end

    local scale = Paint.scaler(ctx)
    local color = Looks.colorer(ctx)
    local fill, high = color(tokens.bar_fill_color), color(tokens.bar_high_color)
    local outline = scale(tokens.bar_outline_width)
    local outline_color = color(look.tile.outline_color)
    local chart = scale(tokens.month_chart_height)
    local gap, label_gap = scale(tokens.month_gap), scale(tokens.label_gap)
    local inner_w = InsightTile.inner_width(width, ctx)
    local bar_w = math.floor((inner_w - (COUNT - 1) * gap) / COUNT)
    local step = bar_w + gap

    local totals = Months.totals(insights.days, ctx.now)
    local values, total = {}, 0
    for i, entry in ipairs(totals) do
        values[i] = entry.seconds
        total = total + entry.seconds
    end
    -- A share of 1 marks only the busiest: most months of a steady year pass the hours tile's 60 %.
    local list = InsightTile.bars(values, chart, 1)

    local part = look.type.insight_caption
    local captions = {}
    for i, entry in ipairs(totals) do
        local line = Typeset.line(part, INITIALS:sub(entry.month, entry.month), step, ctx)
        captions[i] = { line = line, x = (i - 1) * step + math.floor((bar_w - line:getSize().w) / 2) }
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

    local aside = total > 0 and Helpers.duration(total) or "Nothing read yet"
    local tile = InsightTile.compose(width, ctx, LABEL, aside, content_h, paint)
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

Months.height, Months.build = Typeset.measured(compose)

return Months
