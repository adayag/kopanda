-- This month's hours and days read beside an area chart of the last 12 weeks' hours in an insight tile, from
-- ReadingStats.insights, the months' abbreviations from KOReader's translation table (frontend/datetime.lua:14-27).
local Helpers = require("helpers")
local InsightTile = require("insight_tile")
local Looks = require("looks")
local Math = require("optmath")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")
local datetime = require("datetime")

local WEEKS = 12

local Reading = {
    id = "reading",
    settings_prefix = "stats",
}

-- The row of t's weekday, Monday first.
local function row_of(t)
    return (tonumber(os.date("%w", t)) + 6) % 7 + 1
end

-- The noon of the day back days before t's, so a DST change never moves the day.
local function day_before(t, back)
    local day = os.date("*t", t)
    return os.time{ year = day.year, month = day.month, day = day.day - back, hour = 12 }
end

-- The two { value, caption } figures for insights (ReadingStats.insights's shape) at now: the time read and the
-- days read in now's month, up to today.
function Reading.figures(insights, now)
    local days = insights.days
    local total, read = 0, 0
    for i = math.max(1, #days - tonumber(os.date("%d", now)) + 1), #days do
        total = total + days[i]
        if days[i] > 0 then
            read = read + 1
        end
    end
    return {
        { value = Helpers.duration(total), caption = "this month" },
        { value = tostring(read), caption = read == 1 and "day read" or "days read" },
    }
end

-- The seconds read in each of the last WEEKS Monday-to-Sunday weeks to now, oldest first, this week's to today.
local function weeks_of(days, now)
    local monday = #days - row_of(now) + 1
    local weeks = {}
    for k = 1, WEEKS do
        local first = monday - (WEEKS - k) * 7
        local sum = 0
        for i = math.max(1, first), math.min(first + 6, #days) do
            sum = sum + days[i]
        end
        weeks[k] = sum
    end
    return weeks
end

-- The month captions under ctx, one at the x of each week from 2 on whose Monday falls in another month than the
-- week before's, each cut to the room right of its x.
local function month_captions(now, xs, chart_w, ctx)
    local today_row = row_of(now)
    local captions = {}
    local month = os.date("%b", day_before(now, (WEEKS - 1) * 7 + today_row - 1))
    for k = 2, WEEKS do
        local abbreviation = os.date("%b", day_before(now, (WEEKS - k) * 7 + today_row - 1))
        if abbreviation ~= month then
            month = abbreviation
            captions[#captions + 1] = {
                x = xs[k],
                line = Typeset.line(ctx.look.type.insight_caption, datetime.shortMonthTranslation[abbreviation],
                    chart_w - xs[k], ctx),
            }
        end
    end
    return captions
end

-- The height of the line above the baseline at each x from 0 to chart_w - 1, interpolated between the points
-- at xs of heights hs.
local function profile(xs, hs, chart_w)
    local list = {}
    local k = 1
    for x = 0, chart_w - 1 do
        while k < #xs - 1 and x > xs[k + 1] do
            k = k + 1
        end
        local span = xs[k + 1] - xs[k]
        local t = span > 0 and math.min(1, math.max(0, (x - xs[k]) / span)) or 0
        list[x] = Math.round(hs[k] + (hs[k + 1] - hs[k]) * t)
    end
    return list
end

local function free_lines(self)
    for _, figure in ipairs(self.figures) do
        figure.value:free()
        figure.caption:free()
    end
    for _, caption in ipairs(self.captions) do
        caption.line:free()
    end
    self.figures, self.captions = {}, {}
end

local function compose(width, ctx)
    local insights = ReadingStats.insights(ctx.now)
    if insights.state == "off" then
        return InsightTile.compose(width, ctx, "Reading", "Reading stats are off", 0, function() end)
    end

    local look = ctx.look
    local tokens = look.insights
    local scale = Paint.scaler(ctx)
    local color = Looks.colorer(ctx)
    local caption_part = look.type.insight_caption
    local caption_h = Typeset.line_height(caption_part, ctx)
    local padding, label_gap = scale(tokens.padding), scale(tokens.label_gap)
    local value_gap, record_gap = scale(tokens.value_gap), scale(tokens.record_gap)
    local inner_w = InsightTile.inner_width(width, ctx)
    local column_w = math.floor(inner_w * tokens.reading_column)

    local texts = Reading.figures(insights, ctx.now)
    local lines, value_part = InsightTile.values(look.type.insight_value, { texts[1].value, texts[2].value },
        column_w, ctx)
    local value_h = Typeset.line_height(value_part, ctx)
    local figure_h = value_h + value_gap + caption_h
    local figures = {}
    for i, text in ipairs(texts) do
        figures[i] = { value = lines[i], caption = Typeset.line(caption_part, text.caption, column_w, ctx) }
    end

    local chart_x = column_w + padding
    local chart_w = inner_w - chart_x
    local chart = scale(tokens.chart_height)
    local stroke = scale(tokens.chart_line_width)
    local hairline = look.stroke.hairline and scale(look.stroke.hairline) or 0
    local ring = scale(tokens.today_ring)
    local weeks = weeks_of(insights.days, ctx.now)
    local busiest = math.max(unpack(weeks))
    local xs, hs = {}, {}
    for k, seconds in ipairs(weeks) do
        xs[k] = Math.round((k - 1) * (chart_w - 1) / (WEEKS - 1))
        hs[k] = busiest > 0 and Math.round((chart - stroke) * seconds / busiest) or 0
    end
    local heights = profile(xs, hs, chart_w)
    local captions = month_captions(ctx.now, xs, chart_w, ctx)
    local line_color, area_color, paper = color(tokens.chart_line_color), color(tokens.chart_area_color),
        color("paper")
    local content_h = math.max(2 * figure_h + record_gap, chart + label_gap + caption_h)

    local function paint(bb, x, y)
        for i, figure in ipairs(figures) do
            local fy = y + (i - 1) * (figure_h + record_gap)
            figure.value:paintTo(bb, x, fy)
            figure.caption:paintTo(bb, x, fy + value_h + value_gap)
        end
        local left, bottom = x + chart_x, y + chart
        -- The top of the line's stroke at column cx.
        local function top_of(cx)
            return bottom - stroke - heights[cx]
        end
        for cx = 0, chart_w - 1 do
            local top = top_of(cx)
            Paint.fill(bb, left + cx, top, 1, bottom - top, area_color)
        end
        for cx = 0, chart_w - 1 do
            local a, b = top_of(cx), top_of(math.min(cx + 1, chart_w - 1))
            local from = math.min(a, b)
            Paint.fill(bb, left + cx, from, 1, math.max(a, b) - from + stroke, line_color)
        end
        if hairline > 0 then
            Paint.fill(bb, left, bottom - hairline, chart_w, hairline, line_color)
        end
        local r = math.floor(ring / 2)
        local cx, cy = left + xs[WEEKS], top_of(xs[WEEKS]) + math.floor(stroke / 2)
        Paint.fill(bb, cx - r, cy - r, 2 * r, 2 * r, paper, r)
        Paint.border(bb, cx - r, cy - r, 2 * r, 2 * r, stroke, line_color, r)
        for _, caption in ipairs(captions) do
            caption.line:paintTo(bb, left + caption.x, bottom + label_gap)
        end
    end

    local tile = InsightTile.compose(width, ctx, "Reading", "hours a week, last 12 weeks", content_h, paint)
    tile.figures, tile.captions, tile.value_size = figures, captions, value_part.size
    local free_tile = tile.free
    function tile:free()
        free_lines(self)
        free_tile(self)
    end
    return tile
end

Reading.height, Reading.build = Typeset.measured(compose)

return Reading
