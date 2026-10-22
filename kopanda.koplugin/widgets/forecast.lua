-- The finish-by forecast: the day the featured book ends at the last fourteen days' pace, its title and the time
-- left, in an insight tile, or what is missing for it. Weekday and month names from KOReader's translation tables
-- (frontend/datetime.lua:29-42 month names, :54-62 long day names).
local FeaturedBook = require("featured_book")
local Helpers = require("helpers")
local InsightTile = require("insight_tile")
local Paint = require("paint")
local ReadingStats = require("reading_stats")
local Typeset = require("typeset")
local datetime = require("datetime")

local PACE_DAYS = 14
local MIN_PER_DAY = 300

local Forecast = {
    id = "forecast",
    settings_prefix = "stats",
}

-- The type part each line is set in, and the token of the gap above it.
local PARTS = { "insight_value", "insight_note", "featured_authors", "featured_caption" }
local GAPS = { nil, "value_gap", "label_gap", "label_gap" }

-- The tile's lines for book (FeaturedBook.current's) and insights (ReadingStats.insights') at now: the finish day,
-- its date, the title and the caption; or "No book" or "No pace yet" and what to do, then the title when there
-- is a book.
function Forecast.lines(book, insights, now)
    if not book then
        return { "No book", "Open one and this fills in" }
    end
    local title = book.title or ""
    local days = insights.days
    if not (book.seconds_left and insights.state == "ok" and days) then
        return { "No pace yet", "Read a few pages first", title }
    end
    local sum = 0
    for i = #days - PACE_DAYS + 1, #days do
        sum = sum + days[i]
    end
    local per_day = math.max(MIN_PER_DAY, sum / PACE_DAYS)
    local days_out = math.max(0, math.ceil(book.seconds_left / per_day) - 1)
    local t = os.date("*t", now)
    local finish = os.time{ year = t.year, month = t.month, day = t.day + days_out, hour = 12 }
    local value = datetime.shortDayOfWeekToLongTranslation[os.date("%a", finish)]
    if days_out == 0 then
        value = "Today"
    elseif days_out == 1 then
        value = "Tomorrow"
    end
    return {
        value,
        tonumber(os.date("%d", finish)) .. " " .. datetime.longMonthTranslation[os.date("%B", finish)]
            .. ", at this pace",
        title,
        Helpers.duration(book.seconds_left) .. " left · " .. Helpers.duration(per_day) .. " a day",
    }
end

local function compose(width, ctx)
    local look = ctx.look
    local scale = Paint.scaler(ctx)
    local inner_w = InsightTile.inner_width(width, ctx)
    local texts = Forecast.lines(FeaturedBook.current(), ReadingStats.insights(ctx.now), ctx.now)
    local lines, ys = {}, {}
    local content_h = 0
    for i, text in ipairs(texts) do
        if GAPS[i] then
            content_h = content_h + scale(look.insights[GAPS[i]])
        end
        lines[i] = Typeset.line(look.type[PARTS[i]], text, inner_w, ctx)
        ys[i] = content_h
        content_h = content_h + lines[i]:getSize().h
    end
    local tile = InsightTile.compose(width, ctx, "Finish by", nil, content_h, function(bb, x, y)
        for i, line in ipairs(lines) do
            line:paintTo(bb, x, y + ys[i])
        end
    end)
    tile.lines = lines
    local free_tile = tile.free
    function tile:free()
        local held = self.lines
        for i = #held, 1, -1 do
            held[i]:free()
            held[i] = nil
        end
        free_tile(self)
    end
    return tile
end

Forecast.height, Forecast.build = Typeset.measured(compose)

return Forecast
